from semantic_kernel.connectors.azure_ai_search import AzureAISearchStore
import os
from dotenv import load_dotenv

load_dotenv()
AZURE_AI_SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT")
AZURE_AI_SEARCH_API_KEY = os.getenv("AZURE_SEARCH_ADMIN_KEY")

vector_store = AzureAISearchStore(AZURE_AI_SEARCH_ENDPOINT, AZURE_AI_SEARCH_API_KEY)
