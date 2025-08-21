# Azure AI Infrastructure Deployment Checklist

## Pre-Deployment

- [ ] Review and update parameter files for target environment
- [ ] Validate Bicep templates with `bicep build`
- [ ] Check resource naming conventions
- [ ] Verify subscription and resource group permissions
- [ ] Ensure AI service quota availability in target region
- [ ] Check Azure OpenAI model availability
- [ ] Validate Key Vault access for secrets

## Infrastructure Deployment

- [ ] Run `azd up` and monitor for errors
- [ ] Verify all Azure resources deployed successfully
- [ ] Check resource tags are applied correctly
- [ ] Validate network security groups and private endpoints
- [ ] Test connectivity and permissions

## AI Service Configuration

- [ ] Run post-deployment configuration: `scripts/post-deploy-setup.ps1`
- [ ] Verify AI Search index creation
- [ ] Confirm OpenAI model deployments (embedding + chat models)
- [ ] Test AI Search connectivity and query functionality
- [ ] Validate OpenAI service accessibility
- [ ] Configure Azure AI Foundry agent (manual step)
- [ ] Verify AI Translator service setup

## Data Preparation

- [ ] Copy environment template: `Copy-Item .env.template .env`
- [ ] Update .env with deployed service endpoints
- [ ] Setup Python virtual environment: `uv venv .venv`
- [ ] Install dependencies: `uv sync`
- [ ] Run data ingestion: `uv run data/ingest-data.py`
- [ ] Verify search index population

## Validation & Testing

- [ ] Run deployment validation: `scripts/validate-deployment.ps1`
- [ ] Test RAG system: `uv run medicaid-rag.py`
- [ ] Test news scraper: `uv run scraper.py`
- [ ] Test AI agent: `uv run bing.py`
- [ ] Verify all AI services are responding correctly
- [ ] Check monitoring and logging are working

## Post-Deployment

- [ ] Update CONTEXT.md with any new resources or configurations
- [ ] Document any manual configuration steps required
- [ ] Update CHANGELOG.md with deployment details
- [ ] Set up cost monitoring and alerts
- [ ] Configure backup and disaster recovery (if applicable)

## Cleanup (for test environments)

- [ ] Run `azd down` to remove test resources
- [ ] Verify all resources were deleted
- [ ] Check for any orphaned resources in the portal
- [ ] Confirm no ongoing charges for AI services

---

_Use this checklist for consistent, reliable AI solution deployments._
