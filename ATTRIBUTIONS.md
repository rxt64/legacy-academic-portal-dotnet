# Attributions

This repository (SIGEA) is original work released under the MIT License (see
`LICENSE`). It was written from scratch for a modernization and security lab.
No private source, no private Git history, and no code of unknown provenance
were copied in.

## Design inspiration (not copied)

- **Microsoft "Contoso University" sample** — The domain model of this lab
  (the `Person` Table-Per-Hierarchy with `Student`/`Instructor`, plus
  `Department`, `Course`, `Enrollment`, `OfficeAssignment` and the
  instructor/course many-to-many) follows the shape of Microsoft's well-known
  Contoso University ASP.NET MVC / EF tutorial, whose sample code Microsoft
  publishes under the MIT License. The entity *names and relationships* are
  recognisable on purpose, but the schema scripts, seed data, controllers,
  views, styling and the security-lab code here were authored for this
  project. **All data is fictitious and original.** No files from the
  Microsoft sample were copied.

  A future modernization effort is free to restructure or replace any of this.

## Third-party runtime dependencies

Resolved at build time by NuGet (packages.config); not redistributed here:

- Microsoft ASP.NET MVC 5, Razor, WebPages, Web Optimization (Apache-2.0 / MS)
- Entity Framework 6.4.4 (Apache License 2.0 / MIT)
- Newtonsoft.Json (MIT), bootstrap (MIT), jQuery (MIT)
- xUnit, Moq, Xunit.SkippableFact (test-only; Apache-2.0 / BSD / MIT / MS-PL)

No third-party binaries or images are distributed in this repository.
