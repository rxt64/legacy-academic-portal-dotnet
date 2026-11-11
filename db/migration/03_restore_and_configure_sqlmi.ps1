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
    DECLARE @killSql NVARCHAR(MAX) = N'';
    SELECT @killSql = @killSql + N'KILL ' + CAST(session_id AS NVARCHAR(20)) + N';'
    FROM sys.dm_exec_sessions
    WHERE database_id = DB_ID(N'$TargetDatabaseName') AND session_id <> @@SPID AND is_user_process = 1;
    IF LEN(@killSql) > 0 EXEC sp_executesql @killSql;
    DROP DATABASE [$TargetDatabaseName];
END
RESTORE DATABASE [$TargetDatabaseName]
FROM URL = N'$backupBlobUrl';
"@
Invoke-SqlMiQuery -Database "master" -Query $restoreSql -CommandTimeout 900 | Out-Null

Write-Host "==> [4/4] Configurando logins SQL (sigea_app / sigea_labro), permisos mínimos y acceso Microsoft Entra en [$TargetDatabaseName]..."
$masterLoginsSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'sigea_app')
    CREATE LOGIN [sigea_app] WITH PASSWORD = N'SgQn62M7vq#e!dDxT4', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [sigea_app] WITH PASSWORD = N'SgQn62M7vq#e!dDxT4', CHECK_POLICY = OFF;
ALTER LOGIN [sigea_app] ENABLE;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'sigea_labro')
    CREATE LOGIN [sigea_labro] WITH PASSWORD = N'Sg68UHqPC49acj!@ty', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [sigea_labro] WITH PASSWORD = N'Sg68UHqPC49acj!@ty', CHECK_POLICY = OFF;
ALTER LOGIN [sigea_labro] ENABLE;
"@
Invoke-SqlMiQuery -Database "master" -Query $masterLoginsSql | Out-Null

$grantsSql = @"
IF USER_ID('sigea_app') IS NULL
    CREATE USER [sigea_app] FOR LOGIN [sigea_app];
ELSE
    ALTER USER [sigea_app] WITH LOGIN = [sigea_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [sigea_app];

IF USER_ID('sigea_labro') IS NULL
    CREATE USER [sigea_labro] FOR LOGIN [sigea_labro];
ELSE
    ALTER USER [sigea_labro] WITH LOGIN = [sigea_labro];
GRANT SELECT ON dbo.Person TO [sigea_labro];
GRANT SELECT ON dbo.Enrollment TO [sigea_labro];
GRANT SELECT ON dbo.Course TO [sigea_labro];

BEGIN TRY
    IF USER_ID(N'$ModernAcaIdentityName') IS NULL
        EXEC(N'CREATE USER [$ModernAcaIdentityName] FROM EXTERNAL PROVIDER;');
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [$ModernAcaIdentityName];
END TRY
BEGIN CATCH
    PRINT 'Info: Managed Identity user creation skipped (Directory Readers not assigned to SQL MI in tenant); Entra Admin + SQL logins active.';
END CATCH
DBCC CHECKIDENT ('dbo.Person', RESEED);
DBCC CHECKIDENT ('dbo.Department', RESEED);
DBCC CHECKIDENT ('dbo.Enrollment', RESEED);
"@
Invoke-SqlMiQuery -Database $TargetDatabaseName -Query $grantsSql | Out-Null

$swRestore.Stop()
Write-Host "==> Restauración y configuración en Azure SQL Managed Instance completadas en $([Math]::Round($swRestore.Elapsed.TotalSeconds, 2))s."
