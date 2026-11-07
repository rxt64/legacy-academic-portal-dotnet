/* =====================================================================
   SIGEA - 01_insert_witness_and_validate_source.sql
   
   1. Inserta (de forma idempotente) un registro testigo reconocible
      para demostrar en vivo que la migración traslada el estado real
      de la base origen (no un seed reejecutado en el destino).
   2. Ejecuta consultas de validación pre-migración: conteos, agregados
      monetarios y académicos, integridad referencial, valores de
      secuencias/identity y verificación del registro testigo.
   ===================================================================== */
SET NOCOUNT ON;
USE [SIGEA];
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Person WHERE Email = N'valeria.testigo@valleclaro.example')
BEGIN
    INSERT INTO dbo.Person (LastName, FirstName, Discriminator, EnrollmentDate, Email)
    VALUES (N'Testigo-Migracion', N'Valeria', N'Student', '2026-11-06', N'valeria.testigo@valleclaro.example');

    DECLARE @WitnessId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Enrollment (CourseID, StudentID, Grade)
    VALUES (1050, @WitnessId, 4.00);
END
GO

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    CAST(DATABASEPROPERTYEX(DB_NAME(), 'Updateability') AS NVARCHAR(32)) AS Updateability,
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Student') AS StudentCount,
    (SELECT COUNT(*) FROM dbo.Person WHERE Discriminator = 'Instructor') AS InstructorCount,
    (SELECT COUNT(*) FROM dbo.Course) AS CourseCount,
    (SELECT COUNT(*) FROM dbo.Department) AS DepartmentCount,
    (SELECT COUNT(*) FROM dbo.Enrollment) AS EnrollmentCount,
    (SELECT COUNT(Grade) FROM dbo.Enrollment) AS GradedEnrollmentCount,
    (SELECT COUNT(*) FROM dbo.OfficeAssignment) AS OfficeAssignmentCount,
    (SELECT COUNT(*) FROM dbo.CourseAssignment) AS CourseAssignmentCount,
    (SELECT CAST(SUM(Budget) AS DECIMAL(14,2)) FROM dbo.Department) AS TotalDepartmentBudget,
    (SELECT CAST(ROUND(AVG(Grade), 4) AS DECIMAL(6,4)) FROM dbo.Enrollment WHERE Grade IS NOT NULL) AS AverageGrade,
    IDENT_CURRENT('dbo.Person') AS PersonIdentityCurrent,
    IDENT_CURRENT('dbo.Department') AS DepartmentIdentityCurrent,
    IDENT_CURRENT('dbo.Enrollment') AS EnrollmentIdentityCurrent;
GO

-- Integridad referencial y verificación del registro testigo
SELECT
    p.ID AS WitnessStudentID,
    p.LastName,
    p.FirstName,
    p.Email,
    e.CourseID,
    c.Title AS CourseTitle,
    e.Grade
FROM dbo.Person p
JOIN dbo.Enrollment e ON e.StudentID = p.ID
JOIN dbo.Course c ON c.CourseID = e.CourseID
WHERE p.Email = N'valeria.testigo@valleclaro.example';
GO
