<#
.SYNOPSIS
    Aprovisionamiento inicial y actualización idempotente de SIGEA dentro de la VM Windows Server en Azure.
.DESCRIPTION
    - Distingue instalación inicial vs actualización (no elimina la base SIGEA ni sus datos en redespliegues).
    - Inicializa y formatea el disco administrado persistente (LUN 0 -> F:\) para datos y logs de SQL Server.
    - Configura SQL Server 2022 Developer en loopback (127.0.0.1:1433) con inicio automático.
    - Genera credenciales únicas para sigea_app y sigea_labro resguardadas en C:\SIGEA\Secrets\sql-credentials.json (sin imprimirlas).
    - Ejecuta sqlcmd con -b para fallar ante cualquier error SQL inesperado.
    - Instala IIS + ASP.NET 4.8, configura SigeaAppPool con ApplicationPoolIdentity (permisos mínimos) y publica SIGEA.Web.
    - Sustituye explícitamente ${SIGEA_APP_PASSWORD} y ${SIGEA_LAB_PASSWORD} en Web.config, establece debug="false" y ENABLE_VULNERABILITY_LABS="false".
#>
[CmdletBinding()]
param(
    [string]$StageDir = "C:\SIGEA\stage",
    [string]$SitePhysicalPath = "C:\inetpub\sigea",
    [string]$SecretsPath = "C:\SIGEA\Secrets\sql-credentials.json",
    [string]$SqlDataDriveLetter = "F",
    [int]$SqlStartupTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "==> [1/7] Preparando directorios y almacenamiento persistente (LUN 0)..."
New-Item -ItemType Directory -Force -Path "C:\SIGEA\Secrets" | Out-Null
& icacls "C:\SIGEA\Secrets" /inheritance:r /grant:r "BUILTIN\Administrators:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null

$rawDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Select-Object -First 1
if ($null -ne $rawDisk) {
    Write-Host "    Inicializando disco persistente en LUN $($rawDisk.Number) como unidad ${SqlDataDriveLetter}:..."
    $rawDisk | Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -DriveLetter $SqlDataDriveLetter -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQLDATA" -Confirm:$false | Out-Null
}

$sqlDataDir = "${SqlDataDriveLetter}:\MSSQL\Data"
$sqlLogDir  = "${SqlDataDriveLetter}:\MSSQL\Log"
$sqlBakDir  = "${SqlDataDriveLetter}:\MSSQL\Backup"
foreach ($dir in @($sqlDataDir, $sqlLogDir, $sqlBakDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    & icacls $dir /grant "NT Service\MSSQLSERVER:(OI)(CI)F" "BUILTIN\Administrators:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null
}

Write-Host "==> [2/7] Configurando SQL Server 2022 Developer (inicio automático y Mixed Mode)..."
Set-Service -Name "MSSQLSERVER" -StartupType Automatic
$sqlSvc = Get-Service -Name "MSSQLSERVER"
if ($sqlSvc.Status -ne 'Running') {
    Start-Service -Name "MSSQLSERVER"
}

$regInstance = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").MSSQLSERVER
$mssqlRegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$regInstance\MSSQLServer"
$currentLoginMode = (Get-ItemProperty -Path $mssqlRegPath -Name "LoginMode").LoginMode
$currentDataDir   = (Get-ItemProperty -Path $mssqlRegPath -Name "DefaultData" -ErrorAction SilentlyContinue).DefaultData
$currentLogDir    = (Get-ItemProperty -Path $mssqlRegPath -Name "DefaultLog" -ErrorAction SilentlyContinue).DefaultLog

$needsSqlRestart = $false
if ($currentLoginMode -ne 2) {
    Set-ItemProperty -Path $mssqlRegPath -Name "LoginMode" -Value 2
    $needsSqlRestart = $true
}
if ($currentDataDir -ne $sqlDataDir) {
    Set-ItemProperty -Path $mssqlRegPath -Name "DefaultData" -Value $sqlDataDir
    $needsSqlRestart = $true
}
if ($currentLogDir -ne $sqlLogDir) {
    Set-ItemProperty -Path $mssqlRegPath -Name "DefaultLog" -Value $sqlLogDir
    $needsSqlRestart = $true
}

# Asegurar que el puerto 1433 esté bloqueado en el firewall de Windows para tráfico entrante externo
if (-not (Get-NetFirewallRule -DisplayName "SIGEA-Block-Inbound-SQL-1433" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "SIGEA-Block-Inbound-SQL-1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Block | Out-Null
}

if ($needsSqlRestart) {
    Write-Host "    Reiniciando servicio MSSQLSERVER para aplicar configuración..."
    Restart-Service -Name "MSSQLSERVER" -Force
}

$sqlcmdExe = Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -Filter "sqlcmd.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -First 1
if (-not $sqlcmdExe) {
    throw "No se encontró sqlcmd.exe en la máquina virtual."
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$sqlReady = $false
while ($sw.Elapsed.TotalSeconds -lt $SqlStartupTimeoutSeconds) {
    & $sqlcmdExe -S "localhost" -E -C -b -Q "SELECT 1" *> $null
    if ($LASTEXITCODE -eq 0) {
        $sqlReady = $true
        break
    }
    Start-Sleep -Seconds 3
}
if (-not $sqlReady) {
    throw "Timeout esperando a que SQL Server acepte conexiones locales (${SqlStartupTimeoutSeconds}s)."
}

Write-Host "==> [3/7] Gestionando credenciales únicas de aplicación y laboratorio (sin exposición en consola)..."
function New-RandomLabPassword {
    $u = "ABCDEFGHJKLMNPQRSTUVWXYZ".ToCharArray() | Get-Random -Count 4
    $l = "abcdefghijkmnopqrstuvwxyz".ToCharArray() | Get-Random -Count 6
    $d = "23456789".ToCharArray() | Get-Random -Count 4
    $s = @('#','!','@','$') | Get-Random -Count 2
    $mix = ($u + $l + $d + $s) | Sort-Object { Get-Random }
    return "Sg" + (-join $mix)
}

if (Test-Path $SecretsPath) {
    $credObj = Get-Content -Path $SecretsPath -Raw | ConvertFrom-Json
} else {
    $credObj = [PSCustomObject]@{
        sigeaAppPassword = (New-RandomLabPassword)
        sigeaLabPassword = (New-RandomLabPassword)
        createdAtUtc     = (Get-Date).ToUniversalTime().ToString("o")
    }
    $credObj | ConvertTo-Json | Set-Content -Path $SecretsPath -Encoding UTF8
    & icacls $SecretsPath /inheritance:r /grant:r "BUILTIN\Administrators:F" "NT AUTHORITY\SYSTEM:F" | Out-Null
}

Write-Host "==> [4/7] Aprovisionando base SIGEA, cuentas de mínimo privilegio y datos (idempotente)..."
$initSql = @"
SET NOCOUNT ON;
IF DB_ID('SIGEA') IS NULL
BEGIN
    CREATE DATABASE [SIGEA]
    ON PRIMARY (
        NAME = N'SIGEA_Data',
        FILENAME = N'$sqlDataDir\SIGEA.mdf',
        SIZE = 64MB,
        FILEGROWTH = 32MB
    )
    LOG ON (
        NAME = N'SIGEA_Log',
        FILENAME = N'$sqlLogDir\SIGEA_log.ldf',
        SIZE = 32MB,
        FILEGROWTH = 16MB
    );
END
GO
IF SUSER_ID('sigea_app') IS NULL
    CREATE LOGIN [sigea_app] WITH PASSWORD = N'$($credObj.sigeaAppPassword)', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [sigea_app] WITH PASSWORD = N'$($credObj.sigeaAppPassword)', CHECK_POLICY = OFF;
GO
IF SUSER_ID('sigea_labro') IS NULL
    CREATE LOGIN [sigea_labro] WITH PASSWORD = N'$($credObj.sigeaLabPassword)', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [sigea_labro] WITH PASSWORD = N'$($credObj.sigeaLabPassword)', CHECK_POLICY = OFF;
GO
USE [SIGEA];
GO
IF USER_ID('sigea_app') IS NULL
    CREATE USER [sigea_app] FOR LOGIN [sigea_app];
ELSE
    ALTER USER [sigea_app] WITH LOGIN = [sigea_app];
GO
IF USER_ID('sigea_labro') IS NULL
    CREATE USER [sigea_labro] FOR LOGIN [sigea_labro];
ELSE
    ALTER USER [sigea_labro] WITH LOGIN = [sigea_labro];
GO
"@

$tempAccountSql = Join-Path $env:TEMP "sigea_accounts_init.sql"
try {
    Set-Content -Path $tempAccountSql -Value $initSql -Encoding UTF8
    & $sqlcmdExe -S "localhost" -E -C -b -i $tempAccountSql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Error configurando base SIGEA y logins." }
} finally {
    Remove-Item -Path $tempAccountSql -Force -ErrorAction SilentlyContinue
}

# Verificar si el esquema ya existe (preservar datos en redespliegues)
$tableExistsRaw = & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -h -1 -W -b -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID('dbo.Person','U') IS NOT NULL THEN 1 ELSE 0 END;"
if ($LASTEXITCODE -ne 0) { throw "Error consultando estado del esquema SIGEA." }
$schemaExists = ($tableExistsRaw | Out-String).Trim() -eq "1"

if (-not $schemaExists) {
    Write-Host "    Instalación inicial detectada: aplicando 01_schema.sql y 02_synthetic_data.sql..."
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -i (Join-Path $StageDir "db\schema\01_schema.sql") | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fallo al aplicar 01_schema.sql." }
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -i (Join-Path $StageDir "db\data\02_synthetic_data.sql") | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fallo al aplicar 02_synthetic_data.sql." }
} else {
    Write-Host "    Esquema existente detectado en disco persistente: preservando datos y verificando permisos mínimos..."
    $grantSql = @"
USE [SIGEA];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [sigea_app];
GRANT SELECT ON dbo.Person TO [sigea_labro];
GRANT SELECT ON dbo.Enrollment TO [sigea_labro];
GRANT SELECT ON dbo.Course TO [sigea_labro];
"@
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -Q $grantSql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fallo al asegurar permisos mínimos en SIGEA." }
}

Write-Host "==> [5/7] Instalando roles IIS y ASP.NET 4.8..."
Install-WindowsFeature -Name Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Static-Content, Web-Http-Errors, Web-Health, Web-Http-Logging, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-App-Dev, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Tools, Web-Mgmt-Console | Out-Null
Set-Service -Name "W3SVC" -StartupType Automatic
Start-Service -Name "W3SVC"

Write-Host "==> [6/7] Publicando SIGEA.Web en IIS y aplicando transformación segura de Web.config..."
New-Item -ItemType Directory -Force -Path $SitePhysicalPath | Out-Null
$publishedAppDir = Join-Path $StageDir "publish"
if (-not (Test-Path $publishedAppDir)) {
    throw "No se encontró el directorio de publicación en $publishedAppDir."
}

& robocopy $publishedAppDir $SitePhysicalPath /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "Error copiando archivos publicados a $SitePhysicalPath (robocopy exit code $LASTEXITCODE)."
}

$webConfigPath = Join-Path $SitePhysicalPath "Web.config"
[xml]$xml = Get-Content -Path $webConfigPath -Encoding UTF8

foreach ($add in $xml.configuration.connectionStrings.add) {
    if ($add.name -eq "SchoolContext") {
        $add.connectionString = "Server=127.0.0.1;Database=SIGEA;User Id=sigea_app;Password=$($credObj.sigeaAppPassword);TrustServerCertificate=True;MultipleActiveResultSets=True"
    }
    elseif ($add.name -eq "LabReadOnlyContext") {
        $add.connectionString = "Server=127.0.0.1;Database=SIGEA;User Id=sigea_labro;Password=$($credObj.sigeaLabPassword);TrustServerCertificate=True"
    }
}

foreach ($setting in $xml.configuration.appSettings.add) {
    if ($setting.key -eq "ENABLE_VULNERABILITY_LABS") {
        $setting.value = "false"
    }
}

$xml.configuration.'system.web'.compilation.debug = "false"
$xml.Save($webConfigPath)

Import-Module WebAdministration
$appPoolName = "SigeaAppPool"
if (-not (Test-Path "IIS:\AppPools\$appPoolName")) {
    New-WebAppPool -Name $appPoolName | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value "Integrated"
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "autoStart" -Value $true
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "startMode" -Value "AlwaysRunning"
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"

& icacls $SitePhysicalPath /grant "IIS AppPool\${appPoolName}:(OI)(CI)RX" "BUILTIN\Administrators:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null
& icacls $webConfigPath /inheritance:r /grant:r "IIS AppPool\${appPoolName}:R" "BUILTIN\Administrators:F" "NT AUTHORITY\SYSTEM:F" | Out-Null

if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
    Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "serverAutoStart" -Value $false
}

$siteName = "SIGEA"
if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
    New-Website -Name $siteName -PhysicalPath $SitePhysicalPath -ApplicationPool $appPoolName -Port 80 -IPAddress "127.0.0.1" | Out-Null
} else {
    Set-ItemProperty "IIS:\Sites\$siteName" -Name "physicalPath" -Value $SitePhysicalPath
    Set-ItemProperty "IIS:\Sites\$siteName" -Name "applicationPool" -Value $appPoolName
}
Set-ItemProperty "IIS:\Sites\$siteName" -Name "serverAutoStart" -Value $true
Restart-WebAppPool -Name $appPoolName
Start-Website -Name $siteName

Write-Host "==> [7/7] Verificando respuesta HTTP local (http://127.0.0.1/) y bloqueo 404 de /Lab..."
$respHome = Invoke-WebRequest -Uri "http://127.0.0.1/" -UseBasicParsing -TimeoutSec 30
if ($respHome.StatusCode -ne 200) {
    throw "El tablero de SIGEA devolvió código inesperado: $($respHome.StatusCode)"
}

$labStatus = 0
try {
    $rLab = Invoke-WebRequest -Uri "http://127.0.0.1/Lab" -UseBasicParsing -TimeoutSec 15
    $labStatus = [int]$rLab.StatusCode
} catch {
    if ($_.Exception.Response) {
        $labStatus = [int]$_.Exception.Response.StatusCode
    }
}
if ($labStatus -ne 404) {
    throw "La ruta /Lab debía devolver 404 con ENABLE_VULNERABILITY_LABS=false, pero devolvió $labStatus"
}

Write-Host "==> Aprovisionamiento de SIGEA completado exitosamente (HTTP 200 en /, HTTP 404 en /Lab)."
