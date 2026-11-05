# Contrato de despliegue por tags · Diseño, sin activación

> **Estado:** revisado y asumido por `vps-infra` el **2026-11-05** como diseño. **No
> implementado, no habilitado y no ejecutado.** No autoriza acceso al VPS, cambios de usuarios, rutas,
> servicios, Caddy, DNS, UFW, Podman/Quadlet, copias, credenciales ni despliegues.
> Cualquier fase de este contrato exige autorización propia e identificable.

Este documento define la parte de `vps-infra` del mecanismo de despliegue mediante tags de
GitHub. La aplicación posee la convención de tags, la construcción y verificación de la
release, la promoción y la aceptación; este repositorio posee el contrato seguro para
**recibir y activar** una release ya verificada, el aislamiento entre entornos, los
privilegios, las rutas, los servicios, las copias y la recuperación.

No repite la especificación del host TEST
([PR #9](https://github.com/jmartinlabs/vps-infra/pull/9), MERGED en `901204c`; la spec
conserva estado DRAFT/pendiente de aprobación), el contrato de integración de esquema/seed
([SPEC34 §5](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md#5-contrato-de-despliegue-con-vps-infra-solo-interfaz))
ni el runbook de la aplicación. Cuando se solapen, prevalece el documento propietario de cada
materia y este contrato solo añade la interfaz de activación.

## 1. Estado de partida y límites de las afirmaciones

- `[CONFIRMADO]` El VPS no tiene MyFinanzas desplegada. El contenido del sitio raíz figura
  como página estática informada, no verificada por completo; no se ha accedido al VPS para
  este documento. No hay rama `test` en `myfinanzas-app` y el flujo vigente es
  `feature/* → main`.
- `[CONFIRMADO]` La release de la aplicación es un paquete privado con `image.oci.tar`,
  `frontend/`, `manifest.json` y `manifest.sha256`; se selecciona por ID/digest inmutable,
  nunca por etiqueta móvil. La aplicación no publica ese paquete como artifact de CI.
- `[CONFIRMADO]` El host TEST y sus puertos están en
  [`specs/02-infra-test-01-host-specification.md`](../specs/02-infra-test-01-host-specification.md),
  integrada por el PR #9 (`901204c`). La spec conserva estado DRAFT/pendiente de aprobación;
  este documento **no** la modifica ni declara TEST operativo.
- `[CONFIRMADO]` El PR #9 describe el despliegue TEST como manual. Este contrato prepara la
  activación automática **solo cuando el sistema se habilite expresamente**; mientras no se
  habilite, el procedimiento manual y sus gates siguen vigentes. La habilitación sustituirá
  únicamente el disparador, no los controles de host, copia, recuperación o autorización.
- `[PENDIENTE]` No se ha accedido al VPS para este diseño. No se han creado usuarios,
  directorios, unidades, credenciales, reglas de Caddy ni copias.

## 2. Frontera con `myfinanzas-app`

| Materia | `myfinanzas-app` | `vps-infra` |
| --- | --- | --- |
| Tag, origen y autor | Convención, validación, workflows y registro de la ejecución | Comprueba el contrato recibido; no gestiona tags ni ramas |
| Release | Construcción, manifiesto, checksums, ID/digest y promoción | No reconstruye, no parchea y no sustituye el artefacto |
| Esquema y seed | Contrato de esquema por SHA, manifiesto de seed TEST | Comprueba compatibilidad declarada antes de abrir estado; no migra por iniciativa propia |
| Host | Declara el entorno, el smoke esperado y la evidencia | Activa, aísla, copia, verifica y devuelve el resultado |
| Copias | Política de la aplicación y CLI de copia/restauración | Ejecuta la copia del host, custodia local/externa y ensaya la restauración |
| Aceptación | Funcional y de release | Operativa del host y de la activación |

La aplicación entrega un **contrato de despliegue** por ejecución. El host lo valida de nuevo
y falla cerrado; no confía en un mensaje del workflow sin verificar el artefacto y el estado
real.

## 3. Entrada y salida del contrato

### 3.1 Entrada mínima desde la aplicación

| Campo | Regla |
| --- | --- |
| `environment` | Exactamente `test` o `prod`; no se infiere del nombre del host ni del tag |
| `version` | SemVer completo, idéntico al tag y al contrato de despliegue. `[PENDIENTE]` El manifiesto actual de `release.py` no declara versión de aplicación; D2/D3 fijan el campo o su derivación |
| `tag` | `deploy-test-v<semver>` o `deploy-prod-v<semver>`; tag inmutable |
| `release_sha` | SHA de 40 caracteres del commit construido; ancestro del origen autorizado |
| `release_manifest_sha256` | SHA-256 del manifiesto de release verificado |
| `image_id` / digest OCI | ID inmutable; nunca una etiqueta mutable |
| `frontend_sha256` / `frontend_files` | `[PENDIENTE]` El manifiesto actual publica un mapa `frontend_files` ruta→SHA-256, no un único checksum; D2/D3 o una decisión específica del manifiesto fijan el checksum determinista del conjunto o el campo equivalente |
| `schema_version` / `schema_contract` | Contrato declarado por el código de ese SHA |
| `seed_manifest_sha256` | Solo TEST; manifiesto del dataset ficticio. `[PENDIENTE]` D11 debe reconciliar el seed con el SHA y el esquema |
| `qa_reference` | Referencia a la QA independiente del SHA, sin secretos |
| `ci_run_id` / `rootless_run_id` | Ejecuciones asociadas al SHA exacto y su resultado |
| `approval_reference` | Solo PROD; Environment `production`, ejecución, revisor, SHA y versión que autoriza la activación |
| `backup_plan` / `rollback_pair` | Copia previa exigida y par exacto de vuelta atrás |
| `smoke_profile` | Conjunto fijo de comprobaciones y valores esperados no secretos |

Los campos que contengan rutas, identificadores de ejecución o referencias de evidencia no
son secretos. Nunca se envían contraseñas, TOTP, claves `age`, cookies, bases de datos ni
contenido financiero. Los campos marcados `[PENDIENTE]` se cierran en la Fase 1 junto con
D2/D3/D11 de la especificación de la aplicación; el host no los inventa ni los deduce de
texto libre.

### 3.2 Salida del host

| Campo | Contenido |
| --- | --- |
| `deployment_id` | Entorno + versión + intento; único e inmutable |
| `result` | `success`, `failed` o `blocked_before_mutation` |
| `activated_release` | SHA, manifiesto y digest realmente activados |
| `previous_release` | Par exacto conservado para recuperación |
| `backup_id` | Copia creada o referencia de la copia previa verificada |
| `smoke_results` | Comprobaciones ejecutadas, resultado y hora, sin secretos |
| `rollback_status` | `not_needed`, `available`, `blocked` o `executed` |
| `evidence_location` | Ruta privada del expediente; no se publica en Git |

El resultado se devuelve a la aplicación y se conserva en el run de GitHub y en el expediente
privado existente. No se crea un registro público paralelo ni se copian estados del tablero.

## 4. Precondiciones de activación

Antes de modificar el VPS, el host comprueba y registra:

1. **Entorno y tag.** El tag y el entorno coinciden; no hay otro despliegue activo en ese
   entorno. Un tag de TEST no puede activar PROD.
2. **Origen.** El SHA es de 40 caracteres, el commit es ancestro del origen autorizado
   (`main` hoy; la política futura se define en §8) y el tag no apunta a una rama corta,
   un merge ref ni un commit ajeno.
3. **Evidencia de la aplicación.** CI requerida y gate Rootless constan `SUCCESS` para el
   SHA exacto. La referencia de QA está presente y es revisable; el host no la sustituye.
4. **Artefacto.** El paquete existe, su manifiesto y checksums verifican, el commit esperado
   coincide y el digest es inmutable. Si no coincide, se detiene; no se reconstruye.
5. **Promoción PROD.** Para `prod`, la versión, el SHA y el digest coinciden exactamente con
   los que superaron TEST y su smoke; si falta la evidencia o el artefacto es distinto, se
   detiene. TEST no requiere este paso.
6. **Aprobación PROD.** Para `prod`, existe una aprobación verificable del Environment
   `production` (run, revisor, SHA y versión) antes de liberar credenciales o activar. TEST
   no requiere esta aprobación; su habilitación es el interruptor de DEP5 (§9).
7. **Esquema y datos.** El contrato de esquema del manifiesto es compatible con el estado o
   con la migración expresamente autorizada. TEST exige su marcador y seed verificados; PROD
   exige la autorización de datos reales y la copia previa.
8. **Copia y recuperación.** Existe una copia válida y una restauración ensayada según la
   política aplicable. Sin copia o sin plan de recuperación no se activa.
9. **Host.** Usuario, rutas, permisos, unidad, loopback, Caddy, DNS, disco, memoria y puertos
   están en el estado esperado. Cualquier desviación detiene el proceso antes de mutar.
10. **Capacidad.** Hay espacio para release, copia y margen operativo; los límites del
    contenedor y del host siguen vigentes.

La comprobación previa es de solo lectura. Un fallo de validación produce
`blocked_before_mutation` y no cambia servicios, datos, Caddy, DNS ni firewall.

## 5. Secuencia de activación

La secuencia detallada de parada, copia, cambio de unidad y arranque pertenece al runbook de
la aplicación y al host TEST; este contrato fija el orden y las condiciones de la interfaz.

1. **Reservar el entorno.** Adquirir el bloqueo exclusivo del entorno y registrar
   `deployment_id`. Si ya hay uno activo, rechazar sin tocar el host.
2. **Preflight sin mutación.** Ejecutar §4 completa y registrar el resultado.
3. **Preparar la release.** Materializar el paquete verificado en una ruta **nueva** e
   inmutable, identificada por versión, SHA y digest. Nunca sobrescribir la release anterior.
4. **Copia previa.** Si existe estado, crear la copia cifrada conforme a la política y
   verificar su integridad. No se copia una base activa por separado de WAL/SHM.
5. **Mantenimiento.** Impedir tráfico y detener/verificar el escritor anterior antes de las
   tareas offline. No abrir dos versiones sobre el mismo estado.
6. **Activar.** Cambiar backend y frontend como conjunto, usando la ruta/ID inmutable y la
   unidad revisada. No se mezcla un frontend de otra release ni se usa una etiqueta móvil.
7. **Smoke.** Ejecutar el perfil acordado: salud, ruta protegida sin sesión, autenticación
   cuando el perfil lo permita, lectura/escritura sintética y frontend. En TEST, además,
   `seed verify` y ausencia de datos ajenos. Registrar resultados.
8. **Cerrar o detener.** Si todo pasa, registrar `success`, conservar la release anterior y
   liberar el bloqueo. Si falla, detenerse, preservar estado, copia, logs y artefactos, y
   aplicar el procedimiento de recuperación autorizado.

El mecanismo exacto de activación —unidad nueva, drop-in o enlace atómico— se decidirá tras
la auditoría del host. Cualquiera de ellos debe ser revisable, reversible y no sobrescribir
la release anterior.

### 5.1 Fallos y recuperación

- Un fallo de validación **antes** de mutar no autoriza reparaciones automáticas.
- Un fallo **después** de activar no se oculta con un reintento ciego: se preserva el estado y
  se sigue el runbook. No se restaura automáticamente una copia ni se revierten migraciones a
  la fuerza.
- El rollback solo procede al par exacto con prueba cruzada reproducible. La coincidencia de
  `schema_version` o el nombre de un contrato no son prueba suficiente.
- Si la release, el manifiesto, el esquema, la copia o la autenticación no son compatibles, se
  bloquea antes de abrir la base y se solicita decisión.
- Un error de validación nunca debe dejar el VPS en un estado parcialmente modificado.

## 6. Aislamiento TEST / PROD

`[PROPUESTA]` Los dos entornos deben separar, como mínimo:

| Elemento | TEST | PROD |
| --- | --- | --- |
| Identidad de ejecución | Usuario/UID propio o unidad claramente separada | Usuario/UID propio o unidad claramente separada |
| Unidad y release | Unidad TEST independiente | Unidad PROD independiente |
| Raíz de datos | Raíz TEST 0700, solo datos ficticios | Raíz PROD 0700, datos reales solo con autorización |
| Copias | Raíz TEST y destino externo aprobado | Raíz PROD y destino externo aprobado |
| Loopback | `127.0.0.1:18082` (contrato TEST) | `127.0.0.1:18081` (contrato PROD) |
| Caddy / DNS | Sitio y registro TEST | Sitio y registro de producción |
| Credenciales | Credenciales TEST | Credenciales PROD, distintas |
| Logs | Retención y acceso TEST | Retención y acceso PROD |

No se comparten sockets, volúmenes, claves, cookies, bases ni credenciales entre entornos.
Caddy solo publica HTTPS y enruta a loopback; no se exponen API, SQLite, Vite ni puertos
internos. La creación de usuarios adicionales, si se decide, exige autorización y auditoría
del host; el estado actual solo tiene `mfadmin`.

TEST usa exclusivamente datos ficticios y el seed test-only. PROD no importa el seed ni el
Excel sin una autorización específica y la validación financiera correspondiente.

## 7. Seguridad operativa

- **Credenciales.** Un principal por entorno, de mínimos privilegios, sin root y sin reutilizar
  la clave de administración. Los secretos viven en el entorno protegido o en un almacén
  autorizado, nunca en Git, en la release ni en los logs. Rotación y revocación definidas.
- **Ejecución.** El mecanismo de ejecución (runner dedicado, SSH restringido u otro) debe
  impedir comandos arbitrarios, limitar el destino y no conceder más privilegios que los de
  activación. Se decide con el modelo de amenaza y la auditoría del host.
- **Tags y artefactos.** La protección de tags y la inmutabilidad del artefacto se verifican
  antes de confiar en ellos. El host no reconstruye ni sustituye un artefacto aprobado.
- **Concurrencia.** Un solo despliegue activo por entorno; el segundo se rechaza. El bloqueo
  se libera al terminar, con éxito o fallo.
- **Copia y recuperación.** No hay despliegue sin copia válida y plan de recuperación. PROD
  con datos reales sigue sujeto a DT6/T-BKP de MyFinanzas y a la autorización de operación.
- **Auditoría.** Se registran tag, actor, SHA, digest, aprobación, ejecución, copia, smoke y
  resultado. Los logs no contienen secretos ni datos financieros.
- **Fallo cerrado.** Permisos, esquema, artefacto, copia o smoke desconocidos bloquean; no se
  convierten en un éxito por ausencia de error.

## 8. Estrategia de ramas y origen de tags

`[CONFIRMADO]` Se mantiene `feature/* → main`. Los tags apuntan a commits concretos de
`main`; no se crea una rama `test` en esta entrega.

`[PROPUESTA]` Si en el futuro se adopta `feature/* → test → main`, solo cambiará la política
de origen de los tags: TEST podrá consumir commits del origen de integración y PROD deberá
consumir commits promovidos a `main`. La convención, la inmutabilidad y los controles de
artefacto no cambian. Cualquier adopción exige actualizar este documento y la política de
tags; no se infiere de una propuesta abierta.

## 9. Decisiones pendientes antes de implementar

Se usa la nomenclatura **DEP1–DEP10** (*deployment*) para no colisionar con las decisiones
**H1–H6** de la especificación host de TEST ni con los identificadores **DT** de MyFinanzas.

| ID | Decisión | Recomendación | Bloquea |
| --- | --- | --- | --- |
| DEP1 | ¿Usuarios/UID separados por entorno o una identidad con unidades aisladas? | Separar identidad si la auditoría y la operación lo permiten; no asumirlo | Fase 2 |
| DEP2 | Transporte y almacenamiento privado de la release | Almacén privado direccionado por digest, con manifiesto y retención acordada; sin reconstruir en PROD | Fase 1 |
| DEP3 | Mecanismo de activación (unidad nueva, drop-in o enlace atómico) | Elegir tras auditar Quadlet y demostrar reversibilidad | Fase 2 |
| DEP4 | Principal y vía de ejecución (runner dedicado, SSH restringido u otro) | Mínimos privilegios, sin root, sin comandos arbitrarios; revisar el modelo de amenaza | Fase 2 |
| DEP5 | ¿TEST automático o manual al habilitar? | Automático solo tras los gates, con interruptor explícito y estado inicial desactivado | Fase 4 |
| DEP6 | Revisores de PROD y separación de funciones | Required reviewers; el autor del tag no aprueba su propia ejecución | Fase 5 |
| DEP7 | Destino externo, retención, RPO/RTO y custodia | Política única aprobada; simulacro de restauración antes de PROD | Fases 4–5 |
| DEP8 | Cambios de Caddy/DNS para TEST | Aplicar el contrato de la spec 02 del host TEST (en `main`) solo con autorización; no tocar el sitio raíz | Fase 4 |
| DEP9 | Rollback automático o manual | Manual y con evidencia; sin restauración automática silenciosa | Fases 4–5 |
| DEP10 | Adopción futura de `test` como rama de integración | Solo si se decide; actualizar únicamente la política de origen de tags | Futuro |

## 10. Fases propuestas

| Fase | Objetivo | Salida | Autorización |
| --- | --- | --- | --- |
| 0 | Documentar y revisar este contrato | PR revisada; sin cambios operativos | Actual |
| 1 | Resolver DEP1–DEP10 y cerrar la interfaz con la aplicación | Decisiones registradas; sin VPS | Separada |
| 2 | Preparar host e identidades, rutas, unidades y copias de ensayo | Evidencia de preflight; sin release real | Separada |
| 3 | Dry-run del contrato con artefactos de ensayo y sin datos reales | Checks negativos y positivos; VPS intacto | Separada |
| 4 | Habilitar TEST y ejecutar el primer tag de TEST | Smoke, copia y evidencia; PROD intacto | Separada |
| 5 | Habilitar PROD tras backup/restore, aceptación y revisores | Primer despliegue aprobado y verificado | Separada |
| 6 | Revisar la política de ramas si se adopta `test` | Solo cambia el origen de tags | Separada |

Ninguna fase se deduce de otra. Un merge documental no habilita la siguiente.

## 11. Fuera de alcance de este documento

- Crear tags operativos, moverlos, sobrescribirlos, borrarlos o reutilizarlos; activar
  workflows de despliegue.
- Configurar credenciales, accesos SSH, runners o secretos.
- Cambiar usuarios, rutas, servicios, Caddy, DNS, UFW, Podman/Quadlet o firewall.
- Desplegar, actualizar, restaurar, reiniciar o retirar nada en el VPS.
- Promocionar TEST a PROD, importar datos reales o aprobar merges.
- Sustituir la spec del host TEST, el runbook de la aplicación o sus gates.

## 12. Referencias

- [Arquitectura de la plataforma](arquitectura.md)
- [Operaciones y recuperación](operaciones.md)
- [Roadmap](roadmap.md)
- [Estado actual](estado-actual.md)
- [Host TEST (PR #9, MERGED `901204c`; spec DRAFT)](https://github.com/jmartinlabs/vps-infra/blob/main/specs/02-infra-test-01-host-specification.md)
- `myfinanzas-app`: especificación `DEPLOY-TAGS-01`, mantenida en su repositorio.
