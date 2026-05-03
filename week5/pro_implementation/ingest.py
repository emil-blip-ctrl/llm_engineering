import time
from pathlib import Path
from openai import OpenAI
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from chromadb import PersistentClient
from tqdm import tqdm
from litellm import completion

from concurrent.futures import ThreadPoolExecutor, as_completed
from tenacity import retry, wait_exponential, stop_after_attempt

load_dotenv(override=True)

# =========================
# CONFIG (same variables kept)
# =========================

MODEL = "openai/gpt-5.4-mini"
DB_NAME = str(Path(__file__).parent.parent / "preprocessed_db")
collection_name = "docs"
embedding_model = "text-embedding-3-large"
KNOWLEDGE_BASE_PATH = Path(__file__).parent.parent / "knowledge-base"
AVERAGE_CHUNK_SIZE = 400  # increased for fewer chunks

wait = wait_exponential(multiplier=1, min=2, max=20)

WORKERS = 3
EMBED_BATCH_SIZE = 256
MAX_RETRIES = 3

openai = OpenAI()

# =========================
# MODELS (UNCHANGED)
# =========================

class Result(BaseModel):
    page_content: str
    metadata: dict


class Chunk(BaseModel):
    headline: str = Field(...)
    summary: str = Field(...)
    original_text: str = Field(...)

    def as_result(self, document):
        metadata = {"source": document["source"], "type": document["type"]}
        return Result(
            page_content=self.headline + "\n\n" + self.summary + "\n\n" + self.original_text,
            metadata=metadata,
        )


class Chunks(BaseModel):
    chunks: list[Chunk]


# =========================
# FUNCTIONS (ALL NAMES PRESERVED)
# =========================

def fetch_documents():
    documents = []

    for folder in KNOWLEDGE_BASE_PATH.iterdir():
        doc_type = folder.name
        for file in folder.rglob("*.md"):
            with open(file, "r", encoding="utf-8") as f:
                documents.append({
                    "type": doc_type,
                    "source": file.as_posix(),
                    "text": f.read()
                })

    print(f"📄 Loaded {len(documents)} documents")
    return documents


def make_prompt(document):
    how_many = max(1, len(document["text"]) // AVERAGE_CHUNK_SIZE)

    return f"""
Split this document into chunks for retrieval.

- Ensure full coverage
- Include overlap (~20%)
- Each chunk must include:
  - headline
  - summary
  - original_text

Document type: {document["type"]}
Source: {document["source"]}

Document:
{document["text"]}
"""


def make_messages(document):
    return [{"role": "user", "content": make_prompt(document)}]


@retry(wait=wait, stop=stop_after_attempt(MAX_RETRIES))
def process_document(document):
    start = time.time()

    response = completion(
        model=MODEL,
        messages=make_messages(document),
        response_format=Chunks,
        max_retries=0,
    )

    reply = response.choices[0].message.content
    doc_chunks = Chunks.model_validate_json(reply).chunks

    print(f"⏱ Chunked {document['source']} in {time.time() - start:.2f}s")

    return [chunk.as_result(document) for chunk in doc_chunks]


def create_chunks(documents):
    """
    SAME FUNCTION NAME, improved internals:
    - replaced multiprocessing with ThreadPool (safer for APIs)
    """
    chunks = []

    print("🔄 Creating chunks...")

    with ThreadPoolExecutor(max_workers=WORKERS) as executor:
        futures = [executor.submit(process_document, doc) for doc in documents]

        for future in tqdm(as_completed(futures), total=len(futures)):
            try:
                chunks.extend(future.result())
            except Exception as e:
                print(f"❌ Error processing document: {e}")

    print(f"✅ Created {len(chunks)} chunks")
    return chunks


def _batch_list(lst, batch_size):
    """internal helper (does not affect API)"""
    for i in range(0, len(lst), batch_size):
        yield lst[i:i + batch_size]


def create_embeddings(chunks):
    """
    SAME FUNCTION NAME, fixed:
    - batching added (fixes 2048 error)
    """
    chroma = PersistentClient(path=DB_NAME)

    if collection_name in [c.name for c in chroma.list_collections()]:
        chroma.delete_collection(collection_name)

    collection = chroma.get_or_create_collection(collection_name)

    texts = [chunk.page_content for chunk in chunks]
    metas = [chunk.metadata for chunk in chunks]
    ids = [str(i) for i in range(len(chunks))]

    print(f"🧠 Creating embeddings for {len(texts)} chunks...")

    all_vectors = []

    for batch in tqdm(list(_batch_list(texts, EMBED_BATCH_SIZE))):
        try:
            res = openai.embeddings.create(
                model=embedding_model,
                input=batch
            )
            all_vectors.extend([e.embedding for e in res.data])
        except Exception as e:
            print(f"❌ Embedding batch failed: {e}")

    print(f"📦 Storing embeddings...")

    collection.add(
        ids=ids,
        embeddings=all_vectors,
        documents=texts,
        metadatas=metas
    )

    print(f"✅ Vectorstore created with {collection.count()} documents")


# =========================
# MAIN (UNCHANGED)
# =========================

if __name__ == "__main__":
    start_total = time.time()

    documents = fetch_documents()
    chunks = create_chunks(documents)
    create_embeddings(chunks)

    print(f"\n🚀 Ingestion complete in {time.time() - start_total:.2f}s")