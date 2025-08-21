# Medicaid RAG + AI Agent Solution

A comprehensive AI solution for Medicaid policy research, combining RAG (Retrieval Augmented Generation) with AI agents for intelligent document search and real-time news analysis.

## 🏗️ Architecture

This solution deploys and integrates multiple Azure AI services:

- **[Azure AI Search](https://learn.microsoft.com/en-us/azure/search/search-what-is-azure-search)** - Vector search for RAG over Medicaid documents
- **[Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/overview)** - GPT-4o-mini and text-embedding-3-large models
- **[Azure AI Translator](https://azure.microsoft.com/en-us/products/ai-services/ai-translator)** - Multi-language document translation
- **[Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/)** - AI agents with intelligent model management
- **[Playwright](https://github.com/microsoft/playwright)** - Web scraping for news analysis

## 🚀 Quick Start

### Prerequisites

Before deploying, ensure you have:

- **Azure CLI** 2.60+ (`az --version`)
- **PowerShell** 7.0+ (`$PSVersionTable.PSVersion`)
- **Python** 3.11+ (`python --version`)
- **Azure Subscription** with appropriate permissions for:
  - Creating resource groups
  - Deploying AI services (OpenAI, Search, Translator)
  - Managing Key Vault and storage accounts

### Step 1: Clone and Setup

```bash
git clone https://github.com/ng4567/azure-ai-playwright.git
cd azure-ai-playwright

# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"
```

### Step 2: Deploy Azure Infrastructure

The deployment script includes intelligent features:

- **Smart Region Selection**: Automatically finds regions with available OpenAI quota
- **Quota Validation**: Pre-flight checks ensure sufficient capacity
- **Resource Cleanup**: Handles soft-deleted resources automatically
- **Comprehensive Monitoring**: Sets up logging and alerting

```powershell
# Deploy complete infrastructure with intelligent region selection
.\scripts\deploy-azure.ps1 -SubscriptionId "your-subscription-id" -ProjectName "medicaid-rag" -Environment "dev" -Location "centralus"

# The script will:
# 1. 🔍 Test multiple regions for OpenAI quota availability
# 2. 🎯 Select the best region (e.g., eastus with 1M TPM)
# 3. 🧹 Clean up any conflicting soft-deleted resources
# 4. 🚀 Deploy all 10 Azure resources (~10-15 minutes)
# 5. ✅ Validate deployment completion

# Optional: Preview changes first
.\scripts\deploy-azure.ps1 -SubscriptionId "your-id" -ProjectName "medicaid-rag" -Environment "dev" -Location "centralus" -WhatIf

# Optional: Skip quota check if you've already verified capacity
.\scripts\deploy-azure.ps1 -SubscriptionId "your-id" -ProjectName "medicaid-rag" -Environment "dev" -Location "centralus" -SkipQuotaCheck
```

### Step 3: Validate Deployment

```powershell
# Comprehensive infrastructure validation
.\scripts\validate-deployment.ps1 -SubscriptionId "your-subscription-id" -ProjectName "medicaid-rag" -Environment "dev"

# This validates:
# ✅ All 10 Azure resources exist and are accessible
# ✅ OpenAI models (GPT-4o-mini, text-embedding-3-large) are deployed
# ✅ Service connectivity and endpoint accessibility
# ✅ Deployment status and health checks
# 📊 Provides detailed success/failure reporting
```

Expected validation output:
```
🔍 Azure AI Infrastructure Validation
====================================

✅ Resource Group [rg-medicaid-rag-dev]: Location: centralus
✅ OpenAI Service [openai-medicaid-rag-dev-xyz]: Location: eastus
✅ OpenAI Model Deployment: gpt-chat (gpt-4o-mini) - Succeeded
✅ OpenAI Model Deployment: text-embedding (text-embedding-3-large) - Succeeded
✅ AI Search Service [search-medicaid-rag-dev-xyz]: Location: centralus
✅ Storage Account [medicaidragstordev]: Resource exists
✅ Key Vault [medicaid-rag-kv-dev]: Successfully accessed vault

📊 Validation Summary
====================
Total Checks: 23
✅ Passed: 23
Success Rate: 100%

🎉 All critical validations passed! Infrastructure is ready for use.
```

# Setup Python environment
uv venv .venv
.\.venv\Scripts\activate.ps1
uv sync

# Copy and configure environment variables
Copy-Item ..\.env.template .env
# Edit .env with your deployed service details (check Key Vault for secrets)
```

### Step 4: Ingest Data & Test

```powershell
# Ingest Medicaid documents into search index
uv run ..\data\ingest-data.py

# Test the applications
uv run medicaid-rag.py        # RAG query system
uv run scraper.py             # News scraper
uv run bing.py                # AI agent with Bing search
```

## 💡 Applications

### 1. `src/medicaid-rag.py` - RAG Query System

- **Purpose**: Search Medicaid documents using natural language
- **Features**: Multi-language translation, semantic search, contextual answers
- **Usage**: `uv run src/medicaid-rag.py`

### 2. `src/scraper.py` - News Scraper

- **Purpose**: Scrape Google News for Medicaid policy updates
- **Features**: Automated news collection, text extraction
- **Usage**: `uv run src/scraper.py`

### 3. `src/bing.py` - AI Agent Search

- **Purpose**: AI agent that searches Bing for current Medicaid news
- **Features**: Real-time web search, summarized results with sources
- **Usage**: `uv run src/bing.py`

## 📁 Project Structure

```text
azure-ai-playwright/
├── data/                    # Medicaid documents for ingestion
├── docs/                    # Comprehensive documentation
├── scripts/                 # Deployment and configuration automation
├── src/                     # Python applications
│   ├── medicaid-rag.py     # RAG query system
│   ├── scraper.py          # News scraping application
│   └── bing.py             # AI agent application
├── .env.template           # Environment variables template
├── azure.yaml              # Azure Developer CLI configuration
└── TODO.md                 # Future enhancements
```

## 📖 Documentation

- **[docs/POST_DEPLOYMENT_CONFIG.md](docs/POST_DEPLOYMENT_CONFIG.md)** - Service configuration guide
- **[docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md)** - Local development workflow
- **[docs/BEST_PRACTICES.md](docs/BEST_PRACTICES.md)** - Development best practices
- **[docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md)** - Deployment verification
- **[docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)** - Commands and troubleshooting

## 🔄 Environment Management

**Deploy Environment**:
```powershell
azd up
```

**Teardown Environment** (saves costs):
```powershell
azd down
```

**Refresh Environment**:
```powershell
azd down
azd up
scripts/post-deploy-setup.ps1
```

## 🛠️ Development Workflow

1. **Deploy infrastructure** → Configure services → Ingest data
2. **Develop locally** → Test with deployed Azure services
3. **Iterate** → Modify code → Test immediately
4. **Cleanup** → `azd down` when not developing

See [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md) for detailed workflows.

## 📋 Prerequisites

- [Azure Subscription](https://azure.microsoft.com/free/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://aka.ms/azd)
- [Python 3.11+](https://python.org)
- [uv package manager](https://docs.astral.sh/uv/getting-started/installation/)

## 🔮 Future Enhancements

See [TODO.md](TODO.md) for planned features including multi-environment support, Azure hosting, and advanced AI capabilities.
