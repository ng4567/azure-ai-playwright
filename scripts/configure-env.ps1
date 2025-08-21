# Azure Environment Configuration Script
# Populates .env files with values from deployed Azure resources

param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$ResourceGroupName = "rg-medicaid-rag-dev",
    [string]$Environment = "dev",
    [string]$ProjectName = "medicaid-rag",
    [string]$OutputPath = "src\.env"
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 Azure Environment Configuration" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

# Ensure we're logged into Azure
$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Cyan

# Set subscription if provided
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    Write-Host "✅ Active subscription: $SubscriptionId" -ForegroundColor Cyan
}

Write-Host "📋 Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host ""

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName --query "." -o tsv
if ($rgExists -ne "true") {
    Write-Error "❌ Resource group not found: $ResourceGroupName"
    exit 1
}

Write-Host "🔍 Discovering Azure resources..." -ForegroundColor Yellow

# Function to get resource by type
function Get-AzureResource {
    param([string]$Type, [string]$FriendlyName)
    
    try {
        $resource = az resource list --resource-group $ResourceGroupName --resource-type $Type --query "[0]" | ConvertFrom-Json
        if ($resource) {
            Write-Host "   ✅ Found $FriendlyName: $($resource.name)" -ForegroundColor Green
            return $resource
        } else {
            Write-Warning "   ⚠️  $FriendlyName not found"
            return $null
        }
    } catch {
        Write-Warning "   ⚠️  Error finding $FriendlyName`: $_"
        return $null
    }
}

# Function to get Key Vault secret
function Get-KeyVaultSecret {
    param([string]$VaultName, [string]$SecretName)
    
    try {
        $secret = az keyvault secret show --vault-name $VaultName --name $SecretName --query "value" -o tsv 2>$null
        return $secret
    } catch {
        Write-Warning "   ⚠️  Could not retrieve secret $SecretName from $VaultName"
        return $null
    }
}

# Discover resources
$openAI = Get-AzureResource "Microsoft.CognitiveServices/accounts" "Azure OpenAI Service"
$search = Get-AzureResource "Microsoft.Search/searchServices" "Azure AI Search"
$translator = Get-AzureResource "Microsoft.CognitiveServices/accounts" "Azure AI Translator"
$storage = Get-AzureResource "Microsoft.Storage/storageAccounts" "Storage Account"
$keyVault = Get-AzureResource "Microsoft.KeyVault/vaults" "Key Vault"
$workspace = Get-AzureResource "Microsoft.MachineLearningServices/workspaces" "AI Foundry Workspace"

Write-Host ""

# Filter resources by kind
if ($openAI -and $translator) {
    # Determine which is OpenAI vs Translator by checking kind or name
    $resources = @($openAI, $translator)
    $openAI = $resources | Where-Object { $_.kind -eq "OpenAI" -or $_.name -like "*openai*" } | Select-Object -First 1
    $translator = $resources | Where-Object { $_.kind -eq "TextTranslation" -or $_.name -like "*translator*" } | Select-Object -First 1
}

Write-Host "🔐 Retrieving secrets from Key Vault..." -ForegroundColor Yellow

$envVars = @{}

if ($keyVault) {
    $vaultName = $keyVault.name
    
    # OpenAI secrets
    if ($openAI) {
        $envVars['AZURE_OPENAI_ENDPOINT'] = Get-KeyVaultSecret $vaultName "openai-endpoint"
        $envVars['AZURE_OPENAI_API_KEY'] = Get-KeyVaultSecret $vaultName "openai-api-key"
        $envVars['AZURE_OPENAI_CHAT_DEPLOYMENT'] = Get-KeyVaultSecret $vaultName "openai-chat-deployment"
        $envVars['AZURE_OPENAI_EMBEDDING_DEPLOYMENT'] = Get-KeyVaultSecret $vaultName "openai-embedding-deployment"
    }
    
    # Search secrets
    if ($search) {
        $envVars['AZURE_SEARCH_ENDPOINT'] = Get-KeyVaultSecret $vaultName "search-endpoint"
        $envVars['AZURE_SEARCH_ADMIN_KEY'] = Get-KeyVaultSecret $vaultName "search-admin-key"
        $envVars['AZURE_SEARCH_QUERY_KEY'] = Get-KeyVaultSecret $vaultName "search-query-key"
    }
    
    # Translator secrets
    if ($translator) {
        $envVars['AZURE_TRANSLATOR_ENDPOINT'] = Get-KeyVaultSecret $vaultName "translator-endpoint"
        $envVars['AZURE_TRANSLATOR_KEY'] = Get-KeyVaultSecret $vaultName "translator-api-key"
        $envVars['AZURE_TRANSLATOR_REGION'] = Get-KeyVaultSecret $vaultName "translator-region"
    }
}

