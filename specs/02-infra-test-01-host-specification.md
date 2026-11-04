# 02 — INFRA-TEST-01-HOST: host del entorno TEST de MyFinanzas — Specification

Status: **DRAFT — pendiente de revisión y aprobación.** No autoriza DEV, acceso al VPS, DNS,
Caddy, UFW, Podman/Quadlet, despliegue, datos reales ni merge.
Approval source/date: PENDING
Context and brainstorming: packet de coordinación `INFRA-TEST-01-HOST` (2026-11-04); sin
brainstorming separado.
Base: `vps-infra` `main` `70f37e37e8ea1ab05dd65777cf9290ebc708c1a6` (2026-11-04), sin
cambios de infraestructura en esta rama.
Contrato de aplicación: [SPEC34 — INFRA-TEST-01](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md),
PR [#207](https://github.com/jmartinlabs/myfinanzas-app/pull/207), **MERGED** en `main`
`58346e12eb24b9d8ddef6a0be660f0d66654f5ec`, aprobada por el usuario el 2026-11-04.
Antecedente histórico: [vps-infra PR #7](https://github.com/jmartinlabs/vps-infra/pull/7)
(CLOSED, no mergeado); no es contrato vigente ni autorización.
Test plan: [02 — test plan](02-infra-test-01-host-testplan.md).


Las marcas `[CONFIRMADO]`, `[INFORMADO]`, `[PROPUESTA]` y `[PENDIENTE]` distinguen hechos
comprobados en repositorios o por consulta de solo lectura, información recibida no
verificada, diseño sometido a aprobación y cuestiones sin decisión. Ninguna marca convierte
una propuesta en autorización. **Esta spec no afirma que el VPS tenga ya ninguno de los
elementos descritos.**

## 1. Objetivo y alcance

`[CONFIRMADO]` El objetivo es definir la parte **host** del entorno TEST de MyFinanzas,
accesible por `https://test.myfinanzas.pp.ua`, aislado de `myfinanzas.pp.ua`, con datos
exclusivamente ficticios y sin PROD. El contrato funcional de la aplicación pertenece a
SPEC34; este documento solo posee el host y la interfaz que lo conecta con la app.

Esta especificación:

- define identidad, rutas, permisos, DNS, Caddy, UFW, unidad Quadlet, copias, restauración,
  rollback y retirada del host TEST;
- **consume** la release, el runtime y el artefacto de seed de `myfinanzas-app`; no diseña
  el seed, no implementa la app y no reimplementa sus CLIs;
- **no** ejecuta ninguna fase, no accede al VPS, no cambia servicios y no usa datos reales;
- **no** duplica SPEC34: la referencia y resume solo la interfaz en §4.5 y §11;
- **no** sustituye el gate Rootless, la compatibilidad de esquema ni las aprobaciones de la
  aplicación.

### 1.1 Resultado esperado

1. Un host auditado y aprovisionado con usuario dedicado `mftest`, rootless, `linger` y
   rutas privadas verificadas.
2. Un bloque Caddy independiente para `test.myfinanzas.pp.ua` que no altera el sitio raíz.
3. Una unidad Quadlet TEST que ejecuta solo la imagen de aplicación verificada por ID
   inmutable, publicada en `127.0.0.1:18082` y con límites 1 GiB / 1 CPU / 128 pids.
4. Un seed reproducible ejecutado en el host con el artefacto test-only de la app, marcador
   `test-instance.json`, manifiesto/checksums y reset archivado.
5. Copia cifrada local y externa, restauración aislada y rollback bloqueado sin prueba.
6. Evidencia de que `myfinanzas.pp.ua`, sus datos y sus servicios permanecen intactos.
7. Una retirada autorizada que preserva datos y copias sin borrar recursos sin inventario.

### 1.2 Fuera de alcance

- Ejecutar cualquier fase, incluida la auditoría de solo lectura.
- Acceder al VPS, SSH, consola del proveedor, DNS, Caddy, UFW, Podman, Quadlet o systemd.
- Cambiar servicios, usuarios, permisos, firewall, certificados o visibilidad.
- PROD, promoción de TEST, datos reales, Excel, migraciones operativas o importaciones.
- Diseñar o implementar el seed, la imagen test-only, el runtime o la release de la app.
- Desplegar, activar, actualizar, reiniciar, restaurar o retirar nada real.
- Merge de esta spec, de su test plan o de cualquier PR derivada.

## 2. Estado de partida y límites de las afirmaciones

`[CONFIRMADO]` Consulta de solo lectura del repositorio local y de GitHub el 2026-11-04. No
se ha accedido al VPS, ni siquiera en lectura. No se ha ejecutado ninguna comprobación de
host, DNS, Caddy, Podman ni backup para esta spec.

| Hecho | Evidencia | Estado |
| --- | --- | --- |
| `vps-infra` `main` en `70f37e3` | `git rev-parse` local | `[CONFIRMADO]` Base documental. |
| SPEC34 aprobada el 2026-11-04 y mergeada | PR #207, merge `58346e1` | `[CONFIRMADO]` Contrato de aplicación. |
| PR #7 de `vps-infra` cerrado sin merge | API de GitHub, `closedAt` 2026-11-04T18:20Z | `[CONFIRMADO]` Solo antecedente histórico. |
| VPS Aruba Cloud, Debian 13, 2 vCPU / 4 GB / 40 GB | [estado-actual](../docs/estado-actual.md) | `[INFORMADO]` No verificado. |
| Usuario `mfadmin`, SSH por claves, UFW, Caddy, Podman rootless y Quadlet | [estado-actual](../docs/estado-actual.md) | `[INFORMADO]` No verificado. |
| Dominio raíz `myfinanzas.pp.ua` y página estática de prueba | [estado-actual](../docs/estado-actual.md) | `[INFORMADO]` No verificado. |
| IP pública del VPS | No documentada | `[PENDIENTE]` No se inventa. |
| Ruta y contenido reales del `Caddyfile` | No documentados | `[PENDIENTE]` Auditoría. |
| Versión de Podman/Quadlet y directivas admitidas | No documentadas | `[PENDIENTE]` Auditoría. |
| Reglas UFW efectivas y puertos escuchando | No documentados | `[PENDIENTE]` Auditoría. |
| Proveedor DNS, TTL y registros A/AAAA reales | No documentados | `[PENDIENTE]` Auditoría. |
| Espacio libre, inodos y servicios existentes | No documentados | `[PENDIENTE]` Auditoría. |
| Destino externo de copia y custodia de identidad `age` | No aprobados | `[PENDIENTE]` Decisión del usuario. |
| Release y artefacto de seed de la app | No construidos | `[PENDIENTE]` Dependencia de `myfinanzas-app`. |

`[CONFIRMADO]` El runbook de MyFinanzas mantiene el despliegue como **NOT deployable** hasta
cumplir sus gates. Esta spec no rebaja ni sustituye el gate Rootless sobre el SHA exacto.

## 3. Frontera de responsabilidades

| Elemento | Responsable | Límite |
| --- | --- | --- |
| Código, servicios, esquema, migraciones, `production-init`, `setup`, backup/restore | `myfinanzas-app` | No se reimplementan en `vps-infra`. |
| Release, imagen, frontend, manifiesto, evidencia Rootless y compatibilidad | `myfinanzas-app` | Asociados al SHA exacto; el host no reconstruye ni parchea. |
| Herramienta de seed, dataset `FT-1`, `seed-manifest.json` y verificación | `myfinanzas-app` | Test-only; el host lo consume y no lo diseña. |
| SO, SSH, usuario `mftest`, `subuid`/`subgid`, `linger`, rutas y permisos | `vps-infra` | Requiere acceso autorizado y ruta administrativa. |
| UFW, Caddy, TLS, DNS, puertos y cabeceras del sitio TEST | `vps-infra` | No se toca `myfinanzas.pp.ua` ni el sitio raíz. |
| Unidad Quadlet TEST, activación, logs y límites | `vps-infra` | Revisada contra el contrato de app en cada release. |
| Copias locales/externas, restauración, rollback y retirada | `vps-infra` + usuario | El destino externo y la custodia de claves los decide el usuario. |
| Interfaz Caddy ↔ app (puerto, health, rutas, env, estático) | Conjunta | Cualquier cambio se coordina y se revisa en ambos repos. |
| Aprobación de spec, auditoría, provisión, DNS, Caddy, deploy, seed, backup, reset y retirada | Usuario | Cada autorización es independiente e identificable. |
| Revisión de arquitectura y seguridad | Álex / QA | Recomendación, no autorización. |

`[CONFIRMADO]` Regla de frontera: `vps-infra` no implementa el seed ni el runtime de la app;
`myfinanzas-app` no define la unidad, Caddy, DNS, UFW ni las rutas del host. Un cambio de
contrato se documenta antes de que el otro repositorio lo consuma.

## 4. Contrato host

`[PROPUESTA]` Salvo donde se indique `[CONFIRMADO]`, los valores de esta sección son diseño
sometido a aprobación y a la auditoría de la fase 1. No son estado verificado del VPS.

### 4.1 Identidad, dominio y entrada

| Campo | Valor propuesto | Origen / estado |
| --- | --- | --- |
| `environment` | `test` (metadato del host; la app recibe `NODE_ENV=production` y `APP_ORIGIN`) | `[CONFIRMADO]` SPEC34. |
| `public_host` | `test.myfinanzas.pp.ua` | `[CONFIRMADO]` Contrato del packet y SPEC34. |
| `public_origin` | `https://test.myfinanzas.pp.ua` | `[CONFIRMADO]` SPEC34. |
| `root_site` | `myfinanzas.pp.ua` | `[CONFIRMADO]` Debe permanecer intacto. |
| `host_user` | `mftest`, sin login SSH ni contraseña, con `linger` | `[PROPUESTA]` Pendiente de aprobación y auditoría. |
| `host_uid_gid` | Asignado por el host; se registra, no se fija aquí | `[PENDIENTE]` No inventar UID/GID. |
| `container_uid_gid` | `10001:10001` con `keep-id:uid=10001,gid=10001` | `[CONFIRMADO]` SPEC34 y `Containerfile`. |
| `unit_name` / `container_name` | `myfinanzas-test-api` | `[PROPUESTA]` |
| `caddy_upstream` | `127.0.0.1:18082` | `[PROPUESTA]` SPEC34 lo deja pendiente de esta spec. |
| `api_container_port` | `3001` | `[CONFIRMADO]` `main.ts`. |
| `api_bind_host` | `0.0.0.0` solo dentro del namespace | `[CONFIRMADO]` `server-config.ts`. |
| `static_root` | `/var/www/myfinanzas-test/current` | `[PROPUESTA]` |
| `dns_record` | `test` A/AAAA a la IP pública del VPS; TTL 300; sin wildcard | `[PROPUESTA]` IP `[PENDIENTE]`. |
| `tls` | HTTPS automático de Caddy; HTTP→HTTPS | `[PROPUESTA]` Sujeto a auditoría de Caddy. |
| `image` | `sha256:<ID inmutable del manifiesto>`; `Pull=never` | `[CONFIRMADO]` SPEC34. |
| `seed_image` | ID inmutable propio, solo tareas efímeras | `[PROPUESTA]` SPEC34 §4.2. |
| `resources` | 1 GiB RAM, 1 CPU, 128 pids, tmpfs 64 MiB | `[CONFIRMADO]` SPEC34 y RUNBOOK. |
| `disk_budget` | ≤ 5 GB para TEST; ≥ 20 % libre y ≥ 10 % de inodos | `[PROPUESTA]` Heredado del antecedente; confirmar en fase 1. |
| `retention` | Release actual + anterior; copia actual + anterior; sin poda global | `[PROPUESTA]` |
| `backup` | Copia cifrada local + externa; restore a destino nuevo | `[PROPUESTA]` SPEC34 §3.5. |
| `rollback` | Solo al par exacto release/imagen/esquema con prueba; si no, bloquear | `[CONFIRMADO]` SPEC34. |
| `secrets` | Ninguno en Git, PR, logs o imagen; `auth.key` 0600; identidad `age` fuera del VPS | `[CONFIRMADO]` SPEC34 y [security](guidelines/security.md). |

### 4.2 Red y exposición

`[PROPUESTA]` La topología exacta se confirma en la auditoría; no se asume que Caddy y el
contenedor compartan red o permisos.

- Caddy escucha 443/80 en el host y sirve el sitio TEST.
- `/api/*` se reenvía a `127.0.0.1:18082`.
- El contenedor escucha `3001` con bind `0.0.0.0` **solo dentro de su namespace**.
- `3001` no se publica en el host; SQLite no se expone; Vite `5173` no se publica.
- No se usa `Network=host`, `--privileged`, socket de Podman, `:U` ni montajes de dispositivos.
- El puerto `18082` debe quedar en loopback; la publicación rootless se verifica con
  `ss -ltnp` y con un intento externo fallido.
- Caddy debe poder leer `/var/www/myfinanzas-test/current`; el usuario de Caddy y los
  permisos reales se determinan en la auditoría.
- No se abre ningún puerto nuevo en UFW para TEST. La entrada pública existente
  (SSH/80/443, a confirmar en la auditoría) no se modifica sin autorización específica.

### 4.3 Rutas y permisos

| Ruta | Propietario / modo propuesto | Contenido | Nota |
| --- | --- | --- | --- |
| `/srv/myfinanzas-test` | `mftest:mftest` `0700` | Raíz privada del entorno | Ancestro no escribible por terceros. |
| `/srv/myfinanzas-test/data` | `mftest:mftest` `0700` | Raíz de datos montada completa en `/var/lib/myfinanzas` | No montar solo `database.sqlite`. |
| `/srv/myfinanzas-test/data/state` | `mftest:mftest` `0700` | Estado operativo | Creado por `production-init`; no debe existir antes. |
| `.../state/database.sqlite` | `mftest:mftest` `0600` | SQLite | Sin symlinks/hardlinks; WAL/SHM con las mismas garantías. |
| `.../state/auth.key` | `mftest:mftest` `0600` | Clave de autenticación | No regenerar si se pierde; restaurar la pareja. |
| `.../data/test-instance.json` | `mftest:mftest` `0600` | Marcador TEST | Lo crea `seed init`; guard de entorno. |
| `.../data/seed-manifest.json` | `mftest:mftest` `0600` | Manifiesto del seed | No secreto; se conserva como evidencia. |
| `.../data/reset/state-<UTC>` | `mftest:mftest` `0700` | Estado archivado por reset | Evidencia; no se borra automáticamente. |
| `/srv/myfinanzas-test/releases` | `mftest:mftest` `0700` | Paquetes OCI y manifiestos | Solo releases verificadas; conservar la anterior. |
| `/srv/myfinanzas-test/backups` | `mftest:mftest` `0700` | Copias cifradas | Sin identidad `age` permanente. |
| `/var/www/myfinanzas-test` | `root:root` `0755` | Raíz estática pública | Caddy debe leerla; sin secretos ni estado. |
| `/var/www/myfinanzas-test/current` | `root:root`, symlink | Release estática activa | Cambio atómico; el destino no sale de la raíz. |
| `~mftest/.config/containers/systemd` | `mftest:mftest` `0700` | Unidad Quadlet | Sin secretos en la unidad. |

`[CONFIRMADO]` El propietario efectivo del host no tiene por qué coincidir con el UID
interno 10001; `keep-id` mapea la identidad. La verificación debe comprobar el mapeo real y
que los archivos son legibles/escriturables por el UID efectivo de la app, no solo por
`mftest`.

### 4.4 Recursos, secretos y límites

- `[CONFIRMADO]` Memoria 1 GiB, CPU 1, pids 128 y tmpfs 64 MiB para el contenedor.
- `[PROPUESTA]` Presupuesto de disco ≤ 5 GB para TEST, con márgenes mínimos de 20 % libre
  y 10 % de inodos antes de desplegar. El valor real se mide en fase 1 y se registra.
- `[PROPUESTA]` La release actual y la anterior se conservan; no hay poda global ni
  automática de copias.
- `[CONFIRMADO]` Sin secretos en Git, PR, chat, logs, imagen o variables públicas.
- `[CONFIRMADO]` `auth.key` solo en archivo `0600`; el token de `setup` se entrega por
  archivo `0600` y se elimina tras uso; la identidad `age` no reside de forma permanente en
  el VPS.
- `[PROPUESTA]` Los logs operativos se conservan redactados y sin cuerpos de peticiones,
  cookies, tokens ni contenido financiero.
- `[CONFIRMADO]` Si aparece un dato real, una ruta fuera de TEST o un propietario
  inesperado: detener, preservar y escalar. No borrar ni reintentar a ciegas.

### 4.5 Interfaz con la aplicación (resumen)

`[CONFIRMADO]` El detalle completo vive en
[SPEC34 §5](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md#5-contrato-de-despliegue-con-vps-infra-solo-interfaz).
Aquí solo se resume lo que el host consume:

| Campo | Valor / obligación | Origen |
| --- | --- | --- |
| `public_origin` | `https://test.myfinanzas.pp.ua` | SPEC34. |
| `caddy_upstream` | `127.0.0.1:18082` | Propuesta de esta spec. |
| `api_container_port` | `3001` | SPEC34. |
| `health_path` | `/api/health` → `200` `{"ok":true}` | SPEC34. |
| `protected_probe` | `/api/saldos` → `401` sin sesión | SPEC34. |
| `data_mount` | Raíz de datos completa → `/var/lib/myfinanzas:rw` | SPEC34. |
| `state` | `state/database.sqlite` + `state/auth.key` | SPEC34. |
| `env` | `NODE_ENV=production`, `APP_ORIGIN`, `DATABASE_PATH`, `AUTH_KEY_PATH`, `API_BIND_HOST` | SPEC34. |
| `image` | ID inmutable del manifiesto; `Pull=never` | SPEC34. |
| `seed_image` | ID inmutable propio; solo tareas efímeras | SPEC34 §4.2. |
| `resources` | 1 GiB, 1 CPU, 128 pids, tmpfs 64 MiB | SPEC34. |
| `backup` | CLI de la misma imagen/UID, `age`, montaje separado; restore a destino nuevo | SPEC34 §3.5. |
| `rollback` | Solo al par exacto con prueba; si no, bloqueo y preservación | SPEC34. |

`[CONFIRMADO]` `infra/runtime.py:render` **no** se reutiliza para TEST mientras fije
`18081` y `APP_ORIGIN=https://myfinanzas.pp.ua`. La unidad TEST se define en este
entregable (D6; §6).

## 5. Seed reproducible en el host

`[CONFIRMADO]` El seed es diseño de `myfinanzas-app` (SPEC34 §4) y **no se diseña aquí**.
El host lo consume como artefacto test-only, lo ejecuta en tareas efímeras y conserva la
evidencia. Sin el artefacto y la release de la app, las fases 5–8 no son ejecutables.

### 5.1 Artefactos que consume el host

- Paquete de release verificado: `image.oci.tar`, `frontend/`, `manifest.json` y
  `manifest.sha256`, con ID inmutable y `--expected-commit`.
- Artefacto de seed test-only: imagen/CLI, dataset `FT-1`, `seed-manifest.json` y checksums,
  construido desde el mismo SHA y con manifiesto propio.
- Evidencia Rootless y de compatibilidad de esquema del SHA exacto.
- El host **no** construye, parchea, migra ni reimplementa ninguno de estos artefactos.

### 5.2 Secuencia obligatoria

`[CONFIRMADO]` La secuencia aprobada en SPEC34 D3 es:
`production-init → seed init/apply/verify → setup`.

| # | Acción | Condición / resultado |
| --- | --- | --- |
| 1 | Detener cualquier unidad TEST y confirmar que `127.0.0.1:18082` no responde | No se siembra con la unidad activa. |
| 2 | Confirmar que `<data-root>/state` no existe | `production-init` exige estado inexistente. |
| 3 | Ejecutar `production-init` como tarea efímera | Crea DB+clave limpias, sin usuario ni fixtures. |
| 4 | Ejecutar `seed init` | Valida entorno, ruta, permisos y esquema; escribe `test-instance.json` `0600`. |
| 5 | Ejecutar `seed apply` | Aplica `FT-1` con servicios de la app; escribe `seed-manifest.json`. |
| 6 | Ejecutar `seed verify` | Compara manifiesto, marcador y estado; sin drift. |
| 7 | Ejecutar `setup` | Crea el propietario; token por archivo `0600`, eliminado tras uso. |
| 8 | Crear copia cifrada de línea base y copiarla fuera del VPS | Antes de publicar Caddy/DNS. |
| 9 | Activar unidad, publicar frontend y habilitar la ruta TEST | Solo con seed verificado y copia externa. |

`[CONFIRMADO]` Las tareas efímeras usan el mismo UID/mount que la app, sin red
(`--network=none`) y sin referenciar la imagen de seed en la unidad permanente.

### 5.3 Marcador, manifiesto y guardas

`[CONFIRMADO]` El host verifica, sin sustituir al seed:

- `test-instance.json` existe, es regular `0600`, con `environment=test`,
  `public_origin=https://test.myfinanzas.pp.ua`, `seed_manifest_sha256` y
  `schema_version` coherentes.
- `seed-manifest.json` y sus checksums lógicos coinciden con el estado y con el SHA
  esperado; un manifiesto ausente, alterado o de otro commit bloquea.
- Las guardas del seed rechazan origen distinto de TEST, marcador ausente/ajeno, ruta no
  canónica, symlink, permisos incorrectos, esquema no admitido, propietario existente y
  estado no vacío. Códigos esperados: `0` éxito/no-op, `2` guarda, `3` drift, `1` error
  técnico.
- Un segundo `seed apply` con el mismo manifiesto es no-op `0`; un estado parcial se
  rechaza sin reparación automática.
- El host no acepta ficheros, stdin, Excel, SQL externo ni datos de entorno para el seed.

### 5.4 Reset archivado

`[CONFIRMADO]` `seed reset --confirm reset-test` solo se ejecuta con la unidad parada y el
health de `18082` sin responder. Renombra `<data-root>/state` a
`<data-root>/reset/state-<UTC>` con creación exclusiva, sin sobrescribir, y no recrea ni
siembra por sí mismo. El estado archivado es evidencia; no se borra automáticamente. La
retirada de `reset/` exige inventario y autorización.

### 5.5 Verificación y evidencia

- `seed verify` → `0`, sin drift, con `seed_manifest_sha256` registrado.
- SQL de solo lectura: `PRAGMA integrity_check=ok`, `foreign_key_check` vacío,
  `schema_version=24`, conteos e IDs de `FT-1`.
- API autenticada y UI: IDs ficticios esperados; sin sesión, `401`.
- Solo `FT-1`; sin Excel, bases reales, exportaciones ni credenciales.
- La creación pasó por servicios de la app, no por SQL crudo.

### 5.6 Prohibiciones

- Endpoint HTTP de seed, ruta oculta, flag de arranque o «modo demo».
- Incluir `tools/test-seed` o el dataset en la imagen de producción o en el frontend.
- Referenciar la imagen de seed en la unidad permanente.
- Importar el Excel, una base real, un volcado o cualquier fichero externo.
- Usar SQL crudo para saltarse servicios, contadores, auditoría o idempotencia.
- Reutilizar, copiar o «limpiar» el estado de PROD para TEST.
- Declarar éxito sin manifiesto, checksums y evidencia de ejecución.

## 6. Unidad Quadlet TEST (D6)

### 6.1 Propiedad y decisión

`[CONFIRMADO]` D6 está aprobada: la unidad TEST es responsabilidad de este entregable host
de `vps-infra`. **No** se reutiliza `runtime.py:render` de PROD mientras fije `18081` y el
origen de PROD. La unidad se escribe y revisa en `vps-infra` contra el contrato de SPEC34;
parametrizar la CLI de la app es un trabajo posterior, no un requisito de esta entrega.

`[CONFIRMADO]` La unidad propuesta **no se instala, no se activa y no se valida en el host**
en esta fase documental. Es una plantilla para revisión y para la fase 5.

### 6.2 Unidad propuesta (no instalada)

Fichero propuesto: `~mftest/.config/containers/systemd/myfinanzas-test-api.container`.

```ini
[Unit]
Description=MyFinanzas TEST rootless API
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Container]
Image=sha256:REPLACE_WITH_VERIFIED_IMAGE_ID
Pull=never
ContainerName=myfinanzas-test-api
UserNS=keep-id:uid=10001,gid=10001
User=10001
Group=10001
PublishPort=127.0.0.1:18082:3001
Volume=/srv/myfinanzas-test/data:/var/lib/myfinanzas:rw
Environment=NODE_ENV=production
Environment=APP_ORIGIN=https://test.myfinanzas.pp.ua
Environment=DATABASE_PATH=/var/lib/myfinanzas/state/database.sqlite
Environment=AUTH_KEY_PATH=/var/lib/myfinanzas/state/auth.key
Environment=API_BIND_HOST=0.0.0.0
NoNewPrivileges=true
ReadOnly=true
DropCapability=all
Tmpfs=/tmp:rw,noexec,nosuid,nodev,tmpcopyup,mode=0711,size=64m
HealthCmd=/usr/local/bin/bun /app/healthcheck.mjs
HealthInterval=30s
HealthTimeout=3s
HealthRetries=3
HealthStartPeriod=30s
PodmanArgs=--http-proxy=false --read-only-tmpfs=false --memory=1g --cpus=1 --pids-limit=128 --health-on-failure=kill

[Service]
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

Condiciones de revisión:

- `Image` es el ID inmutable verificado; nunca una etiqueta móvil. `Pull=never`.
- `18082` es el puerto de TEST; `3001` sigue siendo el puerto interno de la API.
- No hay `Network=host`, `--privileged`, socket de Podman, `:U` ni dispositivos.
- La unidad no contiene secretos; `auth.key` es solo el archivo persistente.
- `ReadOnly=true` y `--read-only-tmpfs=false` mantienen el rootfs de solo lectura y `/tmp`
  temporal controlado.
- La auditoría debe confirmar que la versión instalada de Quadlet admite
  `StartLimitIntervalSec`, `StartLimitBurst`, `HealthCmd` y las demás directivas. Si no,
  se sustituyen por una alternativa equivalente revisada, sin relajar el endurecimiento.
- Verificar que `/run`, `/var/tmp` y el tmpfs `/tmp` no necesitan escritura adicional; si la
  app la requiere, se revisa el contrato y se documenta.
- La unidad permanente **solo** usa la imagen de aplicación. La imagen de seed se usa en
  tareas efímeras y no aparece aquí.

### 6.3 Condiciones de activación

`[PROPUESTA]` No se activa la unidad hasta que se cumplan, como mínimo:

1. Auditoría de host completada y autorización de provisión.
2. Usuario `mftest`, `subuid`/`subgid`, `linger`, rutas y permisos verificados.
3. Release y seed verificados por manifiesto; gate Rootless en `SUCCESS` sobre el SHA.
4. `production-init`, `seed init/apply/verify` y `setup` completados; `seed verify` → `0`.
5. Copia cifrada local y externa de línea base verificadas.
6. Caddy preparado y validado, sin publicar aún el sitio si la app no está lista.
7. UFW y loopback comprobados; `18082` no expuesto; `3001` no publicado.

### 6.4 Frontend estático

- Se sirve solo `frontend/` del paquete verificado, nunca el servidor Vite.
- Publicación atómica: `releases/<sha>/` y symlink `current`; el destino no sale de la raíz.
- Directorios `0755`, archivos `0644`, propietario `root:root`; sin escritura para `mftest`.
- No se copian `node_modules`, fuentes, tests, `.env`, claves, bases, mapas de fuente ni
  archivos de estado. Si aparecen, se bloquea la publicación y se corrige el artefacto.
- La release anterior se conserva hasta verificar la nueva.

## 7. DNS, Caddy, UFW, copias y recuperación

### 7.1 DNS

`[PROPUESTA]` Añadir, con autorización del usuario y tras la auditoría:

```text
test.myfinanzas.pp.ua. 300 IN A    <IP_PUBLICA_VERIFICADA>
test.myfinanzas.pp.ua. 300 IN AAAA <IPv6_PUBLICA_VERIFICADA, si existe>
```

- No crear wildcard. No modificar `myfinanzas.pp.ua` ni sus registros.
- Si el dominio raíz usa proxy/CDN, **no** copiar ese registro al subdominio TEST sin
  decisión expresa; `test` debe apuntar a la IP del VPS.
- Verificar A/AAAA con resolutores públicos antes de habilitar Caddy.
- La IP, el proveedor DNS y el TTL reales se registran en la evidencia; no se inventan.
- Crear el registro `test` no acredita HTTPS ni entorno operativo.

### 7.2 Caddy y HTTPS

`[PROPUESTA]` Bloque independiente para `test.myfinanzas.pp.ua`. La ubicación exacta
(`Caddyfile` principal o fichero importado) se decide **después** de auditar la
configuración real. No se sustituye ni se edita el sitio raíz sin backup y autorización.

```caddyfile
test.myfinanzas.pp.ua {
    encode zstd gzip

    header {
        Strict-Transport-Security "max-age=300"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        X-Frame-Options "DENY"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'"
        X-Robots-Tag "noindex, nofollow"
    }

    handle /api/* {
        reverse_proxy 127.0.0.1:18082
    }

    handle /assets/* {
        header Cache-Control "public, max-age=31536000, immutable"
        root * /var/www/myfinanzas-test/current
        file_server
    }

    handle {
        header Cache-Control "no-store"
        root * /var/www/myfinanzas-test/current
        try_files {path} /index.html
        file_server
    }
}
```

Condiciones:

- `/api/*` no debe tener fallback a `index.html`; un 404 de API sigue siendo 404.
- Caddy conserva `Host` y añade `X-Forwarded-Proto`; la app decide cookies Secure por
  `APP_ORIGIN`.
- HSTS se limita a `max-age=300`; sin `includeSubDomains` ni `preload`.
- `style-src 'unsafe-inline'` es un margen para la UI; se revisa tras verificar la build.
- Sin listado de directorios ni mapas de fuente.
- Antes de recargar: backup del fichero principal y de los imports que afecten al sitio,
  `caddy validate` y comprobación del sitio raíz después de la recarga.
- La recarga que publica TEST no se ejecuta hasta que la unidad esté activa y el seed
  verificado; si se prepara antes, se acepta una ventana 502 y no se declara operativo.
- El usuario y permisos reales de Caddy para leer `/var/www/myfinanzas-test` se confirman
  en la auditoría.

### 7.3 UFW y loopback

- `18082` solo escucha en `127.0.0.1`; `3001` no se publica en el host; SQLite no es
  accesible; Vite no se publica.
- UFW no abre puertos nuevos para TEST. La entrada pública existente (SSH/80/443, a
  confirmar en la auditoría) no se modifica sin autorización específica.
- Comprobar con `ss -ltnp`, `ufw status numbered`, `podman port` y un intento externo
  fallido contra `18082` y `3001`.
- No se modifican reglas, zonas ni servicios de otras aplicaciones para «hacer sitio».

### 7.4 Copia local y externa

`[PROPUESTA]` Antes de habilitar Caddy:

- Copia cifrada con `age` desde la misma imagen/UID de la app, con snapshot SQLite coherente
  y la clave de autenticación; no se copian DB/WAL por separado.
- Copia local en `/srv/myfinanzas-test/backups` `0700` y copia fuera del VPS en el destino
  aprobado por el usuario.
- Checksums origen/destino, retención de la copia actual y la anterior, y verificación de
  que la identidad `age` no reside permanentemente en el VPS.
- Sin secretos, bases en claro ni claves en Git, PR, logs o chat.
- DT6/T-BKP sigue abierto: esta copia es un mínimo de TEST, no un RPO/RTO de producción.

### 7.5 Restauración aislada

- Restaurar solo a un directorio nuevo, nunca sobre el estado activo.
- Verificar pareja DB+clave, identidad/integridad/FK, health `200`, ruta protegida `401` y
  `FT-1` por API/UI con MFA.
- El estado activo se conserva; una restauración fallida preserva origen, copia y destino y
  se escala.
- Registrar el RTO observado. No se promete RTO de producción.

### 7.6 Rollback

- Rollback de aplicación solo al par exacto release/imagen/esquema con prueba reproducible.
  Sin prueba, se bloquea y se preserva el estado; no se fuerza un downgrade de esquema ni se
  reemplaza el estado activo por una copia.
- Rollback de Caddy desde el backup validado, con `caddy validate`, recarga y comprobación
  del sitio raíz.
- Si no hay par compatible, se decide entre una release compatible o una reconstrucción de
  TEST con estado nuevo, con autorización específica.
- El rollback no borra copias ni datos; no usa `reset-failed`, `chmod`/`chown` ni `:U` para
  «hacer que funcione».

### 7.7 Retirada

`[PROPUESTA]` La retirada autorizada:

1. Detiene y deshabilita la unidad TEST.
2. Retira o deshabilita el bloque Caddy de TEST tras backup y validación.
3. Retira el registro DNS `test` sin tocar el dominio raíz.
4. Deshabilita `linger` si `mftest` no tiene otro uso autorizado.
5. Preserva datos, copias y evidencia; no borra sin inventario y autorización.
6. Verifica que `myfinanzas.pp.ua` sigue respondiendo igual.

## 8. Criterios de aceptación host

Todos son **documentales** hasta que se ejecuten en la fase indicada del
[test plan](02-infra-test-01-host-testplan.md). Estado inicial: `UNRUN`.

| ID | Criterio verificable | Fase |
| --- | --- | --- |
| `INFRA-TEST-01-HOST-AC01` | La rama solo añade esta spec y su test plan; no toca código, `infra/`, workflows, `docs/` operativos ni el VPS; no hay acceso remoto, deploy ni merge. | 0 |
| `INFRA-TEST-01-HOST-AC02` | Auditoría de solo lectura completada y redactada: identidad/SO/recursos, servicios, puertos, SSH, UFW, Caddy, DNS, Podman/Quadlet, usuarios, disco/inodos y backups; sin cambios y con diferencias frente a lo informado. | 1 |
| `INFRA-TEST-01-HOST-AC03` | `mftest` existe como usuario dedicado, sin login SSH ni contraseña, con `subuid`/`subgid`, `linger` y `systemd --user` operativo; UID/GID registrados y sin reutilizar `mfadmin`. | 2 |
| `INFRA-TEST-01-HOST-AC04` | Rutas y permisos: raíz privada `0700`, `data`/`state` `0700`, DB y `auth.key` `0600`, `releases`/`backups` `0700`, estático `0755` de `root`, `current` atómico dentro de la raíz y sin symlinks/hardlinks en el estado. | 2 |
| `INFRA-TEST-01-HOST-AC05` | `test.myfinanzas.pp.ua` resuelve A/AAAA a la IP pública verificada, sin wildcard; el registro raíz y el proveedor no cambian; la resolución se confirma con resolutores públicos. | 3 |
| `INFRA-TEST-01-HOST-AC06` | Caddy valida un bloque independiente para TEST, sirve HTTPS válido, redirige HTTP→HTTPS, aplica CSP/HSTS corto/noindex/nosniff, proxyfica `/api/*` a `127.0.0.1:18082` sin fallback SPA y sirve el estático desde `current`; el sitio raíz sigue intacto. | 4, 6 |
| `INFRA-TEST-01-HOST-AC07` | La unidad Quadlet está activa y habilitada al arranque por `linger`, usa imagen inmutable `Pull=never`, `keep-id` 10001, publica `127.0.0.1:18082:3001`, limita 1 GiB/1 CPU/128 pids, rootfs de solo lectura, tmpfs 64 MiB y no referencia la imagen de seed. | 5 |
| `INFRA-TEST-01-HOST-AC08` | `/api/health` responde `200` `{"ok":true}` en loopback y HTTPS; una ruta protegida sin sesión responde `401`; no hay bypass de autenticación. | 5, 6 |
| `INFRA-TEST-01-HOST-AC09` | `18082` solo escucha en loopback; `3001`, SQLite y Vite no son accesibles desde fuera; UFW no abre puertos nuevos; los intentos externos fallan y otros servicios no se alteran. | 2, 6 |
| `INFRA-TEST-01-HOST-AC10` | El host ejecuta el artefacto test-only en el orden `production-init → seed init/apply/verify → setup`; `test-instance.json` `0600`, manifiesto/checksums coinciden, las guardas rechazan origen/ruta/permisos/esquema/propietario/estado incorrectos y el reset archiva sin borrar. | 5 |
| `INFRA-TEST-01-HOST-AC11` | Copia cifrada local y externa verificadas, con snapshot SQLite coherente y clave de autenticación; checksums origen/destino, retención actual+anterior y ausencia de secretos en Git/logs. | 6 |
| `INFRA-TEST-01-HOST-AC12` | Restauración aislada a destino nuevo con MFA: health `200`, `401` y `FT-1` visibles; estado activo intacto; fallo preserva origen, copia y destino; RTO registrado. | 7 |
| `INFRA-TEST-01-HOST-AC13` | Rollback de app sin prueba del par exacto se bloquea y preserva datos; rollback de Caddy desde backup validado deja el sitio raíz intacto; sin downgrade forzado ni sobrescritura del estado activo. | 7 |
| `INFRA-TEST-01-HOST-AC14` | `myfinanzas.pp.ua` y su DNS/HTTP/HTTPS siguen respondiendo igual antes y después; solo se añadió el registro `test`; no se modificó el bloque raíz de Caddy, UFW ni otros servicios. | 6, 8 |
| `INFRA-TEST-01-HOST-AC15` | La retirada autorizada detiene la unidad, retira Caddy/DNS de TEST, deshabilita `linger` si procede y preserva datos/copias; el dominio raíz queda intacto y no hay borrado sin inventario. | 8 |
| `INFRA-TEST-01-HOST-AC16` | TEST respeta el presupuesto de disco acordado y los márgenes de espacio/inodos; memoria, CPU y pids se miden dentro de los límites y sin afectar a otros servicios. | 6 |
| `INFRA-TEST-01-HOST-AC17` | No hay Excel, bases reales, exportaciones, credenciales, TOTP, cookies, claves ni datos personales en host, repo, logs o copias; solo `FT-1` identificable y evidencia redactada. | 5, 6 |

### 8.1 Trazabilidad con SPEC34

| Host AC | SPEC34 AC relacionadas | Relación |
| --- | --- | --- |
| AC01 | AC01 | Alcance documental y ausencia de cambios. |
| AC02–AC04 | — | Controles propios del host (auditoría, identidad, rutas). |
| AC05 | AC17 | DNS `test` sin tocar el dominio raíz. |
| AC06 | AC12, AC17 | HTTPS, cabeceras, cookies y sitio raíz. |
| AC07 | AC11, AC18 | Unidad, UID y límites. |
| AC08 | AC11 | Health y `401`. |
| AC09 | AC13 | Loopback, UFW y no exposición. |
| AC10 | AC04–AC09 | Seed, guardas, determinismo, idempotencia y reset. |
| AC11 | AC14 | Copia local y externa. |
| AC12 | AC14 | Restauración aislada y RTO. |
| AC13 | AC15 | Rollback bloqueado y Caddy. |
| AC14 | AC17 | Sitio raíz intacto. |
| AC15 | AC19 | Retirada. |
| AC16 | AC18 | Capacidad y disco. |
| AC17 | AC16 | Ausencia de datos reales y secretos. |

## 9. Fases y autorizaciones

`[PENDIENTE]` Cada fase exige autorización **separada, explícita e identificable** del
usuario. Ninguna se deduce de la anterior; «ok», «dale» o «continúa» no autorizan una fase
protegida. El detalle de método, entorno y evidencia está en el
[test plan](02-infra-test-01-host-testplan.md).

| Fase | Contenido | Autorización | Evidencia de salida | Estado |
| --- | --- | --- | --- | --- |
| 0 | Aprobar esta spec y su test plan | Usuario | Aprobación registrada | UNRUN |
| 1 | Auditoría de solo lectura del host | Usuario | Inventario redactado y diferencias | UNRUN |
| 2 | Provisión de usuario, rutas, permisos, `linger` y UFW | Usuario | Identidad, rutas, UFW y versiones registradas | UNRUN |
| 3 | DNS `test` | Usuario | Registro A/AAAA y resolución pública; raíz intacta | UNRUN |
| 4 | Caddy y HTTPS | Usuario | Backup, `caddy validate`, bloque validado, raíz intacta | UNRUN |
| 5 | Despliegue y seed | Usuario | Release verificada, seed `0`, unidad activa, frontend | UNRUN |
| 6 | Smoke y copias | Usuario | HTTPS/health/401, `FT-1`, límites, copia local/externa | UNRUN |
| 7 | Restauración y rollback | Usuario | Restore aislado, rollback bloqueado/ensayado | UNRUN |
| 8 | Retirada | Usuario | Unidad/DNS/Caddy retirados, datos preservados, raíz intacta | UNRUN |

`[PROPUESTA]` El orden 3→4→5 es de **preparación**. El registro DNS `test` puede crearse
antes de que la app esté lista, pero no acredita HTTPS ni entorno operativo. La recarga de
Caddy que publica TEST se ejecuta solo cuando la unidad está activa y el seed verificado; si
se prepara antes, se acepta una ventana 502 y no se declara operativo. La fase 6 es la que
acredita HTTPS, smoke y copias.

## 10. Dependencias, riesgos y decisiones

### 10.1 Dependencias

| Dependencia | Estado | Efecto |
| --- | --- | --- |
| SPEC34 / PR #207 | Aprobada 2026-11-04 y mergeada en `58346e1` | Contrato de app; no autoriza DEV ni deploy. |
| Release, imagen y artefacto de seed | No construidos | Sin ellos, fases 5–8 no ejecutables. |
| E4.9 / v25 | En implementación, no mergeado | TEST se ancla a esquema 24; no se prueban cierres. |
| E4.5 / DT7 | No apta | Sin históricos ni transición de ejercicio. |
| E4.7 / E4.10 / E4.11 | DRAFT | Fuera del dataset y del smoke. |
| DT6 / T-BKP | Abierto | Afecta a backup/restore; TEST exige mínimo local+externo. |
| Gate Rootless | Obligatorio por RUNBOOK | Sin `SUCCESS` sobre el SHA exacto no se despliega. |
| Caddy real | Desconocido hasta auditoría | Sujeto a backup, `caddy validate` y rollback. |
| DNS real | Desconocido hasta auditoría | Sin registro `test` no hay TLS ni entorno operativo. |
| Flake SQLite **B3** | Sin reproducción Linux | Puede aparecer en el ensayo; no se oculta. |
| VPS 2 vCPU / 4 GB / 40 GB | `[INFORMADO]` | Presupuesto pequeño; límites y medición obligatorios. |
| Acceso al host | No autorizado | Fases 1–8 bloqueadas. |

### 10.2 Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Caddy mal editado | Interrupción del sitio raíz | Backup, `caddy validate`, recarga controlada y rollback. |
| DNS `test` con proxy/CDN heredado | TLS/routing incorrectos | No copiar el registro raíz sin decisión; verificar A/AAAA. |
| Colisión de `18082` | Unidad no arranca | Auditoría de puertos; puerto reservado solo para TEST. |
| `linger`/rootless mal configurado | Unidad no persiste tras logout/reboot | Verificar `loginctl`, `subuid`/`subgid` y `systemctl --user`. |
| Seed en entorno equivocado | Contaminación o pérdida | Origen exacto, marcador, ruta, permisos, propietario y base vacía. |
| Imagen de seed en la unidad | Superficie innecesaria | Inventario y revisión de la unidad; solo imagen app. |
| Reset sobre PROD | Pérdida irreversible | Solo `<data-root>/state`; marcador TEST; archivar, no borrar. |
| Copia externa inexistente | Sin recuperación real | Bloqueo de activación hasta destino aprobado y verificado. |
| Restore sobre estado activo | Pérdida de escrituras | Restore solo a destino nuevo; preservar origen/copia/destino. |
| Disco o inodos insuficientes | ENOSPC | Presupuesto, medición y márgenes antes de desplegar. |
| Flake B3 | Falso FAIL/PASS | Diagnóstico Linux; no ocultar ni reintentar a ciegas. |
| Login TEST público | Fuerza bruta | MFA, límites de app y `noindex`; allowlist de borde solo con decisión. |
| Deriva documental con la app | Unidad incoherente | Revisión campo a campo por release y actualización coordinada. |
| Retirada sin inventario | Pérdida de datos/copias | Preservar, inventariar y autorizar antes de borrar. |
| Auditoría que expone secretos | Fuga de información | Evidencia redactada; no volcar claves, cookies ni bases. |

### 10.3 Decisiones de host propuestas

| ID | Decisión | Recomendación | Estado |
| --- | --- | --- | --- |
| H1 | Identidad | Usuario dedicado `mftest`, rootless, sin login SSH, con `linger`. | `[PROPUESTA]` |
| H2 | Exposición | Caddy → `127.0.0.1:18082` → `3001`; sin publicar API/DB/Vite. | `[PROPUESTA]` |
| H3 | Rutas | `/srv/myfinanzas-test/{data,releases,backups}` y `/var/www/myfinanzas-test/current`. | `[PROPUESTA]` |
| H4 | Seed | Consumir el artefacto test-only en orden `production-init → seed → setup`, con marcador/manifiesto y reset archivado. | `[PROPUESTA]` |
| H5 | Unidad | Unidad TEST propia de `vps-infra`; no reutilizar `runtime.py:render` de PROD. | `[CONFIRMADO]` D6 |
| H6 | Recuperación | Copia local+externa cifrada y restore aislado antes de habilitar Caddy. | `[PROPUESTA]` |

## 11. Coordinación con myfinanzas-app

`[CONFIRMADO]` El contrato de aplicación es
[SPEC34](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md),
PR [#207](https://github.com/jmartinlabs/myfinanzas-app/pull/207), head
`58346e12eb24b9d8ddef6a0be660f0d66654f5ec`. Esta spec **no abre una segunda spec de
aplicación** ni duplica su contenido.

- **Qué posee la app:** release, imagen, frontend, runtime, seed test-only, dataset `FT-1`,
  manifiesto/checksums, `production-init`, `setup`, backup/restore y evidencia Rootless.
- **Qué posee este entregable:** host, usuario, rutas, permisos, UFW, Caddy, TLS, DNS,
  Quadlet, unidad TEST, copias del host, restauración, rollback y retirada.
- **Interfaz:** cualquier cambio de puerto, env, ruta, health, CLI o artefacto se documenta
  en SPEC34 (o su sucesora) y se revisa aquí antes de la fase 5. No se acepta una unidad
  desincronizada.
- **Secuencia:** la app debe entregar release y seed verificados antes de la fase 5 del
  host. Las fases 1–4 del host pueden preparar el terreno, pero no declaran TEST operativo.
- **Test plans:** el de la app cubre AC04–AC09/AC14/AC15/AC19 de su contrato; este plan
  cubre los AC host y enlaza la trazabilidad de §8.1. Ningún resultado se hereda.
- **Merge:** la aprobación de SPEC34 no autoriza DEV, release, despliegue ni merge. La
  PR #207 consta `MERGED` en `58346e1`; no
  se infiere permiso operativo.

## 12. Trazabilidad y límites de las afirmaciones

- `[CONFIRMADO]` Los hechos de §2 y §11 proceden del checkout local y de la API de GitHub;
  no de una inspección del VPS.
- `[INFORMADO]` El hardware, SO, usuario, UFW, Caddy, Podman/Quadlet y dominio raíz son
  información recibida, pendiente de auditoría.
- `[PROPUESTA]` Rutas, usuario `mftest`, puerto `18082`, DNS, Caddy, unidad, copias y
  presupuesto de disco son diseño, no implementación ni estado real.
- `[PENDIENTE]` La aprobación de esta spec, la auditoría, la provisión y todas las fases.
- Ningún `UNRUN` es `PASS` ni `FAIL`. No se hereda evidencia de otras entregas.
- Las rutas de host citadas son propuestas; no son directorios verificados ni un contrato
  vigente hasta que la fase 1 y la aprobación lo confirmen.
- La aprobación de esta spec no autoriza DEV, VPS, DNS, Caddy, deploy, datos reales ni merge.
