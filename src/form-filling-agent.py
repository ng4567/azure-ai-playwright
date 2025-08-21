import os
from dotenv import load_dotenv
from openai import AsyncAzureOpenAI
from json import loads
import asyncio

#check if json file with data exists ../output/conduent_contact_form_fields.json
json_file = '../output/conduent_contact_form_fields.json'
assert os.path.exists(json_file), "conduent_contact_form_fields.json file does not exist, please run contact-form-scraper.py script first to generate the data!"
dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(dotenv_path)

# --- Azure OpenAI config ---
AOAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AOAI_API_KEY = os.getenv("AZURE_OPENAI_API_KEY")
AOAI_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-06-01")

chat_client = AsyncAzureOpenAI(
    api_version="2024-12-01-preview",
    azure_endpoint=os.getenv("CHAT_CLIENT_ENDPOINT"),
    api_key=AOAI_API_KEY
)

CHAT_MODEL = os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-5")

def parse_form_fields(path: str) -> list[str]:
    """Parse form fields and return array of field names"""
    with open(path, 'r') as f:
        json_data = loads(f.read())
    # Extract fields array from the JSON structure
    form_fields = json_data.get("fields", [])
    return [field["name"] for field in form_fields if "name" in field and field["name"]]

async def chat_with_agent(prompt: str) -> str:
    system_prompt = """
    You are a helpful assistant that can parse form fields and return array of field names. 
    You are going to be given a list of fields from a web scraper that parsed a contact us form. 
    Figure out which list of fields are likely to be real fillable elements. Some like cnd_language and description are not real fillable elements.
    Extract the field names.

    Next, pretend you are actually filling out the form. 
    You are a customer of conduent reaching out to support on behalf of the NY State Department of Transportation. 
    For each field in the form, create a sample value and return the filled out form in a JSON format.

    Your response should only contain the final JSON. Don't write anything else.
    """


    response = await chat_client.chat.completions.create(
        model=CHAT_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt}
        ]
    )
    print(f"LLM response: {response.choices[0].message.content}")
    return response.choices[0].message.content

def main():
    parsed_form_fields = parse_form_fields(json_file)
    print(f"Found {len(parsed_form_fields)} form fields: {parsed_form_fields}")
    
    # Convert list to string for the agent
    fields_str = f"Here are the form fields I found: {', '.join(parsed_form_fields)}"
    asyncio.run(chat_with_agent(fields_str))

if __name__ == "__main__":
    main()