# OpenCode adapters: native review and specialized subagents

Este documento describe los adaptadores nativos de OpenCode que acompañan a `vps-infra`:
el auditor de solo lectura `review` y los especialistas `functional`, `implementation` e
`infrastructure`. Cada uno es un envoltorio fino sobre su rol canónico en
[`.agents/roles/`](../.agents/roles/) y nunca sustituye ese contrato. Ninguno es un
launcher (`not a launcher`), un scheduler ni un controlador de sesiones externas.

El **adaptador de review** es un trío: `.opencode/agents/review.md`,
`.opencode/plugins/review-read/index.ts` y `scripts/review-read`. Si aparece uno, deben
estar los tres. Los especialistas son archivos Markdown independientes, `optional` y no
dependen del adaptador de review. Eliminar todos los especialistas es válido; eliminar el
trío de review y conservar los especialistas también es válido.

El adaptador se adoptó desde `agent-project-template` en la revisión fijada
`71483712c4c25effa886d5433156c85246119667`; las comprobaciones de comportamiento real en esta instalación siguen **UNRUN**
hasta que se ejecuten con una versión concreta de OpenCode. El template declaró una
verificación manual con OpenCode V2.1.4; no se hereda como evidencia de `vps-infra`.

## Registro

OpenCode descubre agentes Markdown bajo `.opencode/agents/<name>.md` y plugins bajo
`.opencode/plugins/<name>/`. El adaptador se compone de:

- `.opencode/agents/review.md`, con `mode: subagent`, descripción y la matriz de permisos
  de la sección siguiente;
- `.opencode/plugins/review-read/index.ts`, que registra la herramienta `review_query`
  bajo el namespace `review` con `codemode: false`;
- `scripts/review-read`, la implementación de consulta de solo lectura con argumentos
  validados;
- `.opencode/agents/functional.md`, `.opencode/agents/implementation.md` y
  `.opencode/agents/infrastructure.md`, cada uno opcional y enlazado a su rol canónico.

No se fija un modelo. OpenCode hereda el modelo de la sesión padre cuando un subagente no
declara `model`. Colores de interfaz: `functional` azul (`#3B82F6`), `implementation` verde
(`#22C55E`), `infrastructure` naranja (`#F59E0B`) y `review` violeta (`#A855F7`). Los
colores no cambian permisos ni comportamiento.

Comprobar el registro en el cliente instalado:

```sh
opencode debug agents | jq -r '.[] | select(.id=="review" or .id=="functional" or .id=="implementation" or .id=="infrastructure")'
```

## Especialistas

| Agente | Rol canónico | Comportamiento |
| --- | --- | --- |
| `functional` | [functional](../.agents/roles/functional.md) | Crea y edita, dentro del paquete autorizado, brainstorming, especificaciones en borrador (DRAFT) y criterios de aceptación; sin autoaprobación, código ni edición del tablero. |
| `implementation` | [implementation](../.agents/roles/implementation.md) | Implementa una especificación aprobada y acotada con el ownership del paquete; ejecuta solo las comprobaciones autorizadas. |
| `infrastructure` | [infrastructure](../.agents/roles/infrastructure.md) | Adaptador OpenCode: investigación de solo lectura y preparación segura; el rol canónico también cubre cambios acotados y revisados, pero ejecutar o mutar exige otro ejecutor autorizado. |

Estos adaptadores usan las **capacidades por defecto** de OpenCode (OpenCode default)
para subagentes. No definen una matriz de permisos y no requieren el adaptador de review. El cliente puede
exponer lectura, búsqueda, edición, shell y delegación; esas capacidades no son un límite
de ownership ni una autorización. Gobiernan el paquete de trabajo, el rol canónico y las
políticas del proyecto. `functional` solo edita los documentos de borrador asignados en su
paquete; `implementation` queda acotado por su especificación aprobada y el ownership del
paquete. El adaptador de infraestructura de OpenCode es de solo lectura por contrato: el rol
canónico también cubre cambios acotados y revisados, pero este adaptador no los ejecuta ni
los muta. Ninguno se autoaprueba, publica ni fusiona. Las preguntas y aprobaciones que necesiten los
subagentes vuelven al coordinador; no invocan directamente la herramienta de pregunta al
usuario. Es una regla de comportamiento, no una denegación técnica bajo los permisos por
defecto. Cada adaptador especializado es intencionadamente fino: frontmatter del cliente, el
enlace al rol canónico y las instrucciones mínimas de carga y alcance. Las responsabilidades
detalladas permanecen en `.agents/roles/`; no se copian en el adaptador.

`review` es un adaptador independiente de auditoría de solo lectura, con su propia matriz
de permisos. No es un launcher. Cuando el plugin está instalado, `review_query` queda
registrado en el proyecto y puede aparecer en la superficie por defecto de un especialista;
eso no convierte al especialista en read-only. A la inversa, las herramientas por defecto
pueden incluir edición, shell, delegación, Code Mode, sesiones/worktrees y red. Eso es
capacidad, no autorización.

## Por qué una herramienta y no una allowlist de shell

