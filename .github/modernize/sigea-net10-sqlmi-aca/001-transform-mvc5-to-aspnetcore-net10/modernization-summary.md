# Modernization Summary — 001-transform-mvc5-to-aspnetcore-net10

## Result

- **finalStatus**: success
- **successCriteriaStatus**:
  - `passBuild`: true (`dotnet build SIGEA.sln` — 0 errors, 8 warnings, all pre-existing CVE advisories on a transitive package, explicitly out of scope per skipped task `002-security-cve-remediation`)
  - `passUnitTests`: true (`dotnet test` on `SIGEA.Tests` — 8 passed, 2 skipped (DB-gated integration tests requiring `SIGEA_IT=1` + a local SQL Server instance), 0 failed)
- Consistency check (`validation-check-consistency`): 0 Critical, 0 Major, 0 Minor issues.
- Completeness check: no remaining references to `System.Web`, EF6-style `EntityFramework` namespace, `System.Configuration.ConfigurationManager`, or `packages.config` anywhere under `src/`.

## Scope boundary respected

Only task `001-transform-mvc5-to-aspnetcore-net10` was executed. Tasks `002-security-cve-remediation` and `003-deployment-azure-container-apps` are marked `"status": "skipped"` in `tasks.json` and were **not** executed — no CVE package bumps and no Azure deployment/az CLI actions were performed. Per explicit instruction, the Dockerfile deliverable normally owned by task 003 was pulled forward into this task's scope (build-context validation only, no image push/deploy).

## What changed

### Project conversion
- `src/SIGEA.Web/SIGEA.Web.csproj` and `src/SIGEA.Tests/SIGEA.Tests.csproj` converted from legacy-format projects (`packages.config`) to SDK-style projects (`Microsoft.NET.Sdk.Web` / `Microsoft.NET.Sdk`) targeting `net10.0`, with `PackageReference` for all dependencies (`Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.EntityFrameworkCore.Design`, `Azure.Identity`, `Microsoft.Data.SqlClient` for the web project; `xunit`, `Xunit.SkippableFact`, `Moq`, `Microsoft.EntityFrameworkCore.InMemory`, `Microsoft.NET.Test.Sdk` for tests).
- Removed legacy ASP.NET-only files: `Global.asax(.cs)`, `App_Start/FilterConfig.cs`, `App_Start/RouteConfig.cs`, `Properties/AssemblyInfo.cs`, `Web.config`, `Views/web.config`, both `packages.config` files, `SIGEA.Tests/app.config`.

### Data access layer (EF6 → EF Core)
- `DAL/SchoolContext.cs` rewritten as an EF Core `DbContext`, preserving:
  - **Table-Per-Hierarchy** `Person`/`Student`/`Instructor` via `HasDiscriminator<string>("Discriminator")`.
  - **`CourseAssignment` many-to-many** via explicit `UsingEntity<Dictionary<string,object>>` mapping to the existing table/column names.
  - **`OfficeAssignment` shared-primary-key** 1:0..1 relationship via `HasOne/WithOne/HasForeignKey<OfficeAssignment>`.
  - `Course.CourseID` business key (`ValueGeneratedNever()`), `Department.Budget` → `money`, `Enrollment.Grade` → `decimal(3,2)`.
- Added a `ResolveConnectionString(IConfiguration, name)` helper shared by `Program.cs` and the lab query code, supporting both local SQL-auth connection strings (dev) and Managed Identity connection strings (cloud) without code branching.

### Security fixes
- **DOTNET-SQLI-01** (`DAL/LabQueries.cs`): replaced string-concatenated SQL with a parameterized `SqlCommand` using `@term`. The SQL text is now identical regardless of the search input — verified by `LabQueriesSqlTests` which assert the generated SQL always contains `LIKE @term` and never embeds the caller-supplied term (including an injection payload like `x%' OR '1'='1' --`), consistent with `docs/security-labs.md` acceptance criteria.
- **DOTNET-IDOR-01** (`Controllers/LabController.cs`): added the same object-level ownership check used in `TranscriptController.Details` — a student session (`sid`) must match the requested transcript `id`, otherwise the controller now returns `403 Forbidden` instead of returning another student's transcript. Covered conceptually by the existing `TranscriptController` test pattern; `LabController`'s check mirrors it exactly.

