# Recepción y despliegue del paquete TEST — MyFinanzas

Fecha: 2026-11-07
Estado: **DRAFT — procedimiento documental, no ejecutado.**
Referencias: [spec host 02](../specs/02-infra-test-01-host-specification.md),
[paquete de despliegue](paquete-despliegue-myfinanzas-test-01.md),
[preparación DNS/Caddy](preparacion-dns-caddy-test-01.md) y
[release gate](release-gate.md).

El host TEST ya está aprovisionado (2A/2B PASS). Este documento prepara la recepción del
paquete que construirá GitHub Actions en `myfinanzas-app`, la verificación, la importación
de imágenes y el despliegue manual con Podman rootless de `mftest`.

No se construyen imágenes, no se ejecuta nada en el VPS, no se modifica DNS/Caddy y no se
despliega durante esta preparación.

## 1. Contrato del artifact

`[CONFIRMADO]` Según el workflow de MyFinanzas #288:

- Origen: `release_ref=myfinanzas-app/test`.
- Formato: `myfinanzas-test-artifact-zip.v1`.
- Artifact ZIP descargable de GitHub Actions, sin cifrar: `myfinanzas-test-<release_sha>.zip`.
  El SHA-256 del ZIP se calcula al recibirlo y se registra; `SHA256SUMS` viaja dentro.
- Contenido:
  - `manifest.json`
  - `manifest.sha256`
  - `image.oci.tar`
  - `image.seed.oci.tar`
  - `frontend/`
  - `SHA256SUMS`
- Sin secretos, bases, datos reales, claves, `.env`, Excel ni estado.
- `seed-manifest.json` **no** viaja en el paquete de build: se genera tras `seed apply` y se
  entrega al gate como artefacto de ejecución.
- El manifiesto de la app declara el bloque `seed` (ID inmutable, digest OCI, hash del
  archivo OCI, payload del rootfs, receta, fuente, contratos y lock).
- Las imágenes se seleccionan por ID/digest inmutable, nunca por etiqueta móvil.

`SHA256SUMS` cubre todos los ficheros del artifact excepto él mismo. El gate verifica el
hash del ZIP descargado y los hashes internos del directorio extraído. `seed-manifest.json`
se genera después de `seed apply`; el gate lo verifica en `verify-seed`.

## 2. Recepción y verificación

Procedimiento del operador, en una ruta nueva y privada. No ejecutar todavía.

1. Recibir el paquete por el canal autorizado y registrar run de GitHub, fecha, SHA de la
   app y `release_ref`.
2. Verificar el checksum externo **antes** de extraer:
   ```bash
   sha256sum myfinanzas-test-<release_sha>.zip
   (cd <directorio-extraido> && sha256sum -c SHA256SUMS)
   ```
3. Crear un directorio nuevo bajo `/srv/myfinanzas-test/releases/<release_sha>` con
   `mftest:mftest` `0700`; extraer allí sin seguir enlaces.
4. Verificar `manifest.sha256` y que el árbol contiene solo los cinco elementos permitidos.
5. Comprobar que `manifest.inputs.source` coincide con `release_sha` y que
   `manifest.seed.image` coincide con `seed_image`.
6. No importar, no arrancar ni modificar estado hasta pasar el preflight del paquete.

## 3. Validación previa y verificación posterior

### 3.1 Preflight del paquete, antes de mutar estado

La solicitud TEST lleva `seed_manifest_sha256: null` porque FT-1 aún no se ha aplicado.

```bash
./scripts/release-gate check \
  --request /ruta/deploy-request.json \
  --release-dir /srv/myfinanzas-test/releases/<release_sha> \
  --package /ruta/privada/myfinanzas-test-<release_sha>.zip \
  --state /ruta/state-fixture.json \
  --evidence /ruta/evidence-fixture.json \
  --mode dry-run
```

Debe validar `package.sha256`, `manifest.sha256`, `oci.archive`, `seed.oci` y
`frontend.files`. `seed.manifest` queda `skipped` porque se genera después de `seed apply`.

### 3.2 Verificación posterior de FT-1

Después de `seed apply` y `seed verify`, actualizar `seed_manifest_sha256` en la solicitud y
ejecutar:

```bash
./scripts/release-gate verify-seed \
  --request /ruta/deploy-request.json \
  --release-dir /srv/myfinanzas-test/releases/<release_sha> \
  --seed-manifest /srv/myfinanzas-test/data/seed-manifest.json
```

Debe validar `source.commit`, `source.schema`, `source.seed_image`, dataset `FT-1` y el hash
del manifiesto. Solo después se instala/activa la unidad.

Un `success` no acredita GitHub, Rootless, QA ni autorización de despliegue.

## 4. Importación de imágenes

Solo tras verificar el paquete:

```bash
podman load --input image.oci.tar
podman load --input image.seed.oci.tar
podman image inspect sha256:<APP_IMAGE_ID>
podman image inspect sha256:<SEED_IMAGE_ID>
```

