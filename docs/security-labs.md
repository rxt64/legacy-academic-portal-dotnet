# Ejercicios de seguridad — SIGEA

Laboratorio **local** con vulnerabilidades intencionales sobre datos
sintéticos. Activación: `ENABLE_VULNERABILITY_LABS=true` en `Web.config` **y**
acceso por loopback. Con el flag en `false` (por defecto) las rutas `/Lab/**`
devuelven 404. Cada caso está marcado en el código con
`SECURITY-LAB: <ID> — vulnerabilidad intencional para demostración local`.

---

## DOTNET-SQLI-01 — Inyección SQL

- **Categoría / CWE:** Inyección SQL · **CWE-89**
- **Archivo y método:** `src/SIGEA.Web/DAL/LabQueries.cs`,
  `BuildSql(string)` y `VulnerableSearch(string)`
- **Endpoint:** `GET /Lab/Sqli?term=...` (`LabController.Sqli`, con `[LabOnly]`)
- **Cuenta de BD:** `sigea_labro`, **solo lectura** (SELECT en `Person`,
  `Enrollment`, `Course`), vía la conexión separada `LabReadOnlyContext`.

### Requisitos para activarlo
`ENABLE_VULNERABILITY_LABS=true`, acceso por loopback, base local provista.

### Entrada controlada por el usuario → construcción → punto de llegada
1. **Entrada:** el parámetro `term` (campo "Apellido contiene").
2. **Construcción:** en `BuildSql`, `term` se **concatena** en el `LIKE`:
   ```csharp
   "... WHERE Discriminator = 'Student' AND LastName LIKE '%" + term + "%' ..."
   ```
3. **Llegada a SQL Server:** en `VulnerableSearch`, la cadena se ejecuta con un
   `System.Data.SqlClient.SqlCommand` (`cmd.ExecuteReader()`), sin parámetros.

### Reproducción local inocua
1. Buscar `mora` → **2 filas** (apellidos con "mora").
2. Buscar `x%' OR '1'='1' --` → el filtro se subvierte y devuelve **todas las
   filas de Person (26)**, incluidos instructores: la precedencia de `AND`/`OR`
   convierte el `WHERE` en `(... AND LastName LIKE '%x%') OR ('1'='1')`. La
   página muestra el SQL exacto enviado.

**Resultado observable:** el conteo salta de 2 a 26; el filtro por apellido (y
por `Discriminator`) queda anulado. Sin modificar datos (cuenta de solo
lectura; verificado: `UPDATE` → *The UPDATE permission was denied*).

> Verificado contra SQL Server 2022 real el 2026-11-06: `mora` → 2;
> `x%' OR '1'='1' --` → 26; `UPDATE` como `sigea_labro` → permiso denegado.

### Causa raíz
Concatenación de entrada no confiable en el texto SQL y uso de `SqlCommand`
sin parámetros.

### Impacto conceptual
El atacante altera la lógica del filtro y lee filas no previstas. Acotado aquí
a lectura de datos sintéticos por la cuenta de permisos mínimos.

### Corrección recomendada (futura, **no aplicada** en el caso vulnerable)
Parametrizar con `SqlParameter`/`@term` (o LINQ, como la búsqueda normal en
`StudentsController.Index`). DO NOT fix in place: es el estado "antes".

### Criterio de aceptación de la corrección
- La búsqueda usa parámetros; `term` nunca se concatena.
- Con `term = x%' OR '1'='1' --` el resultado es el mismo conjunto que para un
  apellido que no existe (0 filas), tratando el texto como literal.

---

## DOTNET-IDOR-01 — Falta de autorización por objeto

- **Categoría / CWE:** Referencia directa insegura a objeto / autorización
  ausente · **CWE-639 / CWE-285**
