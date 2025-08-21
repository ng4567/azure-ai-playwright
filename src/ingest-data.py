from dotenv import load_dotenv
import os
import glob
import hashlib
from typing import List
from openai import AzureOpenAI
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import ResourceNotFoundError
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchFieldDataType,
    VectorSearch,
    VectorSearchProfile,
    HnswAlgorithmConfiguration,
    SearchField,
)
from pathlib import Path
load_dotenv()

service_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
search_admin_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
credential=AzureKeyCredential(search_admin_key)
INDEX_NAME = "md-medicaid"
REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
AOAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AOAI_API_KEY = os.getenv("AZURE_OPENAI_API_KEY")
AOAI_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-06-01")
AOAI_EMBED_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBED_DEPLOYMENT", "text-embedding-3-small")
EMBED_DIMS = int(os.getenv("AZURE_OPENAI_EMBED_DIMS", "1536"))

aoai_client = AzureOpenAI(
    api_key=AOAI_API_KEY,
    api_version=AOAI_API_VERSION,
    azure_endpoint=AOAI_ENDPOINT,
)


index_client = SearchIndexClient(endpoint=service_endpoint, credential=credential)
search_client = SearchClient(endpoint=service_endpoint, index_name=INDEX_NAME, credential=AzureKeyCredential(search_admin_key))

def ensure_index():
    try:
        index_client.get_index(INDEX_NAME)  # will raise if not found
        print(f"Index '{INDEX_NAME}' already exists.")
        return
    except ResourceNotFoundError:
        print(f"Index '{INDEX_NAME}' does not exist. Creating it now...")

        # Minimal schema: id (key), content (searchable), path/title (filterable & facetable if you want)
    fields = [
        SimpleField(name="id",      type=SearchFieldDataType.String, key=True,  filterable=True, sortable=True),
        SearchableField(name="content", analyzer_name="en.lucene"),  # full-text searchable
        SimpleField(name="path",    type=SearchFieldDataType.String, filterable=True, sortable=True, facetable=True),
        SimpleField(name="title",   type=SearchFieldDataType.String, filterable=True, sortable=True),
        SimpleField(name="length",  type=SearchFieldDataType.Int32,  filterable=True, sortable=True),
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=EMBED_DIMS,
            vector_search_profile_name="vpr-hnsw",
        ),
    ]

    index = SearchIndex(
        name=INDEX_NAME,
        fields=fields,
        vector_search=VectorSearch(
            algorithms=[HnswAlgorithmConfiguration(name="algo-hnsw")],
            profiles=[VectorSearchProfile(name="vpr-hnsw", algorithm_configuration_name="algo-hnsw")],
        ),
    )
    index_client.create_index(index)
    print(f"Created index '{INDEX_NAME}'.")

def get_embedding(text: str) -> List[float]:
    if not AOAI_ENDPOINT or not AOAI_API_KEY:
        raise RuntimeError("Azure OpenAI environment variables are not set. Please set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_API_KEY.")
    # Trim excessively long inputs to avoid model token limits (simple char-based truncate)
    snippet = text if len(text) <= 16000 else text[:16000]
    resp = aoai_client.embeddings.create(
        input=snippet,
        model=AOAI_EMBED_DEPLOYMENT,
    )
    vec = resp.data[0].embedding
    if len(vec) != EMBED_DIMS:
        raise RuntimeError(f"Embedding length {len(vec)} does not match EMBED_DIMS {EMBED_DIMS}. Check your deployment and AZURE_OPENAI_EMBED_DIMS.")
    return vec

def file_to_doc(path: str) -> dict:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()
    # stable id: hash of path+size; avoids dupes on re-runs
    stat = os.stat(path)
    h = hashlib.sha1(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()
    doc = {
    "id": h,
    "content": text,
    "path": os.path.abspath(path),
    "title": os.path.basename(path),
    "length": len(text),
    }
    try:
        doc["embedding"] = get_embedding(text)
    except Exception as e:
        # Surface a clear error so the user can fix env/config
        raise RuntimeError(f"Failed to create embedding for {path}: {e}")
    return doc


def load_txt_files(directory: str):
    paths = sorted(glob.glob(os.path.join(directory, "**", "*.txt"), recursive=True))
    for p in paths:
        yield file_to_doc(p)

def upload_documents(batch_iterable, batch_size=1000):
    batch = []
    uploaded = 0
    for doc in batch_iterable:
        batch.append(doc)
        if len(batch) >= batch_size:
            results = search_client.upload_documents(documents=batch)
            uploaded += sum(1 for r in results if r.succeeded)
            print(f"Uploaded batch, total uploaded: {uploaded}")
            batch = []
    if batch:
        results = search_client.upload_documents(documents=batch)
        uploaded += sum(1 for r in results if r.succeeded)
        print(f"Uploaded final batch, total uploaded: {uploaded}")

if __name__ == "__main__":
    if not service_endpoint or not search_admin_key:
        raise SystemExit("Set AZURE_SEARCH_ENDPOINT and AZURE_SEARCH_ADMIN_KEY environment variables first.")

    ensure_index()
    upload_documents(load_txt_files(DATA_DIR), batch_size=500)
    print("Done.")
