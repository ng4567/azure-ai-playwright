// Main infrastructure template for Medicaid RAG + AI Agent solution
// Deploys Azure AI Foundry with integrated AI services

targetScope = 'subscription'

// Parameters
@description('The location for all resources')
param location string = 'centralus'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Project name used for resource naming')
param projectName string = 'medicaid-rag'

@description('Resource group name')
param resourceGroupName string = 'rg-${projectName}-${environment}'

@description('Tags to apply to all resources')
param tags object = {
  project: projectName
  environment: environment
  workload: 'ai-rag'
  costCenter: 'development'
  deployedBy: 'bicep'
  deployedAt: utcNow()
}

// OpenAI Model Configuration
@description('Embedding model to deploy')
param embeddingModel string = 'text-embedding-3-large'

@description('Chat model to deploy')
param chatModel string = 'gpt-4o-mini'

@description('Additional models to deploy (optional)')
param additionalModels array = []

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy monitoring infrastructure first
module monitoring 'modules/monitoring.bicep' = {
  scope: resourceGroup
  name: 'monitoring-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
  }
}

// Deploy Key Vault for secrets management
module keyVault 'modules/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyvault-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Storage Account with docs container
module storage 'modules/storage.bicep' = {
  scope: resourceGroup
  name: 'storage-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Azure AI Foundry (AI Hub + AI Project)
module aiFoundry 'modules/ai-foundry.bicep' = {
  scope: resourceGroup
  name: 'ai-foundry-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    keyVaultId: keyVault.outputs.keyVaultId
    storageAccountId: storage.outputs.storageAccountId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Azure OpenAI with model deployments
module openAI 'modules/openai.bicep' = {
  scope: resourceGroup
  name: 'openai-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    aiHubId: aiFoundry.outputs.aiHubId
    keyVaultId: keyVault.outputs.keyVaultId
    embeddingModel: embeddingModel
    chatModel: chatModel
    additionalModels: additionalModels
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Azure AI Search
module aiSearch 'modules/ai-search.bicep' = {
  scope: resourceGroup
  name: 'ai-search-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    aiHubId: aiFoundry.outputs.aiHubId
    keyVaultId: keyVault.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Azure AI Translator
module translator 'modules/translator.bicep' = {
  scope: resourceGroup
  name: 'translator-deployment'
  params: {
    location: location
    projectName: projectName
    environment: environment
    tags: tags
    aiHubId: aiFoundry.outputs.aiHubId
    keyVaultId: keyVault.outputs.keyVaultId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Outputs for automation scripts
output resourceGroupName string = resourceGroup.name
output location string = location

// AI Services Outputs
output aiHubName string = aiFoundry.outputs.aiHubName
output aiProjectName string = aiFoundry.outputs.aiProjectName
output aiProjectEndpoint string = aiFoundry.outputs.aiProjectEndpoint

output openAIServiceName string = openAI.outputs.openAIServiceName
output openAIEndpoint string = openAI.outputs.openAIEndpoint
output embeddingDeploymentName string = openAI.outputs.embeddingDeploymentName
output chatDeploymentName string = openAI.outputs.chatDeploymentName

output aiSearchServiceName string = aiSearch.outputs.aiSearchServiceName
output aiSearchEndpoint string = aiSearch.outputs.aiSearchEndpoint

output translatorServiceName string = translator.outputs.translatorServiceName
output translatorEndpoint string = translator.outputs.translatorEndpoint

// Infrastructure Outputs
output storageAccountName string = storage.outputs.storageAccountName
output docsContainerName string = storage.outputs.docsContainerName
output keyVaultName string = keyVault.outputs.keyVaultName
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName

// Key Vault Secret Names for automation scripts
output secretNames object = {
  openAIApiKey: openAI.outputs.apiKeySecretName
  aiSearchAdminKey: aiSearch.outputs.adminKeySecretName
  translatorKey: translator.outputs.translatorKeySecretName
  storageConnectionString: storage.outputs.connectionStringSecretName
}
