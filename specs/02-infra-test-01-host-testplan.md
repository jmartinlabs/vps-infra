# 02 — INFRA-TEST-01-HOST: Test plan

Specification: [02 — host del entorno TEST de MyFinanzas](02-infra-test-01-host-specification.md)

Status: **DRAFT — ejecución `UNRUN`; sin ningún `PASS`.** No autoriza DEV, acceso al VPS,
auditoría, DNS, Caddy, UFW, Podman/Quadlet, despliegue, datos reales ni merge.
Base: `vps-infra` `main` `b45ffeb9ceaae9b656a5db6e11f90b12d3a72198` (2026-11-05).
Auditoría y Caddy: [auditoría 2026-11-05](../docs/auditorias/2026-11-05-infra-audit-vps-001-cierre.md)
y [cierre Caddy](../docs/auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md).
Contrato de integración MyFinanzas ↔ `vps-infra`:
[SPEC34 §5](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md#5-contrato-de-despliegue-con-vps-infra-solo-interfaz)
y manifiesto de cada release. `vps-infra` no rastrea PRs de la aplicación. Flujo actual
`feature/* → main`: TEST consume una release de un SHA inmutable de `myfinanzas-app/main`;
PROD futuro, de `main`; no hay rama `test`; el despliegue es manual y no automatizado.
Antecedente histórico: [vps-infra PR #7](https://github.com/jmartinlabs/vps-infra/pull/7)
(CLOSED, no mergeado); no es contrato vigente.

> **Nota de verificación.** El packet describe PR #207 como «no mergeado». La consulta de
> solo lectura a GitHub devuelve `MERGED` (head `8fe839c`, merge commit `58346e1`). Se
> registra la discrepancia; no se infiere autorización de DEV ni de despliegue.

## 1. Cómo leer este plan

- **Estado.** Todos los criterios empiezan en `UNRUN`. `UNRUN` no es `PASS` ni `FAIL`; solo
  indica que no hay evidencia ejecutada. Un `PASS` exigiría comando real, entorno, candidato
  y evidencia enlazada; este plan no lo declara.
- **Entorno.** Cada criterio declara dónde se ejecuta. Un runner efímero no acredita el VPS
  Debian ni Caddy/DNS reales.
- **Owner.** Quién ejecuta y quién revisa. El owner operativo no aprueba la fase.
- **Fase.** La fase de §4 que debe estar autorizada antes de ejecutar.
- **Evidencia.** Qué se conserva en el expediente privado del operador. Nunca se publican
  secretos, cookies, TOTP, importes, IPs privadas ni bases de datos.
- **Dependencia.** Sin release/seed de la app, los casos de fase 5–8 quedan bloqueados, no
  «aprobados por omisión».

## 2. Entornos de prueba

| ID | Entorno | Qué acredita | Qué **no** acredita |
| --- | --- | --- | --- |
| E0 | Checkout local limpio y diff de la rama | Alcance documental, enlaces, clasificación y ausencia de cambios | Estado del VPS, Caddy, DNS o Podman |
| E1 | Host de ensayo aislado o runner Linux efímero | Sintaxis de unidad, permisos, seed, backup/restore sintéticos | Debian 13, Caddy, DNS, UFW y disco reales |
| E2 | VPS real auditado el 2026-11-05; TEST no desplegado | Estado actual de SO, SSH, UFW, Caddy 2.11.9, Podman, DNS y disco | Usuario, rutas, unidad TEST, loopback y persistencia de TEST |
| E3 | Red externa y resolutores públicos | DNS, TLS, cabeceras, cookies y no exposición de puertos | Estado interno del host |
| E4 | Destino externo de copia aprobado por el usuario | Copia off-VPS y restauración desde ella | Custodia definitiva, SLA o RPO/RTO de producción |

## 3. Matriz de criterios de aceptación

Todos los estados son `UNRUN`. Los placeholders `<…>` se sustituyen solo con valores
verificados y redactados.

| ID | Precondiciones y acción | Resultado esperado | Método / comando previsto | Entorno | Owner | Fase | Evidencia | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `INFRA-TEST-01-HOST-AC01` | Revisar el diff de la rama y la lista de archivos; comprobar que solo se añaden spec y test plan | Sin cambios de código, `infra/`, workflows, `docs/` operativos ni VPS; sin deploy ni merge | `git status --short`; `git diff --stat main...HEAD` (tras el commit de la rama); `git diff --check main...HEAD`; `python3 scripts/check_harness.py`; `./scripts/validate-template` | E0 | vps-infra / QA | 0 | Diff, lista de archivos y salida de checks | UNRUN |
| `INFRA-TEST-01-HOST-AC02` | Auditoría de solo lectura autorizada; registrar sin secretos | Inventario redactado de SO/recursos/servicios/puertos/SSH/UFW/Caddy/DNS/Podman/Quadlet/usuarios/disco/backups; diferencias frente a lo informado; ningún cambio | `hostnamectl`; `cat /etc/os-release`; `timedatectl`; `ss -ltnp`; `ufw status verbose`; `podman info`; `systemctl --user list-units`; `caddy version`; `dig`; `df -h`; `df -i`; `findmnt`; `getent passwd`; `loginctl list-users`; `ls -ld` | E2 | vps-infra / QA | 1 | Informe redactado con fecha, comandos y diferencias; sin volcar secretos | UNRUN |
| `INFRA-TEST-01-HOST-AC03` | Autorizar provisión; crear/verificar usuario dedicado | `mftest` existe, sin login SSH ni contraseña, con `subuid`/`subgid`, `linger` y `systemd --user` operativo; UID/GID registrados; `mfadmin` no se reutiliza | `id mftest`; `getent passwd mftest`; `grep -E '^mftest:' /etc/subuid /etc/subgid`; `loginctl show-user mftest -p Linger`; `sudo -iu mftest systemctl --user status`; revisión de `sshd_config`/`AllowUsers` | E2 | vps-infra / QA | 2 | Salida de identidad, `linger`, subuid/subgid y estado de usuario | UNRUN |
| `INFRA-TEST-01-HOST-AC04` | Verificar rutas y permisos antes de sembrar | Raíz privada `0700`; `data`/`state` `0700`; DB y `auth.key` `0600`; `releases`/`backups` `0700`; estático `0755` de `root`; `current` atómico dentro de la raíz; sin symlinks/hardlinks en estado | `namei -l`; `stat -c '%a %U:%G %n'`; `find`; `readlink -f`; `findmnt`; `getfacl` si aplica | E2 | vps-infra / QA | 2, 5 | Árbol de rutas, propietarios, modos y destino de `current` | UNRUN |
| `INFRA-TEST-01-HOST-AC05` | Autorizar DNS; consultar antes/después | `test` resuelve A/AAAA a la IP pública verificada, sin wildcard; el registro raíz no cambia; resolución coherente en resolutores públicos | `dig +short test.myfinanzas.pp.ua A`; `dig +short test.myfinanzas.pp.ua AAAA`; `dig @1.1.1.1`; `dig @8.8.8.8`; `dig +short myfinanzas.pp.ua` antes/después | E3 | vps-infra / usuario | 3 | Respuestas DNS antes/después, proveedor, TTL y comparación del registro raíz | UNRUN |
| `INFRA-TEST-01-HOST-AC06` | Caddy preparado y validado; unidad y seed listos para la recarga que publica TEST | Bloque independiente válido; HTTPS válido; HTTP→HTTPS; CSP/HSTS corto/noindex/nosniff; `/api/*` a `127.0.0.1:18082` sin fallback SPA; estático desde `current`; sitio raíz intacto | `caddy validate --config <CADDYFILE>`; `caddy reload`; `curl -D- https://test.myfinanzas.pp.ua/api/health`; `curl -I http://test.myfinanzas.pp.ua`; `openssl s_client -connect test.myfinanzas.pp.ua:443 -servername test.myfinanzas.pp.ua`; `curl -D- https://myfinanzas.pp.ua` | E2, E3 | vps-infra / usuario | 4, 6 | Backup y diff de Caddy, `validate`, cabeceras, certificado y respuesta del sitio raíz | UNRUN |
| `INFRA-TEST-01-HOST-AC07` | Unidad autorizada e instalada con imagen verificada | Unidad activa y habilitada al arranque por `linger`; `Pull=never`; `keep-id` 10001; publica `127.0.0.1:18082:3001`; 1 GiB/1 CPU/128 pids; rootfs solo lectura; tmpfs 64 MiB; sin imagen de seed | `systemctl --user cat myfinanzas-test-api`; `systemctl --user show myfinanzas-test-api -p ActiveState,UnitFileState,MainPID`; `podman inspect myfinanzas-test-api`; `systemd-analyze verify` si aplica; `loginctl show-user mftest -p Linger` | E2 | vps-infra / QA | 5 | Unit file, estado, `podman inspect`, límites y reinicio tras logout/reboot | UNRUN |
| `INFRA-TEST-01-HOST-AC08` | Unidad activa y ruta publicada | `/api/health` → `200` `{"ok":true}` en loopback y HTTPS; ruta protegida sin sesión → `401`; sin bypass | `curl -fsS http://127.0.0.1:18082/api/health`; `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18082/api/saldos`; equivalentes HTTPS | E2, E3 | vps-infra / QA | 5, 6 | Códigos, cuerpo de health y cabeceras; sin cookies ni tokens | UNRUN |
| `INFRA-TEST-01-HOST-AC09` | Unidad activa; revisar red y firewall | `18082` solo loopback; `3001` no publicado; SQLite y Vite no accesibles; UFW sin puertos nuevos; intentos externos fallan; otros servicios intactos | `ss -ltnp`; `ufw status numbered`; `podman port myfinanzas-test-api`; `curl`/`nc` externos a `18082` y `3001`; comparación de servicios | E2, E3 | vps-infra / QA | 2, 6 | Inventario de puertos, reglas UFW, intentos fallidos y servicios sin cambios | UNRUN |
| `INFRA-TEST-01-HOST-AC10` | Release y seed de la app disponibles; unidad parada; estado inexistente | Orden `production-init → seed init/apply/verify → setup`; `test-instance.json` `0600`; manifiesto/checksums coinciden; guardas rechazan origen/ruta/permisos/esquema/propietario/estado; reset archiva sin borrar; unidad sin imagen de seed | Tareas efímeras de `podman run --rm --network=none`; `seed verify --expected-manifest-sha256`; `sha256sum`; `stat`; casos negativos de §5; `test -f` del marcador | E2 | vps-infra / myfinanzas-app / QA | 5 | Códigos `0/2/3`, manifiesto, checksums, árbol de estado y ausencia de seed en la unidad | UNRUN |
| `INFRA-TEST-01-HOST-AC11` | Seed verificado; destino externo aprobado | Copia cifrada local y externa con snapshot SQLite coherente y clave; checksums origen/destino; retención actual+anterior; identidad `age` fuera del VPS; sin secretos en Git/logs | `backup-cli create <DESTINO_NUEVO> <DESTINATARIO_AGE>`; `sha256sum`; copia al destino externo; `age` solo en entorno autorizado; `ls -l`; revisión de logs | E2, E4 | myfinanzas-app / usuario / vps-infra | 6 | Checksums, rutas lógicas, retención y confirmación de destino | UNRUN |
| `INFRA-TEST-01-HOST-AC12` | Copia externa verificada; destino nuevo aislado | Restore con MFA: health `200`, `401` y `FT-1`; estado activo intacto; fallo preserva origen/copia/destino; RTO registrado | `backup-cli restore <COPIA> <DESTINO_NUEVO> <IDENTIDAD_AGE>`; contenedor/unidad temporal en loopback alternativo autorizado; `curl`; smoke de API/UI; hash del estado activo antes/después | E1, E2 | myfinanzas-app / vps-infra / QA | 7 | Salida de restore, health, `401`, `FT-1`, hashes y RTO | UNRUN |
| `INFRA-TEST-01-HOST-AC13` | Par de release conocido; backup de Caddy; autorización de fase 7 | Rollback de app sin prueba del par se bloquea y preserva; rollback de Caddy desde backup validado; sitio raíz intacto; sin downgrade forzado ni sobrescritura del estado | Intento de rollback sin evidencia; `caddy validate` del backup; `caddy reload`; `systemctl --user status`; `curl` al sitio raíz; revisión de esquema | E1, E2 | myfinanzas-app / vps-infra / QA | 7 | Bloqueo documentado, backup validado, estado preservado y raíz intacta | UNRUN |
| `INFRA-TEST-01-HOST-AC14` | TEST operativo; registrar estado raíz antes/después | `myfinanzas.pp.ua` DNS/HTTP/HTTPS igual; solo se añadió `test`; sin cambios en Caddy raíz, UFW ni otros servicios | `dig` raíz; `curl -D-` raíz; `sha256sum` del backup/diff de Caddy; comparación de reglas y servicios | E2, E3 | vps-infra / usuario | 6, 8 | Respuestas antes/después, diff de Caddy y comparación de servicios | UNRUN |
| `INFRA-TEST-01-HOST-AC15` | Autorización de retirada; inventario previo | Unidad detenida/deshabilitada; Caddy/DNS de TEST retirados; `linger` deshabilitado si procede; datos/copias preservados; raíz intacta; sin borrado sin inventario | `systemctl --user stop/disable`; backup y edición de Caddy; eliminación del registro DNS; `loginctl disable-linger`; `find`/`ls` de inventario; `curl` raíz | E2, E3 | vps-infra / usuario | 8 | Inventario, estado de unidad, Caddy/DNS retirados y raíz intacta | UNRUN |
| `INFRA-TEST-01-HOST-AC16` | TEST en marcha; umbrales de disco acordados | Dentro de ≤ 5 GB propuestos y márgenes ≥ 20 % libre / ≥ 10 % inodos; 1 GiB/1 CPU/128 pids medidos; sin impacto en otros servicios | `systemctl --user show -p MemoryCurrent,CPUUsageNSec,TasksCurrent`; `podman stats --no-stream`; `df -h`; `df -i`; comparación antes/después | E2 | vps-infra / QA | 6 | Métricas, umbrales y comparación con otros servicios | UNRUN |
| `INFRA-TEST-01-HOST-AC17` | Revisar host, repo, logs y copias | Solo `FT-1`; sin Excel, bases reales, exportaciones, credenciales, TOTP, cookies, claves ni datos personales; evidencia redactada | `seed verify`; inventario de rutas; `find` de `.xlsx`, `.sqlite`, `.env`, claves y exportaciones; revisión de logs; grep de secretos | E0, E2, E4 | usuario / QA | 5, 6 | Inventario redactado, `seed verify` y ausencia de datos ajenos | UNRUN |
| `INFRA-TEST-01-HOST-AC18` | Selección de release TEST desde `myfinanzas-app/main` | SHA de 40 caracteres, `release_ref=myfinanzas-app/main`, `release_sha` registrado; SHA ancestro de `origin/main`; sin etiqueta móvil; PROD futuro desde `main`; el host no gestiona ramas | `git merge-base --is-ancestor <SHA> origin/main`; `git rev-parse`; manifiesto; `release_ref`/`release_sha`; gate Rootless | E0, E1 | myfinanzas-app / vps-infra / QA | 5 | SHA, rama, manifiesto y gate; sin deploy | UNRUN |

`AC-17`/`AC-18` del cierre de Caddy son independientes de los AC host `AC17`/`AC18`; todos
siguen `UNRUN` y no se cubren con el contador de AC host.

La auditoría 2026-11-05 cubrió SO/recursos/SSH/UFW/Caddy/Podman/DNS y el estado de backups,
pero **no** completó Quadlet/cgroup ni el inventario profundo de backups: AC02 sigue `UNRUN`.
AC10 queda pendiente de la release/seed desde `main`; el contrato de integración lo declara MyFinanzas en el manifiesto (hoy 25/C25).

## 4. Fases y gates de autorización

Cada fila exige autorización explícita e identificable del usuario. Una autorización no
habilita las siguientes. Todos los estados empiezan en `UNRUN`.

| Fase | Objetivo | Precondición | Evidencia de salida | Estado |
| --- | --- | --- | --- | --- |
| 0 | Aprobar esta spec y su test plan | Documento revisado | Aprobación registrada | UNRUN |
| 1 | Auditoría de solo lectura | Autorización de acceso de lectura | Inventario redactado y diferencias | UNRUN |
| 2 | Provisión del host | Auditoría completada y aprobada | Usuario, rutas, permisos, `linger`, UFW y versiones | UNRUN |
| 3 | DNS `test` | Auditoría de DNS/proveedor | Registro A/AAAA, resolución y raíz intacta | UNRUN |
| 4 | Caddy y HTTPS | Backup y ubicación real de Caddy | `caddy validate`, bloque validado y raíz intacta | UNRUN |
| 5 | Despliegue y seed | Release/seed desde SHA de `myfinanzas-app/main`; gate Rootless; rutas listas | Seed `0`, unidad activa, frontend y ruta preparada | UNRUN |
| 6 | Smoke y copias | TEST operativo | HTTPS/health/401, `FT-1`, límites y copia local/externa | UNRUN |
| 7 | Restauración y rollback | Copia externa verificada | Restore aislado, rollback bloqueado/ensayado y RTO | UNRUN |
| 8 | Retirada | Autorización específica e inventario | Unidad/Caddy/DNS retirados, datos preservados, raíz intacta | UNRUN |

`[PROPUESTA]` La fase 4 puede preparar y validar Caddy, pero la recarga que publica TEST se
ejecuta al final de la fase 5, cuando la unidad está activa y el seed verificado. La fase 6
es la que acredita HTTPS, smoke y copias; una ventana 502 entre 4 y 5 no se declara
operativa.

La selección del SHA y la construcción de release/seed son responsabilidad de
`myfinanzas-app`. El host solo consume un SHA inmutable de `myfinanzas-app/main` en la fase 5;
integrar una PR no despliega nada; no hay rama `test`.

## 5. Casos negativos obligatorios

Todos `UNRUN`; ninguno se convierte en `PASS` por ausencia de error.

| Caso | Resultado esperado |
| --- | --- |
| Seed con `APP_ORIGIN=https://myfinanzas.pp.ua` | Rechazo `2`; sin escrituras. |
| Seed sin `test-instance.json` | Rechazo `2`; sin escrituras. |
| Seed con `--data-root` relativo o con symlink | Rechazo `2`; sin escrituras. |
| Seed con directorio `0755` o archivos `0644` | Rechazo `2`; no se corrige el permiso. |
| Seed con `owner` ya creado | Rechazo `2`; el estado se preserva. |
| Seed sobre base con movimientos ajenos | Rechazo `2`/`3`; sin reparación automática. |
| Seed con esquema distinto del declarado por la release (hoy 25/C25; 24/26) | Rechazo; no se migra ni se fuerza. |
| Seed repetido con el mismo manifiesto | `0` sin escrituras. |
| Seed con la unidad activa o `18082` respondiendo | Rechazo; no se siembra. |
| Reset sin confirmación explícita | Rechazo; no se archiva nada. |
| Reset con la unidad respondiendo | Rechazo; no se archiva nada. |
| Artefacto de seed referenciado por la unidad permanente | Bloqueo de activación. |
| Imagen por etiqueta móvil | Rechazo; solo ID inmutable. |
| Release de una rama distinta de `main` o etiqueta móvil | Bloqueo; solo SHA de `myfinanzas-app/main`. |
| Cambio de configuración TEST aplicado a PROD u otra aplicación | Bloqueo y reversión; entornos aislados. |
| Manifiesto alterado o commit distinto | No se carga la imagen. |
| SHA sin Rootless `SUCCESS` | Bloqueo de despliegue. |
| Intento de montar solo `database.sqlite` | Rechazo; raíz de datos completa. |
| `:U`, `--privileged`, `Network=host` o socket de Podman | Rechazo por contrato de seguridad. |
| `18082` escuchando en `0.0.0.0` | Bloqueo; no se publica el servicio. |
| `3001` o SQLite accesibles desde fuera | Bloqueo; se corrige antes de seguir. |
| Dato real detectado en TEST | Parada, preservación y escalado; sin borrado. |
| Caddy inválido o sitio raíz afectado | Bloqueo y rollback desde backup. |
| Copia externa ausente o no verificable | Bloqueo de activación. |
| Restore sobre el estado activo | Rechazo; solo destino nuevo. |
| Retirada sin inventario | Bloqueo; no se borra nada. |

## 6. Coordinación con myfinanzas-app

`[CONFIRMADO]` El contrato de aplicación vive en
[SPEC34](https://github.com/jmartinlabs/myfinanzas-app/blob/main/specs/34-infra-test-01-specification.md),
PR [#207](https://github.com/jmartinlabs/myfinanzas-app/pull/207), head `8fe839c`, merge
commit `58346e12eb24b9d8ddef6a0be660f0d66654f5ec`, aprobada y mergeada el 2026-11-04. Este test plan **no
abre una segunda spec de aplicación**.

- La app posee release, imagen, frontend, runtime, seed test-only, dataset `FT-1`,
  manifiesto/checksums y evidencia Rootless.
- Este entregable posee host, usuario, rutas, permisos, UFW, Caddy, DNS, Quadlet, unidad
  TEST, copias del host, restore, rollback y retirada.
- Cualquier cambio de puerto, env, ruta, health, CLI o artefacto se documenta en SPEC34 (o
  su sucesora) y se revisa aquí antes de la fase 5. No se acepta una unidad desincronizada.
- La app debe entregar release y seed verificados antes de la fase 5. Las fases 1–4 pueden
  preparar el host, pero no declaran TEST operativo.
- Los AC de la app (`INFRA-TEST-01-AC04…AC09`, `AC12`, `AC14`, `AC15`, `AC17`, `AC19`) y los host de §3 se
  enlazan en la trazabilidad de la [spec](02-infra-test-01-host-specification.md#81-trazabilidad-con-spec34).
  Ningún resultado se hereda.
- PR #207 consta `MERGED` en `58346e1`; no se infiere permiso
  operativo.

## 7. Comandos previstos (borrador, no ejecutados)

Los comandos son ilustrativos y **no se han ejecutado**. Los placeholders `<…>` se
sustituyen solo con valores verificados. No se incluyen secretos, IPs privadas, cookies ni
rutas privadas reales.

```sh
# Fase 1 — auditoría de solo lectura (autorización expresa)
hostnamectl
cat /etc/os-release
timedatectl
ss -ltnp
ufw status verbose
podman info
systemctl --user list-units --type=service
caddy version
dig +short myfinanzas.pp.ua A
df -h
df -i
findmnt
getent passwd
loginctl list-users

# Fase 2 — identidad y rutas
id mftest
getent passwd mftest
grep -E '^mftest:' /etc/subuid /etc/subgid
loginctl show-user mftest -p Linger
namei -l /srv/myfinanzas-test/data/state/database.sqlite
stat -c '%a %U:%G %n' /srv/myfinanzas-test /srv/myfinanzas-test/data /srv/myfinanzas-test/data/state
readlink -f /var/www/myfinanzas-test/current

# Fase 3 — DNS
dig +short test.myfinanzas.pp.ua A
dig +short test.myfinanzas.pp.ua AAAA
dig @1.1.1.1 +short test.myfinanzas.pp.ua A
dig @8.8.8.8 +short test.myfinanzas.pp.ua A
dig +short myfinanzas.pp.ua A

# Fase 4 — Caddy (solo tras backup y con la unidad/seed listos para publicar)
caddy validate --config <CADDYFILE>
caddy reload --config <CADDYFILE>
curl -D- https://test.myfinanzas.pp.ua/api/health
curl -I http://test.myfinanzas.pp.ua
openssl s_client -connect test.myfinanzas.pp.ua:443 \
  -servername test.myfinanzas.pp.ua </dev/null 2>/dev/null |
  openssl x509 -noout -subject -issuer -dates

# Fase 5 — unidad, salud y aislamiento
systemctl --user cat myfinanzas-test-api
systemctl --user show myfinanzas-test-api -p ActiveState,UnitFileState,MainPID
podman inspect myfinanzas-test-api
curl -fsS http://127.0.0.1:18082/api/health
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18082/api/saldos
ss -ltnp | grep -E '18082|3001'
ufw status numbered
podman port myfinanzas-test-api

# Fase 5 — seed (tareas efímeras, mismo UID/mount; imagen test-only)
# production-init y setup según el RUNBOOK de la app.
podman run --rm --pull=never --network=none \
  --userns=keep-id:uid=10001,gid=10001 --user=10001:10001 \
  --read-only --read-only-tmpfs=false \
  --volume=<DATA_ROOT>:/var/lib/myfinanzas:rw \
  --env=NODE_ENV=production \
  --env=APP_ORIGIN=https://test.myfinanzas.pp.ua \
  --env=DATABASE_PATH=/var/lib/myfinanzas/state/database.sqlite \
  --env=AUTH_KEY_PATH=/var/lib/myfinanzas/state/auth.key \
  <SEED_IMAGE_ID> tools/test-seed/cli.ts verify --data-root /var/lib/myfinanzas

# Fase 6 — copias y límites
# backup-cli create <DESTINO_NUEVO> <DESTINATARIO_AGE>
# copia externa y verificación de checksums
systemctl --user show myfinanzas-test-api \
  -p MemoryCurrent,CPUUsageNSec,TasksCurrent
podman stats --no-stream

# Fase 7 — restauración (destino nuevo y aislado)
# backup-cli restore <COPIA> <DESTINO_NUEVO> <IDENTIDAD_AGE>
# contenedor/unidad temporal en loopback alternativo autorizado
```

## 8. Evidencia y expediente privado

Por cada ejecución se registra, fuera del repositorio y sin secretos:

- Fecha UTC, fase, operador, autorización aplicable y entorno.
- SHA de la app, SHA del manifiesto, ID de imagen app y ID de imagen seed.
- Resultado por AC: `PASS` / `FAIL` / `BLOCKED` / `UNRUN`, comando y salida redactada.
  En este plan, todos empiezan en `UNRUN`.
- Para seed: `dataset_sha256`, `seed_manifest_sha256`, checksums lógicos y resultado
  `verify`.
- Para copias: ruta lógica, checksums origen/destino, retención, resultado de restauración
  y RTO observado.
- Para Caddy/DNS: hash del backup, `caddy validate`, registros antes/después y diff del
  sitio raíz.
- Para UFW/red: inventario de puertos, reglas y intentos externos fallidos.
- Desviaciones, excepciones y su aprobación explícita.

No se publican: contraseñas, TOTP, códigos de recuperación, cookies, tokens de `setup`,
claves, bases, importes reales, IPs privadas ni logs crudos.

## 9. Bloqueos y dependencias de ejecución

| ID | Bloqueo | Efecto | Desbloqueo |
| --- | --- | --- | --- |
| B01 | Spec y test plan sin aprobar | Ninguna fase ejecutable | Aprobación del usuario |
| B02 | Sin autorización para una nueva sesión en el host; fase 1 incompleta (Quadlet/cgroup y backups) | Fase 2 bloqueada | Completar la parte pendiente de la fase 1 con autorización |
| B03 | Release y artefacto de seed no construidos desde `main` | Fases 5–8 bloqueadas | Entrega verificada de `myfinanzas-app/main` |
| B15 | Contrato de integración pendiente de actualización en MyFinanzas | El esquema/seed no está declarado en el manifiesto | MyFinanzas actualice su SPEC34/test plan y entregue release/seed |
| B05 | DT6/T-BKP abierto | Backup/restore limitados | Copia externa mínima y decisión |
| B06 | Flake SQLite B3 sin reproducción Linux | Riesgo de falso FAIL/PASS | Diagnóstico Linux; no ocultar |
| B07 | Gate Rootless no ejecutado sobre el SHA | Despliegue bloqueado | Run `SUCCESS` sobre el SHA exacto |
| B08 | Caddy 2.11.9 auditado; bloque TEST pendiente | Edición del `Caddyfile` puede afectar al sitio raíz | Backup, `caddy validate`, bloque independiente y rollback |
| B09 | Apex DNS conocido; `test` NXDOMAIN | Sin TLS ni entorno operativo | Autorización y creación del registro `test` |
| B10 | Destino externo no aprobado | Activación bloqueada | Decisión del usuario |
| B11 | 35 GB libres y 3 % de inodos medidos | El presupuesto ≤5 GB cabe; revalidar en fase 6 | Medición antes/después |
| B12 | `mftest`/`linger` no verificados | Unidad no persiste | Provisión y prueba de reboot |
| B13 | Quadlet/cgroup no revalidados en Debian 13 | Unidad no arranca o no persiste | Preflight rootless y prueba de reboot |

## 10. Criterios de parada

Detener la fase, preservar evidencia y escalar si ocurre cualquiera de estos casos:

- Aparece un dato real, el Excel, una base real o una credencial en TEST.
- El seed detecta propietario, datos ajenos, esquema distinto o ruta no TEST.
- El manifiesto, el checksum o el SHA no coinciden.
- Falta el gate Rootless o la prueba de compatibilidad para el par exacto.
- La unidad entra en `start-limit`, el health falla o el puerto queda expuesto.
- Caddy no valida, el sitio raíz deja de responder o el certificado es inválido.
- La copia externa no existe, no verifica o la restauración falla.
- El disco o los inodos bajan de los márgenes acordados.
- La auditoría requiere elevación, acceso no contemplado o información sensible.

No se usa `reset-failed`, `chmod`/`chown`, `:U`, borrado de estado ni reintento ciego para
«hacer que funcione».

## 11. Estado actual

- Documentos creados: spec 02 y este test plan. Sin código, sin `infra/`, sin cambios en el
  VPS.
- Comprobaciones locales reportadas por el desarrollador: `git diff --check`,
  `python3 scripts/check_harness.py` y `./scripts/validate-template` con exit 0; CI `validate`
  en PASS revisado. No acreditan el VPS, Caddy, DNS ni Podman y no sustituyen la QA independiente.
- Comprobaciones de host: auditoría de solo lectura 2026-11-05 y Caddy 2.11.9 documentados;
  seed, backup/restore y TEST desplegado siguen **UNRUN**.
- AC: **18 / 18 `UNRUN`**; la auditoría no completa AC02 y AC18 depende del SHA de `main`.
  Los checks locales no convierten AC01 en `PASS` sin revisión independiente y aprobación.
- Fases: **0 / 9 autorizadas**; la auditoría de 2026-11-05 cubrió parte de la fase 1, sin declararla completa.
- Próxima acción independiente: revisión/aprobación de esta enmienda y de H1–H6; merge de
  actualización del contrato en MyFinanzas; selección del SHA de `main` antes de la fase 5.
