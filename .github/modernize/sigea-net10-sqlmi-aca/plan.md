# Modernization Plan: SIGEA ASP.NET MVC 5 to ASP.NET Core on .NET 10

**Project**: SIGEA (SIGEA.Web + SIGEA.Tests)

---

## Technical Framework

- **Language**: C# (.NET Framework 4.8)
- **Framework**: ASP.NET MVC 5
- **Build Tool**: MSBuild
- **Database**: SQL Server 2022 (to be accessed via Azure SQL Managed Instance)
- **Key Dependencies**: Entity Framework 6.4.4, `System.Web` (classic ASP.NET pipeline), `packages.config`

---

## Overview

> This migration upgrades SIGEA from classic ASP.NET MVC 5 on .NET Framework 4.8 with Entity
> Framework 6 to ASP.NET Core MVC on .NET 10 with EF Core. The application currently runs as an
> IIS-hosted, EF6-backed app with two known lab vulnerabilities: a SQL injection point built from
> string concatenation and an insecure-direct-object-reference (IDOR) gap on transcript access. The
> new architecture will:
>
> - Run on ASP.NET Core MVC / .NET 10 and EF Core, removing the .NET Framework/IIS dependency and
>   enabling cross-platform container hosting.
> - Remediate `DOTNET-SQLI-01` (parameterized `SqlCommand`) and `DOTNET-IDOR-01` (enforced student
>   transcript ownership check), closing both intentional security gaps.
> - Authenticate to Azure SQL Managed Instance using Managed Identity instead of SQL
>   username/password connection strings.
> - Run as a container image on Azure Container Apps for scalable, passwordless cloud hosting.
>
> The migration follows a single comprehensive code-modernization pass (framework, data access,
> and security remediation together), followed by dependency CVE remediation, then containerized
> deployment to the existing Azure infrastructure already defined under `infra/azure`.

---

## Migration Impact Summary

| Application | Original Service | New Azure Service | Authentication | Comments |
|-------------|------------------|--------------------|-----------------|----------|
| SIGEA.Web | IIS / .NET Framework 4.8 | Azure Container Apps | Managed Identity | Container image built from new multi-stage Dockerfile |
| SIGEA.Web | SQL Server 2022 (EF6, SQL auth) | Azure SQL Managed Instance | Managed Identity | `DOTNET-SQLI-01` parameterized query fix applied |
| SIGEA.Web | Transcript access (IDOR gap) | N/A (in-app authorization) | N/A | `DOTNET-IDOR-01` ownership check enforced |

---

## Open Questions & Questionnaire

- [ ] No infrastructure provisioning requested; plan reuses existing IaC under `infra/azure` (`ask_user` unavailable — inferred default: "use infrastructure/configuration already defined in the repository").
- [ ] Integration testing was not requested and `ask_user` is unavailable; no `setupBaseline`/`integrationTest` tasks were added. Re-run plan creation with explicit input if integration tests are desired.
- [ ] Security/CVE remediation scope was not specified by the user; default CVE remediation requirements from the template were used.
