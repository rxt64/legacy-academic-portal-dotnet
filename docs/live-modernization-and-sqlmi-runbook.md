# Runbook en Vivo: Modernización Agéntica de SIGEA y Migración de SQL Server 2022 a Azure SQL Managed Instance

> **Propósito:** Guía operativa verificada para la sesión en vivo de **60 minutos** de **SIGEA** (*Instituto Superior Valle Claro*), integrando el flujo **Assess → Plan → Execute** de **GitHub Copilot Modernization Agent (`modernize` CLI v1.0.91)** con el recorrido de **10–15 minutos de migración de base de datos** desde SQL Server 2022 Developer Edition hacia **Azure SQL Managed Instance** en **Mexico Central (`mexicocentral`)**.

---

## 1. Cronograma integrado de la demostración (60 minutos)

| Bloque | Duración objetivo | Duración medida en ensayo | Actividad en vivo | Checkpoint de respaldo (transparente, preejecutado) |
|---|---:|---:|---|---|
| **Bloque 1: Contexto y línea base legacy** | 5 min | 1.5 min | Mostrar SIGEA legacy en Azure Front Door (`https://sigea-lab-kt2comvd-cbhuh5bma9h9esb9.b02.azurefd.net/`), verificar conteos (20 estudiantes, 6 instructores, 8 cursos, 4 departamentos, 33 matrículas, presupuesto `1,015,000.00`) y crear el **registro testigo** en vivo. | Script [`db/migration/01_insert_witness_and_validate_source.sql`](../db/migration/01_insert_witness_and_validate_source.sql) |
| **Bloque 2: Fase Assess (`modernize assess`)** | 10 min | **1 min 56 s** (`122.22 s`) | Ejecutar `modernize assess`, inspeccionar el reporte generado en `.github/modernize/assessment/` (detección de .NET Framework 4.8, conexiones SQL, estado de sesión `InProc`). | Reporte preejecutado en rama `rehearsal/modernization-dryrun` |
| **Bloque 3: Fase Plan (`modernize plan create`)** | 10 min | **2 min 02 s** (`122.24 s`) | Generar el plan estructurado (`plan.md` + `tasks.json`) vinculando la skill de proyecto [`sigea-mvc5-to-aspnetcore-net10`](../.github/skills/sigea-mvc5-to-aspnetcore-net10/SKILL.md). | `.github/modernize/sigea-net10-sqlmi-aca/plan.md` en rama `rehearsal/modernization-dryrun` |
| **Bloque 4: Migración de Base de Datos (SQL Server 2022 → Azure SQL MI)** | **12–15 min** | **~3.5 min** (técnico) + explicación | Pausa de escrituras, backup nativo `COPY_ONLY` con `CHECKSUM`, subida privada por Managed Identity a `stsigeamigkt2comvd/sqlbackups`, `RESTORE DATABASE [SIGEA]` en `sqlmi-sigea-mxc3-kt2comvd` y validación de paridad. | Base preejecutada `[SIGEA_Rehearsal]` ya restaurada en `sqlmi-sigea-mxc3-kt2comvd` y backup `SIGEA_rehearsal.bak` en Blob Storage |
| **Bloque 5: Fase Execute (`modernize plan execute`) y Seguridad** | 15 min | **~9 min 30 s** (transformación + build + tests) | Ejecutar la transformación a ASP.NET Core / .NET 10 + EF Core, verificar remediación de `DOTNET-SQLI-01` (`@term`) y `DOTNET-IDOR-01` (403 en expediente ajeno) y ejecutar `dotnet test` (`23.25 s`). | Commit `60f3c5a` en rama `rehearsal/modernization-dryrun` |
| **Bloque 6: Publicación en Azure Container Apps y Validación** | 8 min | **1 min 11 s** (`71.22 s` ACR build) + ~65 s ACA | Construir imagen en `acrlegacylabbkt2comvd.azurecr.io` y desplegar en `cae-legacy-modern-mxc` sin alterar todavía el endpoint legacy de Front Door. | Imagen preconstruida `acrlegacylabbkt2comvd.azurecr.io/sigea-modern-rehearsal:v1` |

> **Regla de transparencia para el presentador:** Si por tiempo de agenda decide saltar la espera de `modernize plan execute` (~9.5 min) usando la rama `rehearsal/modernization-dryrun` o la base `[SIGEA_Rehearsal]`, indíquelo explícitamente a la audiencia como *"checkpoint preejecutado del mismo plan para optimizar el tiempo en vivo"*.

---

## 2. Diferenciación explícita: Capacidades nativas vs. Herramientas externas vs. Skills personalizadas

