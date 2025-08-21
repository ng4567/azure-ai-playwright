# Pre-flight Quota Check Script
# Validates Azure quota for AI services before deployment

param(
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$Location = "centralus",
    [string]$ResourceGroupName = "rg-medicaid-rag-dev"
)

Write-Host "🔍 Pre-flight Quota Check for Azure AI Services" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Ensure we're logged into Azure
$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Cyan
Write-Host "📍 Target Location: $Location" -ForegroundColor Cyan
Write-Host ""

$quotaErrors = 0
$quotaWarnings = 0

# Function to check quota
function Test-Quota {
    param(
        [string]$Provider,
        [string]$ResourceType,
        [string]$MetricName,
        [int]$RequiredQuota,
        [string]$Description
    )
    
    Write-Host "🔍 Checking $Description..." -ForegroundColor Yellow
    
    try {
        # Get current quota usage
        $quotaResponse = az rest --method GET --url "https://management.azure.com/subscriptions/$SubscriptionId/providers/$Provider/locations/$Location/quotas/$ResourceType" --query "properties" 2>$null
        
        if ($quotaResponse) {
            $quota = $quotaResponse | ConvertFrom-Json
            $currentUsage = $quota.currentUsage
            $limit = $quota.limit
            $available = $limit - $currentUsage
            
            Write-Host "   Current Usage: $currentUsage" -ForegroundColor White
            Write-Host "   Quota Limit: $limit" -ForegroundColor White
            Write-Host "   Available: $available" -ForegroundColor White
            
            if ($available -ge $RequiredQuota) {
                Write-Host "   ✅ Sufficient quota available" -ForegroundColor Green
            } elseif ($available -gt 0) {
                Write-Host "   ⚠️  Limited quota available (need $RequiredQuota, have $available)" -ForegroundColor Yellow
                $script:quotaWarnings++
            } else {
                Write-Host "   ❌ No quota available (need $RequiredQuota, have $available)" -ForegroundColor Red
                $script:quotaErrors++
            }
        } else {
            Write-Host "   ⚠️  Could not retrieve quota information" -ForegroundColor Yellow
            $script:quotaWarnings++
        }
    }
    catch {
        Write-Host "   ⚠️  Error checking quota: $_" -ForegroundColor Yellow
        $script:quotaWarnings++
    }
    
    Write-Host ""
}

# Function to check OpenAI model availability
function Test-OpenAIModelAvailability {
    param(
        [string]$ModelName,
        [string]$Description
    )
    
    Write-Host "🤖 Checking $Description availability..." -ForegroundColor Yellow
    
    try {
        # Check model availability in the region
        $modelsResponse = az rest --method GET --url "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Location/models" --query "value[?name=='$ModelName']" 2>$null
        
        if ($modelsResponse) {
            $models = $modelsResponse | ConvertFrom-Json
            if ($models.Count -gt 0) {
                $model = $models[0]
                Write-Host "   ✅ $ModelName is available in $Location" -ForegroundColor Green
                Write-Host "   Version: $($model.version)" -ForegroundColor White
                if ($model.capabilities) {
                    Write-Host "   Capabilities: $($model.capabilities -join ', ')" -ForegroundColor White
                }
            } else {
                Write-Host "   ❌ $ModelName is not available in $Location" -ForegroundColor Red
                $script:quotaErrors++
            }
        } else {
            Write-Host "   ⚠️  Could not retrieve model availability" -ForegroundColor Yellow
            $script:quotaWarnings++
        }
    }
    catch {
        Write-Host "   ⚠️  Error checking model availability: $_" -ForegroundColor Yellow
        $script:quotaWarnings++
    }
    
    Write-Host ""
}

# Check Azure OpenAI Service quota
Test-Quota -Provider "Microsoft.CognitiveServices" -ResourceType "OpenAI.Standard" -MetricName "OpenAI" -RequiredQuota 1 -Description "Azure OpenAI Service"

# Check Azure AI Search quota
Test-Quota -Provider "Microsoft.Search" -ResourceType "searchServices" -MetricName "SearchServices" -RequiredQuota 1 -Description "Azure AI Search Service"

# Check Cognitive Services quota (for Translator)
Test-Quota -Provider "Microsoft.CognitiveServices" -ResourceType "TextTranslation" -MetricName "TextTranslation" -RequiredQuota 1 -Description "Azure AI Translator Service"

# Check OpenAI model availability
Test-OpenAIModelAvailability -ModelName "text-embedding-3-large" -Description "Text Embedding 3 Large model"
Test-OpenAIModelAvailability -ModelName "gpt-4o-mini" -Description "GPT-4o Mini model"

# Check region capacity for AI services
Write-Host "🌍 Checking regional capacity..." -ForegroundColor Yellow
try {
    $capacityResponse = az rest --method GET --url "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Location/usages" 2>$null
    if ($capacityResponse) {
        Write-Host "   ✅ Regional capacity information available" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Could not retrieve regional capacity information" -ForegroundColor Yellow
        $quotaWarnings++
    }
}
catch {
    Write-Host "   ⚠️  Error checking regional capacity: $_" -ForegroundColor Yellow
    $quotaWarnings++
}
Write-Host ""

# Summary
Write-Host "📊 Pre-flight Check Summary:" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

if ($quotaErrors -eq 0 -and $quotaWarnings -eq 0) {
    Write-Host "🎉 All quota checks passed! Ready for deployment." -ForegroundColor Green
    exit 0
} elseif ($quotaErrors -eq 0) {
    Write-Host "⚠️  $quotaWarnings warning(s) found. Deployment may succeed but monitor carefully." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Recommendations:" -ForegroundColor Cyan
    Write-Host "   - Monitor deployment progress closely"
    Write-Host "   - Have backup regions ready"
    Write-Host "   - Consider requesting quota increases"
    exit 0
} else {
    Write-Host "❌ $quotaErrors error(s) and $quotaWarnings warning(s) found." -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Required Actions:" -ForegroundColor Cyan
    Write-Host "   1. Request quota increases for failed checks"
    Write-Host "   2. Consider alternative regions with available capacity"
    Write-Host "   3. Contact Azure support if needed"
    Write-Host ""
    Write-Host "🌍 Alternative regions to try:" -ForegroundColor Cyan
    Write-Host "   - East US 2"
    Write-Host "   - West US 2"
    Write-Host "   - North Central US"
    Write-Host "   - South Central US"
    exit 1
}
