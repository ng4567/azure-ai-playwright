#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates Azure AI infrastructure deployment for Medicaid RAG application.

.DESCRIPTION
    This script performs comprehensive validation of the deployed Azure AI infrastructure,
    including resource existence, configuration, and OpenAI model deployments.

.PARAMETER SubscriptionId
    The Azure subscription ID where resources are deployed.

.PARAMETER ProjectName
    The name of the project (used in resource naming).

.PARAMETER Environment
    The target environment (dev, test, prod).

.PARAMETER ResourceGroupName
    Optional. The resource group name. If not provided, will be constructed from project and environment.

.EXAMPLE
    .\validate-deployment.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ProjectName "medicaid-rag" -Environment "dev"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory = $true)]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName
)

# Set error handling
$ErrorActionPreference = "Stop"

# Initialize validation results
$validationResults = @{
    TotalChecks = 0
    PassedChecks = 0
    FailedChecks = 0
    Warnings = 0
    Results = @()
}

function Write-ValidationResult {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Details = "",
        [string]$ResourceName = ""
    )
    
    $validationResults.TotalChecks++
    
    $icon = switch ($Status) {
        "PASS" { "✅"; $validationResults.PassedChecks++ }
        "FAIL" { "❌"; $validationResults.FailedChecks++ }
        "WARN" { "⚠️"; $validationResults.Warnings++ }
        default { "ℹ️" }
    }
    
    $message = "$icon $Check"
    if ($ResourceName) {
        $message += " [$ResourceName]"
    }
    if ($Details) {
        $message += ": $Details"
    }
    
    Write-Host $message
    
    $validationResults.Results += @{
        Check = $Check
        Status = $Status
        Details = $Details
        ResourceName = $ResourceName
    }
}

function Test-ResourceExists {
    param(
        [string]$ResourceGroupName,
        [string]$ResourceName,
        [string]$ResourceType
    )
    
    try {
        $resource = az resource show --resource-group $ResourceGroupName --name $ResourceName --resource-type $ResourceType --output json 2>$null | ConvertFrom-Json
        return $resource -ne $null
    }
    catch {
        return $false
    }
}

function Test-OpenAIModels {
    param(
        [string]$ResourceGroupName,
        [string]$OpenAIAccountName
    )
    
    try {
        $deployments = az cognitiveservices account deployment list --resource-group $ResourceGroupName --name $OpenAIAccountName --output json | ConvertFrom-Json
        
        $expectedModels = @{
            'gpt-chat' = 'gpt-4o-mini'
            'text-embedding' = 'text-embedding-3-large'
        }
        
        $results = @{}
        
        foreach ($deployment in $deployments) {
            $deploymentName = $deployment.name
            $modelName = $deployment.properties.model.name
            $provisioningState = $deployment.properties.provisioningState
            
            if ($expectedModels.ContainsKey($deploymentName)) {
                $expectedModel = $expectedModels[$deploymentName]
                if ($modelName -eq $expectedModel -and $provisioningState -eq "Succeeded") {
                    $results[$deploymentName] = "PASS"
                    Write-ValidationResult "OpenAI Model Deployment" "PASS" "$deploymentName ($modelName) - $provisioningState" $OpenAIAccountName
                }
                else {
                    $results[$deploymentName] = "FAIL"
                    Write-ValidationResult "OpenAI Model Deployment" "FAIL" "$deploymentName expected $expectedModel, got $modelName - $provisioningState" $OpenAIAccountName
                }
            }
        }
        
        # Check for missing deployments
        foreach ($expectedDeployment in $expectedModels.Keys) {
            if (-not $results.ContainsKey($expectedDeployment)) {
                Write-ValidationResult "OpenAI Model Deployment" "FAIL" "$expectedDeployment deployment not found" $OpenAIAccountName
            }
        }
        
        return $results.Values -notcontains "FAIL"
    }
    catch {
        Write-ValidationResult "OpenAI Model Validation" "FAIL" "Failed to validate models: $($_.Exception.Message)" $OpenAIAccountName
        return $false
    }
}

