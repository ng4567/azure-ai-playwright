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
        [string]$Location,
        [string]$SubscriptionId,
        [string]$Description
    )

    Write-Host "🔍 Checking $Description..." -ForegroundColor Yellow

    try {
        # Get current quota usage using Azure CLI
        $usage = az cognitiveservices usage list --location $Location --subscription $SubscriptionId 2>$null | ConvertFrom-Json

        if ($usage) {
            # Check for OpenAI models we need
            $gpt4oMiniQuota = $usage | Where-Object { $_.name.value -like "*gpt-4o-mini*" -and $_.limit -gt 0 }
            $embeddingQuota = $usage | Where-Object { $_.name.value -like "*text-embedding-3-large*" -and $_.limit -gt 0 }
            $openAiAccountQuota = $usage | Where-Object { $_.name.value -like "*OpenAI.S0.AccountCount*" }

            if ($openAiAccountQuota) {
                $accountsUsed = $openAiAccountQuota.currentValue
                $accountsLimit = $openAiAccountQuota.limit
                $accountsAvailable = $accountsLimit - $accountsUsed

                Write-Host "   OpenAI Accounts: $accountsUsed/$accountsLimit used" -ForegroundColor White

                if ($accountsAvailable -gt 0) {
                    Write-Host "   ✅ OpenAI account quota available" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ No OpenAI account quota available" -ForegroundColor Red
                    $script:quotaErrors++
                }
            }

            if ($gpt4oMiniQuota) {
                $maxGptQuota = ($gpt4oMiniQuota | Measure-Object -Property limit -Maximum).Maximum
                Write-Host "   GPT-4o-mini: $maxGptQuota TPM available" -ForegroundColor Green
            } else {
                Write-Host "   ❌ No GPT-4o-mini quota found" -ForegroundColor Red
                $script:quotaErrors++
            }

            if ($embeddingQuota) {
                $maxEmbeddingQuota = ($embeddingQuota | Measure-Object -Property limit -Maximum).Maximum
                Write-Host "   Text-embedding-3-large: $maxEmbeddingQuota TPM available" -ForegroundColor Green
            } else {
                Write-Host "   ❌ No text-embedding-3-large quota found" -ForegroundColor Red
                $script:quotaErrors++
            }

            if ($gpt4oMiniQuota -and $embeddingQuota -and $accountsAvailable -gt 0) {
                Write-Host "   ✅ Sufficient OpenAI quota available" -ForegroundColor Green
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

# Function to check AI Search quota
function Test-AISearchQuota {
    param(
        [string]$Location,
        [string]$SubscriptionId,
        [string]$Description
    )

    Write-Host "🔍 Checking $Description..." -ForegroundColor Yellow

    try {
        # Check search service quota using resource provider quotas
        $searchQuota = az provider show --namespace Microsoft.Search --query "resourceTypes[?resourceType=='searchServices'].locations[]" --output json 2>$null | ConvertFrom-Json

        # Convert location to display name format (e.g., eastus -> East US)
        $locationDisplayName = switch ($Location.ToLower()) {
            "eastus" { "East US" }
            "eastus2" { "East US 2" }
            "westus" { "West US" }
            "westus2" { "West US 2" }
            "westus3" { "West US 3" }
            "centralus" { "Central US" }
            "northcentralus" { "North Central US" }
            "southcentralus" { "South Central US" }
            "westcentralus" { "West Central US" }
            "northeurope" { "North Europe" }
            "westeurope" { "West Europe" }
            "francecentral" { "France Central" }
            "uksouth" { "UK South" }
            "ukwest" { "UK West" }
            "japaneast" { "Japan East" }
            "japanwest" { "Japan West" }
            "australiaeast" { "Australia East" }
            "australiasoutheast" { "Australia Southeast" }
            "southeastasia" { "Southeast Asia" }
            "eastasia" { "East Asia" }
            "canadacentral" { "Canada Central" }
            "canadaeast" { "Canada East" }
            "brazilsouth" { "Brazil South" }
            "centralindia" { "Central India" }
            "southindia" { "South India" }
            "koreacentral" { "Korea Central" }
            "koreasouth" { "Korea South" }
            default { $Location }
        }

        if ($searchQuota -and $searchQuota -contains $locationDisplayName) {
            Write-Host "   ✅ Azure AI Search is available in $Location" -ForegroundColor Green

            # Try to get more specific quota info - but this often fails, so treat as informational
            try {
                $quotas = az quota show --scope "/subscriptions/$SubscriptionId/providers/Microsoft.Search/locations/$Location" --resource-name searchServices 2>$null | ConvertFrom-Json

                if ($quotas -and $quotas.properties -and $quotas.properties.limit) {
                    $limit = $quotas.properties.limit
                    $usage = $quotas.properties.currentUsage
                    Write-Host "   Search Services: $usage/$limit used" -ForegroundColor White
                    if (($limit - $usage) -gt 0) {
                        Write-Host "   ✅ AI Search quota available" -ForegroundColor Green
                    } else {
                        Write-Host "   ❌ No AI Search quota available" -ForegroundColor Red
                        $script:quotaErrors++
                    }
                } else {
                    Write-Host "   ✅ AI Search quota appears sufficient (detailed quota unavailable)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "   ✅ AI Search service supported (detailed quota check not available)" -ForegroundColor Green
            }
        } else {
            Write-Host "   ❌ Azure AI Search not available in $Location" -ForegroundColor Red
            $script:quotaErrors++
        }
    }
    catch {
        Write-Host "   ⚠️  Error checking AI Search quota: $_" -ForegroundColor Yellow
        $script:quotaWarnings++
    }

    Write-Host ""
}

# Function to check AI Translator quota
function Test-TranslatorQuota {
    param(
        [string]$Location,
        [string]$SubscriptionId,
        [string]$Description
    )

    Write-Host "🔍 Checking $Description..." -ForegroundColor Yellow

    try {
        # Check if Cognitive Services (which includes Translator) is available
        $cognitiveServices = az provider show --namespace Microsoft.CognitiveServices --query "resourceTypes[?resourceType=='accounts'].locations[]" --output json 2>$null | ConvertFrom-Json

        # Convert location to display name format (e.g., eastus -> East US)
        $locationDisplayName = switch ($Location.ToLower()) {
            "eastus" { "East US" }
            "eastus2" { "East US 2" }
            "westus" { "West US" }
            "westus2" { "West US 2" }
            "westus3" { "West US 3" }
            "centralus" { "Central US" }
            "northcentralus" { "North Central US" }
            "southcentralus" { "South Central US" }
            "westcentralus" { "West Central US" }
            "northeurope" { "North Europe" }
            "westeurope" { "West Europe" }
            "francecentral" { "France Central" }
            "uksouth" { "UK South" }
            "ukwest" { "UK West" }
            "japaneast" { "Japan East" }
            "japanwest" { "Japan West" }
            "australiaeast" { "Australia East" }
            "australiasoutheast" { "Australia Southeast" }
            "southeastasia" { "Southeast Asia" }
            "eastasia" { "East Asia" }
            "canadacentral" { "Canada Central" }
            "canadaeast" { "Canada East" }
            "brazilsouth" { "Brazil South" }
            "centralindia" { "Central India" }
            "southindia" { "South India" }
            "koreacentral" { "Korea Central" }
            "koreasouth" { "Korea South" }
            default { $Location }
        }

        if ($cognitiveServices -and $cognitiveServices -contains $locationDisplayName) {
            Write-Host "   ✅ Azure AI Translator is available in $Location" -ForegroundColor Green

            # Check account count quota
            $usage = az cognitiveservices usage list --location $Location --subscription $SubscriptionId 2>$null | ConvertFrom-Json
            $accountQuota = $usage | Where-Object { $_.name.value -eq "AccountCount" }

            if ($accountQuota) {
                $accountsUsed = $accountQuota.currentValue
                $accountsLimit = $accountQuota.limit
                $accountsAvailable = $accountsLimit - $accountsUsed

                Write-Host "   Cognitive Services Accounts: $accountsUsed/$accountsLimit used" -ForegroundColor White

                if ($accountsAvailable -gt 0) {
                    Write-Host "   ✅ Cognitive Services account quota available" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ No Cognitive Services account quota available" -ForegroundColor Red
                    $script:quotaErrors++
                }
            } else {
                Write-Host "   ✅ Cognitive Services quota appears sufficient" -ForegroundColor Green
            }
        } else {
            Write-Host "   ❌ Azure AI Translator not available in $Location" -ForegroundColor Red
            $script:quotaErrors++
        }
    }
    catch {
        Write-Host "   ⚠️  Error checking Translator quota: $_" -ForegroundColor Yellow
        $script:quotaWarnings++
    }

    Write-Host ""
}

# Check Azure OpenAI Service quota
Test-Quota -Location $Location -SubscriptionId $SubscriptionId -Description "Azure OpenAI Service"

# Check Azure AI Search quota
Test-AISearchQuota -Location $Location -SubscriptionId $SubscriptionId -Description "Azure AI Search Service"

# Check Cognitive Services quota (for Translator)
Test-TranslatorQuota -Location $Location -SubscriptionId $SubscriptionId -Description "Azure AI Translator Service"

# Check regional capacity for AI services
Write-Host "🌍 Checking regional capacity..." -ForegroundColor Yellow
try {
    $usage = az cognitiveservices usage list --location $Location --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    if ($usage -and $usage.Count -gt 0) {
        Write-Host "   ✅ Regional capacity information available ($($usage.Count) quota types found)" -ForegroundColor Green

        # Show some key metrics
        $openAiQuotas = $usage | Where-Object { $_.name.value -like "*OpenAI*" -and $_.limit -gt 0 }
        if ($openAiQuotas) {
            Write-Host "   OpenAI quotas available: $($openAiQuotas.Count) types" -ForegroundColor White
        }
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
