# Post-Deployment Configuration

This document outlines the automated and manual configuration steps required after infrastructure deployment.

## 🤖 Automated Configuration (via Scripts)

The following configurations are automated through scripts in the `/scripts` folder:

### 1. AI Search Index Setup
**Script**: `scripts/setup-search-index.ps1`
- Creates the `md-medicaid` search index
- Configures vector search profiles
- Sets up field mappings for RAG operations

### 2. OpenAI Model Deployments
**Script**: `scripts/deploy-models.ps1`
- Deploys `text-embedding-3-small` model
- Deploys `gpt-5-chat` model
- Verifies model availability and quota

### 3. Key Vault Secret Population
**Script**: `scripts/populate-secrets.ps1`
- Stores API keys securely in Key Vault
- Creates managed identity access policies
- Updates application configuration

## 🔧 Manual Configuration Steps

### 1. Azure AI Foundry Agent Setup
1. Navigate to Azure AI Foundry portal
2. Create new agent with Bing Search tool enabled
3. Configure agent settings for Medicaid policy search
4. Copy agent ID to environment variables

### 2. Data Ingestion
**After infrastructure deployment, run data ingestion manually:**

```powershell
# Activate Python environment
.\.venv\Scripts\activate.ps1

# Run data ingestion script
uv run data/ingest-data.py
```

**This will:**
- Process documents from `/data` folder
- Generate embeddings using deployed model
- Populate the AI Search index

### 3. Service Validation
**Run validation script:**
```powershell
scripts/validate-deployment.ps1
```

**This validates:**
- AI Search index exists and is queryable
- OpenAI models are deployed and accessible
- AI Foundry agent is configured
- All services can authenticate properly

## 🏃‍♂️ Quick Start After Deployment

1. **Copy environment template:**
   ```powershell
   Copy-Item .env.template .env
   ```

2. **Run post-deployment automation:**
   ```powershell
   scripts/post-deploy-setup.ps1
   ```

3. **Configure Foundry agent manually** (see above)

4. **Ingest data:**
   ```powershell
   .\.venv\Scripts\activate.ps1
   uv run data/ingest-data.py
   ```

5. **Validate setup:**
   ```powershell
   scripts/validate-deployment.ps1
   ```

6. **Start developing:**
   ```powershell
   uv run medicaid-rag.py
   ```

## 🔍 Troubleshooting

### Common Issues

**AI Search Index Creation Fails**
- Verify AI Search service tier supports vector search
- Check quota limits for search units
- Ensure proper RBAC permissions

**Model Deployment Timeout**
- Verify OpenAI service quota in target region
- Check for regional capacity constraints
- Retry deployment after a few minutes

**Authentication Failures**
- Verify Azure CLI is logged in: `az account show`
- Check managed identity assignments
- Validate Key Vault access policies

### Debug Commands

```powershell
# Check Azure CLI authentication
az account show

# List deployed resources
az resource list --resource-group $env:AZURE_RESOURCE_GROUP_NAME --output table

# Test AI Search connectivity
az search service show --name your-search-service --resource-group $env:AZURE_RESOURCE_GROUP_NAME

# Check OpenAI deployments
az cognitiveservices account deployment list --name your-openai-service --resource-group $env:AZURE_RESOURCE_GROUP_NAME
```

---

_For additional help, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md) or [TROUBLESHOOTING.md](TROUBLESHOOTING.md)_
