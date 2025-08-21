---

# 📦 Project Scope

**Medicaid RAG + AI Agent Solution** — A comprehensive Azure AI solution for Medicaid policy research, combining RAG (Retrieval Augmented Generation) with AI agents for intelligent document search and real-time news analysis.

**Phase 1:** Infrastructure deployment and local development setup for AI-powered Medicaid research tools.

---

## 🗂️ Project Structure

```
azure-ai-playwright/
├── data/                        # Medicaid documents for ingestion
│   ├── medicaid-eligibility.txt # Medicaid eligibility guidelines
│   ├── medicaid-savings-programs.txt # Medicaid savings program info
│   ├── employed-individuals-with-disabilities.txt # Disability-related documents
│   └── ingest-data.py          # Data ingestion script for AI Search
├── docs/                        # Documentation and guides
│   ├── BEST_PRACTICES.md       # Development and Azure AI best practices
│   ├── DEPLOYMENT_CHECKLIST.md # Step-by-step deployment guide
│   ├── DECISIONS.md            # Architectural Decision Records
│   ├── POST_DEPLOYMENT_CONFIG.md # Service configuration automation
│   ├── LOCAL_DEVELOPMENT.md    # Local development workflow
│   ├── QUICK_REFERENCE.md      # Commands and troubleshooting
│   └── SESSION_NOTES_TEMPLATE.md # Session tracking template
├── scripts/                    # Deployment and configuration automation
│   ├── post-deploy-setup.ps1   # Main post-deployment configuration
│   ├── setup-search-index.ps1  # AI Search index creation
│   ├── deploy-models.ps1       # OpenAI model deployment
│   ├── populate-secrets.ps1    # Key Vault secret management
│   └── validate-deployment.ps1 # Deployment validation
├── .env.template              # Environment variables template
├── .gitignore                 # Git ignore rules
├── azure.yaml                 # Azure Developer CLI template
├── CHANGELOG.md              # Change tracking for context regrounding
├── CONTEXT.md                # This file - project context and goals
├── TODO.md                   # Future opportunities and enhancements
├── README.md                 # Project overview and getting started
├── medicaid-rag.py           # RAG query system for Medicaid documents
├── scraper.py                # Google News scraper for Medicaid policy
├── bing.py                   # AI agent with Bing search integration
└── pyproject.toml            # Python project configuration
```

---

## 🔁 Principles & Best Practices

### ✅ Reusability

- Modular Bicep structure
- Parameter-driven deployment
- Supports multiple environments via `azd`

### 🔐 Security

- Private endpoints, NSGs, RBAC (least privilege)
- Managed Identity (UAMI) for service authentication
- Key Vault for secrets (API keys never hardcoded)
- Diagnostic logging and Defender for Cloud enabled
- AI service security and compliance considerations

### ⚙️ Manageability

- Standardized tags: `environment`, `owner`, `project`, `costCenter`
- Resource locks for critical AI infrastructure
- Centralized logging via Log Analytics
- Azure Policy for AI governance and compliance
- Cost monitoring for AI service usage

### 🧊 Immutability

- Deploy only through Bicep & azd
- No portal-based changes
- Parameter files per environment
- Infra easily destroyed/recreated
- Model deployment automation

### ⚡ PoC-Ready Simplicity

- Rapid deployment via `azd up`
- Minimal dependencies (Bicep + Azure CLI)
- Self-contained modules for portability
- Automated post-deployment configuration
- Ready-to-use AI applications

---

## 🤖 AI Services Architecture

### Core Services

- **Azure AI Search**: Vector search index for Medicaid documents
- **Azure OpenAI**: GPT-5-Chat and text-embedding-3-small models
- **Azure AI Translator**: Multi-language document translation
- **Azure AI Foundry**: AI agents with Bing search capabilities

### Data Flow

1. **Document Ingestion**: Medicaid documents → AI Search index
2. **Query Processing**: User query → embedding → vector search
3. **RAG Response**: Retrieved context + OpenAI → generated answer
4. **Translation**: Response translated to Spanish/French via Translator
5. **News Analysis**: Playwright scraping + AI agent Bing search

---

## 🌍 Environments

**Current**: Single development environment with local Python execution
**Future**: Multi-environment support (dev/staging/prod) - see TODO.md

---

## 🔧 Tooling

- [Azure Developer CLI](https://aka.ms/azd) - Infrastructure deployment
- [Bicep](https://aka.ms/bicep) - Infrastructure as Code
- [Azure CLI](https://docs.microsoft.com/cli/azure/) - Service management
- [Python 3.11+](https://python.org) - Application runtime
- [uv](https://docs.astral.sh/uv/) - Python package management
- [Playwright](https://playwright.dev/python/) - Web scraping framework

---

## 🔮 Future-Ready

- Multi-environment deployments (dev/staging/prod)
- Azure Container Apps hosting for Python applications
- CI/CD via GitHub Actions or Azure DevOps
- Advanced monitoring and cost optimization
- Enterprise security and compliance features

---

## � References

- [Azure AI Search Documentation](https://learn.microsoft.com/azure/search/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-foundry/openai/overview)
- [Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
