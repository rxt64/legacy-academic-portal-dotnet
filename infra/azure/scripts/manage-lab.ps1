<#
.SYNOPSIS
    Script operativo desde la estación de trabajo para desplegar, validar, iniciar, desasignar,
    restablecer datos o eliminar el laboratorio de SIGEA (e infraestructura compartida) en Azure Mexico Central.
.DESCRIPTION
    Operaciones soportadas (-Action):
    - Validate     : Ejecuta az bicep build, az deployment sub validate y what-if en mexicocentral.
    - Deploy       : Ejecuta el despliegue de Bicep en mexicocentral.
    - Start        : Inicia la VM vm-sigea-win.
    - Status       : Verifica (solo lectura, sin cambios) el estado de VM/discos/SQL MI con salida en color [OK]/[FALLO].
                      Pensado para correr rápido antes de cada bloque de la demo, no solo al inicio del evento.
    - Deallocate   : Desasigna (detiene facturación de cómputo) la VM vm-sigea-win.
    - ResetDataset : Invoca reset-dataset-sigea.ps1 dentro de la VM mediante az vm run-command.
    - Teardown     : Elimina exclusivamente el grupo de recursos del laboratorio (requiere -ConfirmTeardown).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Validate', 'Deploy', 'Start', 'Status', 'Deallocate', 'ResetDataset', 'TeardownTargetsOnly', 'Teardown')]
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
        Write-Host "==> Verificando SKU de discos administrados de $VmName y vm-jumpbox-lab (restaurando StandardSSD_LRS si una política de gobernanza los degradó a Standard_LRS al desasignar)..."
        foreach ($dName in @("osdisk-$VmName", "disk-$VmName-sqldata", "osdisk-vm-jumpbox-lab")) {
            $sku = az disk show --resource-group $ResourceGroupName --name $dName --query "sku.name" -o tsv 2>$null
            if ($sku -eq "Standard_LRS") {
                Write-Host "    Restaurando $dName de Standard_LRS a StandardSSD_LRS..."
                az disk update --resource-group $ResourceGroupName --name $dName --sku StandardSSD_LRS | Out-Null
            }
        }
        Write-Host "==> Iniciando VM $VmName y vm-jumpbox-lab en $ResourceGroupName..."
        az vm start --resource-group $ResourceGroupName --name $VmName
        az vm start --resource-group $ResourceGroupName --name "vm-jumpbox-lab" 2>$null

        Write-Host "==> Verificando estado de Azure SQL Managed Instance en $ResourceGroupName (suscripción $(az account show --query id -o tsv))..."
        $sqlMiJson = az sql mi list --resource-group $ResourceGroupName --query "[].{name:name, state:state}" -o json 2>$null
        $allSqlMis = @()
        if ($sqlMiJson) { $allSqlMis = $sqlMiJson | ConvertFrom-Json }
        if (-not $allSqlMis -or $allSqlMis.Count -eq 0) {
            Write-Warning "No se encontró ninguna Azure SQL Managed Instance en el grupo de recursos '$ResourceGroupName'. Si esperabas encontrar una ya desplegada, confirma: (1) la suscripción activa (az account show), (2) el nombre del grupo de recursos, y (3) en el Portal, navega a 'SQL managed instances' (NO 'Azure Arc > SQL Server instances', que es un servicio distinto para SQL Server on-premises/VM registrado vía Arc)."
        }
        foreach ($mi in $allSqlMis) {
            if ($mi.state -eq 'Stopped') {
                Write-Host "    Iniciando Azure SQL Managed Instance $($mi.name) (estado actual: Stopped)..."
                az sql mi start --resource-group $ResourceGroupName --mi $mi.name --no-wait
            }
            else {
                Write-Host "    Azure SQL Managed Instance $($mi.name) ya está en estado '$($mi.state)' (no requiere inicio)."
            }
        }
    }
    'Status' {
        Write-Host "==> Verificando estado de los recursos de SIGEA (solo lectura, sin cambios)..."
        foreach ($v in @($VmName, "vm-jumpbox-lab")) {
            $vmState = az vm get-instance-view --resource-group $ResourceGroupName --name $v --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]" -o tsv 2>$null
            if ($vmState -eq 'VM running') {
                Write-Host "[OK] VM $v -> $vmState" -ForegroundColor Green
            } else {
                Write-Host "[FALLO] VM $v -> '$vmState' (se esperaba 'VM running')" -ForegroundColor Red
            }
        }
        foreach ($dName in @("osdisk-$VmName", "disk-$VmName-sqldata", "osdisk-vm-jumpbox-lab")) {
            $sku = az disk show --resource-group $ResourceGroupName --name $dName --query "sku.name" -o tsv 2>$null
            if ($sku -eq 'StandardSSD_LRS') {
                Write-Host "[OK] Disco $dName -> $sku" -ForegroundColor Green
            } else {
                Write-Host "[FALLO] Disco $dName -> '$sku' (se esperaba StandardSSD_LRS; una política de gobernanza pudo degradarlo)" -ForegroundColor Red
            }
        }
        $sqlMiJson = az sql mi list --resource-group $ResourceGroupName --query "[].{name:name, state:state}" -o json 2>$null
        $allSqlMis = @()
        if ($sqlMiJson) { $allSqlMis = $sqlMiJson | ConvertFrom-Json }
        if (-not $allSqlMis -or $allSqlMis.Count -eq 0) {
            Write-Host "[FALLO] No se encontró ninguna Azure SQL Managed Instance en '$ResourceGroupName'." -ForegroundColor Red
        }
        foreach ($mi in $allSqlMis) {
            if ($mi.state -eq 'Ready') {
                Write-Host "[OK] SQL MI $($mi.name) -> Ready" -ForegroundColor Green
            } else {
                Write-Host "[FALLO] SQL MI $($mi.name) -> '$($mi.state)' (se esperaba Ready; ejecuta -Action Start para reiniciarlo)" -ForegroundColor Red
            }
        }
    }
    'Deallocate' {
        Write-Host "==> Desasignando VM $VmName y vm-jumpbox-lab en $ResourceGroupName (detiene cargos de cómputo)..."
        az vm deallocate --resource-group $ResourceGroupName --name $VmName
        az vm deallocate --resource-group $ResourceGroupName --name "vm-jumpbox-lab" 2>$null
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
    'TeardownTargetsOnly' {
        if (-not $ConfirmTeardown) {
            throw "Para eliminar los recursos destino de modernización debe especificar explícitamente -ConfirmTeardown."
        }
        Write-Host "==> Eliminando selectivamente solo los recursos destino de modernización de SIGEA (conservando VM legacy, discos y Front Door)..."
        $sqlMis = az sql mi list --resource-group $ResourceGroupName --query "[].name" -o tsv
        foreach ($mi in $sqlMis) {
            if ($mi) { az sql mi delete --resource-group $ResourceGroupName --name $mi --yes --no-wait }
        }
        $acrs = az acr list --resource-group $ResourceGroupName --query "[].name" -o tsv
        foreach ($acr in $acrs) {
            if ($acr) { az acr delete --resource-group $ResourceGroupName --name $acr --yes }
        }
        $caes = az containerapp env list --resource-group $ResourceGroupName --query "[].name" -o tsv
        foreach ($cae in $caes) {
            if ($cae) { az containerapp env delete --resource-group $ResourceGroupName --name $cae --yes --no-wait }
        }
        $stgs = az storage account list --resource-group $ResourceGroupName --query "[?starts_with(name, 'stsigeamig')].name" -o tsv
        foreach ($st in $stgs) {
            if ($st) {
                az network private-endpoint delete --resource-group $ResourceGroupName --name "pe-$st-blob" 2>$null
                az storage account delete --resource-group $ResourceGroupName --name $st --yes
            }
        }
        az identity delete --resource-group $ResourceGroupName --name "id-sigea-modern-aca" 2>$null
    }
    'Teardown' {
        if (-not $ConfirmTeardown) {
            throw "Para eliminar el grupo de recursos $ResourceGroupName debe especificar explícitamente -ConfirmTeardown."
        }
        Write-Host "==> Eliminando exclusivamente el grupo de recursos del laboratorio: $ResourceGroupName..."
        az group delete --name $ResourceGroupName --yes --no-wait
    }
}
