from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import ListSortOrder, Tool
import os
from dotenv import load_dotenv

# Find repo root by going one level up from src/
dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(dotenv_path)

project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint=os.getenv("FOUNDRY_PROJECT_ENDPOINT"))

agent = project.agents.get_agent(os.getenv("FOUNDRY_AGENT_ID"))

thread = project.agents.threads.create()
print(f"Created thread, ID: {thread.id}")

message = project.agents.messages.create(
    thread_id=thread.id,
    role="user",
    content="Search the web with Bing for the latest news on changes to Medicaid policy. List out 5 sources you searched and summarize their contents. Please  also include the urls."
)

run = project.agents.runs.create_and_process(
    thread_id=thread.id,
    agent_id=agent.id
    )

if run.status == "failed":
    print(f"Run failed: {run.last_error}")
else:
    messages = project.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)

    for message in messages:
        if message.text_messages:
            print(f"{message.role}: {message.text_messages[-1].text.value}")