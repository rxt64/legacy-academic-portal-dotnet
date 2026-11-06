<#
.SYNOPSIS
    Script operativo desde la estación de trabajo para desplegar, validar, iniciar, desasignar,
    restablecer datos o eliminar el laboratorio de SIGEA (e infraestructura compartida) en Azure Mexico Central.
.DESCRIPTION
    Operaciones soportadas (-Action):
    - Validate     : Ejecuta az bicep build, az deployment sub validate y what-if en mexicocentral.
    - Deploy       : Ejecuta el despliegue de Bicep en mexicocentral.
    - Start        : Inicia la VM vm-sigea-win.
    - Deallocate   : Desasigna (detiene facturación de cómputo) la VM vm-sigea-win.
    - ResetDataset : Invoca reset-dataset-sigea.ps1 dentro de la VM mediante az vm run-command.
    - Teardown     : Elimina exclusivamente el grupo de recursos del laboratorio (requiere -ConfirmTeardown).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Validate', 'Deploy', 'Start', 'Deallocate', 'ResetDataset', 'Teardown')]
    [string]$Action,

    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    [string]$Location = "mexicocentral",
    [string]$ResourceGroupName = "rg-legacy-apps-demo-mxc",
    [string]$VmName = "vm-sigea-win",
    [string]$PresenterAllowedCidr = "",
    [switch]$ConfirmTeardown
)

$ErrorActionPreference = "Stop"
$infraDir = Split-Path -Parent $PSScriptRoot
$bicepFile = Join-Path $infraDir "main.bicep"
$paramFile = Join-Path $infraDir "main.bicepparam"

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) { throw "No se pudo seleccionar la suscripción $SubscriptionId." }
}

switch ($Action) {
    'Validate' {
        Write-Host "==> Compilando Bicep ($bicepFile)..."
        az bicep build --file $bicepFile --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Error compilando Bicep." }

        Write-Host "==> Ejecutando validación ARM..."
        az deployment sub validate `
            --location $Location `
            --name "validate-sigea-shared-mxc" `
            --parameters $paramFile `
            --parameters resourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr `
            --query "{provisioningState:properties.provisioningState, error:error}" -o json
        if ($LASTEXITCODE -ne 0) { throw "Error en validación ARM." }

        Write-Host "==> Ejecutando what-if..."
        az deployment sub what-if `
            --location $Location `
            --name "whatif-sigea-shared-mxc" `
            --parameters $paramFile `
            --parameters resourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr
    }
    'Deploy' {
        if ([string]::IsNullOrEmpty($env:SIGEA_VM_ADMIN_PASSWORD)) {
            throw "Defina la variable de entorno SIGEA_VM_ADMIN_PASSWORD antes de ejecutar Deploy."
        }
        Write-Host "==> Desplegando infraestructura compartida y SIGEA en $Location..."
        az deployment sub create `
            --location $Location `
            --name "deploy-sigea-shared-mxc" `
            --parameters $paramFile `
            --parameters resourceGroupName=$ResourceGroupName presenterAllowedCidr=$PresenterAllowedCidr `
            --query "{provisioningState:properties.provisioningState, outputs:properties.outputs}" -o json
    }
    'Start' {
        Write-Host "==> Iniciando VM $VmName en $ResourceGroupName..."
        az vm start --resource-group $ResourceGroupName --name $VmName
    }
    'Deallocate' {
        Write-Host "==> Desasignando VM $VmName en $ResourceGroupName (detiene cargos de cómputo)..."
        az vm deallocate --resource-group $ResourceGroupName --name $VmName
    }
    'ResetDataset' {
        Write-Host "==> Restableciendo dataset sintético de SIGEA en $VmName..."
        az vm run-command invoke `
            --resource-group $ResourceGroupName `
            --name $VmName `
            --command-id RunPowerShellScript `
            --scripts "powershell.exe -ExecutionPolicy Bypass -File C:\SIGEA\stage\scripts\reset-dataset-sigea.ps1 -Mode Full" `
            --query "value[0].message" -o tsv
    }
    'Teardown' {
        if (-not $ConfirmTeardown) {
            throw "Para eliminar el grupo de recursos $ResourceGroupName debe especificar explícitamente -ConfirmTeardown."
        }
        Write-Host "==> Eliminando exclusivamente el grupo de recursos del laboratorio: $ResourceGroupName..."
        az group delete --name $ResourceGroupName --yes --no-wait
    }
}
