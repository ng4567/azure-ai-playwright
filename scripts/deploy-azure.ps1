# Azure Infrastructure Deployment Script
# Deploys the complete Medicaid RAG + AI Agent solution using Bicep

param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$Location = "centralus",
    [string]$Environment = "dev",
    [string]$ProjectName = "medicaid-rag",
    [switch]$WhatIf,
    [switch]$SkipQuotaCheck,
    [switch]$Clean
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "🚀 Azure Infrastructure Deployment" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green

# Ensure we're in the correct directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$infraPath = Join-Path $rootPath "infra"

if (-not (Test-Path $infraPath)) {
    Write-Error "❌ Infrastructure path not found: $infraPath"
    exit 1
}

Set-Location $rootPath
Write-Host "📁 Working directory: $rootPath" -ForegroundColor Cyan

# Validate Azure CLI login
$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Cyan
Write-Host "📍 Target Location: $Location" -ForegroundColor Cyan
Write-Host "🏷️  Environment: $Environment" -ForegroundColor Cyan
Write-Host ""

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "🔄 Setting active subscription..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to set subscription: $SubscriptionId"
        exit 1
    }
    Write-Host "✅ Active subscription set to: $SubscriptionId" -ForegroundColor Green
}

# Pre-flight quota check
if (-not $SkipQuotaCheck) {
    Write-Host "🔍 Running pre-flight quota check..." -ForegroundColor Yellow
    $quotaScript = Join-Path $scriptPath "check-quota.ps1"
    if (Test-Path $quotaScript) {
        & $quotaScript -SubscriptionId $SubscriptionId -Location $Location
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Pre-flight quota check failed. Use -SkipQuotaCheck to bypass."
            exit 1
        }
    } else {
        Write-Warning "⚠️  Quota check script not found. Proceeding without validation."
    }
}

# Prepare deployment parameters
$deploymentName = "medicaid-rag-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$resourceGroupName = "rg-$ProjectName-$Environment"
$parametersFile = Join-Path $infraPath "main.bicepparam"

# Create tags
$tags = @{
    "project" = $ProjectName
    "environment" = $Environment
    "workload" = "ai-rag"
    "costCenter" = "development"
    "deployedBy" = "powershell"
    "deployedAt" = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

$tagsString = ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "

Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   Deployment Name: $deploymentName" -ForegroundColor White
Write-Host "   Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   Parameters File: $parametersFile" -ForegroundColor White
Write-Host ""

# Clean previous deployments if requested
if ($Clean) {
    Write-Host "🧹 Cleaning previous deployments..." -ForegroundColor Yellow
    
    # Check if resource group exists
    $rgExists = az group exists --name $resourceGroupName --query "." -o tsv
    if ($rgExists -eq "true") {
        Write-Host "   Deleting resource group: $resourceGroupName" -ForegroundColor Red
        az group delete --name $resourceGroupName --yes --no-wait
        Write-Host "   ✅ Resource group deletion initiated" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  Resource group does not exist: $resourceGroupName" -ForegroundColor Blue
    }
    
    # Wait for deletion to complete
    Write-Host "   ⏳ Waiting for resource group deletion..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 30
        $rgExists = az group exists --name $resourceGroupName --query "." -o tsv
        Write-Host "   ..." -ForegroundColor Gray
    } while ($rgExists -eq "true")
    
    Write-Host "   ✅ Resource group deleted successfully" -ForegroundColor Green
    Write-Host ""
}

# Check if parameters file exists, create if missing
if (-not (Test-Path $parametersFile)) {
    Write-Host "📄 Creating parameters file..." -ForegroundColor Yellow
    $paramsContent = @"
using './main.bicep'

param location = '$Location'
param environment = '$Environment'
param projectName = '$ProjectName'
param resourceGroupName = '$resourceGroupName'
param tags = {
  project: '$ProjectName'
  environment: '$Environment'
  workload: 'ai-rag'
  costCenter: 'development'
  deployedBy: 'bicep'
  deployedAt: utcNow()
}
param embeddingModel = 'text-embedding-3-large'
param chatModel = 'gpt-4o-mini'
param additionalModels = []
"@
    $paramsContent | Out-File -FilePath $parametersFile -Encoding UTF8
    Write-Host "   ✅ Parameters file created: $parametersFile" -ForegroundColor Green
}

