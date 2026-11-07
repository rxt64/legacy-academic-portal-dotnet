---
name: sigea-mvc5-to-aspnetcore-net10
description: Upgrade ASP.NET MVC 5 (.NET Framework 4.8) and Entity Framework 6 to ASP.NET Core MVC on .NET 10 with EF Core, remediate DOTNET-SQLI-01 and DOTNET-IDOR-01 security vulnerabilities, and configure Managed Identity for Azure SQL Managed Instance and Azure Container Apps
---

# SIGEA Modernization Skill: ASP.NET MVC 5 (.NET 4.8) to ASP.NET Core (.NET 10)

## Overview

This project-level skill guides the GitHub Copilot modernization agent (`modernize`) when upgrading **SIGEA** (`SIGEA.Web` + `SIGEA.Tests`) from classic ASP.NET MVC 5 (.NET Framework 4.8) and Entity Framework 6.4.4 to **ASP.NET Core MVC on .NET 10** (`net10.0`) with **Entity Framework Core 10**, remediating the two intentional lab vulnerabilities (`DOTNET-SQLI-01` and `DOTNET-IDOR-01`), configuring passwordless **Managed Identity** authentication against **Azure SQL Managed Instance**, and containerizing for **Azure Container Apps**.

## Steps

1. **Convert Project Files to SDK-Style (`net10.0`)**:
   - Upgrade `src/SIGEA.Web/SIGEA.Web.csproj` to `Microsoft.NET.Sdk.Web` targeting `net10.0`.
   - Replace `packages.config` with `PackageReference` items (`Microsoft.EntityFrameworkCore.SqlServer`, `Azure.Identity`).
   - Upgrade `src/SIGEA.Tests/SIGEA.Tests.csproj` to `Microsoft.NET.Sdk` targeting `net10.0` with `xunit` and `Microsoft.EntityFrameworkCore.InMemory` / `SqlServer`.

2. **Migrate `SchoolContext` from EF6 to EF Core**:
   - Inject `DbContextOptions<SchoolContext>` via constructor.
   - Configure Table-Per-Hierarchy (TPH) on `Person` using `.HasDiscriminator<string>("Discriminator").HasValue<Student>("Student").HasValue<Instructor>("Instructor")`.
   - Configure the many-to-many join table `CourseAssignment` (`CourseID`, `InstructorID`) and shared-primary-key `OfficeAssignment` (`InstructorID`).

3. **Remediate Intentional Security Vulnerabilities in the Modernized Branch**:
   - **`DOTNET-SQLI-01` (`src/SIGEA.Web/DAL/LabQueries.cs`)**: Replace string concatenation (`"WHERE ... LastName LIKE '%" + term + "%'"`) with a parameterized `SqlCommand` using `cmd.Parameters.Add("@term", SqlDbType.NVarChar, 100).Value = "%" + (term ?? string.Empty) + "%"`.
   - **`DOTNET-IDOR-01` (`src/SIGEA.Web/Controllers/LabController.cs`)**: Enforce object-level ownership check (`if (sid.Value != target) return StatusCode(StatusCodes.Status403Forbidden);`) matching `TranscriptController.Details`.

4. **Configure Managed Identity for Azure SQL Managed Instance**:
   - Configure `appsettings.json` to read `ConnectionStrings:SchoolContext` using `Authentication=Active Directory Managed Identity;User Id=<UAMI_CLIENT_ID>;Encrypt=True;TrustServerCertificate=False;`.
   - Replace `System.Web.HttpContext.Session` with ASP.NET Core `ISession` (`HttpContext.Session.GetInt32` / `SetInt32`).

5. **Containerize for Azure Container Apps**:
   - Create a multi-stage `Dockerfile` using `mcr.microsoft.com/dotnet/sdk:10.0` (build) and `mcr.microsoft.com/dotnet/aspnet:10.0` (runtime) listening on port `8080` as a non-root user.

## Sample Code

### Parameterized Replacement for `DOTNET-SQLI-01`

```csharp
public static string BuildSql() =>
    "SELECT ID, LastName, FirstName, Email, Discriminator " +
    "FROM dbo.Person " +
    "WHERE Discriminator = 'Student' AND LastName LIKE @term " +
    "ORDER BY LastName";

public static List<LabStudentRow> SafeParameterizedSearch(string connectionString, string term)
{
    var rows = new List<LabStudentRow>();
    using var conn = new SqlConnection(connectionString);
    conn.Open();
    using var cmd = new SqlCommand(BuildSql(), conn);
    cmd.Parameters.Add(new SqlParameter("@term", SqlDbType.NVarChar, 100)
    {
        Value = "%" + (term ?? string.Empty).Trim() + "%"
    });
    using var r = cmd.ExecuteReader();
    while (r.Read())
    {
        rows.Add(new LabStudentRow
        {
            ID = r.GetInt32(0),
            LastName = r.IsDBNull(1) ? null : r.GetString(1),
            FirstName = r.IsDBNull(2) ? null : r.GetString(2),
            Email = r.IsDBNull(3) ? null : r.GetString(3),
            Discriminator = r.IsDBNull(4) ? null : r.GetString(4)
        });
    }
    return rows;
}
```

## Verification Checks

- `dotnet build SIGEA.sln -c Release` succeeds with 0 errors.
- `dotnet test SIGEA.sln -c Release` passes all unit, security gate, and parameterized query tests.
- Dashboard counts against the migrated database match baseline (`20` students, `6` instructors, `8` courses, `4` departments, `33` enrollments, total budget `1,015,000.00`, average grade `3.24`, plus the live migration witness student if present).