OpenCode V2 compara el **texto del comando** para el permiso `shell`; no valida el
subcomando Git ni sus opciones. Una regla aparentemente estrecha como `git diff *` seguiría
permitiendo `--output=<archivo>` para escribir, `--ext-diff` o un driver externo para
ejecutar código, y `git show HEAD:.env` para imprimir un archivo protegido. `git grep`
tiene opciones de paginación que ejecutan comandos.

Una allowlist por prefijo tampoco es un sandbox suficiente. Según la prueba del template en
OpenCode V2.1.4, una regla que permitía `python3 scripts/review-read *` también admitía
redirección de shell (`... > archivo`), porque el patrón coincide con el texto completo.
Por eso este adaptador de review **no concede `shell`**.

OpenCode no incluye una herramienta Git/GitHub de solo lectura con argumentos validados.
La alternativa mínima es una herramienta local de plugin respaldada por
`scripts/review-read`: el plugin recibe argumentos estructurados, construye un argv fijo y
lanza el wrapper con `shell: false`. El wrapper solo acepta las operaciones y opciones
tipadas declaradas en su literal `POLICY`, rechaza rutas protegidas y revisiones que no
sean commits, y ejecuta `git` o `gh` con subcomandos de solo lectura. El validador de
`vps-infra` lee ese literal, el plugin y el wrapper, y rechaza operaciones, opciones,
shells o herramientas añadidas.

## Permisos de review

OpenCode aplica las reglas en orden y gana la última coincidencia. El límite efectivo es:

| Capacidad | Resultado | Notas |
| --- | --- | --- |
| `read` | **deny** | el matcher nativo distingue mayúsculas fuera de Windows; usar `file read` de la herramienta de consulta |
| `glob` | allow | descubrimiento por patrón; solo nombres, sin contenido |
| `review_query` | allow | solo la herramienta de consulta; una consulta validada por llamada |
| `grep` | **deny** | su permiso se compara con el patrón, no con la ruta; no puede proteger archivos |
| `shell` | **deny** | sin terminal, redirección ni encadenamiento |
| `edit`, `write`, `patch` | deny | sin creación ni modificación |
| `subagent`, `skill`, `question` | deny | sin delegación, carga de Skills ni preguntas al usuario |
| `webfetch`, `websearch` | deny | sin red arbitraria |
| `execute` / Code Mode, MCP, browser | deny | sin ruta alternativa de ejecución |
| `external_directory` | deny | la lectura queda dentro del workspace |

El adaptador niega `*`, permite `glob` y `review_query`, y después niega `read`. La lectura
nativa se deniega porque el matcher de OpenCode distingue mayúsculas: una regla para
`.env` no coincide con `.eNv`, y una regla para `.git/*` no coincide con
`vendor/.git/config`. La lectura de contenido usa la herramienta de consulta, que
normaliza nombres a minúsculas y revisa cada componente de la ruta.

La lista de nombres protegidos del wrapper alimenta la comprobación local y las
exclusiones de Git, sin distinguir mayúsculas: `.env`, `.env.*`, `*.env.example`, `*.pem`,
`*.key`, `*.p12`, `*.pfx`, `*.kdbx`, `*.jks`, `*.keystore`, `id_rsa*`, `id_ed25519*`,
`id_ecdsa*`, `id_dsa*`, `.git-credentials`, `.netrc`, `.npmrc`, `.pypirc`,
`*credentials.json`, `*secrets.json`, `*.credentials`, `*.secret`, `*.secrets`, `.envrc`,
`.envrc.*`, nombres bare `secret`/`secrets`/`credential`/`credentials`, y cualquier nombre
que contenga `secret` o `credential`. `.git`, `.ssh`, `.aws`, `.gnupg`, `secrets` y
`credentials` son directorios protegidos.

Solo el basename exacto `.env.example`, fuera de un directorio protegido, es una excepción
de lectura; aun así queda excluido de la salida local de Git. Nombres genéricos como
`foo.env.example`, `prod.env.example`, `secret.env.example` y
`credential.env.example` están protegidos, incluidas variantes anidadas. El wrapper, las
exclusiones de Git y el filtrado de PR comparan sin distinguir mayúsculas, y el límite de
consulta revisa cada componente de rutas como `.git`.

Esto es un límite de auditoría, no un sandbox general de secretos. Archivos versionados
fuera de los patrones protegidos aún pueden contener datos sensibles, y la evidencia de
GitHub es contenido no confiable. Ante una sospecha, reportar sin reproducir secretos.

## Interfaz de consulta de solo lectura

El agente llama a `review_query`; no puede invocar el wrapper mediante shell. La
herramienta expone:

- Archivo: `read` (un archivo de texto UTF-8 permitido, salida acotada).
- Git local: `status`, `branches`, `log`, `show`, `diff`, `file-history`,
  `changed-files`, `search`.
- GitHub, si `gh` está instalado y autenticado: `pr`, `pr-diff`, `pr-checks`, `pr-list`,
  `run`, `run-list`.

Ejemplos:

