# 02 — INFRA-TEST-01-HOST: host del entorno TEST de MyFinanzas — Specification

Status: **DRAFT — reconciliada con auditoría (2026-11-05), Caddy 2.11.9, preflight de
solo lectura y Fases 2A/2B (2026-11-07); pendiente de aprobación.** No autoriza DEV, nuevas
fases, DNS, Caddy, UFW, Podman/Quadlet, despliegue, datos reales ni merge.
Approval source/date: PENDING
Context and brainstorming: packet de coordinación `INFRA-TEST-01-HOST` (2026-11-04); sin
brainstorming separado.
Base: `vps-infra` `main` `c1f9f59312fd91120f96633857125554d7a9b624` (2026-11-07), sin
cambios de infraestructura de TEST en esta rama.
Auditoría y Caddy: [auditoría 2026-11-05](../docs/auditorias/2026-11-05-infra-audit-vps-001-cierre.md)
y [cierre VPS-CADDY-UPGRADE-01](../docs/auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md).
Contrato de integración MyFinanzas ↔ `vps-infra`:
[SPEC34 §5](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md#5-contrato-de-despliegue-con-vps-infra-solo-interfaz)
y el manifiesto de cada release. `vps-infra` no rastrea PRs de la aplicación: MyFinanzas
actualiza su propio contrato de esquema/seed. Flujo actual: `feature/* → main`. TEST consume una release construida desde un SHA
inmutable y verificado de `myfinanzas-app/main`; PROD futuro, desde `main`. **No hay rama
`test`** ni se requiere para TEST. El despliegue de TEST es manual e independiente de los
merges, sin automatización. `main` no se considera todavía producción. `vps-infra` mantiene
una sola `main`.
Antecedente histórico: [vps-infra PR #7](https://github.com/jmartinlabs/vps-infra/pull/7)
(CLOSED, no mergeado); no es contrato vigente ni autorización.
Test plan: [02 — test plan](02-infra-test-01-host-testplan.md).
Evidencia Fase 2A: [02A — identidad rootless](../docs/evidencia-infra-test-02a.md).
Evidencia Fase 2B: [02B — rutas y permisos](../docs/evidencia-infra-test-02b.md).
Paquete de despliegue: [MyFinanzas TEST](../docs/paquete-despliegue-myfinanzas-test-01.md).
Preparación DNS/Caddy: [fase 3/4 documental](../docs/preparacion-dns-caddy-test-01.md).


Las marcas `[CONFIRMADO]`, `[INFORMADO]`, `[PROPUESTA]` y `[PENDIENTE]` distinguen hechos
comprobados en repositorios o por consulta de solo lectura, información recibida no
verificada, diseño sometido a aprobación y cuestiones sin decisión. Ninguna marca convierte
una propuesta en autorización. **Esta spec distingue lo verificado de lo propuesto y no
convierte una comprobación en autorización.**

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

`[CONFIRMADO]` Auditoría de solo lectura del VPS (2026-11-04/05) y actualización manual de
Caddy a 2.11.9 el 2026-11-05 con autorización del usuario. Esta spec actualiza el estado
conocido, pero **no ejecuta ni autoriza** ninguna fase de TEST. Los resultados de Caddy
posteriores a la actualización son evidencia del usuario; el agente no accedió al VPS después.

| Hecho | Evidencia | Estado |
| --- | --- | --- |
| `vps-infra` `main` en `c1f9f59` | `git rev-parse` local | `[CONFIRMADO]` Base documental. |
| Contrato de integración MyFinanzas ↔ `vps-infra` | SPEC34 §5 y manifiesto de cada release | `[INFORMADO]` La actualización de esquema/seed corresponde a MyFinanzas; `vps-infra` no rastrea PRs. |
| Flujo actual `feature/* → main`; TEST desde SHA de `myfinanzas-app/main` | Decisión del usuario 2026-11-05 (rectificada) | `[PROPUESTA]` Sin rama `test`; deploy manual, sin automatización; `main` no es producción todavía. |
| PR #7 de `vps-infra` cerrado sin merge | API de GitHub | `[CONFIRMADO]` Solo antecedente histórico. |
| Debian 13.7, kernel 6.12.113, x86_64 KVM/OpenStack; 2 vCPU, 3,8 GiB RAM, disco 40 GB, 35 GB libres, inodos 3 % | [auditoría](../docs/auditorias/2026-11-05-infra-audit-vps-001-nivel2-result.md) | `[CONFIRMADO]` Sin prueba de carga. |
| `mfadmin` UID/GID 1001, `sudo`/`users`, `Linger=yes`; `sudo -n` pide contraseña | Auditoría | `[CONFIRMADO]` NOPASSWD no verificado. |
| SSH: root y contraseñas deshabilitados, clave pública; `X11Forwarding yes`, `AllowTcpForwarding yes`, `AuthenticationMethods any`, sin `AllowUsers` | Comprobación manual del usuario, 2026-11-05 | `[CONFIRMADO]` Hardening pendiente. |
| UFW activo, entrada `deny`, solo 22/80/443 IPv4/IPv6; nftables coherente | Comprobación manual del usuario, 2026-11-05 | `[CONFIRMADO]` Reglas revisadas manualmente. |
| Caddy **2.11.9** (Cloudsmith), `active`/`enabled`, HTTPS 200 verify 0, HTTP 308, solo `CAP_NET_BIND_SERVICE`, `apt-mark hold` | [cierre Caddy](../docs/auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md) | `[CONFIRMADO]` Evidencia del usuario posterior a la actualización. |
| `Caddyfile` de 68 B: sitio `myfinanzas.pp.ua`, `root` y `file_server`; sin `reverse_proxy` ni bloque TEST; `caddy validate` OK | Preflight 2026-11-07 y cierre Caddy | `[CONFIRMADO]` Contenido completo leído; el bloque TEST sigue pendiente. |
| Podman 5.4.2 rootless; sin contenedores/volúmenes/pods; imágenes `nginx`/`hello-world`; Quadlet presente y delegación `cpu memory pids` | Auditoría y preflight 2026-11-07 | `[CONFIRMADO]` Configuración verificada; unidad real y reboot pendientes. |
| DNS apex con A y TTL 14400; sin AAAA/CAA; `test` NXDOMAIN; NS en `uadns.com` | Auditoría | `[CONFIRMADO]` IP pública no documentada aquí. |
| Directorio `myfinanzas/backups` bajo el home del operador: existe `0700`, sin ficheros regulares visibles a profundidad 2 | Auditoría | `[CONFIRMADO]` Inventario y restore no verificados. |
| Recuperación de Caddy: `/root/caddy-upgrade-20261105T151652Z` `0700`, retención hasta 2026-12-05 | Cierre Caddy | `[CONFIRMADO]` No es backup de la aplicación TEST. |
| IP pública, destino externo de copia y release/seed de la app | No documentados | `[PENDIENTE]` No se inventan. |
| TEST desplegado | Auditoría | `[CONFIRMADO]` No hay contenedor ni imagen MyFinanzas. |
| AC-17 (reboot) y AC-18 (rollback) de Caddy | Cierre Caddy | `[PENDIENTE]` `UNRUN`. |

`[CONFIRMADO]` El runbook de MyFinanzas mantiene el despliegue como **NOT deployable** hasta
cumplir sus gates. Esta spec no rebaja ni sustituye el gate Rootless sobre el SHA exacto.

### 2.1 Preflight de solo lectura — 2026-11-07

Sesión como `mfadmin`, sin `sudo`, sin cambios y sin leer secretos, bases ni contenido de
backups. Evidencia redactada fuera del repositorio.

| Comprobación | Resultado |
| --- | --- |
| Host | Debian 13.7, kernel 6.12.113, KVM/OpenStack, 2 vCPU, 3,8 GiB RAM, 35 GB libres, inodos 3 %, sin reboot pendiente. |
| Administración | `mfadmin` UID/GID 1001, subuid/subgid 65536, `Linger=yes`, `systemd --user` activo. |
| Delegación cgroup | `Delegate=yes`; controladores `cpu memory pids`. |
| Podman | 5.4.2 rootless, cgroup systemd; Quadlet en `/usr/libexec/podman/quadlet`; sin unidades propias, contenedores ni volúmenes MyFinanzas; imágenes `nginx`/`hello-world`. |
| `mftest` y rutas | `mftest` no existe; `/srv/myfinanzas-test` y `/var/www/myfinanzas-test` no existen. |
| Puertos | 22/80/443 públicos; 2019 solo loopback; `18082`/`3001` ausentes. |
| Caddy | 2.11.9 activo, `hold`, `NRestarts=0`; Caddyfile de 68 B con sitio raíz, `root` y `file_server`, sin `reverse_proxy` ni bloque TEST; `caddy validate` OK. |
| DNS/HTTP | Apex A, HTTP 308 y HTTPS 200; `test` NXDOMAIN; sin AAAA/CAA observados. |
| Backups | `~mfadmin/myfinanzas/backups` 0700 y vacío; inventario profundo y restore pendientes. |
| SSH/UFW/fail2ban efectivos | **Pendientes de root**: `sshd -T` no pudo ejecutarse sin host keys; UFW/nft/fail2ban requieren privilegios. No se intentó elevar. |
| Datasette | PR #22 pendiente: el wrapper debe usar `.../data/state`, no `.../data`. |

Diferencias principales: el contenido del Caddyfile ya se leyó completo y es mínimo; Quadlet
y la delegación cgroup están verificados a nivel de configuración, pero **no se ha probado
una unidad real ni persistencia tras reboot**. `mftest` y las rutas base se resolvieron en
2A/2B; DNS `test`, backups externos, release/seed, estado y despliegue siguen pendientes.

`[CONFIRMADO]` La ruta de estado `/srv/myfinanzas-test/data/state` está confirmada a nivel
de contrato físico/documental por MyFinanzas: el data root `/srv/myfinanzas-test/data` se
monta en `/var/lib/myfinanzas`, con DB y `auth.key` en `state/`. Es coherente con PR #22 y
con `infra/RUNBOOK.md` de la app. **No implica que `state/` exista ya en el VPS ni autoriza
despliegue.** La ruta específica de PROD sigue pendiente. La corrección del wrapper Datasette
se revisa en PR #22; no se instala ni se despliega desde esta spec.

### 2.2 Fase 2A ejecutada — 2026-11-07

`[CONFIRMADO]` Fase 2A completada con **PASS** por el usuario en sesión SSH interactiva con
`sudo` normal. Evidencia: [02A](../docs/evidencia-infra-test-02a.md).

| Comprobación | Resultado |
| --- | --- |
| Identidad | `mftest` UID/GID `1002:1002`, usuario y grupo existentes; no se reutiliza `mfadmin`. |
| Home y login | `~mftest` `0700` de `mftest:mftest`; shell `nologin`; contraseña bloqueada; sin `authorized_keys`. |
| subuid/subgid | `231072:65536` en ambos ficheros; sin duplicados ni solapamiento. |
| Linger | `Linger=yes`. |
| systemd --user | `running`; `rc=0`. |
| Podman / cgroup | `rootless=true`, `cgroup=systemd`, `Delegate=yes`, controladores `cpu memory pids`. |
| Rutas y puertos | `/srv/myfinanzas-test`, `/var/www/myfinanzas-test` y `data/state` ausentes; `18082`/`3001` ausentes. |

Consecuencias:

- AC03 del test plan host pasa a `PASS`.
- **2B se ejecutó después con PASS**; ver §2.3.
- La unidad Quadlet real y la persistencia tras reboot siguen sin probar; no se declaran
  operativas.
- No se ejecutó recuperación destructiva ni se repitieron las operaciones de 2A.

### 2.3 Fase 2B ejecutada — 2026-11-07

`[CONFIRMADO]` Fase 2B completada con **PASS** por el usuario en sesión SSH interactiva con
`sudo` normal. Evidencia: [02B](../docs/evidencia-infra-test-02b.md).

| Comprobación | Resultado |
| --- | --- |
| Identidad | `mftest` UID/GID `1002:1002`. |
| Raíz privada | `/srv/myfinanzas-test` de `mftest:mftest` `0700`. |
| Datos | `/srv/myfinanzas-test/data` `0700`; `data/state` ausente. |
| Releases y backups | Directorios `0700` de `mftest:mftest`, vacíos. |
| Raíz estática | `/var/www/myfinanzas-test` de `root:root` `0755`; `current` ausente. |
| Quadlet | `~mftest/.config/containers/systemd` `0700` de `mftest:mftest`. |
| Recursos | 35 GB libres; inodos utilizados 3 %. |
| Alcance | Sin cambios en DNS, Caddy, UFW, MyFinanzas, Datasette ni PROD. |

Consecuencias:

- AC04 de **aprovisionamiento** pasa a `PASS`.
- La **Fase 2 de aprovisionamiento** queda completada (2A + 2B).
- **No implica despliegue**: `data/state`, DB, `auth.key`, `current`, unidad, release, seed,
  DNS, Caddy, smoke y copias siguen pendientes de las fases 3–7.
- No se ejecutó recuperación destructiva.

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
sometido a aprobación. La auditoría de 2026-11-05 confirmó el entorno, pero no el diseño de
TEST ni creó usuarios o rutas.

### 4.1 Identidad, dominio y entrada

| Campo | Valor propuesto | Origen / estado |
| --- | --- | --- |
| `environment` | `test` (metadato del host; la app recibe `NODE_ENV=production` y `APP_ORIGIN`) | `[CONFIRMADO]` SPEC34. |
| `public_host` | `test.myfinanzas.pp.ua` | `[CONFIRMADO]` Contrato del packet y SPEC34. |
| `public_origin` | `https://test.myfinanzas.pp.ua` | `[CONFIRMADO]` SPEC34. |
| `root_site` | `myfinanzas.pp.ua` | `[CONFIRMADO]` Debe permanecer intacto. |
| `host_user` | `mftest`, sin login SSH ni contraseña, con `linger` | `[CONFIRMADO]` Creado y verificado en Fase 2A (2026-11-07); ver [evidencia 02A](../docs/evidencia-infra-test-02a.md). |
| `host_uid_gid` | `1002:1002` (asignado por el host; se registra) | `[CONFIRMADO]` Fase 2A; no se fija como regla de diseño. |
| `container_uid_gid` | `10001:10001` con `keep-id:uid=10001,gid=10001` | `[CONFIRMADO]` SPEC34 y `Containerfile`. |
| `unit_name` / `container_name` | `myfinanzas-test-api` | `[PROPUESTA]` |
| `caddy_upstream` | `127.0.0.1:18082` | `[PROPUESTA]` SPEC34 lo deja pendiente de esta spec. |
| `api_container_port` | `3001` | `[CONFIRMADO]` `main.ts`. |
| `api_bind_host` | `0.0.0.0` solo dentro del namespace | `[CONFIRMADO]` `server-config.ts`. |
| `static_root` | `/var/www/myfinanzas-test/current` | `[PROPUESTA]` |
| `dns_record` | `test` A/AAAA a la IP pública del VPS; TTL 300; sin wildcard | `[PROPUESTA]` IP `[PENDIENTE]`. |
| `tls` | HTTPS automático de Caddy; HTTP→HTTPS | `[CONFIRMADO]` Caddy 2.11.9; HTTPS del sitio raíz verificado; bloque TEST pendiente. |
| `caddy_version` | 2.11.9 desde el repositorio estable oficial Cloudsmith; `apt-mark hold` | `[CONFIRMADO]` [Cierre Caddy](../docs/auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md). |
| `caddy_caps` | Solo `CAP_NET_BIND_SERVICE`; *drop-in* `99-local-capabilities.conf` | `[CONFIRMADO]` Verificado en el proceso según evidencia del usuario. |
| `image` | `sha256:<ID inmutable del manifiesto>`; `Pull=never` | `[CONFIRMADO]` SPEC34. |
| `release_ref` | `myfinanzas-app/main` (TEST y PROD futuro); release distinta por SHA | `[PROPUESTA]` Sin rama `test`; el host no gestiona ramas. |
| `release_sha` | SHA de 40 caracteres seleccionado y registrado | `[PROPUESTA]` Se registra cuando exista release; inmutable y verificado por manifiesto. |
| `seed_image` | ID inmutable propio, solo tareas efímeras | `[PROPUESTA]` SPEC34 §4.2. |
| `schema_contract` | Declarado por el manifiesto de la release; el código actual declara `schemaVersion=27`; contract ID pendiente | `[PENDIENTE]` El host no fija el esquema; el manifiesto de release debe declarar el contrato exacto. |
| `resources` | 1 GiB RAM, 1 CPU, 128 pids, tmpfs 64 MiB | `[CONFIRMADO]` SPEC34 y RUNBOOK. |
| `host_capacity` | 2 vCPU, 3,8 GiB RAM, 35 GB libres, inodos 3 % | `[CONFIRMADO]` Auditoría; sin prueba de carga. |
| `disk_budget` | ≤ 5 GB para TEST; ≥ 20 % libre y ≥ 10 % de inodos | `[PROPUESTA]` 35 GB libres y 3 % de inodos medidos; confirmar en fase 2. |
| `retention` | Release actual + anterior; copia actual + anterior; sin poda global | `[PROPUESTA]` |
| `backup` | Copia cifrada local + externa; restore a destino nuevo | `[PROPUESTA]` SPEC34 §3.5; destino externo `[PENDIENTE]`. |
| `rollback` | Solo al par exacto release/imagen/esquema con prueba; si no, bloquear | `[CONFIRMADO]` SPEC34. |
| `secrets` | Ninguno en Git, PR, logs o imagen; `auth.key` 0600; identidad `age` fuera del VPS | `[CONFIRMADO]` SPEC34 y [security](guidelines/security.md). |

### 4.2 Red y exposición

`[PROPUESTA]` La topología actual está auditada: Caddy 2.11.9 en 80/443, UFW solo
22/80/443 y Podman 5.4.2 rootless. Falta validar Quadlet, la delegación cgroup y el bloque
TEST; no se asume que Caddy y el contenedor compartan red o permisos.

- `[CONFIRMADO]` Caddy 2.11.9 escucha 80/443 y sirve el sitio raíz; el bloque TEST está pendiente.
- `/api/*` se reenvía a `127.0.0.1:18082`.
- El contenedor escucha `3001` con bind `0.0.0.0` **solo dentro de su namespace**.
- `3001` no se publica en el host; SQLite no se expone; Vite `5173` no se publica.
- No se usa `Network=host`, `--privileged`, socket de Podman, `:U` ni montajes de dispositivos.
- El puerto `18082` debe quedar en loopback; la publicación rootless se verifica con
  `ss -ltnp` y con un intento externo fallido.
- Caddy debe poder leer `/var/www/myfinanzas-test/current`; el usuario de Caddy y los
  permisos reales se determinan en la auditoría.
- No se abre ningún puerto nuevo en UFW para TEST. `[CONFIRMADO]` La entrada pública actual
  es solo 22/80/443 y no se modifica sin autorización específica.

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

`[CONFIRMADO]` La raíz privada, `data`, `releases`, `backups`, la raíz estática y los
directorios Quadlet se crearon con los propietarios y modos indicados en la Fase 2B. No se
crearon `data/state`, DB, `auth.key` ni `current`; pertenecen a las fases 5–6. No se
reutiliza el directorio de backups del operador para TEST. Evidencia:
[02B](../docs/evidencia-infra-test-02b.md).

`[CONFIRMADO]` El propietario efectivo del host no tiene por qué coincidir con el UID
interno 10001; `keep-id` mapea la identidad. La verificación debe comprobar el mapeo real y
que los archivos son legibles/escriturables por el UID efectivo de la app, no solo por
`mftest`.

### 4.4 Recursos, secretos y límites

- `[CONFIRMADO]` Memoria 1 GiB, CPU 1, pids 128 y tmpfs 64 MiB para el contenedor.
- `[PROPUESTA]` Presupuesto de disco ≤ 5 GB para TEST, con márgenes mínimos de 20 % libre
  y 10 % de inodos antes de desplegar. `[CONFIRMADO]` El host tiene 35 GB libres y 3 % de
  inodos según la Fase 2B; se vuelve a medir antes del despliegue.
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
| `release_ref` | `myfinanzas-app/main` para TEST y PROD futuro | Sin rama `test`; release distinta por SHA. |
| `release_sha` | SHA de 40 caracteres del candidato seleccionado | Se registra cuando exista release; no se infiere de una etiqueta. |
| `seed_image` | ID inmutable propio; solo tareas efímeras | SPEC34 §4.2. |
| `schema_contract` | Declarado por el manifiesto; el código actual declara `schemaVersion=27`; contract ID pendiente | Se verifica por release; el manifiesto debe declarar el contrato exacto; no se fija permanentemente en el host. |
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
  `manifest.sha256`, construido desde el SHA seleccionado de `myfinanzas-app/main` (TEST) con
  ID inmutable y `--expected-commit`.
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
  `schema_version`/`schema_contract` declarados por el manifiesto de la release,
  conteos e IDs de `FT-1`.
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
3. Release y seed verificados por manifiesto, construidos desde el SHA seleccionado de `myfinanzas-app/main`; gate Rootless en `SUCCESS` sobre ese SHA.
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

`[CONFIRMADO]` El apex `myfinanzas.pp.ua` tiene A con TTL 14400, sin AAAA ni CAA;
`test.myfinanzas.pp.ua` responde NXDOMAIN; el proveedor es `uadns.com` según la auditoría.
La IP pública no se documenta aquí.

`[PROPUESTA]` Añadir, con autorización del usuario y tras la auditoría:

```text
test.myfinanzas.pp.ua. 300 IN A    <IP_PUBLICA_VERIFICADA>
test.myfinanzas.pp.ua. 300 IN AAAA <IPv6_PUBLICA_VERIFICADA, si existe>
```

- No crear wildcard. No modificar `myfinanzas.pp.ua` ni sus registros.
- Si el dominio raíz usa proxy/CDN, **no** copiar ese registro al subdominio TEST sin
  decisión expresa; `test` debe apuntar a la IP del VPS.
- Verificar A/AAAA con resolutores públicos antes de habilitar Caddy.
- La IP, el proveedor DNS y el TTL reales se registran en la evidencia; no se inventan. El
  apex usa TTL 14400; el registro `test` puede usar TTL 300 sin tocar el apex.
- Crear el registro `test` no acredita HTTPS ni entorno operativo.

### 7.2 Caddy y HTTPS

`[CONFIRMADO]` Caddy 2.11.9 está activo, con `hold` y solo `CAP_NET_BIND_SERVICE`; no se
modifica su *drop-in* ni el sitio raíz para TEST.

`[CONFIRMADO]` El `Caddyfile` actual tiene 68 B; contiene el sitio `myfinanzas.pp.ua`, `root`
y `file_server`, sin `reverse_proxy` ni bloque TEST. `caddy validate` con 2.11.9 devuelve
configuración válida. No se modifica aún: el bloque TEST se prepara en la fase 4 con backup,
hash/diff y validación, y no se recarga hasta que app/seed estén listos.

`[PROPUESTA]` Bloque independiente para `test.myfinanzas.pp.ua`. La ubicación exacta
(`Caddyfile` principal o fichero importado) se decide en la fase 4, con backup y validación.
No se sustituye ni se edita el sitio raíz sin backup y autorización.

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
  al crear la ruta en la fase 2; Caddy ya corre como `caddy` y la ruta aún no existe.

### 7.3 UFW y loopback

`[CONFIRMADO]` UFW está activo con entrada `deny` y solo 22/80/443 IPv4/IPv6; no hay reglas
para 18082, 3001 ni 2019. TEST no está desplegado.

- `18082` solo escucha en `127.0.0.1`; `3001` no se publica en el host; SQLite no es
  accesible; Vite no se publica.
- UFW no abre puertos nuevos para TEST. La entrada pública actual (22/80/443) no se modifica
  sin autorización específica.
- Comprobar con `ss -ltnp`, `ufw status numbered`, `podman port` y un intento externo
  fallido contra `18082` y `3001`.
- No se modifican reglas, zonas ni servicios de otras aplicaciones para «hacer sitio».

### 7.4 Copia local y externa

`[CONFIRMADO]` Existe una recuperación de Caddy en
`/root/caddy-upgrade-20261105T151652Z` (`0700`, retención hasta 2026-12-05): paquetes,
configuración y datos de Caddy. **No es un backup de MyFinanzas TEST**, su inventario y
restauración no se han verificado y no se borra ni modifica sin autorización.

`[PROPUESTA]` Antes de habilitar Caddy:

- Copia cifrada con `age` desde la misma imagen/UID de la app, con snapshot SQLite coherente
  y la clave de autenticación; no se copian DB/WAL por separado.
- Copia local en `/srv/myfinanzas-test/backups` `0700` y copia fuera del VPS en el destino
  aprobado por el usuario.
- Checksums origen/destino, retención de la copia actual y la anterior, y verificación de
  que la identidad `age` no reside permanentemente en el VPS.
- Sin secretos, bases en claro ni claves en Git, PR, logs o chat.
- DT6/T-BKP sigue abierto: esta copia es un mínimo de TEST, no un RPO/RTO de producción. El
  destino externo y la custodia de la identidad `age` siguen `[PENDIENTE]`.

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
- Rollback de Caddy desde la copia existente, con `caddy validate`, recarga y comprobación
  del sitio raíz. La copia no se ha restaurado ni ensayado; AC-18 sigue `UNRUN`.
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
[test plan](02-infra-test-01-host-testplan.md). AC03 y AC04 pasan a `PASS` con las evidencias
2A/2B; el resto sigue `UNRUN`. La Fase 2 de **aprovisionamiento** está completada, pero no
implica despliegue ni declara TEST operativo.

La auditoría de 2026-11-05 cubrió SO/recursos/SSH/UFW/Caddy/Podman/DNS y el estado de
backups, pero **no completó** la revalidación de Quadlet/cgroup ni el inventario profundo de
backups. Por eso AC02 no se marca `PASS`. AC10 queda pendiente de la release/seed desde
`main`; el contrato de integración lo declara el manifiesto de la release y no se fija permanentemente.

| ID | Criterio verificable | Fase |
| --- | --- | --- |
| `INFRA-TEST-01-HOST-AC01` | La rama solo añade esta spec y su test plan; no toca código, `infra/`, workflows, `docs/` operativos ni el VPS; no hay acceso remoto, deploy ni merge. | 0 |
| `INFRA-TEST-01-HOST-AC02` | Auditoría de solo lectura completada y redactada: identidad/SO/recursos, servicios, puertos, SSH, UFW, Caddy, DNS, Podman/Quadlet, usuarios, disco/inodos y backups; sin cambios y con diferencias frente a lo informado. | 1 |
| `INFRA-TEST-01-HOST-AC03` | `mftest` existe como usuario dedicado, sin login SSH ni contraseña, con `subuid`/`subgid`, `linger` y `systemd --user` operativo; UID/GID registrados y sin reutilizar `mfadmin`. | 2 |
| `INFRA-TEST-01-HOST-AC04` | Rutas y permisos de aprovisionamiento: raíz privada `0700`, `data` `0700`, `releases`/`backups` `0700`, estático `0755` de `root`, Quadlet `0700`; sin `data/state`, `current`, symlinks ni archivos inesperados. | 2 |
| `INFRA-TEST-01-HOST-AC05` | `test.myfinanzas.pp.ua` resuelve A/AAAA a la IP pública verificada, sin wildcard; el registro raíz y el proveedor no cambian; la resolución se confirma con resolutores públicos. | 3 |
| `INFRA-TEST-01-HOST-AC06` | Caddy valida un bloque independiente para TEST, sirve HTTPS válido, redirige HTTP→HTTPS, aplica CSP/HSTS corto/noindex/nosniff, proxyfica `/api/*` a `127.0.0.1:18082` sin fallback SPA y sirve el estático desde `current`; el sitio raíz sigue intacto. | 4, 6 |
| `INFRA-TEST-01-HOST-AC07` | La unidad Quadlet está activa y habilitada al arranque por `linger`, usa imagen inmutable `Pull=never`, `keep-id` 10001, publica `127.0.0.1:18082:3001`, limita 1 GiB/1 CPU/128 pids, rootfs de solo lectura, tmpfs 64 MiB y no referencia la imagen de seed. | 5 |
| `INFRA-TEST-01-HOST-AC08` | `/api/health` responde `200` `{"ok":true}` en loopback y HTTPS; una ruta protegida sin sesión responde `401`; no hay bypass de autenticación. | 5, 6 |
| `INFRA-TEST-01-HOST-AC09` | `18082` solo escucha en loopback; `3001`, SQLite y Vite no son accesibles desde fuera; UFW no abre puertos nuevos; los intentos externos fallan y otros servicios, incluida la futura PROD, no se alteran. | 2, 6 |
| `INFRA-TEST-01-HOST-AC10` | El host ejecuta el artefacto test-only en el orden `production-init → seed init/apply/verify → setup`; `test-instance.json` `0600`, manifiesto/checksums coinciden, las guardas rechazan origen/ruta/permisos/esquema/propietario/estado incorrectos y el reset archiva sin borrar. | 5 |
| `INFRA-TEST-01-HOST-AC11` | Copia cifrada local y externa verificadas, con snapshot SQLite coherente y clave de autenticación; checksums origen/destino, retención actual+anterior y ausencia de secretos en Git/logs. | 6 |
| `INFRA-TEST-01-HOST-AC12` | Restauración aislada a destino nuevo con MFA: health `200`, `401` y `FT-1` visibles; estado activo intacto; fallo preserva origen, copia y destino; RTO registrado. | 7 |
| `INFRA-TEST-01-HOST-AC13` | Rollback de app sin prueba del par exacto se bloquea y preserva datos; rollback de Caddy desde backup validado deja el sitio raíz intacto; sin downgrade forzado ni sobrescritura del estado activo. | 7 |
| `INFRA-TEST-01-HOST-AC14` | `myfinanzas.pp.ua` y su DNS/HTTP/HTTPS siguen respondiendo igual antes y después; solo se añadió el registro `test`; no se modificó el bloque raíz de Caddy, UFW ni otros servicios, incluida la futura PROD. | 6, 8 |
| `INFRA-TEST-01-HOST-AC15` | La retirada autorizada detiene la unidad, retira Caddy/DNS de TEST, deshabilita `linger` si procede y preserva datos/copias; el dominio raíz queda intacto y no hay borrado sin inventario. | 8 |
| `INFRA-TEST-01-HOST-AC16` | TEST respeta el presupuesto de disco acordado y los márgenes de espacio/inodos; memoria, CPU y pids se miden dentro de los límites y sin afectar a otros servicios. | 6 |
| `INFRA-TEST-01-HOST-AC17` | No hay Excel, bases reales, exportaciones, credenciales, TOTP, cookies, claves ni datos personales en host, repo, logs o copias; solo `FT-1` identificable y evidencia redactada. | 5, 6 |
| `INFRA-TEST-01-HOST-AC18` | La release TEST se construye desde un SHA inmutable de `myfinanzas-app/main`, registrado con `release_ref=myfinanzas-app/main` y `release_sha`; se comprueba que el SHA es ancestro de `origin/main` y no se usa una etiqueta móvil; PROD futuro usará `main`; el host no gestiona ramas. | 5 |
| `INFRA-TEST-01-HOST-AC19` | Estado y artefactos de despliegue: `data/state` `0700`, DB y `auth.key` `0600`, `current` atómico dentro de la raíz y sin symlinks/hardlinks en el estado. | 5 |

### 8.1 Trazabilidad con SPEC34

| Host AC | SPEC34 AC relacionadas | Relación |
| --- | --- | --- |
| AC01 | AC01 | Alcance documental y ausencia de cambios. |
| AC02–AC04 | — | Controles propios del host (auditoría, identidad, rutas de aprovisionamiento). |
| AC19 | — | Estado, DB, `auth.key` y `current` antes de sembrar. |
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
| AC18 | — | Selección de release TEST desde `myfinanzas-app/main`; PROD desde `main`; el host no gestiona ramas. |

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
| 5 | Despliegue y seed | Usuario | Release de `main` verificada, seed `0`, unidad activa, frontend | UNRUN |
| 6 | Smoke y copias | Usuario | HTTPS/health/401, `FT-1`, límites, copia local/externa | UNRUN |
| 7 | Restauración y rollback | Usuario | Restore aislado, rollback bloqueado/ensayado | UNRUN |
| 8 | Retirada | Usuario | Unidad/DNS/Caddy retirados, datos preservados, raíz intacta | UNRUN |

La auditoría de 2026-11-05 ejecutó parte de la fase 1; **no se declara completa** porque
Quadlet/cgroup y el inventario profundo de backups siguen pendientes. Las fases 2–8 no están
autorizadas.

`[PROPUESTA]` El orden 3→4→5 es de **preparación**. El registro DNS `test` puede crearse
antes de que la app esté lista, pero no acredita HTTPS ni entorno operativo. La recarga de
Caddy que publica TEST se ejecuta solo cuando la unidad está activa y el seed verificado; si
se prepara antes, se acepta una ventana 502 y no se declara operativo. La fase 6 es la que
acredita HTTPS, smoke y copias.

## 10. Dependencias, riesgos y decisiones

### 10.1 Dependencias

| Dependencia | Estado | Efecto |
| --- | --- | --- |
| Contrato de integración (SPEC34 §5) | Vigente; actualización de esquema/seed a cargo de MyFinanzas | Contrato de app; no autoriza DEV ni deploy. |
| Esquema/seed por release | Declarado en el manifiesto del SHA y de cada release | Seed/AC10 usan el contrato declarado; no se ancla a una versión fija. |
| Release, imagen y artefacto de seed | No construidos | Sin ellos, fases 5–8 no ejecutables. |
| E4.9 / v25 | Estado de desarrollo en MyFinanzas | TEST usa el esquema declarado por el manifiesto de la release; no se fija una versión concreta. |
| E4.5 / DT7 | QA APTO; DT7 abierto; DEV no autorizado | Sin históricos ni transición de ejercicio. |
| E4.7 / E4.10 / E4.11 | Estado de desarrollo en MyFinanzas | Fuera del dataset y del smoke por D5. |
| Flujo actual `feature/* → main` | Sin rama `test`; TEST usa SHA de `main` | Deploy manual e independiente de los merges; host no gestiona ramas. |
| DT6 / T-BKP | Abierto | Afecta a backup/restore; TEST exige mínimo local+externo. |
| Gate Rootless | Obligatorio por RUNBOOK | Sin `SUCCESS` sobre el SHA de `main` no se despliega TEST. |
| Promoción TEST → PROD | Responsabilidad de `myfinanzas-app` | El host no promociona ni cambia ramas; PROD tendrá su propio despliegue. |
| Caddy real | 2.11.9 auditado, `active`, `hold`; `Caddyfile` mínimo | Bloque TEST sujeto a backup, `caddy validate` y rollback. |
| DNS real | Apex A/TTL 14400 conocido; `test` NXDOMAIN | Sin registro `test` no hay TLS ni entorno operativo. |
| Flake SQLite **B3** | Sin reproducción Linux | Puede aparecer en el ensayo; no se oculta. |
| VPS 2 vCPU / 3,8 GiB / 40 GB, 35 GB libres, inodos 3 % | `[CONFIRMADO]` auditoría | Presupuesto pequeño; límites y medición obligatorios. |
| Quadlet y delegación cgroup | Delegación `cpu memory pids` y binario Quadlet verificados; unidad real y reboot no probados | H1 confirmada; H5 pendiente de la unidad real; bloquea fase 5. |
| Acceso al host | Auditoría de solo lectura y Fases 2A/2B ejecutadas; fases 3–8 no autorizadas | Fases 3–8 bloqueadas. |

### 10.2 Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Caddy mal editado | Interrupción del sitio raíz | Backup, `caddy validate`, recarga controlada y rollback; Caddy 2.11.9 ya validado. |
| Contrato de integración sin release/seed | Seed/schema no conformes | Construir release/seed desde `main` y verificar el contrato declarado. |
| `hold` de Caddy sin revisión | Falta de parches | Revisión mensual registrada; `unhold` solo en ventana. |
| Unidad Quadlet no probada | Unidad no persiste | Prueba aislada de unidad y reboot antes de fase 5; delegación ya verificada. |
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
| SHA no verificado o etiqueta móvil | Versión no validada | Registrar `release_ref=myfinanzas-app/main` y `release_sha`; rechazar etiquetas. |
| Configuración TEST aplicada a PROD | Interrupción o fuga entre entornos | Usuarios, unidades, datos, puertos, Caddy y DNS separados; revisión de diff. |
| Retirada sin inventario | Pérdida de datos/copias | Preservar, inventariar y autorizar antes de borrar. |
| Auditoría que expone secretos | Fuga de información | Evidencia redactada; no volcar claves, cookies ni bases. |

### 10.3 Decisiones de host propuestas

| ID | Decisión | Recomendación | Estado tras revisiones 2026-11-05 y Fases 2A/2B (2026-11-07) |
| --- | --- | --- | --- |
| H1 | Identidad | Usuario dedicado `mftest`, rootless, sin login SSH, con `linger`. | `[CONFIRMADO]` Fase 2A (2026-11-07): UID/GID 1002, subuid/subgid 231072:65536, linger y `systemd --user` operativos; Quadlet real y reboot pendientes. |
| H2 | Exposición | Caddy → `127.0.0.1:18082` → `3001`; sin publicar API/DB/Vite. | `[PROPUESTA]` Compatible con Caddy 2.11.9 y UFW 22/80/443; no requiere puertos nuevos. |
| H3 | Rutas | `/srv/myfinanzas-test/{data,releases,backups}` y `/var/www/myfinanzas-test/current`. | `[CONFIRMADO]` Fase 2B: raíz, datos, releases, backups y raíz estática creados con los modos indicados; `data/state` y `current` siguen pendientes de despliegue. No reutilizar backups de `mfadmin`. |
| H4 | Seed | Consumir el artefacto test-only en orden `production-init → seed → setup`, con marcador/manifiesto y reset archivado. | `[CONFIRMADA]` SPEC34 D1–D5; bloqueada por la actualización del contrato en MyFinanzas y el artefacto de seed. |
| H5 | Unidad | Unidad TEST propia de `vps-infra`; no reutilizar `runtime.py:render` de PROD. | `[CONFIRMADA]` D6; pendiente validar Quadlet/cgroup. |
| H6 | Recuperación | Copia local+externa cifrada antes de habilitar Caddy; restore aislado en fase 7 antes de declarar TEST operativo. | `[PENDIENTE]` El destino externo y la custodia de `age` siguen sin aprobar; la copia de Caddy no cubre la app. |

`[PROPUESTA]` Revisión H1–H6: la arquitectura sigue siendo la más simple para 2 vCPU/3,8 GiB;
no añade contenedores ni puertos. H1 y las rutas base de H3 están confirmadas por 2A/2B; H5
sigue pendiente de la unidad Quadlet real y reboot; H4 depende del contrato de app; **H6 es
la decisión material pendiente** junto con el destino externo. Esta revisión no aprueba
H1–H6 ni autoriza despliegue.

### 10.4 Aprobaciones que requieren al usuario

| Tema | Qué se decide | Bloquea |
| --- | --- | --- |
| Contrato de integración | MyFinanzas actualice SPEC34/test plan y entregue release/seed con el contrato declarado | Fase 5; sin release/seed AC10 no es válido |
| Backup externo y recuperación (H6) | Destino, custodia de la identidad `age`, retención, RPO/RTO mínimo y prueba de restore | Fase 6 (copia) y fase 7 (restore) |
| Diseño host H1–H3 | `mftest`, loopback `18082`, rutas `/srv` y `/var/www` | Fase 2 completada; despliegue en fase 5 |
| Quadlet/cgroup | Validar Podman 5.4.2, `linger`, `systemd --user` y arranque tras reboot | Fases 2 y 5 |
| DNS TEST | Crear `test` A/AAAA sin tocar el apex | Fase 3 |
| Ventana y operador | Quién ejecuta cada fase y cuándo | Fases 2–8 |

## 11. Coordinación con myfinanzas-app

`[CONFIRMADO]` El contrato de integración es
[SPEC34 §5](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md#5-contrato-de-despliegue-con-vps-infra-solo-interfaz)
y el manifiesto de cada release. MyFinanzas actualiza su propio contrato de esquema/seed;
`vps-infra` no rastrea PRs de la aplicación. El flujo actual es `feature/* → main`; TEST
consumirá una release de un SHA inmutable de `myfinanzas-app/main` y PROD futuro, de `main`.
No hay rama `test`. El despliegue de TEST es manual e independiente de los merges; `main` no
se considera todavía producción. Esta spec **no abre una segunda spec de aplicación** ni
gestiona ramas.

- **Qué posee la app:** release, imagen, frontend, runtime, seed test-only, dataset `FT-1`,
  manifiesto/checksums, `production-init`, `setup`, backup/restore y evidencia Rootless.
- **Qué posee este entregable:** host, usuario, rutas, permisos, UFW, Caddy, TLS, DNS,
  Quadlet, unidad TEST, copias del host, restauración, rollback y retirada.
- **Interfaz:** cualquier cambio de puerto, env, ruta, health, CLI o artefacto se documenta
  en SPEC34 (o su sucesora) y se revisa aquí antes de la fase 5. No se acepta una unidad
  desincronizada.
- **Secuencia:** la app debe entregar release y seed verificados antes de la fase 5 del
  host. Las fases 1–4 del host pueden preparar el terreno, pero no declaran TEST operativo.
- **Test plans:** el de la app cubre sus AC, incluidas AC04–AC09, AC12, AC14, AC15, AC17 y
  AC19 de la app; este plan cubre los AC host y enlaza la trazabilidad de §8.1. Ningún
  resultado se hereda.
- **Merge:** la aprobación de SPEC34 no autoriza DEV, release, despliegue ni merge. El
  estado de sus PRs se consulta en el repositorio de la app; no se infiere permiso operativo.

### 11.1 Flujo de versiones, validación y despliegue

| Etapa | Responsable | Entrada | Salida | Host |
| --- | --- | --- | --- | --- |
| Selección | `myfinanzas-app` | HEAD de `myfinanzas-app/main` con SHA de 40 caracteres | `release_ref=myfinanzas-app/main`, `release_sha`, manifiesto | Registra el SHA; no gestiona la rama |
| Construcción | `myfinanzas-app` | SHA seleccionado | Release + seed + manifiestos e IDs inmutables | No reconstruye ni parchea |
| Validación | `myfinanzas-app` + `vps-infra` | Artefactos y gate Rootless | CI/Rootless `SUCCESS` y validaciones de host | Fase 5; no declara TEST operativo antes |
| Despliegue TEST | `vps-infra` | Release de `main` verificada | Unidad/servicio TEST | Manual e independiente de los merges |
| PROD futuro | `myfinanzas-app` + futuro host | Release de `main` aprobada | Servicio PROD aislado | Fuera de esta spec; autorización separada |

Reglas:

- Flujo actual: `feature/* → main`; **no hay rama `test`** ni se exige para TEST.
- Integrar una PR **no despliega**; el despliegue de TEST es manual y no automatizado.
- `vps-infra` mantiene una sola rama `main`; no crea ni gestiona ramas de `myfinanzas-app`.
- TEST y la futura PROD usan usuarios, unidades, raíces de datos, directorios, puertos de
  loopback, bloques de Caddy y registros DNS separados. No comparten sockets ni estado.
- El contrato de esquema/seed viaja en el manifiesto de cada release; el host no fija el
  esquema 25 de forma permanente ni reutiliza una release de otro SHA.

## 12. Trazabilidad y límites de las afirmaciones

- `[CONFIRMADO]` Los hechos de §2 proceden de la auditoría de solo lectura 2026-11-05 y del
  [cierre de Caddy](../docs/auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md) (evidencia
  del usuario posterior a la actualización).
- `[CONFIRMADO]` SO, recursos, SSH, UFW, Caddy 2.11.9, Podman 5.4.2 y DNS apex están
  auditados; Quadlet/cgroup y el inventario de backups siguen pendientes.
- `[PROPUESTA]` Rutas, usuario `mftest`, puerto `18082`, DNS, Caddy, unidad, copias y
  presupuesto de disco son diseño, no implementación ni estado real.
- `[PENDIENTE]` La aprobación de esta enmienda, la actualización del contrato de integración en
  MyFinanzas, la selección del SHA de `main`, la provisión y las fases 2–8.
- `[PROPUESTA]` El flujo actual es `feature/* → main`; no hay rama `test`. TEST se despliega
  manualmente desde un SHA de `main`, sin automatización; `main` no se considera producción
  todavía. `vps-infra` conserva una sola `main`.
- Ningún `UNRUN` es `PASS` ni `FAIL`. No se hereda evidencia de otras entregas.
- Las rutas de host citadas son propuestas; no son directorios verificados ni un contrato
  vigente hasta que la fase 1 y la aprobación lo confirmen.
- La aprobación de esta spec no autoriza DEV, VPS, DNS, Caddy, deploy, datos reales ni merge.