# Add non-secret values
if ($storage) {
    $envVars['AZURE_STORAGE_ACCOUNT_NAME'] = $storage.name
    $envVars['AZURE_STORAGE_CONTAINER_NAME'] = "docs"
}

if ($workspace) {
    $envVars['AZURE_AI_PROJECT_NAME'] = $workspace.name
}

# Add static configuration
$envVars['AZURE_SUBSCRIPTION_ID'] = $SubscriptionId
$envVars['AZURE_RESOURCE_GROUP_NAME'] = $ResourceGroupName
$envVars['AZURE_LOCATION'] = if ($openAI) { $openAI.location } else { "centralus" }
$envVars['SEARCH_INDEX_NAME'] = "medicaid-docs"

Write-Host ""
Write-Host "📝 Generating .env file..." -ForegroundColor Yellow

# Create .env content
$envContent = @"
# Azure AI Services Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
# Resource Group: $ResourceGroupName

# Azure OpenAI Service
AZURE_OPENAI_ENDPOINT=$($envVars['AZURE_OPENAI_ENDPOINT'])
AZURE_OPENAI_API_KEY=$($envVars['AZURE_OPENAI_API_KEY'])
AZURE_OPENAI_CHAT_DEPLOYMENT=$($envVars['AZURE_OPENAI_CHAT_DEPLOYMENT'])
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=$($envVars['AZURE_OPENAI_EMBEDDING_DEPLOYMENT'])
AZURE_OPENAI_API_VERSION=2024-02-01

# Azure AI Search
AZURE_SEARCH_ENDPOINT=$($envVars['AZURE_SEARCH_ENDPOINT'])
AZURE_SEARCH_ADMIN_KEY=$($envVars['AZURE_SEARCH_ADMIN_KEY'])
AZURE_SEARCH_QUERY_KEY=$($envVars['AZURE_SEARCH_QUERY_KEY'])
SEARCH_INDEX_NAME=$($envVars['SEARCH_INDEX_NAME'])

# Azure AI Translator
AZURE_TRANSLATOR_ENDPOINT=$($envVars['AZURE_TRANSLATOR_ENDPOINT'])
AZURE_TRANSLATOR_KEY=$($envVars['AZURE_TRANSLATOR_KEY'])
AZURE_TRANSLATOR_REGION=$($envVars['AZURE_TRANSLATOR_REGION'])

# Azure Storage
AZURE_STORAGE_ACCOUNT_NAME=$($envVars['AZURE_STORAGE_ACCOUNT_NAME'])
AZURE_STORAGE_CONTAINER_NAME=$($envVars['AZURE_STORAGE_CONTAINER_NAME'])

# Azure AI Foundry
AZURE_AI_PROJECT_NAME=$($envVars['AZURE_AI_PROJECT_NAME'])

# Azure Configuration
AZURE_SUBSCRIPTION_ID=$($envVars['AZURE_SUBSCRIPTION_ID'])
AZURE_RESOURCE_GROUP_NAME=$($envVars['AZURE_RESOURCE_GROUP_NAME'])
AZURE_LOCATION=$($envVars['AZURE_LOCATION'])

# Application Settings
LOG_LEVEL=INFO
MAX_SEARCH_RESULTS=10
CHUNK_SIZE=1000
CHUNK_OVERLAP=200

# Bing Search (for AI Agent)
# BING_SEARCH_URL=https://api.bing.microsoft.com/v7.0/search
# BING_SEARCH_KEY=your_bing_search_key_here
"@

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write .env file
$envContent | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "   ✅ Environment file created: $OutputPath" -ForegroundColor Green

# Display summary
Write-Host ""
Write-Host "📊 Configuration Summary:" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$configuredCount = 0
$totalCount = 0

foreach ($key in $envVars.Keys) {
    $totalCount++
    if ($envVars[$key]) {
        $configuredCount++
        $displayValue = if ($key -like "*KEY*" -or $key -like "*SECRET*") { "***REDACTED***" } else { $envVars[$key] }
        Write-Host "   ✅ $key = $displayValue" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $key = (not found)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📋 Results: $configuredCount/$totalCount variables configured" -ForegroundColor Blue

if ($configuredCount -eq $totalCount) {
    Write-Host "🎉 All environment variables configured successfully!" -ForegroundColor Green
} else {
    Write-Warning "⚠️  Some environment variables could not be configured. Check your deployment."
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review the generated .env file: $OutputPath" -ForegroundColor Yellow
Write-Host "2. Add any missing values (like Bing Search API key)" -ForegroundColor Yellow
Write-Host "3. Test your applications in the src/ directory" -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 Tip: Keep your .env file secure and never commit it to source control!" -ForegroundColor Blue
