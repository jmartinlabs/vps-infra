# Evidencia local aislada · Datasette admin

Fecha: 2026-11-07. Entorno: Podman rootless local, VM sintética, DB v27/estado
sintético. **No es el VPS real, no contiene datos reales y no sustituye la
validación de la CLI de backup/restore de MyFinanzas.**

## TEST · Mac → túnel SSH → Datasette → UPDATE → lectura app

- Wrapper como `mftest`, estado canónico `/srv/myfinanzas-test/data`, puerto
  loopback `18110`. Arranque: `Editor test listo` (token redactado).
- Túnel SSH desde Mac al host de la VM con `-L 18110:127.0.0.1:18110`.
- Cliente Mac:
  - `GET /-/vps-admin-health`: **200**
  - `POST /database/-/execute-write` con
    `UPDATE movimientos SET importe='tunnel-updated' WHERE id=1`: **200**
  - lectura de la fila: `{"id": 1, "importe": "tunnel-updated"}`.
- Lectura posterior con el UID de la app (`mftest`) sobre la DB real del fixture:
  `tunnel-updated`.

Resultado: **PASS** (sintético).

## PROD · lectura con app/escritor activo

- Escritor externo sintético con WAL y `wal_autocheckpoint=0` insertó
  `prod-live` y mantuvo la conexión.
- Wrapper como `mfprod`, estado canónico `/srv/myfinanzas-prod/data`, puerto
  `18111`, `--read-only`.
- Lectura por el túnel/cliente:
  `{"rows": [{"id": 1, "importe": "100.00"}, {"id": 2, "importe": "prod-live"}]}`
- La escritura HTTP se rechazó; health `read_only=true`.

Resultado: **PASS** (sintético; sin backup ni parada).

## Recuperación sintética · snapshot + restore a directorio nuevo

- Snapshot consistente con `VACUUM INTO` (no `cp`, que perdería el WAL) a
  `/var/home/mftest/backups/copia-1`; `auth.key` copiada; hash
  `f64065aa…c0716a`.
- Modificación posterior en la DB viva a `tunnel-updated-2` y parada del editor.
- Restore del snapshot a `/var/home/mftest/restores/restore-1` (directorio nuevo):
  - `PRAGMA integrity_check`: `ok`
  - `PRAGMA foreign_key_check`: `[]`
  - fila restaurada: `tunnel-updated`
  - hash de `auth.key` restaurada: `f64065aa…c0716a` (coincide).

Resultado: **PASS** de la recuperación de datos sintética. **No es** el backup age
ni la CLI de MyFinanzas.

## Vinculación negativa

- `start test` como `mftest` con `/srv/myfinanzas-prod/data` fue rechazado antes
  de abrir el editor (sin permiso/validación de ruta).
- Tests unitarios cubren además UID/nombre incorrectos, entorno incorrecto,
  `..`, symlink final, symlink padre y path esperado symlink.

## Pruebas automatizadas

- `./scripts/test-datasette-admin`: **34/34 PASS**.
- `./scripts/test-datasette-admin-integration`: **12/12 PASS**.
- `validate-template`, `check_harness`, `test-validator`: **188/188 PASS**.

## Bloqueos

- Backup/restore real con imagen, `age` y CLI de MyFinanzas: **PENDIENTE**;
  delegado por relay 0018/0019. No se declara PASS.
- VPS real, SSH `permitopen`, app MyFinanzas real: no probados.
