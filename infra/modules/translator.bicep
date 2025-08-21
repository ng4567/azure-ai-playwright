@description('Azure AI Translator service for multi-language Medicaid document translation')
param location string = resourceGroup().location
param projectName string
param environment string
param tags object = {}
param aiHubId string
param keyVaultId string
param logAnalyticsWorkspaceId string

@description('Translator service tier')
@allowed(['F0', 'S1', 'S2', 'S3', 'S4'])
param translatorSku string = 'S1'

var translatorServiceName = 'translator-${projectName}-${environment}-${uniqueString(resourceGroup().id)}'
var keyVaultName = last(split(keyVaultId, '/'))

// Azure AI Translator service
resource translatorService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: translatorServiceName
  location: location
  tags: tags
  kind: 'TextTranslation'
  sku: {
    name: translatorSku
  }
  properties: {
    customSubDomainName: translatorServiceName
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

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Store Translator service endpoint in Key Vault
resource translatorEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'translator-endpoint'
  properties: {
    value: translatorService.properties.endpoint
    contentType: 'text/plain'
  }
}

// Store Translator service API key in Key Vault
resource translatorKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'translator-api-key'
  properties: {
    value: translatorService.listKeys().key1
    contentType: 'text/plain'
  }
}

// Store Translator service region in Key Vault
resource translatorRegionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'translator-region'
  properties: {
    value: location
    contentType: 'text/plain'
  }
}

// Diagnostic settings for Translator service
resource translatorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'translator-diagnostics'
  scope: translatorService
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
output translatorServiceName string = translatorService.name
output translatorServiceId string = translatorService.id
output translatorEndpoint string = translatorService.properties.endpoint
output translatorPrincipalId string = translatorService.identity.principalId
output translatorSku string = translatorSku
output translatorKeySecretName string = translatorKeySecret.name
