# Paquete operativo — despliegue de MyFinanzas TEST

Fecha: 2026-11-07
Estado: **DRAFT — no autorizado y no ejecutado.**
Base: `vps-infra` `main` `c1f9f59`; Fase 2 de aprovisionamiento `PASS` (2A+2B).
Referencias: [spec host 02](../specs/02-infra-test-01-host-specification.md),
[test plan](../specs/02-infra-test-01-host-testplan.md),
[evidencia 2A](evidencia-infra-test-02a.md),
[evidencia 2B](evidencia-infra-test-02b.md),
[preparación DNS/Caddy](preparacion-dns-caddy-test-01.md) y
[recepción y despliegue del paquete](paquete-test-recepcion-01.md).

## 1. Objetivo

Desplegar MyFinanzas TEST en `https://test.myfinanzas.pp.ua`, aislado de
`myfinanzas.pp.ua` y de PROD, con datos exclusivamente ficticios `FT-1` y sin abrir puertos
nuevos.

El aprovisionamiento del host ya está hecho. Este paquete cubre **DNS, Caddy, release/seed,
unidad, smoke y copia local**, no la creación de otro host ni PROD.

## 2. Estado de partida

| Elemento | Estado |
| --- | --- |
| Host | Debian 13.7; 2 vCPU; 3,8 GiB; 35 GB libres; inodos 3 %. |
| Identidad | `mftest` UID/GID `1002:1002`; `linger`; `systemd --user`; Podman rootless y cgroups. |
| Rutas | `/srv/myfinanzas-test/{data,releases,backups}` y raíz estática creadas; `data/state` y `current` ausentes. |
| Servicios TEST | Sin unidad, contenedor, servicio ni puerto `18082`/`3001`. |
| Caddy | 2.11.9 activo; solo sitio raíz; sin bloque TEST; `caddy validate` OK. |
| DNS | `test.myfinanzas.pp.ua` NXDOMAIN; apex sin cambios. |
| Release/seed | Paquete de GitHub Actions no disponible; `tools/test-seed` y `Containerfile.seed` sí existen en `myfinanzas-app/test`. |
| Datasette | PR #22 pendiente de merge; no bloquea el despliegue de la app, pero debe resolverse antes de usar el panel. |
| PRs host | #23 evidencia/spec, #24 scripts 2A y #25 script 2B: MERGED; #22 Datasette pendiente. |

## 3. Artefactos que debe entregar MyFinanzas

1. **SHA candidato exacto** de `myfinanzas-app/test` (40 caracteres), congelado para TEST.
   Al preparar este paquete, `origin/test` estaba en
   `87a705f9225d76fe8d2d1b84e308f926e989fdb8` con `schemaVersion=27`; no se asume que siga
   siendo el candidato final si hay nuevos merges.
2. **Gate Rootless `SUCCESS` sobre ese SHA exacto**. El único `SUCCESS` reciente observado
   corresponde a `f800965`; no sirve para `87a705f` ni para otro SHA sin rerun.
3. **Paquete único de GitHub Actions** (`myfinanzas-test-package.v1`) con
   `image.oci.tar`, `image.seed.oci.tar`, `frontend/`, `manifest.json`,
   `manifest.sha256` y SHA-256 del paquete.
4. **Contrato de esquema/seed v27** declarado en el manifiesto, no solo en el código.
   SPEC34/testplan deben dejar de declarar v24/C25.
5. **Seed test-only `FT-1` v27**: imagen incluida en el paquete; `seed init/apply/verify`,
   `test-instance.json` y `seed-manifest.json` se generan en el host y se verifican antes de
   la unidad. Sin datos reales.
6. **Ruta canónica confirmada a nivel de contrato:** `/srv/myfinanzas-test/data/state` para
   DB y `auth.key`, con `data` montado en `/var/lib/myfinanzas`. `state/` sigue ausente y
   PR #22 permanece pendiente de autorización de merge.
7. **Plan de backup TEST**: inclusión de `test-instance.json`/manifiesto, revocación de
   sesiones y destino externo con custodia `age` (puede ser una autorización posterior).
8. **Smoke esperado**: `/api/health` `200`, ruta protegida `401`, `FT-1` visible con MFA y
   `3001` no publicado.

## 4. Secuencia propuesta y gates

Cada gate exige autorización separada. Ninguna autorización habilita el siguiente.

### Gate 3 — DNS `test`