| Componente / Fase | Categoría real | Qué hace exactamente | Intervención del presentador |
|---|---|---|---|
| `modernize` CLI (`v1.0.91`) | **Producto nativo** (GitHub Copilot Modernization Agent) | Orquesta el ciclo **Assess → Plan → Execute**, coordina agentes (`create-modernization-plan`, `execute-modernization-task`, `validate-cves-and-fix`), ejecuta el chequeo de consistencia y genera commits trazables. | Invocar los comandos CLI o el menú interactivo TUI y revisar `plan.md` / `tasks.json`. |
| `dotnet-appcat` (`v1.0.1127`) | **Herramienta externa invocada por `modernize assess`** | Analizador estático de compatibilidad .NET y preparación para la nube invocado automáticamente por `modernize assess`. Preinstalado en `%LOCALAPPDATA%\Microsoft\VisualStudio\AppModernizationExtension\Tools`. | Ninguna durante la demo (ya preinstalado en el host). |
| `.github/skills/sigea-mvc5-to-aspnetcore-net10/SKILL.md` | **Skill personalizada de proyecto** | Define las reglas específicas de SIGEA para migrar MVC 5 / EF6 a ASP.NET Core / .NET 10 / EF Core, parametrizar `DOTNET-SQLI-01`, exigir propiedad en `DOTNET-IDOR-01` y generar el `Dockerfile`. | Mostrar cómo `modernize plan create` descubre automáticamente la skill en `.github/skills/`. |
| `db/migration/*.ps1` y `*.sql` | **Scripts complementarios de migración de datos** | Ejecutan la pausa de escrituras, el backup nativo `COPY_ONLY`, la transferencia privada a Azure Blob Storage con Managed Identity y el `RESTORE DATABASE` en Azure SQL Managed Instance. **No son funciones nativas de `modernize` CLI.** | Ejecutar los 4 pasos del runbook de base de datos en PowerShell. |

---

## 3. Objetivo listo para la fase Plan (`modernize plan create`)

Copie y pegue este prompt exacto durante la demostración en vivo:

```powershell
$sigeaGoal = "Upgrade SIGEA from ASP.NET MVC 5 (.NET Framework 4.8) and Entity Framework 6 to ASP.NET Core MVC on .NET 10 with EF Core, remediate DOTNET-SQLI-01 (parameterized SqlCommand) and DOTNET-IDOR-01 (enforce student transcript ownership), configure Managed Identity authentication for Azure SQL Managed Instance, and containerize for Azure Container Apps."

modernize assess --source . --format markdown
modernize plan create $sigeaGoal --source . --plan-name "sigea-net10-sqlmi-aca" --language dotnet --overwrite
```

---

## 4. Runbook de 10–15 minutos: Migración SQL Server 2022 → Azure SQL Managed Instance

### Paso 1 (Minuto 0–2): Crear el registro testigo y capturar línea base en el origen
> **Nota del presentador:** *"Antes de pausar escrituras, creamos una estudiante testigo (`Valeria Testigo-Migracion`) matriculada en `Introducción a la Programación` (curso `1050`) con calificación `4.00`. Esto demuestra que no estamos corriendo un script de seed en Azure SQL Managed Instance, sino trasladando el estado transaccional exacto del servidor origen."*

Dentro de `vm-sigea-win` (o vía `az vm run-command invoke`):
```powershell
sqlcmd -S localhost -d SIGEA -E -C -b -W -i C:\SIGEA\migration\01_insert_witness_and_validate_source.sql
```
**Resultado observable esperado (medido en `0.26 s`):**
- `StudentCount = 21` (20 originales + 1 testigo `ID = 27`)
- `InstructorCount = 6`, `CourseCount = 8`, `DepartmentCount = 4`
- `EnrollmentCount = 34` (33 originales + 1 matrícula del testigo), `GradedEnrollmentCount = 31`
- `TotalDepartmentBudget = 1015000.00`, `AverageGrade = 3.2613`