Comparar los IDs con `manifest.image` y `manifest.seed.image`. No usar tags móviles.
La imagen de seed se usa solo en tareas efímeras y nunca se referencia en la unidad
permanente.

## 5. Secuencia de despliegue

Precondiciones: unidad TEST parada/ausente, `18082` sin responder y
`/srv/myfinanzas-test/data/state` inexistente.

1. `production-init` con la imagen de app, UID 10001, data root montado en
   `/var/lib/myfinanzas`, `NODE_ENV=production`, `APP_ORIGIN` TEST y rutas explícitas.
2. `seed init`, `seed apply` y `seed verify` con la imagen seed, `--network=none`,
   `--seed-commit <release_sha>` y `--seed-image sha256:<SEED_IMAGE_ID>`.
3. `setup` con archivo de entrega nuevo `0600`; el token no se imprime ni se versiona.
4. Ejecutar el gate de la §3 con el `seed-manifest.json` recién generado.
5. Instalar la unidad Quadlet candidata con el ID inmutable de la app.
6. Publicar el frontend verificado en `/var/www/myfinanzas-test/releases/<sha>/` y crear
   `current` dentro de `/var/www/myfinanzas-test`; nunca apuntar a `/srv` privado.
   La primera activación deja esa raíz `mftest:caddy` `2750` y los ficheros `0640`.
7. Comprobar que Caddy puede leer el frontend sin atravesar `0700`:
   `namei -l /var/www/myfinanzas-test/current` y prueba de lectura como `caddy`.
8. Recargar Caddy solo al final, con autorización separada.
9. Ejecutar smoke y conservar evidencia.

Plantillas de comandos: [RUNBOOK de MyFinanzas](https://github.com/jmartinlabs/myfinanzas-app/blob/test/infra/RUNBOOK.md).
No se copian aquí secretos ni rutas privadas reales.

## 6. Quadlet candidato

Fichero propuesto: `~mftest/.config/containers/systemd/myfinanzas-test-api.container`.

```ini
[Unit]
Description=MyFinanzas TEST rootless API
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Container]
Image=sha256:REPLACE_WITH_VERIFIED_APP_IMAGE_ID
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

No se instala en esta fase. Verificar que la versión de Quadlet del host admite las
directivas y que `/tmp`/`/run` no necesitan escritura adicional.

## 7. DNS y Caddy

La preparación documental está en [DNS/Caddy TEST](preparacion-dns-caddy-test-01.md).
No se crea el registro `test`, no se edita el `Caddyfile` y no se recarga Caddy sin
autorización independiente.

## 8. Smoke mínimo

```bash
curl -fsS http://127.0.0.1:18082/api/health
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18082/api/saldos
curl -D- https://test.myfinanzas.pp.ua/api/health
curl -D- https://myfinanzas.pp.ua
ss -ltn | grep -E '18082|3001'
```

Esperado: health `200` `{"ok":true}`, ruta protegida `401`, frontend/FT-1 visible con MFA,
`3001` no publicado, `18082` solo loopback y apex intacto. Antes de la recarga, `namei -l`
debe mostrar todos los componentes públicos `0755` y la prueba como `caddy` debe leer
`current/index.html`.

## 9. Recuperación básica

- **Fallo antes de mutar:** detener; el VPS queda intacto; no limpiar ni reintentar a ciegas.
- **Fallo tras `production-init`/seed:** detener, preservar `state`, marcador, manifiesto,
  `seed-failure.json` y logs; no borrar ni reparar automáticamente. El `reset` no está
  implementado; requiere decisión y procedimiento autorizado.
- **Fallo de unidad:** detener, revisar `systemctl --user status` y logs; no usar
  `reset-failed` repetidamente para eludir un start-limit.
- **Rollback:** solo al par exacto release/imagen/esquema con prueba; si no existe par
  compatible, bloquear y preservar.
- **Caddy:** restaurar el backup validado y recargar solo con autorización; comprobar el
  sitio raíz.

## 10. Bloqueos y autorizaciones

| Bloqueo | Efecto |
| --- | --- |
| Formato exacto del paquete y ubicación de `seed-manifest.json` sin confirmar | No se puede cerrar el contrato de recepción |
| SHA de TEST no congelado | No hay release ni Rootless válidos |
| Release/seed de GitHub Actions no disponibles | No hay paquete que verificar |
| `schemaVersion=27` sin contract ID/manifiesto confirmado | Gate de esquema bloqueado |
| DNS `test` y Caddy TEST sin autorización | No hay HTTPS ni publicación |
| Backup externo/custodia `age` sin aprobar | Fase 6/7 bloqueadas |
| Reboot real sin ventana | Persistencia no acreditada |

Autorizaciones separadas necesarias: recepción del paquete, importación de imágenes,
`production-init`/seed/setup, instalación de unidad, DNS TEST, Caddy TEST, smoke, backup
externo y reboot. Ninguna se concede por este documento.