- **Archivos:** ruta vulnerable `src/SIGEA.Web/Controllers/LabController.cs`
  (acción `Transcript`); ruta normal correcta
  `src/SIGEA.Web/Controllers/TranscriptController.cs` (acción `Details`).
  Identidad de sesión en `Infrastructure/SessionUser.cs`.
- **Endpoints:** `GET /Lab/Transcript?id=...` (vulnerable, `[LabOnly]`) vs
  `GET /Transcript/Details/{id}` y `GET /Transcript/Mine` (normales).

### Requisitos para activarlo
`ENABLE_VULNERABILITY_LABS=true`, loopback, y **una sesión autenticada** de
estudiante (iniciar sesión en *Mi expediente* con el correo de un estudiante
ficticio).

### Dos cuentas ficticias
- `ana.mora@valleclaro.example` → estudiante **#7** (3 materias)
- `bruno.solis@valleclaro.example` → estudiante **#8** (3 materias)

### Demostración
1. Inicie sesión como **Ana** (`ana.mora@valleclaro.example`). La identidad
   (ID 7) queda en la **sesión**, no en un parámetro.
2. Abra `/Lab/Transcript?id=7` → expediente de Ana (correcto).
3. Cambie a `/Lab/Transcript?id=8` → **se muestra el expediente de Bruno** aun
   estando autenticado como Ana: la ruta de laboratorio **no** verifica que el
   expediente solicitado pertenezca al usuario de la sesión.
4. Contraste: `/Transcript/Details/8` estando autenticado como Ana devuelve
   **403** (la ruta normal verifica propiedad).

**Resultado observable:** acceso de un estudiante al expediente sintético de
otro cambiando el identificador, solo en la ruta de laboratorio.

### Autenticado vs autorizado
Estar **autenticado** (hay una sesión válida) no implica estar **autorizado**
para un objeto concreto. La identidad se toma de la sesión (no manipulable por
query string), pero falta la comprobación de **propiedad** del recurso. Esa
comprobación de autorización por objeto es exactamente lo que hace la ruta
normal y omite la de laboratorio.

### Causa raíz
Ausencia de verificación de propiedad/permiso sobre el objeto solicitado
(`id` de expediente) frente a la identidad autenticada.

### Corrección recomendada (futura)
Comprobar que `id == sesión.StudentID` (o aplicar una política de autorización)
antes de devolver el expediente, como en `TranscriptController.Details`.

### Criterio de aceptación de la corrección
- Autenticado como el estudiante 7, solicitar el expediente 8 devuelve 403/404.
- El estudiante solo puede ver su propio expediente.

---

## Pruebas

Tres grupos separados (proyecto `SIGEA.Tests`, xUnit):

1. **Funcionales normales** — `IntegrationTests` (grupo 1): conteos de la línea
   base y propiedad del expediente. Requieren base local (`SIGEA_IT=1`).
2. **Labs deshabilitados por defecto** — `LabGateTests`, `LabOnlyAttributeTests`
   (grupo 2, offline): sin el flag no hay rutas de laboratorio (404); el gate
   exige flag **y** loopback.
3. **Caracterización del comportamiento vulnerable (opcional)** —
   `LabQueriesSqlTests` (grupo 3, offline, nivel de cadena): confirma la
   concatenación. No afirma que la aplicación sea segura.

> Que una prueba confirme que la vulnerabilidad existe **no** marca la
> aplicación como segura. Las pruebas de laboratorio solo deben ejecutarse
> contra instancias locales creadas para este repositorio.

### Estado de ejecución (honesto)

- **Esquema y datos SQL Server:** ejecutados y verificados contra SQL Server
  2022 real (conteos, agregados, comportamiento de la cuenta de solo lectura y
  del payload SQLi). Ver `docs/functional-baseline.md`.
- **Código .NET y pruebas xUnit:** **no ejecutados** en el entorno de
  construcción (Linux sin .NET Framework/MSBuild). Requieren un build en
  Windows. No se declara ninguna prueba .NET como ejecutada.