### Paso 2 (Minuto 2–5): Pausa de escrituras, backup nativo `COPY_ONLY` y subida privada a Blob Storage
> **Nota del presentador:** *"Definimos aquí el punto de corte de escrituras: detenemos `SigeaAppPool` en IIS y deshabilitamos el login de aplicación `sigea_app`. Importante: tomamos el backup con la base en estado `READ_WRITE` (y la pasamos a `READ_ONLY` inmediatamente después del backup) porque Azure SQL Managed Instance no permite ejecutar `ALTER DATABASE ... SET READ_WRITE` sobre un backup cuya cabecera haya sido marcada como `READ_ONLY`. El archivo `.bak` se sube por Private Endpoint (`10.42.6.4`) a `stsigeamigkt2comvd/sqlbackups` usando el token OAuth2 de la Managed Identity de la VM."*

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\SIGEA\migration\02_freeze_and_backup_source.ps1 `
  -StorageAccountName "stsigeamigkt2comvd" `
  -ContainerName "sqlbackups" `
  -BlobName "SIGEA_migration.bak"
```
**Resultado observable esperado (medido en `1.98 s`):**
- `BACKUP DATABASE successfully processed 690 pages` (`626,688` bytes) y `The backup set on file 1 is valid` (`RESTORE VERIFYONLY WITH CHECKSUM`).
- Subida privada HTTPS vía `10.42.6.4` (`stsigeamigkt2comvd.privatelink.blob.core.windows.net`).

### Paso 3 (Minuto 5–10): Restauración nativa en Azure SQL Managed Instance (`sqlmi-sigea-mxc3-kt2comvd`)
> **Nota del presentador:** *"Nuestra instancia `sqlmi-sigea-mxc3-kt2comvd` fue aprovisionada en Mexico Central con `databaseFormat = AlwaysUpToDate` (motor compatible con SQL Server 2022, nivel de compatibilidad `160`) y `azureADOnlyAuthentication = true`. SQL Managed Instance lee el `.bak` desde Blob Storage usando su propia Managed Identity (`CREDENTIAL ... WITH IDENTITY = 'Managed Identity'`)."*

```powershell
$adminToken = az account get-access-token --resource "https://database.windows.net/" --query "accessToken" -o tsv
powershell.exe -ExecutionPolicy Bypass -File C:\SIGEA\migration\03_restore_and_configure_sqlmi.ps1 `
  -SqlMiHostName "sqlmi-sigea-mxc3-kt2comvd.2d1fac14d3f0.database.windows.net" `
  -StorageAccountName "stsigeamigkt2comvd" `
  -ContainerName "sqlbackups" `
  -BlobName "SIGEA_migration.bak" `
  -TargetDatabaseName "SIGEA" `
  -AccessToken $adminToken
```
> **Checkpoint de respaldo:** Si desea mostrar el resultado de inmediato sin esperar el comando de restauración, la base **`[SIGEA_Rehearsal]`** ya se encuentra restaurada y en estado `ONLINE` (`compatibility_level = 160`) dentro de `sqlmi-sigea-mxc3-kt2comvd.2d1fac14d3f0.database.windows.net`.

### Paso 4 (Minuto 10–15): Validación pre/post migración, punto de cambio de conexión y política de reversión
```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\SIGEA\migration\04_validate_target_and_cutover.ps1 `
  -Action Validate `
  -SqlMiHostName "sqlmi-sigea-mxc3-kt2comvd.2d1fac14d3f0.database.windows.net" `
  -TargetDatabaseName "SIGEA"
```
**Criterios de aceptación verificados:**
- Conteos idénticos (`21` estudiantes, `6` instructores, `8` cursos, `4` departamentos, `34` matrículas, `31` calificadas, `4` oficinas, `8` asignaciones de curso).
- Agregados idénticos (`TotalBudget = 1015000.00`, `AvgGrade = 3.2613`).
- Integridad referencial intacta (`OrphanCourses = 0`, `OrphanEnrollments = 0`).
- Registro testigo presente (`WitnessPresent = 1`, `valeria.testigo@valleclaro.example`).

#### Política de reversión (antes vs. después de habilitar escrituras en el destino)
1. **Reversión ANTES de habilitar nuevas escrituras en Azure SQL Managed Instance (sin pérdida de datos):**
   Mientras la aplicación no haya recibido escrituras en el destino, el origen conserva el 100% del estado válido. Para revertir en segundos:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File C:\SIGEA\migration\04_validate_target_and_cutover.ps1 -Action RollbackSourceReadWrite
   ```
   Esto reactiva `READ_WRITE` en el SQL Server local, habilita `sigea_app` e inicia `SigeaAppPool` sin pérdida de transacciones.
2. **Advertencia crítica DESPUÉS de habilitar escrituras en el destino:**
   Una vez que la aplicación apunta a Azure SQL Managed Instance y acepta altas, ediciones o calificaciones nuevas, **volver a apuntar el connection string al SQL Server origen NO recupera las escrituras realizadas en Managed Instance**. Si se requiere reversión posterior al punto de corte con escrituras activas, debe ejecutarse primero una extracción diferencial de las filas creadas/modificadas en `sqlmi-sigea-mxc3-kt2comvd` antes de reabrir el origen.
