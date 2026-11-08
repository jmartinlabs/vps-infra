# Despliegue directo de MyFinanzas TEST desde GitHub Actions

Fecha: 2026-11-08
Estado: **PROPUESTA — no ejecutada en el VPS.**

Sustituye la arquitectura GHCR + temporizador (`#27`, `#28`, `#293`) por un
despliegue directo desde el workflow, sin polling ni registro intermedio.

## Flujo

```text
push a test ──► capability + qa ──► build/verify/smoke ──► auditoría local
      │                                                      │
      └──────────── workflow_dispatch con deploy_test=true ───┘
                                                             ▼
                                   SSH dedicado (clave + forced command)
                                                             ▼
                             deploy-test-release (mftest, sin sudo)
                                                             ▼
                       verificar → podman load → frontend+unit → smoke
                                                             ▼
                                        rollback automático si falla
```

- Un solo build por SHA (`infra/release.py build --single-build`).
- El bundle viaja por `stdin` a un comando forzado; no se permite shell, SFTP,
  forwarding ni PTY.
- Sin GHCR, sin temporizadores, sin credenciales de registro en el VPS.
- PROD no comparte clave, usuario, rutas ni unidades.

## Controles antes de desplegar

1. `capability` (rootless real) y `qa` sobre el SHA exacto de `test`.
2. `release.py verify` + `smoke.py` del bundle.
3. `scripts/audit-test-release` sobre el bundle: sin estado, credenciales ni
   recursos de `index.html` ausentes.
4. Entorno de GitHub `test` con revisores requeridos (o `deploy_test=true` en
   `workflow_dispatch`). La aprobación del entorno es la autorización operativa.
5. El job comprueba que `origin/test` sigue apuntando al SHA construido.

## Bundle de despliegue

`manifest.json`, `manifest.sha256`, `SHA256SUMS`, `frontend/` y `image.oci.tar`.
No incluye la imagen seed: el seed solo se ejecuta en la primera activación.

## Receptor en el VPS

- Usuario `mftest`, sin sudo. Escribe solo en `~/bin`, `~/.config/containers/systemd`,
  `~/.config/systemd/user`, `/srv/myfinanzas-test` y `/var/www/myfinanzas-test`.
- Clave SSH dedicada, limitada al comando forzado y a la IP de GitHub Actions si
  el proveedor la publica; sin reenvío de agentes ni túneles.
- Verifica manifiesto, `SHA256SUMS`, frontend exacto, recursos de `index.html`,
  digest/ID de imagen y contratos instalados antes de tocar unidad o frontend.
- `podman load` local; nunca descarga.
- Smoke: health `{"ok":true}`, ruta protegida `401`, `current/index.html`.
- Fallo: restaura unidad y `current` anteriores, repite smoke; si el rollback
  falla, detiene la unidad y deja evidencia. Registra `last-deploy.json`.
- Lock para impedir despliegues concurrentes.

## Instalación (una vez, con autorización operativa)

1. Crear clave `myfinanzas-test-deploy` (par ed25519) y añadir la pública en
   `~mftest/.ssh/authorized_keys` con:
   `restrict,command="/home/mftest/bin/myfinanzas-test-deploy --stdin" ssh-ed25519 ...`
2. Instalar `scripts/deploy-test-release` en `/home/mftest/bin/` (0755, mftest).
3. Guardar la privada en el entorno GitHub `test` como `TEST_DEPLOY_KEY` y la
   huella del host en `TEST_DEPLOY_KNOWN_HOSTS`.
4. Definir `TEST_DEPLOY_HOST`, `TEST_DEPLOY_USER=mftest`.
5. Retirar, si existieran, el timer y el servicio `myfinanzas-test-update` y sus
   paquetes GHCR. No se borra nada sin inventario.

## Limpieza de la arquitectura anterior

- Retirar `scripts/test-auto-update`, `scripts/test-test-auto-update`,
  `infra/systemd/user/myfinanzas-test-update.*` y sus referencias documentales.
- Retirar el job `publish` y los inputs `publish_test_ghcr` del workflow.
- Los paquetes GHCR, si se hubieran creado, quedan privados y sin uso; su
  eliminación requiere autorización aparte.

## Rollback

Automático ante smoke fallido (unidad + frontend). Limitaciones: no revierte
datos ni esquema (el despliegue exige el mismo contrato), no hay notificación y
un rollback fallido deja la unidad parada para intervención manual.
