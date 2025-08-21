# Post-Deployment Setup Script
# Automates configuration after infrastructure deployment

param(
    [string]$ResourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME,
    [string]$Location = $env:AZURE_LOCATION
)

Write-Host "🚀 Starting post-deployment configuration..." -ForegroundColor Green

# Ensure we're logged into Azure
$context = az account show --query "name" -o tsv
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Using Azure subscription: $context" -ForegroundColor Cyan

# Set default resource group if not provided
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-medicaid-rag-dev"
    Write-Host "⚠️  Using default resource group: $ResourceGroupName" -ForegroundColor Yellow
}

Write-Host "📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName"
Write-Host "   Location: $Location"
Write-Host ""

# Run individual setup scripts
Write-Host "🔍 Setting up AI Search index..." -ForegroundColor Blue
& "$PSScriptRoot\setup-search-index.ps1" -ResourceGroupName $ResourceGroupName

Write-Host "🤖 Deploying OpenAI models..." -ForegroundColor Blue
& "$PSScriptRoot\deploy-models.ps1" -ResourceGroupName $ResourceGroupName

Write-Host "🔐 Populating Key Vault secrets..." -ForegroundColor Blue
& "$PSScriptRoot\populate-secrets.ps1" -ResourceGroupName $ResourceGroupName

Write-Host "✅ Post-deployment configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Configure Azure AI Foundry agent manually"
Write-Host "   2. Run data ingestion: uv run data/ingest-data.py"
Write-Host "   3. Validate deployment: scripts/validate-deployment.ps1"
Write-Host "   4. Start local development!"
