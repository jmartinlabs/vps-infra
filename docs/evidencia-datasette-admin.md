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

## Revisión de red privada Podman (alternativa a `--network=host`)

Se probó una red bridge privada con publicación solo en loopback:

- `--network=dsadmin -p 127.0.0.1:18112:18112`, Datasette en `0.0.0.0:18112`:
  - loopback 200; IP no-loopback del host **200**; listener `*:18112`.
  - **Rechazado**: no conserva loopback exclusivo en este Podman rootless/pasta.
- Red privada sin `-p`, Datasette en la IP del contenedor: la IP privada no es
  alcanzable desde el host/SSH; no se puede tunelar sin añadir proxy/firewall.
- `pasta -T 127.0.0.1/...` rechaza el binding loopback.

Conclusión: se mantiene `--network=host` + Datasette `127.0.0.1:<puerto>`, que sí
ha demostrado loopback 200 / IP no-loopback 000. Cambiar a red privada exigiría
un proxy o reglas de firewall adicionales, fuera del alcance autorizado.

## Backup/restore real MyFinanzas + age

Ejecutado con el árbol `origin/main` de MyFinanzas exportado en solo lectura, Bun
1.4.3/SQLite 3.53.4, age 1.2.1 Linux y un estado v27 sintético con identidad
`production` y `key_hash` de una clave de 32 bytes.

- `backup-cli.ts create`: `Copia cifrada completada.`; artefactos
  `database.age` y `access-key.age` 0600.
- `backup-cli.ts restore` a directorio nuevo: `Restauración aislada completada.`
  Archivos `database.sqlite` y `auth.key` 0600; `integrity_check=ok`,
  `foreign_key_check=[]`, `schema_version=27`, `origin=production`, hash de
  `auth.key` idéntico, sesiones/challenges/recovery/bootstrap a 0.
- El mismo ciclo se ejecutó a través de `backup_and_verify` del wrapper con una
  imagen de prueba que contiene la CLI, dependencias y age: backup y restore
  completados, artefactos y hashes correctos.

Esto valida la CLI/age/identidad/recuperación con datos sintéticos. La imagen
oficial de release de MyFinanzas y el VPS real siguen sin probarse.

## Pruebas automatizadas

- `./scripts/test-datasette-admin`: **36/36 PASS**.
- `./scripts/test-datasette-admin-integration`: **12/12 PASS**.
- `validate-template`, `check_harness`, `test-validator`: **188/188 PASS**.

## Bloqueos

- Backup/restore con CLI/`age` de MyFinanzas: **PASS local aislado** con el árbol
  `origin/main`, estado v27 sintético `production`, Bun 1.4.3/SQLite 3.53.4 y age
  1.2.1, incluyendo el ciclo a través de `backup_and_verify` del wrapper.
- Imagen oficial de release, VPS real, SSH `permitopen` y app MyFinanzas real:
  **pendientes**; no se declara PASS sobre ellos.
