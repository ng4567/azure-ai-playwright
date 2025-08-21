# Infrastructure Validation Script
# Tests all deployed Azure AI services and verifies configuration

param(
    [string]$ResourceGroupName = "rg-medicaid-rag-dev",
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [switch]$Detailed
)

Write-Host "🔍 Infrastructure Validation" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Ensure we're logged into Azure
$context = az account show --query "name" -o tsv 2>$null
if (-not $context) {
    Write-Error "❌ Not logged into Azure. Run 'az login' first."
    exit 1
}

Write-Host "✅ Authenticated to Azure subscription: $context" -ForegroundColor Cyan
Write-Host "📍 Target Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host ""

$validationErrors = 0
$validationWarnings = 0

# Function to test resource existence and health
function Test-AzureResource {
    param(
        [string]$ResourceType,
        [string]$Description,
        [scriptblock]$TestScript
    )

    Write-Host "🔍 Testing $Description..." -ForegroundColor Yellow

    try {
        $result = & $TestScript
        if ($result) {
            Write-Host "   ✅ $Description is healthy" -ForegroundColor Green
            if ($Detailed -and $result.GetType().Name -eq "PSCustomObject") {
                $result | Format-List | Out-Host
            }
            return $true
        } else {
            Write-Host "   ❌ $Description test failed" -ForegroundColor Red
            $script:validationErrors++
            return $false
        }
    }
    catch {
        Write-Host "   ⚠️  Error testing $Description`: $_" -ForegroundColor Yellow
        $script:validationWarnings++
        return $false
    }
}

# Test Resource Group
Test-AzureResource -ResourceType "ResourceGroup" -Description "Resource Group" -TestScript {
    $rg = az group show --name $ResourceGroupName --query "{name:name, location:location, provisioningState:properties.provisioningState}" -o json 2>$null | ConvertFrom-Json
    if ($rg -and $rg.provisioningState -eq "Succeeded") {
        Write-Host "   📍 Location: $($rg.location)" -ForegroundColor White
        return $rg
    }
    return $null
}

# Test Azure OpenAI Service
Test-AzureResource -ResourceType "OpenAI" -Description "Azure OpenAI Service" -TestScript {
    $openai = az cognitiveservices account list --resource-group $ResourceGroupName --query "[?kind=='OpenAI'].{name:name, endpoint:properties.endpoint, provisioningState:properties.provisioningState}" -o json 2>$null | ConvertFrom-Json
    if ($openai -and $openai.Count -gt 0 -and $openai[0].provisioningState -eq "Succeeded") {
        Write-Host "   🤖 Service Name: $($openai[0].name)" -ForegroundColor White
        Write-Host "   🌐 Endpoint: $($openai[0].endpoint)" -ForegroundColor White

        # Test model deployments
        $deployments = az cognitiveservices account deployment list --name $openai[0].name --resource-group $ResourceGroupName --query "[].{name:name, model:properties.model.name, status:properties.provisioningState}" -o json 2>$null | ConvertFrom-Json
        if ($deployments) {
            Write-Host "   📊 Model Deployments:" -ForegroundColor White
            foreach ($deployment in $deployments) {
                $status = $deployment.status -eq "Succeeded" ? "✅" : "❌"
                Write-Host "      $status $($deployment.name): $($deployment.model)" -ForegroundColor White
            }
        }
        return $openai[0]
    }
    return $null
}

# Test Azure AI Search
Test-AzureResource -ResourceType "Search" -Description "Azure AI Search Service" -TestScript {
    $search = az search service list --resource-group $ResourceGroupName --query "[].{name:name, status:status, sku:sku.name, replicas:replicaCount, partitions:partitionCount}" -o json 2>$null | ConvertFrom-Json
    if ($search -and $search.Count -gt 0 -and $search[0].status -eq "running") {
        Write-Host "   🔍 Service Name: $($search[0].name)" -ForegroundColor White
        Write-Host "   🏷️  SKU: $($search[0].sku)" -ForegroundColor White
        Write-Host "   📊 Replicas: $($search[0].replicas), Partitions: $($search[0].partitions)" -ForegroundColor White
        return $search[0]
    }
    return $null
}