# Validate Bicep template
Write-Host "🔍 Validating Bicep template..." -ForegroundColor Yellow
$mainBicepFile = Join-Path $infraPath "main.bicep"

az deployment sub validate `
    --location $Location `
    --template-file $mainBicepFile `
    --parameters $parametersFile `
    --name $deploymentName

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Bicep template validation failed"
    exit 1
}

Write-Host "✅ Bicep template validation successful" -ForegroundColor Green
Write-Host ""

# What-If mode
if ($WhatIf) {
    Write-Host "👀 Running What-If deployment analysis..." -ForegroundColor Cyan
    
    az deployment sub what-if `
        --location $Location `
        --template-file $mainBicepFile `
        --parameters $parametersFile `
        --name $deploymentName
    
    Write-Host ""
    Write-Host "📊 What-If analysis complete. No actual deployment performed." -ForegroundColor Blue
    exit 0
}

# Deploy infrastructure
Write-Host "🚀 Starting infrastructure deployment..." -ForegroundColor Green
Write-Host "   This may take 10-15 minutes..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date

try {
    $deploymentResult = az deployment sub create `
        --location $Location `
        --template-file $mainBicepFile `
        --parameters $parametersFile `
        --name $deploymentName `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment command failed with exit code $LASTEXITCODE"
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "🎉 Infrastructure deployment completed successfully!" -ForegroundColor Green
    Write-Host "⏱️  Total deployment time: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""

    # Display key outputs
    if ($deploymentResult.properties.outputs) {
        Write-Host "📋 Deployment Outputs:" -ForegroundColor Cyan
        Write-Host "======================" -ForegroundColor Cyan
        
        $outputs = $deploymentResult.properties.outputs
        
        if ($outputs.resourceGroupName) {
            Write-Host "   Resource Group: $($outputs.resourceGroupName.value)" -ForegroundColor White
        }
        if ($outputs.aiHubName) {
            Write-Host "   AI Hub: $($outputs.aiHubName.value)" -ForegroundColor White
        }
        if ($outputs.openAIServiceName) {
            Write-Host "   OpenAI Service: $($outputs.openAIServiceName.value)" -ForegroundColor White
        }
        if ($outputs.aiSearchServiceName) {
            Write-Host "   AI Search: $($outputs.aiSearchServiceName.value)" -ForegroundColor White
        }
        if ($outputs.keyVaultName) {
            Write-Host "   Key Vault: $($outputs.keyVaultName.value)" -ForegroundColor White
        }
        
        Write-Host ""
    }

    # Next steps
    Write-Host "🎯 Next Steps:" -ForegroundColor Green
    Write-Host "=============" -ForegroundColor Green
    Write-Host "1. 🔐 Configure Key Vault access policies for your identity" -ForegroundColor Yellow
    Write-Host "2. 📊 Upload Medicaid documents to the storage container" -ForegroundColor Yellow
    Write-Host "3. 🔍 Create search indexes using the setup scripts" -ForegroundColor Yellow
    Write-Host "4. 🤖 Deploy and test the RAG application" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Tip: Use the automation scripts in /scripts for these tasks!" -ForegroundColor Cyan

} catch {
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Error "❌ Infrastructure deployment failed after $($duration.ToString('mm\:ss'))"
    Write-Host ""
    Write-Host "🔧 Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "1. Check quota availability in the target region" -ForegroundColor White
    Write-Host "2. Verify Azure permissions for resource creation" -ForegroundColor White
    Write-Host "3. Review deployment logs in Azure Portal" -ForegroundColor White
    Write-Host "4. Try a different region if quota is exhausted" -ForegroundColor White
    
    exit 1
}