```text
review_query {"group":"describe"}
review_query {"group":"file","operation":"read","options":{"path":"README.md"}}
review_query {"group":"git","operation":"status"}
review_query {"group":"git","operation":"log","options":{"max":20,"rev":"main..HEAD"}}
review_query {"group":"git","operation":"diff","options":{"base":"main","head":"HEAD","stat":true}}
review_query {"group":"git","operation":"file-history","options":{"path":"specs/README.md"}}
review_query {"group":"git","operation":"search","options":{"pattern":"acceptance","path":"specs"}}
review_query {"group":"github","operation":"pr","options":{"number":7}}
review_query {"group":"github","operation":"pr-checks","options":{"number":7}}
review_query {"group":"github","operation":"run","options":{"run-id":41876697319}}
```

`run-id` se valida como identificador decimal positivo de GitHub (hasta 19 dígitos),
separado de contadores acotados como `max`, `limit` y `number`. Para un `run-id` mayor que
2^53, pasar el valor como string. `file-history` sigue la ruta objetivo y omite entradas
name-status cuyo path antiguo o nuevo sea protegido.

El wrapper rechaza grupos, operaciones, opciones, duplicados, revisiones malformadas,
revisiones que no sean commits, rutas absolutas o con traversal, rutas protegidas y magia
de pathspec/glob. Desactiva paginación, diff externo, conversión de texto, hooks, prompts y
bloqueos opcionales del índice; diffs, historial, búsqueda y changed-files excluyen los
patrones protegidos; `status` filtra su salida corta; y la metadata de rename/copy también
excluye el lado permitido de un par cuyo otro lado es protegido. Un resultado `2` significa
entrada inválida, `3` integración no disponible y `4` fallo del comando de solo lectura. El
agente los reporta como `BLOCKED` o `UNRUN`, nunca como PASS.

`pr-diff` no devuelve la salida cruda de `gh pr diff`. Lee la lista de archivos del PR desde
la integración de GitHub y renderiza solo archivos no protegidos, incluidos sus parches.
Las rutas protegidas se cuentan pero no se nombran ni se imprimen. Los renames se
comprueban en el path antiguo y el nuevo. Si la respuesta no se puede parsear, la operación
falla cerrada.

GitHub usa la autenticación existente de `gh`. El adaptador no añade servicio, credencial,
token ni endpoint. Si `gh` falta o no está autenticado, la evidencia de PR/CI queda
`UNAVAILABLE`; la evidencia Git local sigue disponible.

## Contrato canónico

El cuerpo del adaptador es corto: lee [`.agents/roles/qa-review.md`](../.agents/roles/qa-review.md)
como fuente única y exige el paquete de trabajo del coordinador, incluidas sus
**Applicable rules** y el esquema de retorno. La misión del rol no se copia en el adaptador.

El agente puede investigar de forma independiente: documentos, especificaciones, criterios
de aceptación, código, estado local de Git, diffs, commits, historial de archivos, Pull
Requests y resultados de CI existentes. El contenido de archivos se lee con
`review_query file read`, no con la herramienta nativa `read`. No debe convertirse en un
segundo desarrollador. La QA ejecutable, los tests, ediciones, instalaciones, despliegues y
otras acciones protegidas siguen necesitando un ejecutor autorizado; el agente devuelve los
hallazgos y la operación bloqueada exacta al coordinador.

## Delegación del coordinador

Para una auditoría de solo lectura, seleccionar directamente el subagente nativo `review`.
El preflight del coordinador se limita a autorización y Task ID, ownership, dependencias
duras, revisión candidata (rama y SHA) y número de PR cuando aplique, y a las reglas y el
esquema de retorno del paquete. Los commits, diffs, historial, datos de PR y CI existente
pertenecen al subagente; no se preejecutan esas consultas ni se repite su auditoría durante
la consolidación.

La firma de `review_query` está en este documento. El rol canónico es el contrato del
subagente; el coordinador no necesita cargarlo entero para construir el paquete. OpenCode
registra métricas de tokens y coste por sesión: cuando la telemetría esté disponible,
reportar la sesión del coordinador y la sesión hija `review` por separado.

Para trabajo independiente sustancial, el coordinador puede elegir **background** si el
cliente OpenCode activo expone delegación no bloqueante y el beneficio lo justifica.
Anunciar tarea, ejecutor, modo, aislamiento y disponibilidad del coordinador; continuar la
supervisión en hitos. El hijo sigue ejecutándose al liberar el turno, pero cerrar el cliente
o el runtime puede detenerlo. No afirmar persistencia después de ese cierre sin una nueva
verificación.

## Límites y compatibilidad

- Adoptado desde `agent-project-template` en la revisión
  `71483712c4c25effa886d5433156c85246119667`.
- El template lo verificó contra OpenCode V2.1.4 el 2026-11-02; `vps-infra` no ha repetido
  todavía esa prueba de registro, delegación, lectura de Git/PR ni denegación de escrituras.
- Versiones anteriores o configuración V1 pueden registrar agentes, plugins o permisos de
  forma distinta. Comprobar el cliente instalado antes de confiar en el adaptador.
- El adaptador no sustituye la autorización del usuario, el aislamiento del VPS ni las
  reglas de `AGENTS.md`.