- Crear solo `test` A/AAAA a la IP pública verificada; TTL 300; sin wildcard.
- No tocar el registro raíz.
- Verificar con resolutores públicos y comparar apex antes/después.
- **Bloqueo:** autorización de DNS y decisión de AAAA si no existe.

### Gate 4 — Caddy TEST

- Leer el `Caddyfile` completo y registrar hash; no asumir que solo contiene el sitio raíz.
- Backup y diff; bloque independiente para `test.myfinanzas.pp.ua`.
- `/api/*` a `127.0.0.1:18082`, sin fallback SPA; estático desde
  `/var/www/myfinanzas-test/current`; cabeceras `noindex`, `nosniff` y HSTS corto.
- `caddy validate`; no recargar hasta que la unidad y el seed estén listos.
- **Bloqueo:** contrato de rutas/health de la app y autorización de edición/recarga.

### Gate 5 — release, estado, seed y unidad

Orden obligatorio:

1. Verificar SHA, manifiesto, checksums, IDs, gate Rootless y contrato v27.
2. Ejecutar el **preflight** `release-gate check` del `.tar`, la app, el seed image y el
   frontend; sin `seed manifest` y sin mutar estado.
3. Confirmar `data/state` ausente y rutas vacías.
4. Ejecutar `production-init` para crear `data/state`, DB y `auth.key` `0600`; verificar
   AC19 antes de sembrar.
5. Ejecutar `seed init/apply/verify` con `FT-1` v27; comprobar marcador y manifiesto.
6. Ejecutar **`release-gate verify-seed`** con el `seed-manifest.json` generado; no activar
   nada si falla.
7. Ejecutar `setup` según el contrato de la app y verificar que no hay datos reales.
8. Instalar la unidad Quadlet con imagen inmutable, `Pull=never`, `keep-id` 10001,
   `127.0.0.1:18082:3001`, límites 1 GiB/1 CPU/128 pids, rootfs de solo lectura y tmpfs.
9. Validar la unidad, arrancarla y comprobar health `200` y `401`.
10. Publicar el frontend en `/var/www/myfinanzas-test/releases/<sha>` y `current` dentro de
    esa raíz pública; verificar legibilidad por `caddy`; recargar Caddy solo al final.
11. Smoke: loopback, HTTPS, `401`, `FT-1`, ausencia de `3001`, apex intacto.
- **Bloqueos:** release/seed no disponibles, SHA/Rootless no confirmados, contrato v27
  pendiente. La ruta `data/state` está confirmada a nivel de contrato, pero el estado aún no
  existe y el despliegue no está autorizado.

### Gate 6 — copia y cierre

- Copia cifrada local en `/srv/myfinanzas-test/backups` y copia externa aprobada.
- Checksums origen/destino; retención actual+anterior; identidad `age` fuera del VPS.
- Restore aislado y rollback se reservan para la fase 7, con autorización separada.
- **Bloqueo:** destino externo, custodia `age`, RPO/RTO mínimo y prueba de restore.

## 5. Contrato de despliegue y gate local

Cuando exista release, generar una solicitud
[`deploy-request.v1`](../schemas/deploy-request.v1.json) con versión, tag
`deploy-test-vX.Y.Z`, `release_ref=myfinanzas-app/test`, `release_sha`,
`package_format=myfinanzas-test-package.v1`, `package_sha256`, `manifest_sha256`,
`artifact_ref`, `seed_image`, evidencia CI/Rootless, seed manifest, backup, rollback y smoke.

Preflight antes de mutar estado (`seed_manifest_sha256: null`):

```bash
./scripts/release-gate check \
  --request <deploy-request.json> \
  --release-dir <directorio-extraido> \
  --package <paquete-unico.tar> \
  --state <state-fixture.json> \
  --evidence <evidence-fixture.json> \
  --mode dry-run
```

Después de `seed apply`, actualizar el hash y verificar FT-1 antes de activar la unidad:

```bash
./scripts/release-gate verify-seed \
  --request <deploy-request.json> \
  --release-dir <directorio-extraido> \
  --seed-manifest <seed-manifest.json>
```

`release-gate` es solo `dry-run`: no despliega ni sustituye la autorización manual. Un
resultado `success` no acredita GitHub, QA, Rootless ni el VPS reales.

## 6. Autorizaciones necesarias

