# Despliegue directo de MyFinanzas TEST desde GitHub Actions

Fecha: 2026-11-08 (actualizado: 2026-11-09)
Estado: **PIPELINE EJECUTADO EN TEST; corrección de timeouts del receptor en revisión
(PR #33), pendiente de instalar.**

Sustituye la arquitectura GHCR + temporizador (`#27`, `#28`, `#293`) por un
despliegue directo disparado por el tag `deploy-test-vX.Y.Z`, sin polling, registro
intermedio ni aprobación por Environments. La creación del tag por un actor autorizado es la
orden de despliegue; un Environment sin revisores solo aísla secretos y restringe el ref. Los merges a `test` no despliegan.

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
4. Tag anotado `deploy-test-vX.Y.Z` creado por un actor de `MYFINANZAS_DEPLOY_ACTORS` y con
   `sha=`/`qa_reference=` en la anotación; la creación del tag es la autorización operativa.
5. El job comprueba que el commit del tag es el SHA construido y ancestro de `origin/test`.
6. Environment `test` como frontera de secretos y regla de tags, sin Required reviewers.
7. Interruptor `MYFINANZAS_TEST_DEPLOY=true`; desactivado, el tag no despliega.

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
- Normaliza el ID de imagen a `sha256:<64 hex>` antes de comparar: Podman 4 imprime el
  prefijo y Podman 5 no. Una diferencia real de hash sigue rechazándose.
- `podman load` local; nunca descarga.
- Presupuesto de arranque: la unidad declara `TimeoutStartSec=120s` y
  `TimeoutStopSec=30s`. El `restart` puede consumir hasta 150 s (parada + arranque);
  el cliente espera 180 s, con 30 s de margen real, y 45 s a una parada suelta.
  Así observa el resultado final del job en lugar de abandonarlo pendiente.
- Smoke: health `{"ok":true}`, ruta protegida `401`, `current/index.html`.
- Fallo: antes de restaurar, asienta la unidad (`systemctl stop` + `reset-failed` y
  dos lecturas consecutivas de estado terminal, hasta 20 s más la última consulta)
  para que un arranque pendiente no compita con la recuperación. Después restaura
  unidad y `current`, repite smoke; si el rollback falla o la unidad no asienta,
  intenta detenerla y registra la evidencia en `last-deploy.json`.
- Lock para impedir despliegues concurrentes.

## Instalación (una vez, con autorización operativa)

1. Crear clave `myfinanzas-test-deploy` (par ed25519) y añadir la pública en
   `~mftest/.ssh/authorized_keys` con:
   `restrict,command="XDG_RUNTIME_DIR=/run/user/1002 /home/mftest/bin/myfinanzas-test-deploy --stdin" ssh-ed25519 ...`
2. Instalar `scripts/deploy-test-release` en `/home/mftest/bin/` (0755, mftest) y
   comprobar su SHA-256:
   `d3eb0bc7d6362b39de3db681c26ff81cc7fd5e3b4d33fe783cce91cdc4e1cf85`
3. Guardar la privada como secreto del Environment `test` en `TEST_DEPLOY_KEY` y la huella
   del host en `TEST_DEPLOY_KNOWN_HOSTS` (sin Required reviewers).
4. Definir en el mismo Environment `TEST_DEPLOY_HOST`, `TEST_DEPLOY_USER=mftest` y la
   allowlist `MYFINANZAS_DEPLOY_ACTORS`.
5. Retirar, si existieran, el timer y el servicio `myfinanzas-test-update` y sus
   paquetes GHCR. No se borra nada sin inventario.

## Actualización y rollback del receptor

El receptor es un único fichero ejecutable sin estado propio: su estado son
`current-release.json` y `last-deploy.json` en `/srv/myfinanzas-test`. Instalar o revertir la
versión no reinicia la API ni toca datos.

Actualización (con autorización operativa):

```bash
# 1. Verificar el binario NUEVO antes de instalar y conservar el anterior
sha256sum <nuevo>   # debe coincidir con el SHA-256 aprobado del PR
sudo -u mftest sha256sum /home/mftest/bin/myfinanzas-test-deploy
sudo install -m 0755 -o mftest -g mftest \
  /home/mftest/bin/myfinanzas-test-deploy \
  /home/mftest/bin/myfinanzas-test-deploy.previous
# 2. Confirmar que no hay un despliegue en curso. El lock persiste siempre,
#    así que se comprueba tomándolo, no mirando si el fichero existe:
sudo -u mftest flock -n /srv/myfinanzas-test/update.lock true   # debe salir 0
# 3. Instalar la nueva y verificar
sudo install -m 0755 -o mftest -g mftest <nuevo> /home/mftest/bin/myfinanzas-test-deploy
sudo -u mftest sha256sum /home/mftest/bin/myfinanzas-test-deploy   # debe coincidir con el PR
# 4. Prueba de alcance: la clave forzada solo acepta "deploy:<actor>:<semver>".
#    Un comando distinto debe rechazarse sin mutar. Esto demuestra el forzado,
#    no la integridad del binario: esa la fija el SHA-256 del paso 2.
ssh -i <clave> mftest@<host> 'true'   # exit 2, sin cambios
```

Rollback:

```bash
sudo install -m 0755 -o mftest -g mftest \
  /home/mftest/bin/myfinanzas-test-deploy.previous /home/mftest/bin/myfinanzas-test-deploy
sudo -u mftest sha256sum /home/mftest/bin/myfinanzas-test-deploy   # hash anterior conocido
```

- La versión anterior se conserva hasta que el primer despliegue con la nueva termine bien.
- Un fallo posterior a `write_unit`/`stage_frontend` (smoke o reinicio) restaura unidad y
  `current` con el rollback del propio receptor; si ese rollback falla, detiene la unidad.
  El rollback del ejecutable no requiere tocar el servicio, pero debe hacerse con el lock
  libre y sin un despliegue en curso.
- Guardas: abortar la actualización si el SHA-256 no coincide con el aprobado; no sustituir
  el binario mientras exista `/srv/myfinanzas-test/update.lock` tomado; registrar el hash
  anterior junto al `.previous`.
- El tag consumido no se reutiliza si hubo mutación; si el fallo fue previo, puede
  reintentarse el mismo tag y SHA.

## Incidente 2026-11-09: timeout de arranque

El segundo intento del tag `deploy-test-v0.1.0` falló porque el cliente
`systemctl` del receptor esperaba 60 s mientras systemd permitía 90 s:

- La parada del contenedor anterior duró 0,34 s: no fue la causa.
- systemd inició el arranque a las 09:15:55 UTC.
- Podman no creó el contenedor nuevo hasta las 09:17:03 UTC, 68 s después.
- El receptor agotó sus 60 s a las 09:16:54 UTC e inició el rollback; el `restart`
  del rollback canceló el job todavía pendiente y Podman terminó con código 1.
- El rollback restauró la release anterior (`5d2bb47`) y su smoke pasó.

No fue un fallo del bundle ni de la identidad de la imagen: la unidad anterior usa
el mismo `Image=sha256:<id>` con `Pull=never` y arranca en unos 10 s. El retraso
está en la fase previa a `container create` (preparación de la imagen nueva en su
primer uso o espera de almacenamiento); la línea exacta de Podman queda pendiente
de confirmar en el journal. Lo acreditado es el orden temporal y que el rollback
interrumpió un arranque aún pendiente.

La corrección coordina los timeouts y asienta la unidad antes de recuperar. Como
hubo mutación de unidad y frontend (aunque revertida), este incidente consume el
tag; la siguiente release será `deploy-test-v0.1.1`, solo tras validar la
corrección y recibir autorización.

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
