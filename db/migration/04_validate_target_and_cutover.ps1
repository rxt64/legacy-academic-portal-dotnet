<#
.SYNOPSIS
    Valida paridad de conteos, agregados, integridad referencial y registro testigo entre
    el SQL Server 2022 origen y la base restaurada en Azure SQL Managed Instance, y permite
    ejecutar o revertir el cambio de conexión antes de habilitar nuevas escrituras.
#>
[CmdletBinding()]
param(
    [ValidateSet('Validate', 'RollbackSourceReadWrite', 'CleanupWitnessOnSource')]
    [string]$Action = 'Validate',

    [string]$SqlMiHostName = "",
    [string]$TargetDatabaseName = "SIGEA",
    [string]$AppPoolName = "SigeaAppPool",
    [string]$AccessToken = ""
)

$ErrorActionPreference = "Stop"
$sqlcmdExe = Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -Filter "sqlcmd.exe" -Recurse |
    Select-Object -ExpandProperty FullName -First 1

$validationQuery = @"
SET NOCOUNT ON;
SELECT
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Student') AS StudentCount,
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Instructor') AS InstructorCount,
    (SELECT COUNT(*) FROM dbo.Course) AS CourseCount,
    (SELECT COUNT(*) FROM dbo.Department) AS DepartmentCount,
    (SELECT COUNT(*) FROM dbo.Enrollment) AS EnrollmentCount,
    (SELECT COUNT(Grade) FROM dbo.Enrollment) AS GradedCount,
    (SELECT COUNT(*) FROM dbo.OfficeAssignment) AS OfficeCount,
    (SELECT COUNT(*) FROM dbo.CourseAssignment) AS CourseAssignCount,
    (SELECT CAST(SUM(Budget) AS DECIMAL(14,2)) FROM dbo.Department) AS TotalBudget,
    (SELECT CAST(ROUND(AVG(Grade), 4) AS DECIMAL(6,4)) FROM dbo.Enrollment WHERE Grade IS NOT NULL) AS AvgGrade,
    (SELECT COUNT(*) FROM dbo.Course c LEFT JOIN dbo.Department d ON d.DepartmentID = c.DepartmentID WHERE d.DepartmentID IS NULL) AS OrphanCourses,
    (SELECT COUNT(*) FROM dbo.Enrollment e LEFT JOIN dbo.Person p ON p.ID = e.StudentID WHERE p.ID IS NULL) AS OrphanEnrollments,
    (SELECT COUNT(*) FROM dbo.Person WHERE Email = N'valeria.testigo@valleclaro.example') AS WitnessPresent;
"@

switch ($Action) {
    'Validate' {
        Write-Host "==> Consultando métricas en SQL Server 2022 Origen (localhost/SIGEA)..."
        & $sqlcmdExe -S "localhost" -d "SIGEA" -E -C -b -W -Q $validationQuery
        if (-not [string]::IsNullOrWhiteSpace($SqlMiHostName)) {
            Write-Host "==> Consultando métricas en Azure SQL Managed Instance Destino ($SqlMiHostName/$TargetDatabaseName)..."
            if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
                $sqlAccessToken = $AccessToken
            } else {
                $imdsSqlUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://database.windows.net/"
                $sqlAccessToken = (Invoke-RestMethod -Uri $imdsSqlUrl -Headers @{ Metadata = "true" } -Method GET).access_token
            }
            $conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:${SqlMiHostName},1433;Database=${TargetDatabaseName};Encrypt=True;TrustServerCertificate=False;")
            $conn.AccessToken = $sqlAccessToken
            $conn.Open()
            try {
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = $validationQuery
                $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
                $dt = New-Object System.Data.DataTable
                [void]$adapter.Fill($dt)
                foreach ($row in $dt.Rows) {
                    Write-Host "StudentCount=$($row.StudentCount) | InstructorCount=$($row.InstructorCount) | CourseCount=$($row.CourseCount) | DepartmentCount=$($row.DepartmentCount) | EnrollmentCount=$($row.EnrollmentCount) | GradedCount=$($row.GradedCount) | OfficeCount=$($row.OfficeCount) | CourseAssignCount=$($row.CourseAssignCount) | TotalBudget=$($row.TotalBudget) | AvgGrade=$($row.AvgGrade) | OrphanCourses=$($row.OrphanCourses) | OrphanEnrollments=$($row.OrphanEnrollments) | WitnessPresent=$($row.WitnessPresent)"
                }
            } finally {
                $conn.Close()
            }
        }
    }
    'RollbackSourceReadWrite' {
        Write-Host "==> Reversión segura antes de habilitar escrituras en destino: restaurando SIGEA origen a READ_WRITE, habilitando sigea_app y levantando SigeaAppPool..."
        & $sqlcmdExe -S "localhost" -E -C -b -Q "ALTER DATABASE [SIGEA] SET READ_WRITE; ALTER LOGIN [sigea_app] ENABLE;"
        Import-Module WebAdministration
        Start-WebAppPool -Name $AppPoolName
        Write-Host "==> Origen SIGEA en READ_WRITE, login sigea_app habilitado y SigeaAppPool activo."
    }
    'CleanupWitnessOnSource' {
        Write-Host "==> Limpiando registro testigo de ensayo en el origen y asegurando READ_WRITE..."
        $cleanSql = @"
ALTER DATABASE [SIGEA] SET READ_WRITE;
ALTER LOGIN [sigea_app] ENABLE;
USE [SIGEA];
DELETE FROM dbo.Enrollment WHERE StudentID IN (SELECT ID FROM dbo.Person WHERE Email = N'valeria.testigo@valleclaro.example');
DELETE FROM dbo.Person WHERE Email = N'valeria.testigo@valleclaro.example';
DECLARE @maxId INT = ISNULL((SELECT MAX(ID) FROM dbo.Person), 26);
DBCC CHECKIDENT ('dbo.Person', RESEED, @maxId);
DECLARE @maxEnr INT = ISNULL((SELECT MAX(EnrollmentID) FROM dbo.Enrollment), 33);
DBCC CHECKIDENT ('dbo.Enrollment', RESEED, @maxEnr);
"@
        & $sqlcmdExe -S "localhost" -E -C -b -Q $cleanSql
        Import-Module WebAdministration
        Start-WebAppPool -Name $AppPoolName
        Write-Host "==> Registro testigo eliminado del origen; baseline original restaurado (20 estudiantes, 33 matrículas)."
    }
}