# Test Azure AI Translator
Test-AzureResource -ResourceType "Translator" -Description "Azure AI Translator Service" -TestScript {
    $translator = az cognitiveservices account list --resource-group $ResourceGroupName --query "[?kind=='TextTranslation'].{name:name, endpoint:properties.endpoint, provisioningState:properties.provisioningState, sku:sku.name}" -o json 2>$null | ConvertFrom-Json
    if ($translator -and $translator.Count -gt 0 -and $translator[0].provisioningState -eq "Succeeded") {
        Write-Host "   🌐 Service Name: $($translator[0].name)" -ForegroundColor White
        Write-Host "   🌍 Endpoint: $($translator[0].endpoint)" -ForegroundColor White
        Write-Host "   🏷️  SKU: $($translator[0].sku)" -ForegroundColor White
        return $translator[0]
    }
    return $null
}

# Test Key Vault
Test-AzureResource -ResourceType "KeyVault" -Description "Azure Key Vault" -TestScript {
    $keyvault = az keyvault list --resource-group $ResourceGroupName --query "[].{name:name, vaultUri:properties.vaultUri, provisioningState:properties.provisioningState}" -o json 2>$null | ConvertFrom-Json
    if ($keyvault -and $keyvault.Count -gt 0 -and $keyvault[0].provisioningState -eq "Succeeded") {
        Write-Host "   🔐 Vault Name: $($keyvault[0].name)" -ForegroundColor White
        Write-Host "   🌐 Vault URI: $($keyvault[0].vaultUri)" -ForegroundColor White

        # Test access to secrets (will show count only)
        try {
            $secrets = az keyvault secret list --vault-name $keyvault[0].name --query "length(@)" -o tsv 2>$null
            if ($secrets -ne $null) {
                Write-Host "   🔑 Secrets Count: $secrets" -ForegroundColor White
            }
        } catch {
            Write-Host "   ⚠️  Cannot access secrets (may need permissions)" -ForegroundColor Yellow
        }
        return $keyvault[0]
    }
    return $null
}

# Test Storage Account
Test-AzureResource -ResourceType "Storage" -Description "Azure Storage Account" -TestScript {
    $storage = az storage account list --resource-group $ResourceGroupName --query "[].{name:name, primaryEndpoints:primaryEndpoints, provisioningState:provisioningState}" -o json 2>$null | ConvertFrom-Json
    if ($storage -and $storage.Count -gt 0 -and $storage[0].provisioningState -eq "Succeeded") {
        Write-Host "   💾 Storage Name: $($storage[0].name)" -ForegroundColor White
        Write-Host "   🌐 Blob Endpoint: $($storage[0].primaryEndpoints.blob)" -ForegroundColor White

        # Test docs container
        try {
            $containers = az storage container list --account-name $storage[0].name --query "[?name=='docs'].name" -o tsv 2>$null
            if ($containers -eq "docs") {
                Write-Host "   📁 Docs container: ✅" -ForegroundColor White
            } else {
                Write-Host "   📁 Docs container: ❌" -ForegroundColor Red
            }
        } catch {
            Write-Host "   ⚠️  Cannot access containers (may need permissions)" -ForegroundColor Yellow
        }
        return $storage[0]
    }
    return $null
}

# Test Log Analytics Workspace
Test-AzureResource -ResourceType "LogAnalytics" -Description "Log Analytics Workspace" -TestScript {
    $workspace = az monitor log-analytics workspace list --resource-group $ResourceGroupName --query "[].{name:name, customerId:customerId, provisioningState:provisioningState}" -o json 2>$null | ConvertFrom-Json
    if ($workspace -and $workspace.Count -gt 0 -and $workspace[0].provisioningState -eq "Succeeded") {
        Write-Host "   📊 Workspace Name: $($workspace[0].name)" -ForegroundColor White
        Write-Host "   🆔 Customer ID: $($workspace[0].customerId)" -ForegroundColor White
        return $workspace[0]
    }
    return $null
}