# Main validation logic
Write-Host "� Azure AI Infrastructure Validation" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription
Write-Host "🔄 Setting Azure subscription..." -ForegroundColor Yellow
try {
    az account set --subscription $SubscriptionId
    $currentSub = az account show --output json | ConvertFrom-Json
    Write-ValidationResult "Subscription Access" "PASS" $currentSub.name
}
catch {
    Write-ValidationResult "Subscription Access" "FAIL" "Failed to set subscription: $($_.Exception.Message)"
    exit 1
}

# Construct resource group name if not provided
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-$ProjectName-$Environment"
}

Write-Host ""
Write-Host "📍 Target Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host ""

# Check resource group existence
try {
    $rg = az group show --name $ResourceGroupName --output json | ConvertFrom-Json
    Write-ValidationResult "Resource Group" "PASS" "Location: $($rg.location)" $ResourceGroupName
}
catch {
    Write-ValidationResult "Resource Group" "FAIL" "Resource group not found" $ResourceGroupName
    exit 1
}

# Define expected resources
$expectedResources = @(
    @{
        Name = "$ProjectName-logs-$Environment"
        Type = "Microsoft.OperationalInsights/workspaces"
        DisplayName = "Log Analytics Workspace"
    },
    @{
        Name = "$ProjectName-insights-$Environment"
        Type = "Microsoft.Insights/components"
        DisplayName = "Application Insights"
    },
    @{
        Name = "$ProjectName-kv-$Environment"
        Type = "Microsoft.KeyVault/vaults"
        DisplayName = "Key Vault"
    },
    @{
        Name = "$ProjectName-hub-$Environment"
        Type = "Microsoft.MachineLearningServices/workspaces"
        DisplayName = "AI Foundry Hub"
    },
    @{
        Name = "$ProjectName-project-$Environment"
        Type = "Microsoft.MachineLearningServices/workspaces"
        DisplayName = "AI Foundry Project"
    }
)

# Get actual resources to find dynamic names
$actualResources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json

# Check core resources with fixed names
foreach ($expectedResource in $expectedResources) {
    $resourceExists = Test-ResourceExists -ResourceGroupName $ResourceGroupName -ResourceName $expectedResource.Name -ResourceType $expectedResource.Type
    
    if ($resourceExists) {
        Write-ValidationResult $expectedResource.DisplayName "PASS" "Resource exists" $expectedResource.Name
    }
    else {
        Write-ValidationResult $expectedResource.DisplayName "FAIL" "Resource not found" $expectedResource.Name
    }
}

# Check storage account with dynamic name pattern
$storageResource = $actualResources | Where-Object { $_.type -eq "Microsoft.Storage/storageAccounts" }
if ($storageResource) {
    Write-ValidationResult "Storage Account" "PASS" "Resource exists" $storageResource.name
}
else {
    Write-ValidationResult "Storage Account" "FAIL" "Storage account not found"
}

# Check resources with dynamic names
$openaiResource = $actualResources | Where-Object { $_.type -eq "Microsoft.CognitiveServices/accounts" -and $_.name -like "openai-*" }
if ($openaiResource) {
    Write-ValidationResult "OpenAI Service" "PASS" "Location: $($openaiResource.location)" $openaiResource.name
    
    # Validate OpenAI models
    Write-Host ""
    Write-Host "🤖 Validating OpenAI Model Deployments..." -ForegroundColor Yellow
    $modelsValid = Test-OpenAIModels -ResourceGroupName $ResourceGroupName -OpenAIAccountName $openaiResource.name
}
else {
    Write-ValidationResult "OpenAI Service" "FAIL" "OpenAI resource not found"
}

