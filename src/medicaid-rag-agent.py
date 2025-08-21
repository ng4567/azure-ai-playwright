import os
import asyncio
from dotenv import load_dotenv
from openai import AzureOpenAI
from azure.ai.translation.text import TextTranslationClient
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import HttpResponseError

# Find repo root by going one level up from src/
dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(dotenv_path)

# --- Azure AI Search config ---
AZURE_AI_SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT") or os.getenv("AZURE_AI_SEARCH_ENDPOINT")
AZURE_AI_SEARCH_API_KEY = os.getenv("AZURE_SEARCH_ADMIN_KEY") or os.getenv("AZURE_AI_SEARCH_API_KEY")
AZURE_AI_SEARCH_INDEX = os.getenv("AZURE_AI_SEARCH_INDEX_NAME", "md-medicaid")

# --- Azure OpenAI (Embeddings) config ---
AOAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AOAI_API_KEY = os.getenv("AZURE_OPENAI_API_KEY")
AOAI_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-06-01")
AOAI_EMBED_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBED_DEPLOYMENT", "text-embedding-3-small")
EMBED_DIMS = int(os.getenv("AZURE_OPENAI_EMBED_DIMS", "1536"))


# Azure OpenAI client for query embeddings
embed_client = AzureOpenAI(
    api_key=AOAI_API_KEY,
    api_version=AOAI_API_VERSION,
    azure_endpoint=AOAI_ENDPOINT,
)

# 3) Create an Azure OpenAI client for chat completions (RAG)
chat_client = AzureOpenAI(
    api_version="2024-12-01-preview",
    azure_endpoint="https://nikhi-mcw43lm0-eastus2.cognitiveservices.azure.com/openai/deployments/gpt-5-chat/chat/completions?api-version=2025-01-01-preview",
    api_key=AOAI_API_KEY
)

CHAT_MODEL = os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-4o-mini")

async def search_documents(query: str, top_k: int = 5):
    """Search the Azure AI Search index for relevant documents"""
    from azure.core.credentials import AzureKeyCredential
    from azure.search.documents.aio import SearchClient
    
    # Use Azure SDK directly for more control
    search_client = SearchClient(
        endpoint=AZURE_AI_SEARCH_ENDPOINT,
        index_name=AZURE_AI_SEARCH_INDEX,
        credential=AzureKeyCredential(AZURE_AI_SEARCH_API_KEY)
    )
    
    documents = []
    
    try:
        # First try hybrid search with vector
        # Generate embedding for the query using Azure OpenAI directly
        if not AOAI_ENDPOINT or not AOAI_API_KEY:
            print(f"⚠️  Missing embedding configuration. Skipping vector search.")
            raise ValueError("Missing Azure OpenAI configuration for embeddings")
            
        embed_client = AzureOpenAI(
            api_key=os.getenv("AZURE_OPENAI_EMBEDDING_KEY"),
            api_version=os.getenv("AZURE_OPENAI_EMBEDDING_API_VERSION"),
            azure_deployment=os.getenv("AZURE_OPENAI_EMBED_MODEL_NAME"),
            azure_endpoint=os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT")
        )
        
        try:
            response = embed_client.embeddings.create(
                input=query,
                model=AOAI_EMBED_DEPLOYMENT
            )
            query_vector = response.data[0].embedding
        except Exception as embed_error:
            print(f"⚠️  Embedding generation failed: {embed_error}")
            print(f"   Deployment: {AOAI_EMBED_DEPLOYMENT}")
            print(f"   Endpoint: {AOAI_ENDPOINT}")
            raise
        
        # Perform vector search
        from azure.search.documents.models import VectorizedQuery
        
        vector_query = VectorizedQuery(
            vector=query_vector.tolist() if hasattr(query_vector, 'tolist') else list(query_vector),
            fields="embedding",
            k_nearest_neighbors=top_k
        )
        
        results = await search_client.search(
            search_text=query,
            vector_queries=[vector_query],
            top=top_k,
            select=["id", "title", "content", "path", "length"]
        )
        
        async for result in results:
            documents.append({
                'id': result.get('id', ''),
                'content': result.get('content', ''),
                'title': result.get('title', ''),
                'path': result.get('path', ''),
                'score': result.get('@search.score', 0)
            })
            
    except Exception as e:
        print(f"Vector search failed: {e}")
        print("Falling back to text-only search...")
        
        # Fallback to text-only search
        try:
            results = await search_client.search(
                search_text=query,
                top=top_k,
                select=["id", "title", "content", "path", "length"]
            )
            
            async for result in results:
                documents.append({
                    'id': result.get('id', ''),
                    'content': result.get('content', ''),
                    'title': result.get('title', ''),
                    'path': result.get('path', ''),
                    'score': result.get('@search.score', 0)
                })
        except Exception as e2:
            print(f"Text search also failed: {e2}")
    
    finally:
        await search_client.close()
    
    return documents

