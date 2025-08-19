from dotenv import load_dotenv
import os
import json
import os
import glob
import hashlib
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import ResourceNotFoundError
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchFieldDataType,
)
from pathlib import Path
load_dotenv()

service_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
search_admin_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
credential=AzureKeyCredential(search_admin_key)
INDEX_NAME = "md-medicaid"
REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"

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
    ]
    index = SearchIndex(name=INDEX_NAME, fields=fields)
    index_client.create_index(index)
    print(f"Created index '{INDEX_NAME}'.")


def file_to_doc(path: str) -> dict:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()
    # stable id: hash of path+size; avoids dupes on re-runs
    stat = os.stat(path)
    h = hashlib.sha1(f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()
    return {
        "id": h,
        "content": text,
        "path": os.path.abspath(path),
        "title": os.path.basename(path),
        "length": len(text),
    }

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