$searchResource = $actualResources | Where-Object { $_.type -eq "Microsoft.Search/searchServices" -and $_.name -like "search-*" }
if ($searchResource) {
    Write-ValidationResult "AI Search Service" "PASS" "Location: $($searchResource.location)" $searchResource.name
}
else {
    Write-ValidationResult "AI Search Service" "FAIL" "AI Search resource not found"
}

$translatorResource = $actualResources | Where-Object { $_.type -eq "Microsoft.CognitiveServices/accounts" -and $_.name -like "translator-*" }
if ($translatorResource) {
    Write-ValidationResult "Translator Service" "PASS" "Location: $($translatorResource.location)" $translatorResource.name
}
else {
    Write-ValidationResult "Translator Service" "FAIL" "Translator resource not found"
}

# Check deployment status
Write-Host ""
Write-Host "📋 Checking Deployment Status..." -ForegroundColor Yellow
try {
    $deployments = az deployment group list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    $latestDeployments = $deployments | Sort-Object { $_.properties.timestamp } -Descending | Select-Object -First 8
    
    $allSucceeded = $true
    foreach ($deployment in $latestDeployments) {
        $status = $deployment.properties.provisioningState
        if ($status -eq "Succeeded") {
            Write-ValidationResult "Deployment Status" "PASS" $status $deployment.name
        }
        else {
            Write-ValidationResult "Deployment Status" "FAIL" $status $deployment.name
            $allSucceeded = $false
        }
    }
}
catch {
    Write-ValidationResult "Deployment Status Check" "FAIL" "Failed to retrieve deployment status: $($_.Exception.Message)"
}

# Connectivity tests
Write-Host ""
Write-Host "🌐 Testing Service Connectivity..." -ForegroundColor Yellow

# Test Key Vault access
if ($expectedResources | Where-Object { $_.DisplayName -eq "Key Vault" }) {
    try {
        $kvName = "$ProjectName-kv-$Environment"
        $secrets = az keyvault secret list --vault-name $kvName --output json 2>$null | ConvertFrom-Json
        Write-ValidationResult "Key Vault Access" "PASS" "Successfully accessed vault" $kvName
    }
    catch {
        Write-ValidationResult "Key Vault Access" "WARN" "Unable to access Key Vault (may need access policy configuration)" $kvName
    }
}

# Test OpenAI service endpoint
if ($openaiResource) {
    try {
        $openaiDetails = az cognitiveservices account show --resource-group $ResourceGroupName --name $openaiResource.name --output json | ConvertFrom-Json
        $endpoint = $openaiDetails.properties.endpoint
        if ($endpoint) {
            Write-ValidationResult "OpenAI Endpoint" "PASS" "Endpoint accessible: $endpoint" $openaiResource.name
        }
        else {
            Write-ValidationResult "OpenAI Endpoint" "WARN" "Endpoint not found in resource details" $openaiResource.name
        }
    }
    catch {
        Write-ValidationResult "OpenAI Endpoint" "FAIL" "Failed to retrieve endpoint information" $openaiResource.name
    }
}

# Summary
Write-Host ""
Write-Host "� Validation Summary" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Checks: $($validationResults.TotalChecks)" -ForegroundColor White
Write-Host "✅ Passed: $($validationResults.PassedChecks)" -ForegroundColor Green
Write-Host "❌ Failed: $($validationResults.FailedChecks)" -ForegroundColor Red
Write-Host "⚠️  Warnings: $($validationResults.Warnings)" -ForegroundColor Yellow
Write-Host ""

$successRate = [math]::Round(($validationResults.PassedChecks / $validationResults.TotalChecks) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

if ($validationResults.FailedChecks -eq 0) {
    Write-Host ""
    Write-Host "🎉 All critical validations passed! Infrastructure is ready for use." -ForegroundColor Green
    exit 0
}
else {
    Write-Host ""
    Write-Host "⚠️  Some validations failed. Please review the issues above." -ForegroundColor Yellow
    exit 1
}
