# Actualización automática de MyFinanzas TEST

Fecha: 2026-11-08
Estado: **DRAFT — preparado, no desplegado.**

Referencias: [PR #27](https://github.com/jmartinlabs/vps-infra/pull/27),
[workflow #288](https://github.com/jmartinlabs/myfinanzas-app/pull/288),
[paquete TEST](paquete-test-recepcion-01.md) y
[preparación DNS/Caddy](preparacion-dns-caddy-test-01.md).

## Flujo permanente

1. Integración en `test` ejecuta CI `required`, QA y Rootless sobre el SHA exacto.
2. Con `MYFINANZAS_TEST_AUTO_PUBLISH=true`, GitHub Actions publica en GHCR:
   - `myfinanzas-test-app:sha-<SHA40>`
   - `myfinanzas-test-seed:sha-<SHA40>`
   - `myfinanzas-test-release:sha-<SHA40>` y `myfinanzas-test-release:test`
3. El VPS consulta cada 15 minutos `ghcr.io/jmartinlabs/myfinanzas-test-release:test`.
4. Verifica manifiesto, `SHA256SUMS`, contrato y digests; descarga la app por digest.
5. Actualiza solo imagen, unidad y frontend. No ejecuta seed, no crea estado, no toca
   PROD.
6. Smoke: health `200`, ruta protegida `401` y `current/index.html` presente.
7. Si falla, restaura unidad y frontend anteriores y reintenta smoke. Si el rollback falla,
   detiene la unidad y conserva todo para revisión.
8. Solo actualiza si el esquema declarado coincide con el instalado. Un cambio de esquema
   requiere procedimiento manual.

## Primera activación — operaciones manuales

La primera activación no se automatiza. Requiere autorización específica y ejecutar:

1. `production-init`, seed `FT-1`, `setup` y unidad inicial según el procedimiento aprobado.
2. Dar acceso de lectura a Caddy sin exponer datos privados:
   ```bash
   sudo chown mftest:caddy /var/www/myfinanzas-test
   sudo chmod 2750 /var/www/myfinanzas-test
   sudo install -d -m 2750 -o mftest -g caddy /var/www/myfinanzas-test/releases
   ```
   El directorio de release y la raíz quedan `2750`; los subdirectorios `0750` y los
   ficheros `0640`, con grupo `caddy`; nunca se sirve desde `/srv/myfinanzas-test` `0700`.
3. Instalar el updater y las unidades de usuario:
   ```bash
   sudo install -d -m 0700 -o mftest -g mftest \
     /home/mftest/bin /home/mftest/.config/systemd/user
   sudo install -m 0755 -o mftest -g mftest scripts/test-auto-update \
     /home/mftest/bin/myfinanzas-test-update
   sudo install -m 0644 -o mftest -g mftest \
     infra/systemd/user/myfinanzas-test-update.service \
     infra/systemd/user/myfinanzas-test-update.timer \
     /home/mftest/.config/systemd/user/
   sudo -u mftest env XDG_RUNTIME_DIR="/run/user/$(id -u mftest)" \
     systemctl --user daemon-reload
   sudo -u mftest env XDG_RUNTIME_DIR="/run/user/$(id -u mftest)" \
     systemctl --user enable --now myfinanzas-test-update.timer
   ```
4. Ejecutar una vez `myfinanzas-test-update --once` y revisar journal/estado.
5. Confirmar que `myfinanzas-test-release:test` y los paquetes GHCR son públicos, o el
   pull anónimo no funcionará.

No se ejecuta ninguna de estas operaciones en esta fase.

## Contrato del updater

- Release pointer: `myfinanzas-test-release:test`.
- Manifiesto del release image: `/manifest.json`, `/manifest.sha256`, `/SHA256SUMS`,
  `/frontend/`.
- Identidad de app: `manifest.oci_manifest_digest`; se descarga
  `myfinanzas-test-app@sha256:<digest>`.
- La imagen release declara labels de SHA, manifiesto, app/seed digests y contratos.
- El estado persistente vive en `/srv/myfinanzas-test/data`; no se modifica al actualizar.
- El estado de la última release está en `/srv/myfinanzas-test/current-release.json`.
- Una release que falla smoke/rollback se registra en `failed-release.json` y no se reintenta
  en cada ciclo; un digest nuevo vuelve a intentarlo. Si se corrige la causa del mismo
  digest, retirar `failed-release.json` manualmente tras revisión; no se limpia solo.
- El updater compara `schema` y `data_contract` instalados con el manifiesto; si cambian,
  bloquea y exige migración manual.

## Prueba local

```bash
./scripts/test-test-auto-update
```

Cubre:

- sin estado: no hace nada;
- actualización correcta: unidad, frontend y estado;
- smoke fallido: rollback a unidad/frontend anteriores y registro de release fallida;
- fallo al persistir estado: rollback de unidad/frontend;
- release fallida: no se reintenta el mismo digest;
- cambio de esquema o `data_contract`: bloqueo antes de tocar la unidad.

## Bloqueos reales

1. **Check `qa`:** el workflow automático lo exige; debe existir un check con ese nombre
   sobre el SHA exacto. Sin él no hay publicación automática.
2. **Visibilidad GHCR:** los tres paquetes deben ser públicos para pull anónimo desde el VPS.
3. **Permisos de frontend:** el primer despliegue debe cambiar
   `/var/www/myfinanzas-test` a `mftest:caddy 2750` para que el updater escriba y Caddy lea.
4. **Primera activación:** producción de estado, seed, `setup`, unidad y timer requieren
   autorización y ejecución manual.
5. **No se ha ejecutado nada** en VPS, DNS, Caddy, Quadlet ni datos.
