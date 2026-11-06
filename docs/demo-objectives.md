# Objetivos de la demostración — SIGEA

SIGEA es el **estado legacy** de partida. Esta demo ejercita cuatro temas de
modernización. Nada de lo siguiente está implementado aquí; se documenta como
destino futuro, sin añadir instrucciones permanentes que impidan a un agente
modernizar o corregir el código después.

## Los cuatro temas

### 1. Modernización agéntica con supervisión técnica
Un agente puede analizar este repositorio (.NET Framework 4.8, MVC 5, EF 6,
`System.Web`, `Web.config`) y proponer cambios revisables: migración a ASP.NET
Core, EF6 → EF Core, `Web.config` → `appsettings.json` + middleware. La línea
base en `functional-baseline.md` permite verificar que cada cambio preserva el
comportamiento.

### 2. Migración de base de datos a servicios administrados
Acoplamientos SQL Server a resolver: `IDENTITY`, tipo `money`,
`IDENTITY_INSERT`, mapeos EF6 (TPH, many-to-many clásico).
**Destino futuro propuesto (no implementado): .NET moderno + Azure SQL Managed
Instance**, preservando el esquema relacional y la semántica de claves.

### 3. Identificación y corrección de vulnerabilidades
Dos defectos intencionales verificables (`DOTNET-SQLI-01`, `DOTNET-IDOR-01`)
con ruta de corrección y criterios de aceptación en `security-labs.md`.
Permiten demostrar el ciclo detectar → explicar impacto → proponer fix →
validar, incluyendo la lección **autenticado ≠ autorizado**.

### 4. Preparación de aplicaciones y datos para futuras capacidades de IA
Datos sintéticos coherentes, diccionario de datos y una línea base estable
sobre la que construir, más adelante, consultas asistidas por IA (ver abajo).

## Destinos futuros (documentados, NO implementados)

| Aspecto | Hoy (legacy) | Destino futuro propuesto |
|---------|--------------|--------------------------|
| Lenguaje/runtime | .NET Framework 4.8, MVC 5 | .NET moderno, ASP.NET Core |
| ORM | Entity Framework 6 | EF Core |
| Base de datos | SQL Server | **Azure SQL Managed Instance** |
| Config/hosting | `Web.config`, IIS | `appsettings.json`, Kestrel/contenedor |

## Ejemplos conceptuales de consultas asistidas por IA (futuro)

> Conceptuales. **No** se implementan agentes ni modelos en este repositorio.
> Cada ejemplo indica su **requisito de autorización**.

1. *"¿Qué estudiantes están en riesgo académico (promedio < 2.5)?"*
   → agregación sobre `Enrollment` por estudiante.
   **Autorización:** rol académico/coordinación; dato sensible, no expuesto al
   propio estudiante sobre terceros.
2. *"Resumen de carga docente por instructor"* → `CourseAssignment` +
   `Enrollment`. **Autorización:** rol administrativo.
3. *"Mi expediente"* → `Enrollment` del estudiante autenticado.
   **Autorización:** el propio estudiante; **nunca** el de otro sin permiso —
   exactamente la comprobación de propiedad que falla en el laboratorio
   `DOTNET-IDOR-01` y que la ruta normal sí aplica.

Toda futura capacidad de IA debe aplicar control de acceso **antes** de
responder: autenticación del solicitante y **autorización por objeto/rol**, no
solo relevancia de la consulta. El laboratorio IDOR existe para que esta
lección sea tangible.
