# Agentic Pair Programming Best Practices

## Communication

- Use clear, concise commit messages and comments.
- Regularly update the CONTEXT.md and CHANGELOG.md files.

## Task Breakdown

- Break work into small, well-defined tasks.
- Assign tasks explicitly between human and agent.

## Review Process

- Review each other's code and provide constructive feedback.
- Use pull requests or code review tools if available.

## Session Notes

- Summarize each session in a dedicated file (e.g., SESSION_NOTES.md).

## Context Regrounding

- Reference CONTEXT.md and CHANGELOG.md at the start of each session.
- Update context files as new information emerges.

## Azure AI & Bicep Best Practices

### Infrastructure as Code

- Use descriptive resource names with consistent naming conventions
- Parameterize everything that varies between environments
- Use outputs for values needed by other modules or applications
- Implement proper dependency management with `dependsOn` when needed
- Use resource locks on critical AI infrastructure
- Validate templates with `bicep build` and `az deployment validate`
- Keep modules focused on single responsibilities
- Document all parameters with descriptions and allowed values

### AI Service Management

- **Model Deployment**: Automate OpenAI model deployments with proper quota management
- **Index Management**: Use infrastructure code to create AI Search indexes and schemas
- **Cost Control**: Implement quota limits and usage monitoring for AI services
- **Version Control**: Track model versions and deployment configurations
- **Performance**: Monitor token usage, query latency, and search performance

### Security for AI Workloads

- Store all AI service keys in Key Vault, never in code or config files
- Use managed identities for service-to-service authentication
- Implement network isolation with private endpoints for production
- Enable diagnostic logging for all AI services
- Follow AI governance and compliance requirements
- Implement content filtering and safety measures

## Environment Management

- Use separate parameter files for each environment (dev.bicepparam, prod.bicepparam)
- Never hardcode secrets - use Key Vault references or secure parameters
- Implement proper RBAC with least privilege principles
- Use managed identities instead of service principals when possible
- Tag all resources consistently for cost tracking and governance
- Monitor AI service costs and set up billing alerts
- Implement quota management for OpenAI and other AI services

## Development Workflow

- Always run `azd up` from a clean state to test reproducibility
- Use `azd down` to clean up test deployments and avoid costs
- Validate infrastructure changes in dev environment first
- Run post-deployment scripts to configure AI services
- Test AI service connectivity before developing locally
- Keep infrastructure code in version control with meaningful commit messages

## Data and AI Governance

- **Data Privacy**: Ensure Medicaid data handling complies with HIPAA and privacy regulations
- **Model Governance**: Track model performance, bias, and fairness metrics
- **Content Safety**: Implement content filtering for AI-generated responses
- **Audit Trail**: Log all AI interactions for compliance and debugging
- **Data Lineage**: Document data sources and transformation processes
- **Prompt Engineering**: Version control prompts and test for consistency
- Use pull requests for infrastructure changes, even in solo projects

## Troubleshooting

- Check Azure Activity Log for deployment failures
- Use `az deployment operation list` to see detailed error messages
- Validate Bicep syntax with VS Code Bicep extension
- Test modules individually before integrating
- Keep deployment outputs visible for debugging

---

_These practices help maintain flow and alignment during collaborative coding._
