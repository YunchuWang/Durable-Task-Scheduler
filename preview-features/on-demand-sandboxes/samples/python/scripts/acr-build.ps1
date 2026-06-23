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

$registry = Get-RequiredEnvironmentVariable 'AZURE_CONTAINER_REGISTRY_NAME'
$registryEndpoint = Get-RequiredEnvironmentVariable 'AZURE_CONTAINER_REGISTRY_ENDPOINT'
$environmentName = Get-RequiredEnvironmentVariable 'AZURE_ENV_NAME'

function Build-Image {
    param(
        [Parameter(Mandatory = $true)][string] $ImageRepository,
        [Parameter(Mandatory = $true)][string] $ImageTag,
        [Parameter(Mandatory = $true)][string] $Containerfile
    )

    $fullImage = "${registryEndpoint}/${ImageRepository}:${ImageTag}"
    Write-Host "==> Building ${ImageRepository}:${ImageTag} via ACR Tasks (--platform linux/amd64)..."

    az acr build `
        --registry $registry `
        --image "${ImageRepository}:${ImageTag}" `
        --platform linux/amd64 `
        --file $Containerfile `
        . `
        --no-logs `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "az acr build failed for ${ImageRepository}:${ImageTag}"
    }

    return $fullImage
}

$sandboxImage = Build-Image `
    -ImageRepository "dts-ondemand-sandboxes/sandbox-worker-${environmentName}" `
    -ImageTag 'latest' `
    -Containerfile 'Containerfile'

Write-Host "==> sandbox image   : $sandboxImage"