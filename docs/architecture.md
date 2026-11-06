# Arquitectura actual — SIGEA

Documenta el estado **legacy** y sus acoplamientos reales, como insumo para la
modernización posterior. No describe ningún destino implementado.

## Vista general

```
Navegador ──HTTP──> IIS / IIS Express
                      │
                      └── ASP.NET MVC 5 (.NET Framework 4.8)
                            ├── Controllers (render en servidor, Razor .cshtml)
                            ├── DAL: SchoolContext (Entity Framework 6)
                            │        TranscriptService, LabQueries (SECURITY-LAB)
                            └──ADO.NET/EF──> SQL Server (dbo: Person, Department,
                                              Course, Enrollment, OfficeAssignment,
                                              CourseAssignment)
```

Todo el HTML se **renderiza en el servidor** con Razor; no hay API ni SPA.

## Stack y versiones

| Componente | Versión | Nota de modernización |
|------------|---------|-----------------------|
| .NET Framework | 4.8 | Solo Windows; no es .NET moderno multiplataforma |
| ASP.NET MVC | 5.2.9 | `System.Web`-based; MVC clásico |
| Entity Framework | 6.4.4 | EF6 (no EF Core); TPH, fluent mapping |
| SQL Server | probado en 2022 | `money`, `IDENTITY`, `MERGE`-style scripts |
| Config | `Web.config` | Transformaciones/`appSettings` tradicionales |
| Hosting | IIS / IIS Express | Pipeline integrado de IIS |

## Acoplamientos reales (lo que una migración debe resolver)

1. **`System.Web` / IIS.** MVC 5 depende de `System.Web` y del pipeline de IIS;
   migrar a ASP.NET Core implica reescribir arranque, routing, filtros y
   `Web.config` → `appsettings.json` + middleware. La sesión (`Session`) usada
   por el login se apoya en `System.Web.SessionState`.
2. **Entity Framework 6.** El contexto usa mapeo TPH (`Discriminator`),
   `DatabaseGenerated.None` para `Course.CourseID`, y many-to-many clásico
   (`CourseAssignment`). EF Core modela varias de estas cosas distinto
   (p. ej. many-to-many y TPH han cambiado), así que la migración de ORM no es
   mecánica.
3. **SQL Server-específico.** `IDENTITY`, tipo `money`, e `IDENTITY_INSERT` en
   los scripts de datos. Un motor destino distinto exige equivalencias.
4. **Autenticación mínima basada en sesión.** El login de estudiante guarda la
   identidad en `Session`. La autorización por objeto del expediente es lógica
   de aplicación (y es justo el punto del laboratorio IDOR).

## Cuentas y permisos mínimos

| Cuenta | Rol | Privilegios |
|--------|-----|-------------|
| `sa` | Solo provisión (DBA) | Crea base, logins; **no** es cuenta de ejecución |
| `sigea_app` | **Ejecución** de la app | `SELECT/INSERT/UPDATE/DELETE` sobre el esquema `dbo` |
| `sigea_labro` | Solo laboratorio SQLi | `SELECT` en `Person`, `Enrollment`, `Course`; nada más |

Verificado: `sigea_labro` no puede hacer `UPDATE` (*permission denied*).

## Capas de código

| Carpeta | Responsabilidad |
|---------|-----------------|
| `Controllers` | Pantallas normales + `TranscriptController` (verifica propiedad) + `LabController` (`[LabOnly]`) |
| `DAL` | `SchoolContext` (EF6), `TranscriptService` (datos, sin autorización), `LabQueries` (SQLi) |
| `Infrastructure` | `LabGate` (flag+loopback), `LabOnlyAttribute` (404), `SessionUser` (identidad de sesión) |
| `Models` | Entidades EF6 + ViewModels |
| `Views` | Razor (look académico 2011) |

## Nota de construcción

El esquema SQL Server y los datos se **verificaron contra SQL Server 2022
real**. El proyecto .NET **no se compiló** en el entorno de construcción
(Linux), que no dispone de .NET Framework/MSBuild; requiere un build en
Windows. Ver `docs/functional-baseline.md` §Bloqueos.
