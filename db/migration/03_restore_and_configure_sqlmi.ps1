<#
.SYNOPSIS
    Restaura el backup nativo de SIGEA desde Azure Blob Storage en Azure SQL Managed Instance,
    habilita READ_WRITE en la base destino y configura los permisos de mínimo privilegio y Managed Identity.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SqlMiHostName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [string]$ContainerName = "sqlbackups",
    [string]$BlobName = "SIGEA_migration.bak",
    [string]$TargetDatabaseName = "SIGEA",
    [string]$ModernAcaIdentityName = "id-sigea-modern-aca",
    [string]$ModernAcaIdentityClientId = "9e5b8853-7505-4303-b49b-2d700401a6a6",
    [string]$VmIdentityName = "vm-sigea-win",
    [string]$VmIdentityClientId = "",
    [string]$AccessToken = ""
)

$ErrorActionPreference = "Stop"
$swRestore = [System.Diagnostics.Stopwatch]::StartNew()

if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "==> [1/4] Usando token Microsoft Entra suministrado para conectar a Azure SQL Managed Instance ($SqlMiHostName)..."
    $sqlAccessToken = $AccessToken
} else {
    Write-Host "==> [1/4] Obteniendo token Microsoft Entra (IMDS) para conectar a Azure SQL Managed Instance ($SqlMiHostName)..."
    $imdsSqlUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://database.windows.net/"
    $tokenResp = Invoke-RestMethod -Uri $imdsSqlUrl -Headers @{ Metadata = "true" } -Method GET
    $sqlAccessToken = $tokenResp.access_token
}

function Convert-GuidToSqlSidHex {
    param([string]$GuidString)
    $bytes = ([Guid]::Parse($GuidString)).ToByteArray()
    return "0x" + (($bytes | ForEach-Object { $_.ToString("X2") }) -join "")
}

function Invoke-SqlMiQuery {
    param(
        [string]$Database = "master",
        [string]$Query,
        [int]$CommandTimeout = 600
    )
    $conn = New-Object System.Data.SqlClient.SqlConnection
    $conn.ConnectionString = "Server=tcp:${SqlMiHostName},1433;Database=${Database};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $conn.AccessToken = $sqlAccessToken
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        $cmd.CommandTimeout = $CommandTimeout
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $ds = New-Object System.Data.DataSet
        [void]$adapter.Fill($ds)
        if ($ds.Tables.Count -gt 0) {
            return $ds.Tables[0]
        }
    } finally {
        $conn.Close()
    }
}

$containerUrl = "https://${StorageAccountName}.blob.core.windows.net/${ContainerName}"
$backupBlobUrl = "${containerUrl}/${BlobName}"

Write-Host "==> [2/4] Configurando CREDENTIAL con Managed Identity en SQL Managed Instance para $containerUrl..."
$credSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$containerUrl')
BEGIN
    CREATE CREDENTIAL [$containerUrl] WITH IDENTITY = 'Managed Identity';
END
"@
Invoke-SqlMiQuery -Database "master" -Query $credSql | Out-Null

Write-Host "==> [3/4] Ejecutando RESTORE DATABASE [$TargetDatabaseName] FROM URL = '$backupBlobUrl'..."
$restoreSql = @"
IF DB_ID(N'$TargetDatabaseName') IS NOT NULL
BEGIN
    ALTER DATABASE [$TargetDatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$TargetDatabaseName];
END
RESTORE DATABASE [$TargetDatabaseName]
FROM URL = N'$backupBlobUrl';
"@
Invoke-SqlMiQuery -Database "master" -Query $restoreSql -CommandTimeout 900 | Out-Null

Write-Host "==> [4/4] Configurando permisos mínimos y acceso por Managed Identity (SID binario sin requerir Directory Readers) en [$TargetDatabaseName]..."
$acaSidHex = Convert-GuidToSqlSidHex -GuidString $ModernAcaIdentityClientId
$vmUserSql = ""
if (-not [string]::IsNullOrWhiteSpace($VmIdentityClientId)) {
    $vmSidHex = Convert-GuidToSqlSidHex -GuidString $VmIdentityClientId
    $vmUserSql = @"
IF USER_ID(N'$VmIdentityName') IS NULL
    CREATE USER [$VmIdentityName] WITH SID = $vmSidHex, TYPE = E;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [$VmIdentityName];
"@
}

$grantsSql = @"
IF USER_ID('sigea_app') IS NOT NULL
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [sigea_app];
IF USER_ID('sigea_labro') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.Person TO [sigea_labro];
    GRANT SELECT ON dbo.Enrollment TO [sigea_labro];
    GRANT SELECT ON dbo.Course TO [sigea_labro];
END
IF USER_ID(N'$ModernAcaIdentityName') IS NULL
    CREATE USER [$ModernAcaIdentityName] WITH SID = $acaSidHex, TYPE = E;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [$ModernAcaIdentityName];
$vmUserSql
DBCC CHECKIDENT ('dbo.Person', RESEED);
DBCC CHECKIDENT ('dbo.Department', RESEED);
DBCC CHECKIDENT ('dbo.Enrollment', RESEED);
"@
Invoke-SqlMiQuery -Database $TargetDatabaseName -Query $grantsSql | Out-Null

$swRestore.Stop()
Write-Host "==> Restauración y configuración en Azure SQL Managed Instance completadas en $([Math]::Round($swRestore.Elapsed.TotalSeconds, 2))s."
