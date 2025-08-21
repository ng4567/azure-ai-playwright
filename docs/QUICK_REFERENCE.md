# Quick Reference

## Essential Commands

```powershell
# Azure Developer CLI
azd auth login
azd init --template . --environment dev
azd up                              # Deploy infrastructure
azd down                           # Teardown infrastructure

# Post-deployment configuration
scripts/post-deploy-setup.ps1
scripts/validate-deployment.ps1

# Python environment setup
uv venv .venv
.\.venv\Scripts\activate.ps1
uv sync

# Data ingestion and application usage
uv run data/ingest-data.py         # Populate AI Search index
uv run src/medicaid-rag.py         # RAG query system
uv run src/scraper.py              # News scraper
uv run src/bing.py                 # AI agent with Bing search

# Validate Bicep template (when templates are created)
bicep build main.bicep
az deployment group validate --resource-group <rg-name> --template-file main.bicep
```

## AI Service Management

```powershell
# Check OpenAI deployments
az cognitiveservices account deployment list --name <openai-service> --resource-group <rg-name>

# Test AI Search connectivity
az search service show --name <search-service> --resource-group <rg-name>

# Query AI Search index
$headers = @{"api-key" = "$env:AZURE_SEARCH_ADMIN_KEY"}
Invoke-RestMethod -Uri "$env:AZURE_SEARCH_ENDPOINT/indexes/md-medicaid/docs/search?api-version=2023-11-01" -Headers $headers

# Check AI service costs
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

## Common Issues & Solutions

### Infrastructure Deployment Failures

1. **Permission denied**: Check RBAC assignments for your identity
2. **Resource already exists**: Use unique naming or check for existing resources
3. **Quota exceeded**: Check subscription limits and request increases if needed
4. **AI service unavailable**: Verify service availability in target region

### AI Service Issues

1. **OpenAI model deployment fails**: Check quota limits and regional availability
2. **AI Search index creation fails**: Verify search service tier supports vector search
3. **Authentication errors**: Ensure managed identity or API keys are correctly configured
4. **High latency**: Monitor service performance and consider scaling options

### Local Development Issues

1. **Import errors**: Ensure virtual environment is activated and dependencies installed
2. **Environment variable errors**: Check .env file configuration
3. **AI service timeouts**: Verify network connectivity and service health
4. **Data ingestion fails**: Check AI Search index schema and permissions

### Bicep Compilation Errors

1. **Module not found**: Verify module paths are correct
2. **Parameter type mismatch**: Check parameter definitions match usage
3. **Circular dependency**: Review resource dependencies

## Useful Azure CLI Queries

```powershell
# List all resources in resource group
az resource list --resource-group <rg-name> --output table

# Get deployment operations
az deployment group operation list --resource-group <rg-name> --name <deployment-name>

# Check activity log for errors
az monitor activity-log list --resource-group <rg-name> --max-events 50

# Monitor AI service usage
az monitor metrics list --resource <resource-id> --metric "Total Calls" --start-time 2024-01-01T00:00:00Z

# Check AI Search index status
az search index show --service-name <search-service> --name md-medicaid

# List OpenAI model deployments
az cognitiveservices account deployment list --name <openai-service> --resource-group <rg-name>
```

## Environment Variables Reference

```powershell
# Core Azure settings
$env:AZURE_SUBSCRIPTION_ID
$env:AZURE_RESOURCE_GROUP_NAME
$env:AZURE_LOCATION

# AI Search
$env:AZURE_SEARCH_ENDPOINT
$env:AZURE_SEARCH_ADMIN_KEY
$env:AZURE_AI_SEARCH_INDEX_NAME

# OpenAI
$env:AZURE_OPENAI_ENDPOINT
$env:AZURE_OPENAI_API_KEY
$env:AZURE_OPENAI_EMBED_DEPLOYMENT
$env:AZURE_OPENAI_CHAT_DEPLOYMENT

# AI Foundry
$env:FOUNDRY_PROJECT_ENDPOINT
$env:FOUNDRY_AGENT_ID
```

---

_Keep this handy for quick troubleshooting during AI solution development._

_Keep this handy for quick troubleshooting during development._
