# Despliegue directo de MyFinanzas TEST desde GitHub Actions

Fecha: 2026-11-08
Estado: **PROPUESTA — no ejecutada en el VPS.**

Sustituye la arquitectura GHCR + temporizador (`#27`, `#28`, `#293`) por un
despliegue directo disparado por el tag `deploy-test-vX.Y.Z`, sin polling, registro
intermedio ni GitHub Environments. La creación del tag por un actor autorizado es la orden
de despliegue. Los merges a `test` no despliegan.

## Flujo

```text
tag deploy-test-vX.Y.Z (actor autorizado, anotado e inmutable)
      ▼
tag/actor/SHA + capability + qa ──► build/verify/smoke ──► auditoría local
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
4. Tag anotado `deploy-test-vX.Y.Z` creado por un actor de `MYFINANZAS_DEPLOY_ACTORS`;
   la creación del tag es la autorización operativa, sin segunda aprobación.
5. El job comprueba que el commit del tag es el SHA construido y ancestro de `origin/test`.
6. Interruptor `MYFINANZAS_TEST_DEPLOY=true`; desactivado, el tag no despliega.

## Bundle de despliegue

`manifest.json`, `manifest.sha256`, `SHA256SUMS`, `deploy.json`, `frontend/` e
`image.oci.tar`. No incluye la imagen seed: el seed solo se ejecuta en la primera activación.

`deploy.json` materializa el contrato de DEPLOY-TAGS-01 sin secretos: `environment`,
`version`, `tag`, `release_sha`, `manifest_sha256`, `qa_reference` y `workflow_run_id`. El
receptor comprueba que coinciden con el manifiesto, el comando SSH y el tag antes de mutar.

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
   `restrict,command="XDG_RUNTIME_DIR=/run/user/1002 /home/mftest/bin/myfinanzas-test-deploy --stdin" ssh-ed25519 ...`
2. Instalar `scripts/deploy-test-release` en `/home/mftest/bin/` (0755, mftest).
3. Guardar la privada como secreto `TEST_DEPLOY_KEY` y la huella del host en
   `TEST_DEPLOY_KNOWN_HOSTS` (secretos de repositorio, sin Environments).
4. Definir `TEST_DEPLOY_HOST`, `TEST_DEPLOY_USER=mftest` y la allowlist
   `MYFINANZAS_DEPLOY_ACTORS`.
5. Retirar, si existieran, el timer y el servicio `myfinanzas-test-update` y sus
   paquetes GHCR. No se borra nada sin inventario.

## Limpieza de la arquitectura anterior

- Retirar `scripts/test-auto-update`, `scripts/test-test-auto-update`,
  `infra/systemd/user/myfinanzas-test-update.*` y sus referencias documentales.
- Retirar el job `publish` y los inputs `publish_test_ghcr` del workflow.
- Los paquetes GHCR, si se hubieran creado, quedan privados y sin uso; su
  eliminación requiere autorización aparte.

## Política de rollback (cerrada)

- **Éxito:** se escribe `current-release.json` con versión, tag, actor, SHA, manifiesto,
  QA y ejecución. No se borra la release anterior.
- **Smoke fallido:** se restauran la unidad y el enlace `current` anteriores, se reinicia y
  se repite el smoke. Si pasa, la release anterior queda activa y no se escribe estado.
- **Rollback fallido:** se detiene la unidad, se preservan unidad anterior, estado, logs y
  `last-deploy.json`; no se reintenta automáticamente.
- **Datos y esquema:** no se tocan. El despliegue exige el mismo contrato; una migración no
  forma parte de este flujo. TEST no requiere copia previa porque el estado no cambia.
- **PROD:** exige copia cifrada y restauración verificada antes de activar; el rollback
  app-only es igual, y la recuperación de datos solo desde la copia con autorización
  separada. Ver [diseño PROD](despliegue-prod-diseno-01.md).
- **Versiones:** el tag es inmutable y el receptor rechaza reutilizar una versión desde otro
  SHA; misma versión y SHA es no-op.
