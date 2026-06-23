#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-RequiredEnvironmentVariable {
    param([Parameter(Mandatory = $true)][string] $Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name must be set"
    }

    return $value
}

$subscriptionId = Get-RequiredEnvironmentVariable 'AZURE_SUBSCRIPTION_ID'
$schedulerName = Get-RequiredEnvironmentVariable 'DTS_SCHEDULER_NAME'
$schedulerResourceGroup = Get-RequiredEnvironmentVariable 'DTS_SCHEDULER_RESOURCE_GROUP'
$identityId = Get-RequiredEnvironmentVariable 'AZURE_USER_ASSIGNED_IDENTITY_RESOURCE_ID'

Write-Host "==> Ensuring the 'durabletask' Azure CLI extension is installed..."
az extension add --name durabletask --upgrade --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install or update the durabletask Azure CLI extension"
}

Write-Host "==> Attaching managed identity to scheduler '$schedulerName'..."
az durabletask scheduler identity assign `
    --subscription $subscriptionId `
    --resource-group $schedulerResourceGroup `
    --name $schedulerName `
    --user-assigned $identityId | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to attach managed identity to scheduler '$schedulerName'"
}

$identityName = Split-Path -Leaf $identityId
Write-Host "==> Done. Identity $identityName is attached to '$schedulerName'."