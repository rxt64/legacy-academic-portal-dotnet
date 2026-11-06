/* =====================================================================
   SIGEA - 00_create_logins.sql

   Creates the SIGEA database and the LEAST-PRIVILEGE logins/users the
   application and the SQL-injection lab run as. RUN AS A SERVER ADMIN
   (for the bundled local lab, the 'sa' login of a loopback SQL Server).

   IMPORTANT: 'sa' is used here ONLY to provision, as a DBA would. The
   application NEVER runs as 'sa'. It runs as 'sigea_app' (CRUD on the
   SIGEA schema) and the SQLi lab reads as 'sigea_labro' (SELECT only).

   Passwords are THROWAWAY LAB VALUES for a loopback server with synthetic
   data. Change them for any non-throwaway instance; never commit real ones.
   ===================================================================== */
IF DB_ID('SIGEA') IS NULL
    CREATE DATABASE SIGEA;
GO

/* Server logins (idempotent). */
IF SUSER_ID('sigea_app') IS NULL
    CREATE LOGIN sigea_app   WITH PASSWORD = 'App#Lab2011',   CHECK_POLICY = OFF;
GO
IF SUSER_ID('sigea_labro') IS NULL
    CREATE LOGIN sigea_labro WITH PASSWORD = 'LabRo#Lab2011', CHECK_POLICY = OFF;
GO

USE SIGEA;
GO

/* Database users mapped to the logins. */
IF USER_ID('sigea_app') IS NULL
    CREATE USER sigea_app   FOR LOGIN sigea_app;
GO
IF USER_ID('sigea_labro') IS NULL
    CREATE USER sigea_labro FOR LOGIN sigea_labro;
GO

/* Object grants are issued in 01_schema.sql, after the tables exist.
   sigea_app  -> SELECT/INSERT/UPDATE/DELETE on dbo
   sigea_labro -> SELECT only on Person, Enrollment, Course
   Neither user is added to db_owner or any privileged role. */
GO