### ASP.NET Core migration
- `System.Web.HttpContext.Session` → ASP.NET Core `ISession` (`Infrastructure/SessionUser.cs` rewritten using `GetInt32`/`SetInt32`/`GetString`/`SetString`); session configured in `Program.cs` via `AddDistributedMemoryCache()` + `AddSession(...)`.
- All controllers (`Home`, `Students`, `Courses`, `Departments`, `Enrollments`, `Instructors`, `Account`, `Transcript`, `Lab`) migrated from `System.Web.Mvc.Controller` + inline EF6 context ownership to `Microsoft.AspNetCore.Mvc.Controller` with constructor-injected `SchoolContext` (DI-managed lifetime; manual `Dispose(bool)` overrides removed). `[Bind(Include = "...")]` → `[Bind("...")]`; `HttpNotFound()` → `NotFound()`.
- `Infrastructure/LabGate.cs` converted from a static, `ConfigurationManager`-backed class to an injectable instance class constructed with `IConfiguration`, registered as a singleton in `Program.cs`. `Infrastructure/LabOnlyAttribute.cs` resolves it from `HttpContext.RequestServices` since attribute filters can't take constructor DI directly without `[ServiceFilter]`/`TypeFilterAttribute` — flagged during the consistency check and accepted as a reasonable minimal-change approach.
- Classic ASP.NET `HttpRequestBase.IsLocal` has no ASP.NET Core equivalent; reimplemented as a custom loopback check in `LabGate.IsEnabled(HttpRequest)` using `Connection.RemoteIpAddress`.
- New `Program.cs` minimal-hosting entry point replaces `Global.asax` + `App_Start`: registers `SchoolContext` (EF Core SqlServer provider), `LabGate` (singleton), session, MVC with views, exception handling (`/Home/Error`), static files, routing, and the default `{controller=Home}/{action=Index}/{id?}` route.
- Views updated minimally: `_ViewImports.cshtml` added for shared `@using`s/tag helpers; `_Layout.cshtml` now uses `@inject IConfiguration`/`@inject LabGate` instead of static configuration access; lab views (`Sqli.cshtml`, `Transcript.cshtml`, `Index.cshtml`) updated only in wording to reflect both vulnerabilities being remediated — no HtmlHelper usage changes were needed (`Html.BeginForm`, `LabelFor`, `TextBoxFor`, `DropDownList`, `ActionLink`, `AntiForgeryToken`, etc. all compile unchanged under ASP.NET Core).

### Configuration / Managed Identity
- `appsettings.json` (new, production): `ConnectionStrings:SchoolContext` / `LabReadOnlyContext` use `Authentication=Active Directory Managed Identity;User Id=<UAMI_CLIENT_ID>;Encrypt=True;TrustServerCertificate=False;` against a `<SQLMI_SERVER_FQDN>` placeholder, since **no `infra/infra-config.md` with real Azure SQL Managed Instance / user-assigned managed identity values exists in this repository**. Real values are expected to be supplied via environment-variable overrides (`ConnectionStrings__SchoolContext`, etc.) or environment-specific appsettings at deploy time — this is flagged here for the coordinator/infrastructure task to confirm before actual deployment.
- `appsettings.Development.json` (new): local SQL-auth connection strings for `sigea_app`/`sigea_labro` logins with a `${SIGEA_APP_PASSWORD}` placeholder resolved at runtime (never a hardcoded secret).

### Tests
- `SIGEA.Tests` rewritten to compile and run against the new ASP.NET Core / EF Core APIs:
  - `IntegrationTests.cs` — DB-gated baseline checks (skipped unless `SIGEA_IT=1`), unchanged in substance since original LINQ was already framework-agnostic.
  - `LabGateTests.cs` — rewritten to construct `LabGate` with an in-memory `IConfiguration` and exercise `IsEnabled` using a `DefaultHttpContext` with configured `Connection.RemoteIpAddress` instead of mocking the no-longer-existing `HttpRequestBase`.
  - `LabOnlyAttributeTests.cs` — rewritten using `Microsoft.AspNetCore.Mvc.Filters.ActionExecutingContext` with `HttpContext.RequestServices` resolving a real `LabGate` instance via a minimal `ServiceCollection`.
  - `LabQueriesSqlTests.cs` — rewritten to assert the SQL-injection fix: the generated SQL always contains the `@term` placeholder and is byte-for-byte identical regardless of the input, including malicious payloads.
  - Added `src/SIGEA.Tests/appsettings.json` with local-only placeholder connection strings for the DB-gated tests.
- Result: 8 passed, 2 skipped (expected — no local SQL Server instance in this environment), 0 failed.

### Containerization (pulled forward from task 003, build-only)
- Added `src/SIGEA.Web/Dockerfile`: multi-stage build — `mcr.microsoft.com/dotnet/sdk:10.0` build/publish stage, `mcr.microsoft.com/dotnet/aspnet:10.0` runtime stage, listens on port `8080` (`ASPNETCORE_URLS=http://+:8080`), runs as a dedicated non-root `appuser` (uid/gid 1000). Build context is `src/` (sibling to `SIGEA.Web/`), e.g. `docker build -f SIGEA.Web/Dockerfile src/`.
- The Dockerfile's structure and build-command were validated via the `appmod-build-docker-image` tool (build-context/Dockerfile analysis: base images, exposed ports, non-root final user all confirmed correct). **No local Docker daemon was available in this execution environment, so an actual `docker build` could not be run here** — this should be verified in CI or by the coordinator before task 003 (deployment) is ever executed. No image was pushed and no deployment action was taken, per scope.

## Known follow-ups (out of scope for this task)
- `System.Security.Cryptography.Pkcs 9.0.4` (transitive dependency) has NU1902/NU1903 advisories — explicitly deferred to task `002-security-cve-remediation`, which is marked skipped and was not executed here.
- Real Azure SQL Managed Instance server FQDN and user-assigned managed identity client ID must be supplied (via `infra/infra-config.md` or deployment-time configuration) before `appsettings.json`'s Managed Identity connection strings can be used against a real environment.
