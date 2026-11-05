
"""Embedding orchestration for the ACE RAG project."""

from typing import Iterator


DEFAULT_EMBEDDING_BATCH_SIZE = 16
MODAL_INFERENCE_BATCH_SIZE = 4


def batched(items: list, batch_size: int) -> Iterator[list]:
    """Yield consecutive batches from a list."""
    if batch_size < 1:
        raise ValueError("batch_size must be at least 1.")

    for start in range(0, len(items), batch_size):
        yield items[start:start + batch_size]


def embed_chunks(
    chunks: list[dict],
    embedding_service,
    batch_size: int = DEFAULT_EMBEDDING_BATCH_SIZE,
    inference_batch_size: int = MODAL_INFERENCE_BATCH_SIZE,
) -> list[dict]:
    """
    Generate embeddings for enriched chunks using Modal.

    Returns chunks with an additional 'embedding' field.
    """

    if not chunks:
        return []

    embedded_chunks = []

    for batch_number, batch in enumerate(
        batched(chunks, batch_size), start=1
    ):
        texts = [chunk["text"] for chunk in batch]

        vectors = embedding_service.embed_texts.remote(
            texts,
            input_type="document",
            batch_size=inference_batch_size,
        )

        if len(vectors) != len(batch):
            raise RuntimeError(
                "Embedding count does not match chunk count."
            )

        for chunk, vector in zip(batch, vectors):
            embedded_chunks.append({
                **chunk,
                "embedding": vector,
            })

        print(
            f"Embedded batch {batch_number}: "
            f"{len(embedded_chunks)} chunks completed"
        )

    return embedded_chunks