# Test AI Foundry resources
Test-AzureResource -ResourceType "AIFoundry" -Description "Azure AI Foundry (ML Workspace)" -TestScript {
    $mlworkspaces = az ml workspace list --resource-group $ResourceGroupName --query "[].{name:name, discovery_url:discovery_url, mlflow_tracking_uri:mlflow_tracking_uri}" -o json 2>$null | ConvertFrom-Json
    if ($mlworkspaces -and $mlworkspaces.Count -gt 0) {
        foreach ($workspace in $mlworkspaces) {
            Write-Host "   🧠 Workspace Name: $($workspace.name)" -ForegroundColor White
            if ($workspace.discovery_url) {
                Write-Host "   🔍 Discovery URL: $($workspace.discovery_url)" -ForegroundColor White
            }
        }
        return $mlworkspaces[0]
    }
    return $null
}

# Network connectivity tests
Write-Host ""
Write-Host "🌐 Testing Network Connectivity..." -ForegroundColor Yellow

# Test OpenAI endpoint
$openaiEndpoint = az cognitiveservices account list --resource-group $ResourceGroupName --query "[?kind=='OpenAI'].properties.endpoint" -o tsv 2>$null
if ($openaiEndpoint) {
    try {
        $response = Invoke-WebRequest -Uri "$openaiEndpoint/openai/deployments" -Method GET -UseBasicParsing -TimeoutSec 10 2>$null
        if ($response.StatusCode -eq 401) {
            Write-Host "   ✅ OpenAI endpoint is reachable (401 expected without auth)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  OpenAI endpoint response: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ OpenAI endpoint connectivity failed: $_" -ForegroundColor Red
        $validationErrors++
    }
}

# Test Search endpoint
$searchEndpoint = az search service list --resource-group $ResourceGroupName --query "[].{name:name}" -o json 2>$null | ConvertFrom-Json
if ($searchEndpoint -and $searchEndpoint.Count -gt 0) {
    try {
        $searchUrl = "https://$($searchEndpoint[0].name).search.windows.net"
        $response = Invoke-WebRequest -Uri $searchUrl -Method GET -UseBasicParsing -TimeoutSec 10 2>$null
        if ($response.StatusCode -eq 403) {
            Write-Host "   ✅ AI Search endpoint is reachable (403 expected without auth)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  AI Search endpoint response: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ AI Search endpoint connectivity failed: $_" -ForegroundColor Red
        $validationErrors++
    }
}

# Summary
Write-Host ""
Write-Host "📊 Validation Summary:" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

if ($validationErrors -eq 0 -and $validationWarnings -eq 0) {
    Write-Host "🎉 All validation checks passed! Infrastructure is ready." -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Ready for next steps:" -ForegroundColor Cyan
    Write-Host "   1. Upload documents to storage" -ForegroundColor White
    Write-Host "   2. Create search indexes" -ForegroundColor White
    Write-Host "   3. Deploy application code" -ForegroundColor White
    exit 0
} elseif ($validationErrors -eq 0) {
    Write-Host "⚠️  $validationWarnings warning(s) found. Infrastructure mostly ready." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Consider addressing warnings before proceeding." -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "❌ $validationErrors error(s) and $validationWarnings warning(s) found." -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Please resolve errors before proceeding:" -ForegroundColor Cyan
    Write-Host "   1. Check resource deployment status in Azure Portal" -ForegroundColor White
    Write-Host "   2. Verify permissions and access policies" -ForegroundColor White
    Write-Host "   3. Review deployment logs for specific issues" -ForegroundColor White
    exit 1
}
