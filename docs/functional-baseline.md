# Línea base funcional — SIGEA

Valores verificables tras aplicar `db/schema/01_schema.sql` y
`db/data/02_synthetic_data.sql`. Sirven como referencia para comprobar que una
migración o modernización **preserva el comportamiento**.

> **Verificado el 2026-11-06 contra SQL Server 2022 real** (contenedor
> `mcr.microsoft.com/mssql/server:2022-latest`, loopback). Los conteos y
> agregados de abajo son la salida real de esas consultas.

## Conteos

| Entidad | Valor |
|---------|-------|
| Estudiantes (`Person` Discriminator='Student') | **20** |
| Instructores (Discriminator='Instructor') | **6** |
| Cursos | **8** |
| Departamentos | **4** |
| Matrículas (`Enrollment`) | **33** |
| Matrículas calificadas (Grade no nula) | **30** |

```sql
SELECT COUNT(*) FROM Person WHERE Discriminator='Student';     -- 20
SELECT COUNT(*) FROM Person WHERE Discriminator='Instructor';  -- 6
SELECT COUNT(*) FROM Course;                                   -- 8
SELECT COUNT(*) FROM Department;                               -- 4
SELECT COUNT(*) FROM Enrollment;                               -- 33
SELECT COUNT(Grade) FROM Enrollment;                           -- 30
```

## Agregados monetarios y académicos

| Indicador | Valor |
|-----------|-------|
| Presupuesto total (`SUM(Budget)`) | **1 015 000.00** |
| Promedio de calificación (`AVG(Grade)`) | **3.237** (≈ 3.24) |

```sql
SELECT SUM(Budget) FROM Department;   -- 1015000.00
SELECT AVG(Grade)  FROM Enrollment;   -- 3.2366...
```

## Relaciones comprobables

- Todo `Course.DepartmentID` existe en `Department` (FK).
- Todo `Enrollment.StudentID` apunta a un `Person` con Discriminator='Student'.
- Todo `Enrollment.CourseID` existe en `Course`; `UNIQUE(CourseID, StudentID)`.
- `Department.InstructorID` (administrador) referencia un instructor válido.

## Operaciones CRUD (comportamiento esperado)

| Operación | Efecto esperado |
|-----------|-----------------|
| Alta de estudiante | Nuevo `ID` (identity); conteo de estudiantes +1 |
| Alta de curso | `CourseID` asignado por el usuario (no identity) |
| Matrícula | Nueva fila en `Enrollment`; respeta `UNIQUE(CourseID,StudentID)` |
| Calificación | `UPDATE Enrollment.Grade` (0.00–4.00 o NULL) |
| Alta de departamento | Nuevo `DepartmentID` (identity) con presupuesto |

## Expedientes para el laboratorio IDOR

| Estudiante | ID | Correo | Materias |
|------------|----|--------|---------|
| Ana Mora | 7 | ana.mora@valleclaro.example | 3 |
| Bruno Solís | 8 | bruno.solis@valleclaro.example | 3 |

## Búsqueda (contraste de seguridad)

| Entrada | Ruta normal (parametrizada, LINQ) | Ruta lab (vulnerable, SqlCommand) |
|---------|-----------------------------------|------------------------------------|
| `mora` | 2 estudiantes | 2 filas |
| `x%' OR '1'='1' --` | 0 (texto literal) | **26** (filtro anulado; verificado) |

## Bloqueos de verificación (honesto)

- ✅ **Base de datos:** esquema, datos, agregados, cuenta de solo lectura y
  comportamiento del payload SQLi **ejecutados y verificados** contra SQL
  Server 2022 real.
- ⚠️ **Aplicación .NET:** **no compilada ni ejecutada** en el entorno de
  construcción (Linux sin .NET Framework 4.8 / MSBuild / IIS). El código fuente
  está completo y listo para compilarse en Windows. Las pruebas `SIGEA.Tests`
  **no fueron ejecutadas**; requieren un build en Windows. No se declara
  ninguna prueba .NET como exitosa.
