/* =====================================================================
   SIGEA - 02_synthetic_data.sql

   Deterministic synthetic data. ALL names and figures are fictitious.
   Idempotent: clears tables and reseeds with fixed IDs so counts and
   aggregates are reproducible (see docs/functional-baseline.md).

   Two students are designated for the IDOR lab:
     ID 7  = Ana Mora      (ana.mora@valleclaro.example)
     ID 8  = Bruno Solis   (bruno.solis@valleclaro.example)
   ===================================================================== */
SET NOCOUNT ON;
GO
USE SIGEA;
GO

DELETE FROM dbo.CourseAssignment;
DELETE FROM dbo.OfficeAssignment;
DELETE FROM dbo.Enrollment;
DELETE FROM dbo.Course;
DELETE FROM dbo.Department;
DELETE FROM dbo.Person;
GO

/* ---------------- Person: instructors (1-6) ---------------- */
SET IDENTITY_INSERT dbo.Person ON;
INSERT INTO dbo.Person (ID, LastName, FirstName, Discriminator, HireDate, Email) VALUES
 (1,'Arroyo','Elena','Instructor','2005-09-01','earroyo@valleclaro.example'),
 (2,'Benitez','Carlos','Instructor','2007-01-15','cbenitez@valleclaro.example'),
 (3,'Castro','Marta','Instructor','2009-08-20','mcastro@valleclaro.example'),
 (4,'Duarte','Raul','Instructor','2006-03-10','rduarte@valleclaro.example'),
 (5,'Esquivel','Lucia','Instructor','2010-02-01','lesquivel@valleclaro.example'),
 (6,'Fallas','Jorge','Instructor','2004-11-05','jfallas@valleclaro.example');

/* ---------------- Person: students (7-26) ---------------- */
INSERT INTO dbo.Person (ID, LastName, FirstName, Discriminator, EnrollmentDate, Email) VALUES
 (7, 'Mora','Ana','Student','2022-02-01','ana.mora@valleclaro.example'),
 (8, 'Solis','Bruno','Student','2022-02-01','bruno.solis@valleclaro.example'),
 (9, 'Rojas','Carla','Student','2022-08-01','crojas@valleclaro.example'),
 (10,'Vega','Daniel','Student','2022-08-01','dvega@valleclaro.example'),
 (11,'Nunez','Elisa','Student','2023-02-01','enunez@valleclaro.example'),
 (12,'Herrera','Felipe','Student','2023-02-01','fherrera@valleclaro.example'),
 (13,'Jimenez','Gabriela','Student','2023-02-01','gjimenez@valleclaro.example'),
 (14,'Lopez','Hugo','Student','2023-08-01','hlopez@valleclaro.example'),
 (15,'Mendez','Irene','Student','2023-08-01','imendez@valleclaro.example'),
 (16,'Ortiz','Julio','Student','2023-08-01','jortiz@valleclaro.example'),
 (17,'Pineda','Karina','Student','2024-02-01','kpineda@valleclaro.example'),
 (18,'Quiros','Luis','Student','2024-02-01','lquiros@valleclaro.example'),
 (19,'Ramirez','Monica','Student','2024-02-01','mramirez@valleclaro.example'),
 (20,'Salas','Nestor','Student','2024-08-01','nsalas@valleclaro.example'),
 (21,'Torres','Olga','Student','2024-08-01','otorres@valleclaro.example'),
 (22,'Ugalde','Pablo','Student','2024-08-01','pugalde@valleclaro.example'),
 (23,'Vargas','Rosa','Student','2025-02-01','rvargas@valleclaro.example'),
 (24,'Wong','Sergio','Student','2025-02-01','swong@valleclaro.example'),
 (25,'Zamora','Tania','Student','2025-02-01','tzamora@valleclaro.example'),
 (26,'Alfaro','Victor','Student','2025-08-01','valfaro@valleclaro.example');
SET IDENTITY_INSERT dbo.Person OFF;
GO

/* ---------------- Department (1-4) with budgets ---------------- */
SET IDENTITY_INSERT dbo.Department ON;
INSERT INTO dbo.Department (DepartmentID, Name, Budget, StartDate, InstructorID) VALUES
 (1,'Ingenieria',        350000.00, '2005-09-01', 1),
 (2,'Ciencias',          280000.00, '2006-09-01', 3),
 (3,'Administracion',    210000.00, '2007-09-01', 2),
 (4,'Humanidades',       175000.00, '2008-09-01', 6);
SET IDENTITY_INSERT dbo.Department OFF;
GO

/* ---------------- Course (assigned CourseID) + credits ---------------- */
INSERT INTO dbo.Course (CourseID, Title, Credits, DepartmentID) VALUES
 (1050,'Introduccion a la Programacion', 4, 1),
 (1061,'Estructuras de Datos',           4, 1),
 (2010,'Calculo I',                      3, 2),
 (2021,'Fisica General',                 3, 2),
 (3001,'Fundamentos de Administracion',  3, 3),
 (3014,'Contabilidad I',                 3, 3),
 (4005,'Redaccion Academica',            2, 4),
 (4012,'Historia Contemporanea',         3, 4);
GO

/* ---------------- OfficeAssignment ---------------- */
INSERT INTO dbo.OfficeAssignment (InstructorID, Location) VALUES
 (1,'Edificio A - 210'),
 (2,'Edificio C - 105'),
 (3,'Edificio B - 014'),
 (5,'Edificio A - 118');
GO

/* ---------------- CourseAssignment (instructor teaches course) ---------------- */
INSERT INTO dbo.CourseAssignment (CourseID, InstructorID) VALUES
 (1050,1),(1061,1),(2010,3),(2021,5),(3001,2),(3014,2),(4005,6),(4012,6);
GO

/* ---------------- Enrollment (+ grades; some NULL = not graded) ---------------- */
/* Ana Mora (7) and Bruno Solis (8) have full transcripts for the IDOR lab. */
INSERT INTO dbo.Enrollment (CourseID, StudentID, Grade) VALUES
 (1050, 7, 3.80),(2010, 7, 3.30),(4005, 7, 4.00),
 (1050, 8, 2.90),(1061, 8, 3.10),(2021, 8, 2.50),
 (1050, 9, 3.50),(2010, 9, 3.00),
 (1061,10, 2.70),(2021,10, 3.20),
 (3001,11, 3.90),(3014,11, 3.40),
 (2010,12, 2.80),(2021,12, 2.60),
 (1050,13, 3.60),(4012,13, 3.70),
 (3001,14, 3.10),(3014,14, 2.90),
 (4005,15, 3.80),(4012,15, 3.50),
 (1050,16, 2.40),(1061,16, 2.20),
 (2010,17, 3.90),(2021,17, 4.00),
 (3001,18, 3.00),
 (3014,19, 3.30),
 (4005,20, 3.60),
 (4012,21, 2.80),
 (1050,22, NULL),
 (2010,23, NULL),
 (3001,24, 3.20),
 (4005,25, 3.40),
 (1061,26, NULL);
GO
