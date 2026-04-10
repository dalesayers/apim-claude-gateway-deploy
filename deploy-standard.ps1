param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName,

    [string]$Location,

    [string]$ParametersFile = (Join-Path $PSScriptRoot 'main.customer.bicepparam'),

    [string]$TemplateFile = (Join-Path $PSScriptRoot 'main.bicep'),

    [switch]$WhatIfOnly,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Assert-Command -Name 'az'

az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI is not logged in. Run: az login'
}

az bicep version --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Bicep is not available through Azure CLI. Run: az bicep install'
}

if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile"
}

if (-not (Test-Path $TemplateFile)) {
    throw "Template file not found: $TemplateFile"
}

if (-not $ResourceGroupName -or -not $Location) {
    $paramContent = Get-Content -Path $ParametersFile -Raw

    if (-not $ResourceGroupName) {
        $rgMatch = [regex]::Match($paramContent, "param resourceGroupName = '([^']+)'")
        if ($rgMatch.Success) {
            $ResourceGroupName = $rgMatch.Groups[1].Value
        }
    }

    if (-not $Location) {
        $locationMatch = [regex]::Match($paramContent, "param location = '([^']+)'")
        if ($locationMatch.Success) {
            $Location = $locationMatch.Groups[1].Value
        }
    }
}

if (-not $ResourceGroupName) {
    throw 'ResourceGroupName was not provided and could not be inferred from the parameters file.'
}

if (-not $Location) {
    throw 'Location was not provided and could not be inferred from the parameters file.'
}

Write-Host "Setting Azure subscription to $SubscriptionId"
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to set Azure subscription.'
}

Write-Host "Ensuring resource group $ResourceGroupName exists in $Location"
az group create --name $ResourceGroupName --location $Location --output none
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create or validate resource group.'
}

Write-Host 'Running deployment what-if'
az deployment group what-if --resource-group $ResourceGroupName --parameters $ParametersFile
if ($LASTEXITCODE -ne 0) {
    throw 'What-if failed.'
}

if ($WhatIfOnly) {
    Write-Host 'What-if only requested. Exiting without deployment.'
    return
}

if (-not $Force) {
    $confirmation = Read-Host 'Proceed with deployment? Type yes to continue'
    if ($confirmation -ne 'yes') {
        Write-Host 'Deployment cancelled.'
        return
    }
}

Write-Host 'Starting deployment'
az deployment group create --resource-group $ResourceGroupName --parameters $ParametersFile
if ($LASTEXITCODE -ne 0) {
    throw 'Deployment failed.'
}

Write-Host ''
Write-Host 'Deployment completed.'
Write-Host 'Next steps:'
Write-Host '1. Capture the APIM principalId from the deployment output or az apim show.'
Write-Host '2. Assign Cognitive Services User on the customer Foundry resource.'
Write-Host '3. Create APIM subscriptions for your consuming apps or teams.'
Write-Host '4. Validate POST /claude/v1/messages through the APIM gateway.'
