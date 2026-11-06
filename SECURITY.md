# Seguridad — SIGEA

## Este repositorio contiene vulnerabilidades INTENCIONALES

SIGEA es un **laboratorio de seguridad local**. Incluye, a propósito, defectos
de seguridad pequeños y verificables para que herramientas de análisis y
agentes de modernización puedan **encontrarlos, explicar su impacto y proponer
la corrección**.

**No es una plantilla de producción.** No lo despliegue en Internet ni lo use
como base de un sistema real sin corregir primero los defectos documentados.

## Condiciones del laboratorio

- Las rutas vulnerables se habilitan **exclusivamente** con el appSetting
  `ENABLE_VULNERABILITY_LABS=true`. El valor por defecto es **`false`**.
- No basta el nombre del entorno: además del flag, cada petición a `/Lab/**`
  debe llegar por **loopback** (`Request.IsLocal`); en caso contrario el
  atributo `[LabOnly]` devuelve **404**.
- Con el modo deshabilitado, todas las acciones del laboratorio devuelven
  **404** y no aparecen en el menú.
- Solo se usan **datasets sintéticos**. El laboratorio de SQL-injection usa una
  conexión **de solo lectura** separada (`sigea_labro`), con permisos mínimos.
- **No** se usa `sa` como cuenta de ejecución (solo provisiona, como un DBA).
- **No** hay conexiones a sistemas externos, credenciales reales ni scripts que
  publiquen la aplicación en Internet.
- Las pantallas normales son funcionales y están **separadas** de los
  ejercicios (p. ej. la búsqueda normal de estudiantes es parametrizada; el
  expediente normal verifica propiedad).

Cuando el laboratorio está activo se muestra una banda visible:
**“Laboratorio vulnerable activo · Datos ficticios”**.

## Vulnerabilidades incluidas

| ID | Categoría | CWE | Archivo principal |
|----|-----------|-----|-------------------|
| `DOTNET-SQLI-01` | Inyección SQL (concatenación + `SqlCommand`) | CWE-89 | `src/SIGEA.Web/DAL/LabQueries.cs` |
| `DOTNET-IDOR-01` | Falta de autorización por objeto (IDOR) | CWE-639 / CWE-285 | `src/SIGEA.Web/Controllers/LabController.cs` (acción `Transcript`) |

El detalle completo (reproducción, causa raíz, impacto, corrección esperada y
criterio de aceptación) está en [docs/security-labs.md](docs/security-labs.md).

## Distinción importante

- **Tecnología antigua** — .NET Framework 4.8, MVC 5, EF 6. Es la línea base
  legacy a propósito; no es por sí misma una vulnerabilidad.
- **Tecnología fuera de soporte** — depende de la fecha; se documenta como
  consideración de modernización, no como CVE.
- **Vulnerabilidad conocida verificada (CVE)** — **no** se atribuye ningún CVE
  a ningún componente de este repositorio; no se verificó versión + componente
  afectados. No se añaden librerías vulnerables innecesarias.
- **Vulnerabilidad educativa introducida aquí** — los dos casos `SECURITY-LAB`
  anteriores, marcados en el código.

## Declaración sobre herramientas

Ninguna afirmación de este repositorio dice que una herramienta automática
detectó un problema. Los defectos están documentados porque fueron
**introducidos deliberadamente** por los autores.