def create_rag_prompt(query: str, documents: list) -> str:
    """Create a prompt for RAG with retrieved documents"""
    context = "\n\n".join([
        f"Document: {doc['title']}\n{doc['content'][:1000]}..."
        if len(doc['content']) > 1000 else f"Document: {doc['title']}\n{doc['content']}"
        for doc in documents
    ])
    
    prompt = f"""You are a helpful assistant that answers questions about Medicaid based on the provided context.

Context from documents:
{context}

User Question: {query}

Please answer the question based on the context provided above. If the answer is not in the context, say so."""
    
    return prompt

async def rag_query(query: str):
    """Perform RAG: retrieve relevant documents and generate an answer"""
    print(f"\n🔍 Searching for: '{query}'")
    print("-" * 60)
    
    # Step 1: Retrieve relevant documents
    documents = await search_documents(query, top_k=3)
    
    if not documents:
        print("❌ No relevant documents found.")
        return
    
    print(f"✅ Found {len(documents)} relevant documents:")
    for i, doc in enumerate(documents, 1):
        print(f"   {i}. {doc['title']} (score: {doc['score']:.4f})")
    
    # Step 2: Create RAG prompt
    prompt = create_rag_prompt(query, documents)
    
    # Step 3: Generate response using Azure OpenAI
    print("\n🤖 Generating response...")
    try:
        response = chat_client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[
                {"role": "system", "content": "You are a helpful assistant that provides accurate information about Medicaid."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=500
        )
        
        answer = response.choices[0].message.content
        print(f"\n💬 Answer:\n{answer}")
        
        # Show sources
        print("\n📚 Sources:")
        for doc in documents:
            print(f"   - {doc['title']} ({doc['path']})")

        return answer
            
    except Exception as e:
        print(f"❌ Error generating response: {e}")

async def translate_query(query: str):
    key = os.getenv("AZURE_TRANSLATOR_KEY")
    endpoint = os.getenv("AZURE_TRANSLATOR_ENDPOINT")
    region = os.getenv("AZURE_TRANSLATOR_REGION")

    credential = AzureKeyCredential(key)
    text_translator = TextTranslationClient(credential=credential, region=region)

    try:
        to_language = ["fr", "es"]
        input_text_elements = [query]

        response = text_translator.translate(body=input_text_elements, to_language=to_language)
        translation = response[0] if response else None

        if translation:
            detected_language = translation.detected_language
            if detected_language:
                print(
                    f"Detected languages of the input text: {detected_language.language} with score: {detected_language.score}."
                )
            for translated_text in translation.translations:
                print(f"Text was translated to: '{translated_text.to}' and the result is: '{translated_text.text}'.")

    except HttpResponseError as exception:
        if exception.error is not None:
            print(f"Error Code: {exception.error.code}")
            print(f"Message: {exception.error.message}")

async def main(query: str):
    """Main function to execute a RAG query"""
    print("🏥 Medicaid RAG System")
    print("=" * 60)
    
    response = await rag_query(query)
    print(f"\n")
    
    print(f"Translated response in French and Spanish using Azure AI Translator:")
    await translate_query(response)
    
if __name__ == "__main__":
    # You can change this query to whatever you want to ask
    user_query = "Which disability benefits are availabile if I become disbabled while working?"
    
    # Or pass it as a command line argument
    import sys
    if len(sys.argv) > 1:
        user_query = " ".join(sys.argv[1:])
    
    asyncio.run(main(user_query))