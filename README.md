# SIGEA — Sistema de Gestión Estudiantil y Académica

> **Aplicación ficticia de demostración.** Institución ficticia: **Instituto
> Superior Valle Claro**. Todos los nombres, datos y cifras son inventados y
> no corresponden a ninguna persona u organización real.

SIGEA es una **aplicación legacy funcional** construida a propósito sobre un
stack .NET de ~2011 para servir como *línea base* en un laboratorio de
modernización y seguridad. No es una plantilla de producción.

- **C# / .NET Framework 4.8**
- **ASP.NET MVC 5**
- **Entity Framework 6** (Code-First mapeado al esquema de los scripts)
- **SQL Server**
- **IIS Express / IIS** en Windows
- Configuración tradicional con **`Web.config`**

El modelo deriva del conocido ejemplo *Contoso University* y conserva sus
entidades y relaciones principales: **`Person`** (TPH: `Student`/`Instructor`),
**`Course`**, **`Department`** y **`Enrollment`**. El propósito es que
GitHub Copilot y agentes de modernización analicen, migren y corrijan esta
base después. **No** incluye versiones modernizadas, nube ni IA.

---

## 1. Funcionalidades (pantallas normales)

| Área | Detalle |
|------|---------|
| Tablero | Estudiantes, instructores, cursos, departamentos, matrículas, promedio y presupuesto — **calculado en SQL Server** |
| Estudiantes | Búsqueda, consulta, creación y edición |
| Instructores | Gestión (ficha, oficina, cursos) |
| Cursos | Créditos y departamento |
| Departamentos | Presupuestos y resumen |
| Matrículas | Alta/baja y asignación de curso |
| Calificaciones | Edición de notas e historial (expediente) |
| Mi expediente | Acceso de estudiante con verificación de propiedad |

## 2. Requisitos

- Windows con **.NET Framework 4.8**, Visual Studio 2019/2022 o MSBuild, y
  **IIS Express**.
- **SQL Server** local (Developer/Express). La forma más rápida, en una
  máquina con Docker:

```bash
./scripts/provision-local-db.sh
```

Crea la base `SIGEA`, los **logins de permisos mínimos** y carga el esquema y
los datos sintéticos.

> Cuentas: `sigea_app` (**ejecución**, CRUD sobre el esquema) y `sigea_labro`
> (solo lectura, usada únicamente por el laboratorio de SQLi). **No se usa
> `sa` como cuenta de ejecución** (`sa` solo provisiona, como lo haría un DBA).

### Provisión manual (sqlcmd / SSMS)

```sql
-- como administrador del servidor:
:r db/accounts/00_create_logins.sql
-- contra la base SIGEA:
:r db/schema/01_schema.sql
:r db/data/02_synthetic_data.sql
```

## 3. Ejecutar la aplicación normal

1. Copie `config/Web.config.example` y complete las contraseñas de
   `sigea_app`/`sigea_labro` en su `Web.config` local **o** defina
   `SIGEA_APP_PASSWORD` y sustitúyala en despliegue. **No** hay secretos en el
   `Web.config` versionado.
2. Restaure paquetes NuGet y compile la solución `SIGEA.sln`.
3. Ejecute con IIS Express (F5 en Visual Studio) y abra
   `http://localhost:<puerto>/`.

Los laboratorios de seguridad quedan **deshabilitados** por defecto
(`ENABLE_VULNERABILITY_LABS=false`).

## 4. Ejercicios locales de seguridad (opcional, separado)

> ⚠️ Solo para uso local con datos sintéticos. Ver **[SECURITY.md](SECURITY.md)**
> y **[docs/security-labs.md](docs/security-labs.md)**.

Se habilitan **exclusivamente** poniendo en `Web.config`:

```xml
<add key="ENABLE_VULNERABILITY_LABS" value="true" />
```

y accediendo por **loopback**. Con el valor `false` (por defecto) o desde un
origen no-loopback, las rutas `/Lab/**` devuelven **404** (atributo `[LabOnly]`).
Con los labs activos aparece una banda **“Laboratorio vulnerable activo ·
Datos ficticios”** y la pestaña **Laboratorio**.

## 5. Pruebas

Tres grupos (proyecto `SIGEA.Tests`, xUnit; ejecutar en Windows con
`dotnet test` o el runner de Visual Studio):

1. **Funcionales normales** — `IntegrationTests` (requieren una base local;
   se omiten salvo `SIGEA_IT=1`).
2. **Labs deshabilitados por defecto** — `LabGateTests`, `LabOnlyAttributeTests`
   (offline).
3. **Caracterización del comportamiento vulnerable (opcional)** —
   `LabQueriesSqlTests` (offline, nivel de cadena).

> ⚠️ **Estado de verificación:** el esquema SQL Server y los datos sintéticos
> **fueron ejecutados y verificados** contra SQL Server 2022 real (ver
> [docs/functional-baseline.md](docs/functional-baseline.md)). El **código
> .NET no se compiló ni se ejecutó** en el entorno de construcción (Linux, sin
> .NET Framework/MSBuild). Las pruebas .NET requieren un build en Windows. No
> se declara ninguna prueba .NET como ejecutada. Ver
> [docs/functional-baseline.md](docs/functional-baseline.md) §Bloqueos.

## 6. Documentación

- [infra/azure/README.md](infra/azure/README.md) — **IaC en Bicep (`mexicocentral`), Azure Front Door y operación del laboratorio en Azure**
- [docs/architecture.md](docs/architecture.md)
- [docs/data-dictionary.md](docs/data-dictionary.md)
- [docs/functional-baseline.md](docs/functional-baseline.md)
- [docs/security-labs.md](docs/security-labs.md)
- [docs/demo-objectives.md](docs/demo-objectives.md)
- [SECURITY.md](SECURITY.md) · [ATTRIBUTIONS.md](ATTRIBUTIONS.md)

## 7. Estructura

```
SIGEA.sln
db/            accounts/ schema/ data/ reset/   (SQL Server)
scripts/       provision-local-db.sh
config/        Web.config.example
src/SIGEA.Web/
  Models/      Person (TPH), Student, Instructor, Department, Course, Enrollment, ...
  DAL/         SchoolContext (EF6), TranscriptService, LabQueries (SECURITY-LAB SQLi)
  Infrastructure/ LabGate, LabOnlyAttribute, SessionUser
  Controllers/ Home, Students, Instructors, Courses, Departments, Enrollments,
               Account, Transcript (normal), Lab (SECURITY-LAB)
  Views/       Razor (look académico 2011)
src/SIGEA.Tests/  xUnit (3 grupos)
```
