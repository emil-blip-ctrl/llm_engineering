
"""
Modal embedding service for the ACE RAG project.

Responsibilities:
- Define the Modal Linux environment and dependencies.
- Load Qwen3-Embedding-8B on a GPU.
- Expose a remote method for embedding document chunks and queries.
- Provide a simple smoke test for deployment.

Chroma, query expansion, reranking, and answer generation will be
implemented separately.
"""

from __future__ import annotations
from typing import Literal
from app import app
import modal

# Configuration
EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-8B"

GPU = "A100"

MODEL_CACHE_DIR = "/root/.cache/huggingface"

# Conservative initial settings; tune after measuring performance.
MAX_LENGTH = 8192
DEFAULT_BATCH_SIZE = 4

QUERY_INSTRUCTION = (
    "Given an ACE technical documentation question, "
    "retrieve passages that answer the question."
)


# ---------------------------------------------------------
# Modal environment
# ---------------------------------------------------------

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "torch",
        "transformers>=4.51.0",
        "accelerate",
        "huggingface_hub",
    )
    .env({"HF_HOME": MODEL_CACHE_DIR})
    .add_local_python_source("app")
)


# ---------------------------------------------------------
# Embedding service
# ---------------------------------------------------------

@app.cls(
    image=image,
    gpu=GPU,
    timeout=900,
    scaledown_window=300,
)
class EmbeddingService:
    """Modal worker that loads and reuses the embedding model."""

    @modal.enter()
    def load_model(self) -> None:
        """Load the tokenizer and model when the worker starts."""
        import torch
        import torch.nn.functional as F
        from transformers import AutoModel, AutoTokenizer

        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        if self.device != "cuda":
            raise RuntimeError(
                "CUDA GPU unavailable. Check the Modal GPU configuration."
            )

        self.tokenizer = AutoTokenizer.from_pretrained(
            EMBEDDING_MODEL,
            padding_side="left",
            trust_remote_code=True,
        )

        self.model = AutoModel.from_pretrained(
            EMBEDDING_MODEL,
            torch_dtype=torch.float16,
            device_map="cuda",
            trust_remote_code=True,
        )

        self.model.eval()
        self.normalize = F.normalize

    @modal.method()
    def embed_texts(
        self,
        texts: list[str],
        input_type: Literal["document", "query"] = "document",
        batch_size: int = DEFAULT_BATCH_SIZE,
    ) -> list[list[float]]:
        """
        Convert texts into L2-normalized embedding vectors.

        input_type="document": ACE documentation chunks.
        input_type="query": user questions or expanded queries.

        Returns one vector per input text.
        """
        import torch

        if input_type not in ("document", "query"):
            raise ValueError(
                "input_type must be 'document' or 'query'."
            )

        if batch_size < 1:
            raise ValueError("batch_size must be at least 1.")

        if not texts:
            return []

        prepared_texts = []

        for text in texts:
            cleaned = text.strip()

            if not cleaned:
                raise ValueError("Input texts must not be empty.")

            if input_type == "query":
                cleaned = (
                    f"Instruct: {QUERY_INSTRUCTION}\n"
                    f"Query: {cleaned}"
                )

            prepared_texts.append(cleaned)

        all_embeddings = []

        for start in range(0, len(prepared_texts), batch_size):
            batch = prepared_texts[start : start + batch_size]

            encoded = self.tokenizer(
                batch,
                padding=True,
                truncation=True,
                max_length=MAX_LENGTH,
                return_tensors="pt",
            )

            encoded = {
                key: value.to(self.device)
                for key, value in encoded.items()
            }

            with torch.inference_mode():
                outputs = self.model(**encoded)

                # Qwen3-Embedding uses last-token pooling.
                # Left padding makes the last position the final real token.
                embeddings = outputs.last_hidden_state[:, -1, :]

                # Normalize vectors for cosine-similarity retrieval.
                embeddings = self.normalize(
                    embeddings,
                    p=2,
                    dim=1,
                )

            all_embeddings.extend(
                embeddings.float().cpu().tolist()
            )

        return all_embeddings
