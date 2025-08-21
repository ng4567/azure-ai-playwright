using 'main.bicep'

// Environment Configuration
param location = 'centralus'
param environment = 'dev'
param projectName = 'medicaid-rag'

// Resource Naming
param resourceGroupName = 'rg-medicaid-rag-dev'

// AI Model Configuration
param embeddingModel = 'text-embedding-3-large'
param chatModel = 'gpt-4o-mini'
param additionalModels = [
  // Add future models here as needed
  // Example: 'gpt-4-turbo'
]

// Resource Tags
param tags = {
  project: 'medicaid-rag'
  environment: 'dev'
  workload: 'ai-rag'
  costCenter: 'development'
  deployedBy: 'bicep'
}
