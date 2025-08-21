# Deployment Validation Script
# Validates that all Azure services are properly configured

param(
    [string]$ResourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
)

Write-Host "🔍 Validating deployment..." -ForegroundColor Blue

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
    Write-Host "✅ Environment variables loaded from .env" -ForegroundColor Green
} else {
    Write-Warning "⚠️  .env file not found. Some validations may fail."
}

$errors = 0

# Validate Azure CLI authentication
Write-Host "🔐 Checking Azure authentication..." -ForegroundColor Cyan
$context = az account show --query "name" -o tsv 2>$null
if ($context) {
    Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Green
} else {
    Write-Host "❌ Not authenticated to Azure. Run 'az login'" -ForegroundColor Red
    $errors++
}

# Validate resource group exists
if ($ResourceGroupName) {
    Write-Host "📦 Checking resource group: $ResourceGroupName..." -ForegroundColor Cyan
    $rg = az group show --name $ResourceGroupName --query "name" -o tsv 2>$null
    if ($rg) {
        Write-Host "✅ Resource group exists: $ResourceGroupName" -ForegroundColor Green
    } else {
        Write-Host "❌ Resource group not found: $ResourceGroupName" -ForegroundColor Red
        $errors++
    }
}

# Validate AI Search service
if ($env:AZURE_SEARCH_ENDPOINT) {
    Write-Host "🔍 Checking AI Search service..." -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri "$($env:AZURE_SEARCH_ENDPOINT)/indexes?api-version=2023-11-01" `
            -Headers @{"api-key" = $env:AZURE_SEARCH_ADMIN_KEY} `
            -Method GET -ErrorAction Stop
        Write-Host "✅ AI Search service accessible" -ForegroundColor Green
        
        # Check for medicaid index
        $medicaidIndex = $response.value | Where-Object { $_.name -eq "md-medicaid" }
        if ($medicaidIndex) {
            Write-Host "✅ Medicaid index exists" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Medicaid index not found. Run data ingestion." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ AI Search service not accessible: $_" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "⚠️  AI Search endpoint not configured" -ForegroundColor Yellow
}

# Validate OpenAI service
if ($env:AZURE_OPENAI_ENDPOINT -and $env:AZURE_OPENAI_API_KEY) {
    Write-Host "🤖 Checking OpenAI service..." -ForegroundColor Cyan
    try {
        $headers = @{
            "api-key" = $env:AZURE_OPENAI_API_KEY
            "Content-Type" = "application/json"
        }
        $response = Invoke-RestMethod -Uri "$($env:AZURE_OPENAI_ENDPOINT)/openai/deployments?api-version=2023-05-15" `
            -Headers $headers -Method GET -ErrorAction Stop
        Write-Host "✅ OpenAI service accessible" -ForegroundColor Green
        
        # Check for required deployments
        $embedModel = $response.data | Where-Object { $_.id -eq $env:AZURE_OPENAI_EMBED_DEPLOYMENT }
        $chatModel = $response.data | Where-Object { $_.id -eq $env:AZURE_OPENAI_CHAT_DEPLOYMENT }
        
        if ($embedModel) {
            Write-Host "✅ Embedding model deployed: $($env:AZURE_OPENAI_EMBED_DEPLOYMENT)" -ForegroundColor Green
        } else {
            Write-Host "❌ Embedding model not found: $($env:AZURE_OPENAI_EMBED_DEPLOYMENT)" -ForegroundColor Red
            $errors++
        }
        
        if ($chatModel) {
            Write-Host "✅ Chat model deployed: $($env:AZURE_OPENAI_CHAT_DEPLOYMENT)" -ForegroundColor Green
        } else {
            Write-Host "❌ Chat model not found: $($env:AZURE_OPENAI_CHAT_DEPLOYMENT)" -ForegroundColor Red
            $errors++
        }
    } catch {
        Write-Host "❌ OpenAI service not accessible: $_" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "⚠️  OpenAI service not configured" -ForegroundColor Yellow
}

# Validate Python environment
Write-Host "🐍 Checking Python environment..." -ForegroundColor Cyan
if (Test-Path ".venv") {
    Write-Host "✅ Virtual environment exists" -ForegroundColor Green
} else {
    Write-Host "⚠️  Virtual environment not found. Run 'uv venv .venv'" -ForegroundColor Yellow
}

# Summary
Write-Host ""
if ($errors -eq 0) {
    Write-Host "🎉 All validations passed! Ready for local development." -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Run data ingestion: uv run data/ingest-data.py"
    Write-Host "   2. Test RAG system: uv run medicaid-rag.py"
    Write-Host "   3. Start developing!"
} else {
    Write-Host "❌ $errors validation(s) failed. Please fix the issues above." -ForegroundColor Red
    exit 1
}
