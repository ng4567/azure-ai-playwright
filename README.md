# Medicaid RAG + AI Agent Solution

A comprehensive AI solution for Medicaid policy research, combining RAG (Retrieval Augmented Generation) with AI agents for intelligent document search and real-time news analysis.

## 🏗️ Architecture

This solution deploys and integrates multiple Azure AI services:

- **[Azure AI Search](https://learn.microsoft.com/en-us/azure/search/search-what-is-azure-search)** - Vector search for RAG over Medicaid documents
- **[Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/overview)** - GPT-5-Chat and text-embedding-3-small models
- **[Azure AI Translator](https://azure.microsoft.com/en-us/products/ai-services/ai-translator)** - Multi-language document translation
- **[Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/)** - AI agents with Bing search integration
- **[Playwright](https://github.com/microsoft/playwright)** - Web scraping for news analysis

## 🚀 Quick Start

### Step 1: Prerequisites & Validation

```powershell
# Ensure you have required tools
# - Azure CLI (az --version)
# - PowerShell 7+ ($PSVersionTable.PSVersion)
# - Python 3.11+ (python --version)

# Login to Azure
az login

# Validate quota and model availability
.\scripts\check-quota.ps1 -Location "centralus"
```

### Step 2: Deploy Azure Infrastructure

```powershell
# Deploy complete infrastructure (10-15 minutes)
.\scripts\deploy-azure.ps1 -Environment dev -Location centralus

# Preview changes first (optional)
.\scripts\deploy-azure.ps1 -Environment dev -Location centralus -WhatIf

# Validate deployment health
.\scripts\validate-infrastructure.ps1 -ResourceGroupName "rg-medicaid-rag-dev"
```

### Step 3: Configure Application Environment

```powershell
# Navigate to source directory
cd src

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
