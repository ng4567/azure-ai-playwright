# Key Vault Cleanup Script
# Purges deleted Key Vaults that might conflict with deployments

param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$KeyVaultNamePattern = "*",
    [switch]$ListOnly,
    [switch]$Force
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "🔍 Key Vault Cleanup Utility" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Validate Azure CLI login
$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Cyan

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "🔄 Setting active subscription..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to set subscription: $SubscriptionId"
        exit 1
    }
    Write-Host "✅ Active subscription set to: $SubscriptionId" -ForegroundColor Cyan
}

Write-Host ""

# List deleted Key Vaults
Write-Host "🔍 Searching for deleted Key Vaults..." -ForegroundColor Yellow
$deletedVaults = az keyvault list-deleted --subscription $SubscriptionId -o json 2>$null

if (-not $deletedVaults -or $deletedVaults -eq "[]") {
    Write-Host "✅ No deleted Key Vaults found." -ForegroundColor Green
    exit 0
}

$vaults = $deletedVaults | ConvertFrom-Json

# Filter by pattern if specified
if ($KeyVaultNamePattern -ne "*") {
    $vaults = $vaults | Where-Object { $_.name -like $KeyVaultNamePattern }
}

if ($vaults.Count -eq 0) {
    Write-Host "✅ No deleted Key Vaults match the pattern: $KeyVaultNamePattern" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($vaults.Count) deleted Key Vault(s):" -ForegroundColor Cyan
Write-Host ""

foreach ($vault in $vaults) {
    $name = $vault.name
    $location = $vault.properties.location
    $deletionDate = $vault.properties.deletionDate
    $purgeProtected = $vault.properties.purgeProtectionEnabled

    Write-Host "🗂️  Name: $name" -ForegroundColor White
    Write-Host "   📍 Location: $location" -ForegroundColor Gray
    Write-Host "   🗓️  Deleted: $deletionDate" -ForegroundColor Gray
    Write-Host "   🔒 Purge Protected: $purgeProtected" -ForegroundColor Gray
    Write-Host ""
}

if ($ListOnly) {
    Write-Host "ℹ️  List-only mode. No actions taken." -ForegroundColor Blue
    exit 0
}

# Confirm purge operation
if (-not $Force) {
    $confirmation = Read-Host "⚠️  Do you want to purge these Key Vault(s)? This action is IRREVERSIBLE! (yes/no)"
    if ($confirmation.ToLower() -ne "yes") {
        Write-Host "❌ Operation cancelled by user." -ForegroundColor Red
        exit 1
    }
}

# Purge Key Vaults
Write-Host "🧹 Purging deleted Key Vaults..." -ForegroundColor Yellow

foreach ($vault in $vaults) {
    $name = $vault.name
    $location = $vault.properties.location
    $purgeProtected = $vault.properties.purgeProtectionEnabled

    if ($purgeProtected -eq $true) {
        Write-Host "⚠️  Skipping $name - Purge protection is enabled" -ForegroundColor Yellow
        continue
    }

    Write-Host "   Purging: $name in $location..." -ForegroundColor Gray

    try {
        az keyvault purge --name $name --location $location --subscription $SubscriptionId --no-wait 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Purge initiated for: $name" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Failed to purge: $name" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Error purging $name`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✅ Key Vault cleanup completed." -ForegroundColor Green
Write-Host "ℹ️  Note: Purge operations run in the background and may take a few minutes to complete." -ForegroundColor Blue
