<#
.SYNOPSIS
    Restablecimiento explícito e independiente del dataset sintético de SIGEA en la VM de Azure.
.DESCRIPTION
    Permite restablecer:
    - Mode = 'Full'    : Recrea esquema y carga los datos sintéticos base (20 estudiantes, 6 instructores, 8 cursos, 4 departamentos, 33 matrículas).
    - Mode = 'LabOnly' : Ejecuta únicamente db\reset\90_reset_lab.sql.
#>
[CmdletBinding()]
param(
    [ValidateSet('Full', 'LabOnly')]
    [string]$Mode = 'Full',
    [string]$StageDir = "C:\SIGEA\stage"
)

$ErrorActionPreference = "Stop"
$sqlcmdExe = Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -Filter "sqlcmd.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -First 1
if (-not $sqlcmdExe) {
    throw "No se encontró sqlcmd.exe."
}

if ($Mode -eq 'LabOnly') {
    Write-Host "==> Ejecutando restablecimiento de ejercicios de laboratorio (90_reset_lab.sql)..."
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -i (Join-Path $StageDir "db\reset\90_reset_lab.sql")
    if ($LASTEXITCODE -ne 0) { throw "Fallo al ejecutar 90_reset_lab.sql." }
} else {
    Write-Host "==> Ejecutando restablecimiento completo del dataset sintético de SIGEA..."
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -i (Join-Path $StageDir "db\schema\01_schema.sql")
    if ($LASTEXITCODE -ne 0) { throw "Fallo al ejecutar 01_schema.sql." }
    & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -i (Join-Path $StageDir "db\data\02_synthetic_data.sql")
    if ($LASTEXITCODE -ne 0) { throw "Fallo al ejecutar 02_synthetic_data.sql." }
}

$verifyQuery = @"
SET NOCOUNT ON;
SELECT
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Student') AS Students,
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Instructor') AS Instructors,
    (SELECT COUNT(*) FROM dbo.Course) AS Courses,
    (SELECT COUNT(*) FROM dbo.Department) AS Departments,
    (SELECT COUNT(*) FROM dbo.Enrollment) AS Enrollments,
    (SELECT CAST(SUM(Budget) AS DECIMAL(12,2)) FROM dbo.Department) AS TotalBudget;
"@
Write-Host "==> Verificación del baseline de SIGEA tras restablecimiento:"
& $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -W -Q $verifyQuery
if ($LASTEXITCODE -ne 0) { throw "Fallo al verificar conteos del baseline de SIGEA." }