| Autorización | Alcance | No incluye |
| --- | --- | --- |
| DNS TEST | Crear solo `test` A/AAAA; verificar apex | Wildcard, apex, PROD |
| Caddy TEST | Backup, diff, bloque, `validate`, recarga final | Sitio raíz, certificados de PROD |
| Release/seed | Usar el SHA, release y seed verificados en TEST | Reconstruir la app o usar datos reales |
| Despliegue TEST | Crear estado, seed, unidad, `current`, smoke | PROD, promoción, DNS raíz |
| Backup externo | Destino, custodia `age`, retención y restore | Copia de PROD |
| UFW | **No se propone cambio**; solo verificación | Abrir `18082`/`3001` |
| Merge de PRs | #22 pendiente; #23/#24/#25 ya integradas | Merge automático o despliegue |

## 7. Bloqueos actuales

| ID | Bloqueo | Efecto |
| --- | --- | --- |
| D1 | Paquete único de GitHub Actions no entregado | Gate 5 bloqueado |
| D2 | Imagen seed/paquete FT-1 v27 no entregados | Gate 5 bloqueado |
| D3 | Contrato SPEC34/testplan sigue v24/C25 | Compatibilidad de esquema no declarada |
| D4 | Rootless no ejecutado sobre el SHA elegido | Gate 5 bloqueado |
| D5 | Ruta `data/state` confirmada a nivel de contrato; `state/` aún ausente y PR #22 sin merge | Ruta cerrada; despliegue y panel pendientes |
| D6 | DNS `test` NXDOMAIN y sin autorización | Gate 3 bloqueado |
| D7 | Caddy TEST sin preparar ni autorizar | Gate 4 bloqueado |
| D8 | Unidad Quadlet real y reboot no probados | Persistencia no acreditada |
| D9 | Destino externo/custodia `age` sin aprobar | Gate 6 y fase 7 bloqueados |
| D10 | `sshd -T`, UFW/nftables y fail2ban efectivos pendientes de root | Hardening no acreditado |
| D11 | PR #22 Datasette sin merge | Panel de administración no listo |
| D12 | PRs #23/#24/#25 integradas | Evidencia/procedimientos en `main`; no habilitan despliegue |

## 8. Criterios de parada

Detener y preservar si:

- El SHA, manifiesto, checksum, ID de imagen o gate Rootless no coinciden.
- El manifiesto no declara el contrato v27 o el seed no corresponde al SHA.
- `data/state`, DB, `auth.key` o `current` existen antes de su fase.
- Aparece un dato real, Excel, base real, credencial o exportación.
- La unidad publica `3001`, escucha fuera de loopback o entra en `start-limit`.
- Caddy no valida, el sitio raíz cambia o el certificado TEST falla.
- Se abre un puerto UFW nuevo o se modifica el apex.
- La copia externa no existe, no verifica o no hay custodia `age`.

No se usa `reset-failed`, `chmod`/`chown`, `:U`, borrado de estado ni reintento ciego para
«hacer que funcione».

## 9. Siguiente acción

1. MyFinanzas responde con SHA congelado, release, Rootless sobre ese SHA, contrato v27 y
   seed `FT-1`. La ruta `data/state` ya está confirmada a nivel de contrato.
2. Revisar y aprobar el packet; generar `deploy-request.v1` cuando existan los artefactos.
3. Autorizar DNS y Caddy por separado.
4. Autorizar el despliegue TEST y el seed solo después de que el gate local esté en PASS.
5. Mantener PROD, datos reales y apertura de puertos fuera de alcance.

## 10. Prueba de reboot — separada

El reboot real no forma parte del despliegue ni se ejecuta sin una autorización específica.

- **Precondición:** unidad activa, seed verificado, smoke PASS y copia de línea base
  verificada; ventana acordada con el usuario.
- **Alcance:** reiniciar el VPS una sola vez y comprobar que `linger`, `systemd --user`,
  Quadlet, Podman rootless, `127.0.0.1:18082`, health, `401` y el sitio raíz siguen
  funcionando.
- **Evidencia:** hora, motivo, servicios antes/después, estado de la unidad, puertos,
  health y comparación del apex.
- **Rollback:** si la unidad no arranca, detener, preservar logs y aplicar el procedimiento
  de recuperación autorizado; no reintentar a ciegas.
- **Autorización:** independiente del despliegue y del backup externo.

No se reinicia el VPS en esta fase.
