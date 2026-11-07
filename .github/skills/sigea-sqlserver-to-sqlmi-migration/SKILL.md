---
name: sigea-sqlserver-to-sqlmi-migration
description: Migrate SQL Server 2022 database SIGEA to Azure SQL Managed Instance using offline write-freeze, COPY_ONLY native backup to private Azure Blob Storage, native RESTORE on SQL MI, least-privilege login/user mapping, and pre/post data validation
---

# SIGEA Database Migration Skill: SQL Server 2022 to Azure SQL Managed Instance

## Overview

Guides the offline database migration of **SIGEA** from SQL Server 2022 Developer Edition on `vm-sigea-win` to **Azure SQL Managed Instance** (`sqlmi-sigea-*`, `databaseFormat: AlwaysUpToDate` / `SQLServer2022`) in `mexicocentral` using native `.bak` backup and restore via a private Azure Blob Storage container (`sqlbackups`).

## Steps

1. **Insert Recognizable Witness Record (`Registro Testigo`)**:
   - Before freezing writes on the source database, insert a recognizable witness student (e.g., `Valeria Testigo-Migracion`, `valeria.testigo@valleclaro.example`) and enrollment via the application or `db/migration/01_insert_witness_and_validate_source.sql`.
2. **Freeze Writes on Source (`Pausa de Escrituras`)**:
   - Stop `SigeaAppPool` in IIS or set the source database `ALTER DATABASE [SIGEA] SET READ_ONLY WITH ROLLBACK IMMEDIATE` during the backup window so no post-backup writes occur.
3. **Native `COPY_ONLY` Backup and Upload to Private Blob Storage**:
   - Execute `BACKUP DATABASE [SIGEA] TO DISK = N'F:\MSSQL\Backup\SIGEA_migration.bak' WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM;`
   - Upload `SIGEA_migration.bak` to `https://stsigeamig*.blob.core.windows.net/sqlbackups/SIGEA_migration.bak` using the VM's System-Assigned Managed Identity (`Storage Blob Data Contributor`).
4. **Restore on Azure SQL Managed Instance**:
   - On SQL Managed Instance (`sqlmi-sigea-*.public/private.database.windows.net`), create the server credential:
     ```sql
     CREATE CREDENTIAL [https://stsigeamigkt2comvd.blob.core.windows.net/sqlbackups]
     WITH IDENTITY = 'Managed Identity';
     RESTORE DATABASE [SIGEA]
     FROM URL = 'https://stsigeamigkt2comvd.blob.core.windows.net/sqlbackups/SIGEA_migration.bak';
     ```
5. **Re-map Least-Privilege Users and Managed Identity**:
   - Map `sigea_app` and `sigea_labro` (`ALTER USER ... WITH LOGIN = ...`) and create the Container Apps Managed Identity user (`CREATE USER [id-sigea-modern-aca] FROM EXTERNAL PROVIDER; GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [id-sigea-modern-aca];`).
6. **Validate Pre/Post Counts, Aggregates, Relationships, and Rollback Boundary**:
   - Run `db/migration/04_validate_target.sql` and compare with pre-migration snapshot before enabling new writes on the target.
