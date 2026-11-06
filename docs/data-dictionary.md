# Diccionario de datos — SIGEA

Esquema SQL Server `dbo` (base `SIGEA`). Todos los datos son sintéticos.

## Person  (Table-Per-Hierarchy)
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `ID` | `INT IDENTITY` | NO | PK |
| `LastName` | `NVARCHAR(50)` | NO | Apellidos |
| `FirstName` | `NVARCHAR(50)` | NO | Nombre |
| `Discriminator` | `NVARCHAR(20)` | NO | `'Student'` \| `'Instructor'` (CHECK) |
| `EnrollmentDate` | `DATETIME` | SÍ | Solo estudiantes |
| `HireDate` | `DATETIME` | SÍ | Solo instructores |
| `Email` | `NVARCHAR(100)` | SÍ | Correo |

## Department
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `DepartmentID` | `INT IDENTITY` | NO | PK |
| `Name` | `NVARCHAR(50)` | NO | Nombre |
| `Budget` | `MONEY` | NO | Presupuesto (CHECK ≥ 0) |
| `StartDate` | `DATETIME` | NO | Inicio |
| `InstructorID` | `INT` | SÍ | FK → `Person` (administrador) |

## Course
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `CourseID` | `INT` | NO | PK **asignada** (no identity) |
| `Title` | `NVARCHAR(100)` | NO | Título |
| `Credits` | `INT` | NO | CHECK 1–6 |
| `DepartmentID` | `INT` | NO | FK → `Department` |

## Enrollment
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EnrollmentID` | `INT IDENTITY` | NO | PK |
| `CourseID` | `INT` | NO | FK → `Course` |
| `StudentID` | `INT` | NO | FK → `Person` |
| `Grade` | `DECIMAL(3,2)` | SÍ | GPA 0.00–4.00 (NULL = sin calificar); CHECK |
| | | | `UNIQUE(CourseID, StudentID)` |

## OfficeAssignment
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `InstructorID` | `INT` | NO | PK y FK → `Person` |
| `Location` | `NVARCHAR(50)` | NO | Oficina |

## CourseAssignment  (many-to-many instructor ↔ curso)
| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `CourseID` | `INT` | NO | PK compuesta, FK → `Course` |
| `InstructorID` | `INT` | NO | PK compuesta, FK → `Person` |

## Relaciones (resumen)

```
Department 1───* Course *───* Instructor(Person)      (CourseAssignment)
     │                │
     │ (admin)        *
  Person(Instructor)  Enrollment *───1 Student(Person)
     │
  OfficeAssignment (1:0..1)
```

## Entidades ↔ modelo ContosoUniversity

`Person` (TPH `Student`/`Instructor`), `Course`, `Department`, `Enrollment`
se conservan como en el ejemplo de referencia; `OfficeAssignment` y
`CourseAssignment` enriquecen la gestión de instructores.
