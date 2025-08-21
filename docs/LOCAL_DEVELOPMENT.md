# Local Development Guide

This guide covers running the Medicaid RAG and AI Agent solution locally after Azure infrastructure deployment.

## 📋 Prerequisites

Before starting local development, ensure you have:

- ✅ Azure infrastructure deployed via `azd up`
- ✅ Post-deployment configuration completed
- ✅ Data ingested into AI Search index
- ✅ Environment variables configured in `.env`

## 🛠️ Local Environment Setup

### 1. Python Environment Setup

```powershell
# Navigate to project directory
cd azure-ai-playwright

# Create and activate virtual environment
uv venv .venv
.\.venv\Scripts\activate.ps1

# Install dependencies
uv sync
```

### 2. Environment Configuration

```powershell
# Copy environment template (if not done already)
Copy-Item .env.template .env

# Edit .env with your deployed service endpoints
# These should be populated automatically by post-deployment scripts
```

### 3. Validate Service Connectivity

```powershell
# Run validation script
scripts/validate-deployment.ps1

# Should confirm:
# ✅ AI Search service accessible
# ✅ OpenAI models deployed and accessible
# ✅ AI Foundry agent configured
# ✅ All authentication working
```

## 🚀 Running the Applications

### 1. RAG Query System

**Purpose**: Search Medicaid documents using natural language

```powershell
# Activate environment (if not already active)
.\.venv\Scripts\activate.ps1

# Run RAG application
uv run src/medicaid-rag.py
```

**Example Usage**:
- Ask questions about Medicaid eligibility
- Search for policy information
- Get translated responses in Spanish/French

### 2. News Scraper

**Purpose**: Scrape Google News for Medicaid policy updates

```powershell
# Install Playwright browsers (first time only)
playwright install

# Run news scraper
uv run src/scraper.py
```

**Output**: Creates `medicaid_news_[timestamp].txt` with scraped articles

### 3. AI Agent with Bing Search

**Purpose**: AI agent that searches Bing for current Medicaid news

```powershell
# Run Bing search agent
uv run src/bing.py
```

**Features**:
- Uses Azure AI Foundry agent
- Searches web for latest Medicaid policy news
- Provides summarized results with sources

## 🔧 Development Workflow

### Daily Development Process

1. **Start Development Session**:
   ```powershell
   .\.venv\Scripts\activate.ps1
   ```

2. **Run Applications**:
   ```powershell
   # For RAG queries
   uv run src/medicaid-rag.py

   # For news scraping
   uv run src/scraper.py

   # For AI agent search
   uv run src/bing.py
   ```

3. **Update Data** (as needed):
   ```powershell
   # Add new documents to /data folder
   # Re-run ingestion
   uv run data/ingest-data.py
   ```

### Code Modification Tips

**Adding New Documents**:
- Place text files in `/data` folder
- Run `uv run data/ingest-data.py` to update search index
- New documents automatically available for RAG queries

**Modifying Search Behavior**:
- Edit `src/medicaid-rag.py` to adjust search parameters
- Modify translation settings in the same file
- Test changes immediately with local runs

**Agent Customization**:
- Configure agent behavior in Azure AI Foundry portal
- Update agent prompts and tools as needed
- Test with `uv run src/bing.py`

## 🐛 Troubleshooting Local Development

### Common Issues

**Import Errors**:
```powershell
# Ensure virtual environment is activated
.\.venv\Scripts\activate.ps1

# Reinstall dependencies
uv sync
```

**Authentication Failures**:
```powershell
# Check Azure CLI login
az account show

# Verify environment variables
Get-Content .env
```

**AI Search Connection Issues**:
```powershell
# Test search endpoint
curl "${env:AZURE_SEARCH_ENDPOINT}/indexes?api-version=2023-11-01" `
  -H "api-key: ${env:AZURE_SEARCH_ADMIN_KEY}"
```

**OpenAI API Errors**:
```powershell
# Check model deployments
az cognitiveservices account deployment list `
  --name your-openai-service `
  --resource-group $env:AZURE_RESOURCE_GROUP_NAME
```

### Debug Mode

Enable debug logging by setting in `.env`:
```
LOG_LEVEL=DEBUG
```

This provides detailed logs for:
- AI Search queries and responses
- OpenAI API calls
- Authentication flows
- Error details

## 📊 Monitoring Local Usage

### Usage Tracking

Monitor your Azure service usage:

```powershell
# Check AI Search query usage
az monitor metrics list --resource your-search-service-resource-id

# Check OpenAI token usage
az monitor metrics list --resource your-openai-service-resource-id
```

### Cost Management

Keep track of costs during development:

- Monitor Azure Cost Management portal
- Set up billing alerts for unexpected usage
- Use `azd down` to teardown when not developing

## 🔄 Environment Refresh

If you need to refresh your environment:

```powershell
# Teardown infrastructure
azd down

# Redeploy fresh environment
azd up

# Reconfigure and re-ingest data
scripts/post-deploy-setup.ps1
uv run data/ingest-data.py
```

---

_For additional help, see [POST_DEPLOYMENT_CONFIG.md](POST_DEPLOYMENT_CONFIG.md) or [QUICK_REFERENCE.md](QUICK_REFERENCE.md)_
