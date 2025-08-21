@description('Azure AI Search service for vector search in Medicaid RAG solution')
param location string = resourceGroup().location
param projectName string
param environment string
param tags object = {}
param aiHubId string
param keyVaultId string
param logAnalyticsWorkspaceId string

@description('Search service tier')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSku string = 'basic'

@description('Number of replicas for the search service')
@minValue(1)
@maxValue(12)
param replicaCount int = 1

@description('Number of partitions for the search service')
@allowed([1, 2, 3, 4, 6, 12])
param partitionCount int = 1

var searchServiceName = 'search-${projectName}-${environment}-${uniqueString(resourceGroup().id)}'
var keyVaultName = last(split(keyVaultId, '/'))

// Azure AI Search service
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: searchServiceSku
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      ipRules: []
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      apiKeyOnly: {}
    }
    semanticSearch: searchServiceSku == 'free' ? 'disabled' : 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store Search service endpoint in Key Vault
resource searchEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'search-endpoint'
  properties: {
    value: 'https://${searchService.name}.search.windows.net'
    contentType: 'text/plain'
  }
}

// Store Search service admin key in Key Vault
resource searchAdminKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'search-admin-key'
  properties: {
    value: searchService.listAdminKeys().primaryKey
    contentType: 'text/plain'
  }
}

// Store Search service query key in Key Vault
resource searchQueryKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'search-query-key'
  properties: {
    value: searchService.listQueryKeys().value[0].key
    contentType: 'text/plain'
  }
}

// Diagnostic settings for Search service
resource searchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'search-diagnostics'
  scope: searchService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
      }
      {
        category: 'SearchSlowLogs'
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
output aiSearchServiceName string = searchService.name
output aiSearchServiceId string = searchService.id
output aiSearchEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchPrincipalId string = searchService.identity.principalId
output searchServiceSku string = searchServiceSku
output adminKeySecretName string = searchAdminKeySecret.name
