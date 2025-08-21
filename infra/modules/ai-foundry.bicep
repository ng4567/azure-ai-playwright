// Azure AI Foundry (AI Hub + AI Project) for centralized AI service management

@description('The location for the resources')
param location string

@description('Project name for resource naming')
param projectName string

@description('Environment name')
param environment string

@description('Tags to apply to all resources')
param tags object

@description('Key Vault resource ID')
param keyVaultId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// AI Hub (formerly AI Studio Hub)
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: '${projectName}-hub-${environment}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Hub'
  properties: {
    friendlyName: '${projectName} AI Hub (${environment})'
    description: 'AI Hub for Medicaid RAG and AI Agent solution'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://${location}.api.azureml.ms/discovery'
  }
}

// AI Project within the Hub
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: '${projectName}-project-${environment}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  properties: {
    friendlyName: '${projectName} AI Project (${environment})'
    description: 'AI Project for Medicaid RAG and AI Agent solution'
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Enabled'
  }
}

// Diagnostic settings for AI Hub
resource aiHubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'aiHubDiagnostics'
  scope: aiHub
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AmlComputeClusterEvent'
        enabled: true
      }
      {
        category: 'AmlComputeClusterNodeEvent'
        enabled: true
      }
      {
        category: 'AmlComputeJobEvent'
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
output aiHubId string = aiHub.id
output aiHubName string = aiHub.name
output aiProjectId string = aiProject.id
output aiProjectName string = aiProject.name
output aiProjectEndpoint string = 'https://${aiProject.name}.${location}.inference.ml.azure.com'
output aiHubPrincipalId string = aiHub.identity.principalId
output aiProjectPrincipalId string = aiProject.identity.principalId
