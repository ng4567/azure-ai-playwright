from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import ListSortOrder, Tool
import os
from dotenv import load_dotenv
load_dotenv()

project = AIProjectClient(
    credential=DefaultAzureCredential(),
    endpoint=os.getenv("FOUNDRY_PROJECT_ENDPOINT"))

agent = project.agents.get_agent("asst_z7oR2lFQ3m4FLIMzNZ3KPZMr")

thread = project.agents.threads.create()
print(f"Created thread, ID: {thread.id}")

message = project.agents.messages.create(
    thread_id=thread.id,
    role="user",
    content="Search the web with Bing for the latest news on changes to Medicaid policy. List out 5 sources you searched and summarize their contents"
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


# credential = DefaultAzureCredential()

# project_client = AIProjectClient(
#     endpoint=PROJECT_ENDPOINT,
#     credential=credential
# )

# conn_id = BING_CONNECTION_ID

# # Initialize the Bing Grounding tool
# bing = BingGroundingTool(connection_id=conn_id,)

# with project_client:
#     # Create an agent with the Bing Grounding tool
#     agent = project_client.agents.create_agent(
#         model=MODEL_DEPLOYMENT,  # Model deployment name
#         name="my-agent",  # Name of the agent
#         instructions="You are a helpful agent that searches bing and then returns the results",  # Instructions for the agent
#         tools=bing.definitions,  # Attach the Bing Grounding tool
#     )
#     print(f"Created agent, ID: {agent.id}")

#     # Create a thread for communication
#     thread = project_client.agents.threads.create()
#     print(f"Created thread, ID: {thread.id}")

#     # Add a message to the thread
#     message = project_client.agents.messages.create(
#         thread_id=thread.id,
#         role="user",  # Role of the message sender
#         content="What is the weather in Seattle today?",  # Message content
#     )
#     print(f"Created message, ID: {message['id']}")

#     # Create and process an agent run
#     run = project_client.agents.runs.create_and_process(
#         thread_id=thread.id,
#         agent_id=agent.id,
#         # tool_choice={"type": "bing_grounding"}  # optional, you can force the model to use Grounding with Bing Search tool
#     )
#     print(f"Run finished with status: {run.status}")

#     # Check if the run failed
#     if run.status == "failed":
#         print(f"Run failed: {run.last_error}")

#     # Fetch and log all messages
#     messages = project_client.agents.messages.list(thread_id=thread.id)
#     for message in messages:
#         print(f"Role: {message.role}, Content: {message.content}")

#     project_client.agents.delete_agent(agent.id)
#     print("Deleted agent")