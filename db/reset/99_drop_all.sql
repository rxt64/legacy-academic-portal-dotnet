/* =====================================================================
   SIGEA - 99_drop_all.sql  -- drops all SIGEA schema objects.
   RUN AS A USER WITH DDL ON THE SIGEA DATABASE.
   ===================================================================== */
USE SIGEA;
GO
IF OBJECT_ID('dbo.CourseAssignment','U') IS NOT NULL DROP TABLE dbo.CourseAssignment;
IF OBJECT_ID('dbo.OfficeAssignment','U') IS NOT NULL DROP TABLE dbo.OfficeAssignment;
IF OBJECT_ID('dbo.Enrollment','U')       IS NOT NULL DROP TABLE dbo.Enrollment;
IF OBJECT_ID('dbo.Course','U')           IS NOT NULL DROP TABLE dbo.Course;
IF OBJECT_ID('dbo.Department','U')       IS NOT NULL DROP TABLE dbo.Department;
IF OBJECT_ID('dbo.Person','U')           IS NOT NULL DROP TABLE dbo.Person;
GO
