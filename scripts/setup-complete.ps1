# Complete Setup Script for Medicaid RAG + AI Agent Solution
# Automates the entire deployment and setup process

param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$Location = "centralus",
    [string]$Environment = "dev",
    [string]$ProjectName = "medicaid-rag",
    [switch]$SkipQuotaCheck,
    [switch]$SkipValidation,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "🎯 Medicaid RAG + AI Agent Complete Setup" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Get script directory and set paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath

# Change to root directory
Set-Location $rootPath
Write-Host "📁 Working directory: $rootPath" -ForegroundColor Cyan
Write-Host ""

# Step 1: Prerequisites Check
Write-Host "1️⃣  Checking Prerequisites..." -ForegroundColor Blue
Write-Host "=============================" -ForegroundColor Blue

# Check Azure CLI
try {
    $azVersion = az --version 2>$null | Select-Object -First 1
    Write-Host "   ✅ Azure CLI: $azVersion" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI not found. Please install from https://aka.ms/installazurecli"
    exit 1
}

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "   ✅ PowerShell: $($psVersion.ToString())" -ForegroundColor Green
} else {
    Write-Warning "⚠️  PowerShell 7+ recommended. Current: $($psVersion.ToString())"
}

# Check Python
try {
    $pythonVersion = python --version 2>$null
    Write-Host "   ✅ Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Error "❌ Python not found. Please install Python 3.11+ from https://python.org"
    exit 1
}

# Check uv
try {
    $uvVersion = uv --version 2>$null
    Write-Host "   ✅ uv package manager: $uvVersion" -ForegroundColor Green
} catch {
    Write-Warning "⚠️  uv package manager not found. Install with: pip install uv"
}

Write-Host ""

# Step 2: Azure Authentication
Write-Host "2️⃣  Azure Authentication..." -ForegroundColor Blue
Write-Host "=============================" -ForegroundColor Blue

$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Host "   🔑 Logging into Azure..." -ForegroundColor Yellow
    az login
    $context = az account show --query "name" -o tsv
}

Write-Host "   ✅ Authenticated to: $context" -ForegroundColor Green

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    Write-Host "   ✅ Active subscription: $SubscriptionId" -ForegroundColor Green
}

Write-Host ""

# Step 3: Pre-flight Quota Check
if (-not $SkipQuotaCheck) {
    Write-Host "3️⃣  Pre-flight Quota Check..." -ForegroundColor Blue
    Write-Host "==============================" -ForegroundColor Blue

    $quotaScript = Join-Path $scriptPath "check-quota.ps1"
    if (Test-Path $quotaScript) {
        & $quotaScript -SubscriptionId $SubscriptionId -Location $Location
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Quota check failed. Review quota availability or use -SkipQuotaCheck"
            exit 1
        }
    } else {
        Write-Warning "⚠️  Quota check script not found"
    }
    Write-Host ""
} else {
    Write-Host "3️⃣  Skipping quota check..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 4: Infrastructure Deployment
Write-Host "4️⃣  Infrastructure Deployment..." -ForegroundColor Blue
Write-Host "=================================" -ForegroundColor Blue

$deployScript = Join-Path $scriptPath "deploy-azure.ps1"
if (Test-Path $deployScript) {
    $deployArgs = @(
        "-SubscriptionId", $SubscriptionId
        "-Location", $Location
        "-Environment", $Environment
        "-ProjectName", $ProjectName
    )

    if ($WhatIf) {
        $deployArgs += "-WhatIf"
    }

    & $deployScript @deployArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Infrastructure deployment failed"
        exit 1
    }
} else {
    Write-Error "❌ Deployment script not found: $deployScript"
    exit 1
}

Write-Host ""

# Step 5: Infrastructure Validation
if (-not $SkipValidation -and -not $WhatIf) {
    Write-Host "5️⃣  Infrastructure Validation..." -ForegroundColor Blue
    Write-Host "=================================" -ForegroundColor Blue

    $resourceGroupName = "rg-$ProjectName-$Environment"
    $validateScript = Join-Path $scriptPath "validate-infrastructure.ps1"

    if (Test-Path $validateScript) {
        & $validateScript -ResourceGroupName $resourceGroupName -SubscriptionId $SubscriptionId

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️  Infrastructure validation failed. Check the issues above."
        }
    } else {
        Write-Warning "⚠️  Validation script not found"
    }
    Write-Host ""
} else {
    Write-Host "5️⃣  Skipping infrastructure validation..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 6: Environment Setup
if (-not $WhatIf) {
    Write-Host "6️⃣  Environment Setup..." -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue

    # Create Python virtual environment
    $srcPath = Join-Path $rootPath "src"
    if (-not (Test-Path $srcPath)) {
        New-Item -ItemType Directory -Path $srcPath -Force | Out-Null
    }

    Set-Location $srcPath

    # Setup virtual environment
    if (-not (Test-Path ".venv")) {
        Write-Host "   🐍 Creating Python virtual environment..." -ForegroundColor Yellow
        uv venv .venv
    }

    # Activate virtual environment
    $activateScript = ".\.venv\Scripts\Activate.ps1"
    if (Test-Path $activateScript) {
        & $activateScript
        Write-Host "   ✅ Virtual environment activated" -ForegroundColor Green
    }

    # Install dependencies
    if (Test-Path "..\pyproject.toml") {
        Write-Host "   📦 Installing Python dependencies..." -ForegroundColor Yellow
        uv sync
        Write-Host "   ✅ Dependencies installed" -ForegroundColor Green
    }

    # Setup environment file
    $envTemplate = Join-Path $rootPath ".env.template"
    $envFile = ".env"

    if ((Test-Path $envTemplate) -and (-not (Test-Path $envFile))) {
        Copy-Item $envTemplate $envFile
        Write-Host "   ✅ Environment file created: $envFile" -ForegroundColor Green
        Write-Host "   ⚠️  Remember to update .env with your service details" -ForegroundColor Yellow
    }

    Set-Location $rootPath
    Write-Host ""
}

# Final Summary
if ($WhatIf) {
    Write-Host "👀 What-If Analysis Complete" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "No actual deployment was performed. Review the changes above and run without -WhatIf when ready." -ForegroundColor Blue
} else {
    Write-Host "🎉 Setup Complete!" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 🔐 Update src\.env with your service details from Key Vault" -ForegroundColor Yellow
    Write-Host "2. 📊 Upload Medicaid documents: uv run data\ingest-data.py" -ForegroundColor Yellow
    Write-Host "3. 🧪 Test the applications:" -ForegroundColor Yellow
    Write-Host "   - cd src" -ForegroundColor White
    Write-Host "   - .\.venv\Scripts\Activate.ps1" -ForegroundColor White
    Write-Host "   - uv run medicaid-rag.py" -ForegroundColor White
    Write-Host "   - uv run scraper.py" -ForegroundColor White
    Write-Host "   - uv run bing.py" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Tip: Check docs\ folder for detailed usage guides!" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "📋 Resource Group: rg-$ProjectName-$Environment" -ForegroundColor Blue
Write-Host "📍 Region: $Location" -ForegroundColor Blue
Write-Host "🏷️  Environment: $Environment" -ForegroundColor Blue
