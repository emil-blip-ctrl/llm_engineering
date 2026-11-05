from __future__ import annotations
from pathlib import Path

PROJECT_ROOT = Path().cwd

DOC_DIR = PROJECT_ROOT / "docs"
DOC_PATH = DOC_DIR / "ace12-user_guide.txt"

EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-8B"
LLM = "gpt5-mini"

CHUNKS_PER_QUERY = 10
DEFAULT_QUERY_COUNT = 4
DEFAULT_FINAL_TOP_K = 5

HF_DATASET_REPO = "emitev/ace-rag-data"

MODAL_APP_NAME = "ace-rag"
MODAL_VOLUME_NAME = "ace-rag-chroma"

CHROMA_PERSIST_DIR = Path("/data/chroma")
CHROMA_COLLECTION_NAME = "ace_documentation"

