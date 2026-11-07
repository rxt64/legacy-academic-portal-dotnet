<#
.SYNOPSIS
    Ejecuta la pausa de escrituras en el SQL Server 2022 origen, genera el backup nativo
    COPY_ONLY verificado con CHECKSUM y lo sube de forma privada a Azure Blob Storage
    utilizando la Managed Identity de vm-sigea-win.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [string]$ContainerName = "sqlbackups",
    [string]$BlobName = "SIGEA_migration.bak",
    [string]$BackupFilePath = "F:\MSSQL\Backup\SIGEA_migration.bak",
    [string]$AppPoolName = "SigeaAppPool",
    [switch]$KeepSourceReadWriteForRehearsal
)

$ErrorActionPreference = "Stop"
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

$sqlcmdExe = Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -Filter "sqlcmd.exe" -Recurse |
    Select-Object -ExpandProperty FullName -First 1

if (-not $KeepSourceReadWriteForRehearsal) {
    Write-Host "==> [1/4] Pausa de escrituras: deteniendo AppPool '$AppPoolName' y deshabilitando login de escritura sigea_app..."
    Import-Module WebAdministration
    if ((Get-WebAppPoolState -Name $AppPoolName).Value -ne 'Stopped') {
        Stop-WebAppPool -Name $AppPoolName
    }
    & $sqlcmdExe -S "localhost" -E -C -b -Q "ALTER LOGIN [sigea_app] DISABLE;"
    if ($LASTEXITCODE -ne 0) { throw "Error deshabilitando sigea_app durante pausa de escrituras." }
} else {
    Write-Host "==> [1/4] Modo ensayo (Rehearsal): conservando origen SIGEA activo para no interrumpir la aplicación..."
}

Write-Host "==> [2/4] Generando backup nativo COPY_ONLY con compresión y CHECKSUM en $BackupFilePath (base en READ_WRITE para compatibilidad con SQL MI)..."
$backupDir = Split-Path -Parent $BackupFilePath
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }

$backupSql = @"
BACKUP DATABASE [SIGEA]
TO DISK = N'$BackupFilePath'
WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM, STATS = 25;
RESTORE VERIFYONLY FROM DISK = N'$BackupFilePath' WITH CHECKSUM;
"@
& $sqlcmdExe -S "localhost" -E -C -b -Q $backupSql
if ($LASTEXITCODE -ne 0) { throw "Fallo en BACKUP DATABASE o RESTORE VERIFYONLY." }

if (-not $KeepSourceReadWriteForRehearsal) {
    Write-Host "    Marcando base SIGEA origen como READ_ONLY tras completar el backup..."
    & $sqlcmdExe -S "localhost" -E -C -b -Q "ALTER DATABASE [SIGEA] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; ALTER DATABASE [SIGEA] SET READ_ONLY; ALTER DATABASE [SIGEA] SET MULTI_USER;"
    if ($LASTEXITCODE -ne 0) { throw "Error poniendo SIGEA en modo READ_ONLY post-backup." }
}

$fileInfo = Get-Item $BackupFilePath
Write-Host "    Backup verificado: $($fileInfo.FullName) ($($fileInfo.Length) bytes)"

Write-Host "==> [3/4] Obteniendo token OAuth2 de Managed Identity para Azure Storage..."
$imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/"
$tokenResp = Invoke-RestMethod -Uri $imdsUrl -Headers @{ Metadata = "true" } -Method GET
$accessToken = $tokenResp.access_token

$blobUrl = "https://${StorageAccountName}.blob.core.windows.net/${ContainerName}/${BlobName}"
Write-Host "==> [4/4] Subiendo backup privado hacia $blobUrl..."
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "x-ms-version"  = "2020-10-02"
    "x-ms-blob-type"= "BlockBlob"
}
Invoke-RestMethod -Uri $blobUrl -Method PUT -Headers $headers -InFile $BackupFilePath -ContentType "application/octet-stream" | Out-Null

$swTotal.Stop()
Write-Host "==> Backup y carga a Blob Storage completados en $([Math]::Round($swTotal.Elapsed.TotalSeconds, 2))s."
