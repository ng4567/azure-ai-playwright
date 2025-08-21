@description('Azure OpenAI Service for Medicaid RAG + AI Agent solution')
param location string = resourceGroup().location
param projectName string
param environment string
param tags object = {}
param aiHubId string
param keyVaultId string
param logAnalyticsWorkspaceId string

@description('OpenAI model configuration')
param embeddingModel string = 'text-embedding-3-large'
param chatModel string = 'gpt-4o-mini'
param additionalModels array = []

@description('Model deployment capacity (TPM)')
param gptCapacity int = 10
param embeddingCapacity int = 3

var openAIServiceName = 'openai-${projectName}-${environment}-${uniqueString(resourceGroup().id)}'
var keyVaultName = last(split(keyVaultId, '/'))

// Azure OpenAI Service
resource openAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAIServiceName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAIServiceName
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Chat model deployment
resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAIService
  name: 'gpt-chat'
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModel
      version: chatModel == 'gpt-4o-mini' ? '2024-07-18' : '2024-02-15-preview'
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: gptCapacity
  }
}

// Text embedding model deployment
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAIService
  name: 'text-embedding'
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModel
      version: embeddingModel == 'text-embedding-3-large' ? '1' : '2'
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: embeddingCapacity
  }
  dependsOn: [
    chatDeployment
  ]
}

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store OpenAI endpoint in Key Vault
resource openAIEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'openai-endpoint'
  properties: {
    value: openAIService.properties.endpoint
    contentType: 'text/plain'
  }
}

// Store OpenAI API key in Key Vault
resource openAIKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'openai-api-key'
  properties: {
    value: openAIService.listKeys().key1
    contentType: 'text/plain'
  }
}

// Store OpenAI deployment names in Key Vault
resource chatDeploymentNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'openai-chat-deployment'
  properties: {
    value: chatDeployment.name
    contentType: 'text/plain'
  }
}

resource embeddingDeploymentNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'openai-embedding-deployment'
  properties: {
    value: embeddingDeployment.name
    contentType: 'text/plain'
  }
}

// Diagnostic settings for OpenAI Service
resource openAIDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'openai-diagnostics'
  scope: openAIService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Outputs
output openAIServiceName string = openAIService.name
output openAIServiceId string = openAIService.id
output openAIEndpoint string = openAIService.properties.endpoint
output chatDeploymentName string = chatDeployment.name
output embeddingDeploymentName string = embeddingDeployment.name
output openAIPrincipalId string = openAIService.identity.principalId
output apiKeySecretName string = openAIKeySecret.name
