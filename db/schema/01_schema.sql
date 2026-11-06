/* =====================================================================
   SIGEA - Sistema de Gestion Estudiantil y Academica
   Instituto Superior Valle Claro (institucion ficticia)

   01_schema.sql  -- SQL Server schema (canonical).

   Model derived from the well-known Contoso University sample: the core
   entities Person (TPH: Student / Instructor), Department, Course and
   Enrollment, plus OfficeAssignment and CourseAssignment. All data is
   fictitious. See ATTRIBUTIONS.md.

   Run as a privileged user against a server where the SIGEA database and
   logins already exist (see db/accounts/00_create_logins.sql). This script
   is idempotent for the schema objects.
   ===================================================================== */
SET NOCOUNT ON;
GO
USE SIGEA;
GO

/* Drop in FK-dependency order (safe to re-run). */
IF OBJECT_ID('dbo.CourseAssignment','U') IS NOT NULL DROP TABLE dbo.CourseAssignment;
IF OBJECT_ID('dbo.OfficeAssignment','U') IS NOT NULL DROP TABLE dbo.OfficeAssignment;
IF OBJECT_ID('dbo.Enrollment','U')       IS NOT NULL DROP TABLE dbo.Enrollment;
IF OBJECT_ID('dbo.Course','U')           IS NOT NULL DROP TABLE dbo.Course;
IF OBJECT_ID('dbo.Department','U')       IS NOT NULL DROP TABLE dbo.Department;
IF OBJECT_ID('dbo.Person','U')           IS NOT NULL DROP TABLE dbo.Person;
GO

/* ---------------------------------------------------------------
   Person - Table-Per-Hierarchy. Discriminator = 'Student' | 'Instructor'.
   Students carry EnrollmentDate; instructors carry HireDate.
   --------------------------------------------------------------- */
CREATE TABLE dbo.Person (
    ID              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Person PRIMARY KEY,
    LastName        NVARCHAR(50)  NOT NULL,
    FirstName       NVARCHAR(50)  NOT NULL,
    Discriminator   NVARCHAR(20)  NOT NULL CONSTRAINT CK_Person_Disc
                      CHECK (Discriminator IN ('Student','Instructor')),
    EnrollmentDate  DATETIME NULL,     -- students only
    HireDate        DATETIME NULL,     -- instructors only
    Email           NVARCHAR(100) NULL
);
GO
CREATE INDEX IX_Person_Disc ON dbo.Person(Discriminator);
CREATE INDEX IX_Person_LastName ON dbo.Person(LastName);
GO

/* ---------------------------------------------------------------
   Department - budgets. Administrator is an optional instructor.
   --------------------------------------------------------------- */
CREATE TABLE dbo.Department (
    DepartmentID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Department PRIMARY KEY,
    Name            NVARCHAR(50)  NOT NULL,
    Budget          MONEY         NOT NULL CONSTRAINT CK_Department_Budget CHECK (Budget >= 0),
    StartDate       DATETIME      NOT NULL,
    InstructorID    INT NULL CONSTRAINT FK_Department_Admin REFERENCES dbo.Person(ID)
);
GO

/* ---------------------------------------------------------------
   Course - credits. CourseID is a business key (assigned, not identity).
   --------------------------------------------------------------- */
CREATE TABLE dbo.Course (
    CourseID        INT NOT NULL CONSTRAINT PK_Course PRIMARY KEY,   -- assigned
    Title           NVARCHAR(100) NOT NULL,
    Credits         INT NOT NULL CONSTRAINT CK_Course_Credits CHECK (Credits BETWEEN 1 AND 6),
    DepartmentID    INT NOT NULL CONSTRAINT FK_Course_Department REFERENCES dbo.Department(DepartmentID)
);
GO
CREATE INDEX IX_Course_Department ON dbo.Course(DepartmentID);
GO

/* ---------------------------------------------------------------
   Enrollment - a student's enrollment in a course, with optional grade.
   Grade is a GPA point value 0.00-4.00 (NULL = not yet graded).
   --------------------------------------------------------------- */
CREATE TABLE dbo.Enrollment (
    EnrollmentID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Enrollment PRIMARY KEY,
    CourseID        INT NOT NULL CONSTRAINT FK_Enrollment_Course  REFERENCES dbo.Course(CourseID),
    StudentID       INT NOT NULL CONSTRAINT FK_Enrollment_Student REFERENCES dbo.Person(ID),
    Grade           DECIMAL(3,2) NULL CONSTRAINT CK_Enrollment_Grade CHECK (Grade BETWEEN 0 AND 4),
    CONSTRAINT UQ_Enrollment UNIQUE (CourseID, StudentID)
);
GO
CREATE INDEX IX_Enrollment_Student ON dbo.Enrollment(StudentID);
CREATE INDEX IX_Enrollment_Course  ON dbo.Enrollment(CourseID);
GO

/* ---------------------------------------------------------------
   OfficeAssignment - 1:0..1 with instructor (Person).
   --------------------------------------------------------------- */
CREATE TABLE dbo.OfficeAssignment (
    InstructorID    INT NOT NULL CONSTRAINT PK_OfficeAssignment PRIMARY KEY
                      CONSTRAINT FK_Office_Instructor REFERENCES dbo.Person(ID),
    Location        NVARCHAR(50) NOT NULL
);
GO

/* ---------------------------------------------------------------
   CourseAssignment - many-to-many instructor <-> course.
   --------------------------------------------------------------- */
CREATE TABLE dbo.CourseAssignment (
    CourseID        INT NOT NULL CONSTRAINT FK_CA_Course     REFERENCES dbo.Course(CourseID),
    InstructorID    INT NOT NULL CONSTRAINT FK_CA_Instructor REFERENCES dbo.Person(ID),
    CONSTRAINT PK_CourseAssignment PRIMARY KEY (CourseID, InstructorID)
);
GO

/* ---------------------------------------------------------------
   Least-privilege grants to the application and lab-read-only users.
   (Users are created from logins in db/accounts/00_create_logins.sql.)
   --------------------------------------------------------------- */
IF USER_ID('sigea_app') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO sigea_app;
END
GO
IF USER_ID('sigea_labro') IS NOT NULL
BEGIN
    -- Read-only, and only the tables the SQLi lab needs.
    GRANT SELECT ON dbo.Person     TO sigea_labro;
    GRANT SELECT ON dbo.Enrollment TO sigea_labro;
    GRANT SELECT ON dbo.Course     TO sigea_labro;
END
GO
