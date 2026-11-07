# Administración SQLite TEST/PROD con Datasette

Editor privado para ejecutar SELECT/INSERT/UPDATE/DELETE **directamente** sobre la
base SQLite real de TEST o PROD. No hay snapshots editables, change sets ni una
segunda fase de aplicación.

## Arquitectura

- Datasette corre como el UID de la aplicación (`mftest`/`mfprod`) en Podman rootless.
- Se monta el **directorio real** de estado; SQLite crea y recrea WAL/SHM en él.
- `auth.key` se sustituye solo dentro del namespace del contenedor por un fichero
  dummy; el original no se mueve, copia ni modifica.
- El estado conserva 0700/0600 y no usa ACL.
- El puerto escucha solo en `127.0.0.1`; el acceso desde Mac es por túnel SSH.
- Sin Caddy, sin UFW nuevo y sin puerto público.

Dos perfiles:

| Perfil | Uso | DML |
| --- | --- | --- |
| habitual | cambios de negocio | permitido en tablas de negocio; denegado en protegidas |
| `--maintenance` | correcciones técnicas excepcionales | permitido en protegidas, salvo `schema_version`/`database_origin`; auditoría solo INSERT |

Siempre denegados desde el visor: DDL, migraciones, `ATTACH`, `PRAGMA` peligroso,
`VACUUM INTO`, `load_extension`, CTE de escritura, scripts multi-sentencia, tablas
no clasificadas y escritura de `schema_version`, `user_version`, `application_id`
o `database_origin`. La auditoría es append-only: nunca UPDATE/DELETE ni
`INSERT OR REPLACE`/upsert.

El mismo filtro se aplica al editor SQL, a las rutas HTTP de escritura por filas y
a las conexiones de escritura usadas por callbacks de Datasette. No se puede
saltar la política usando una ruta distinta del formulario SQL. Si el log de
auditoría no se puede escribir, la sentencia se interrumpe antes de confirmar el
cambio.

## Construcción

```bash
podman build -t localhost/vps-datasette-admin:latest infra/datasette-admin
podman run --rm localhost/vps-datasette-admin:latest sqlite3 --version
```

La imagen compila SQLite 3.53.4 desde la amalgama oficial, posterior al fix
WAL-reset 3.51.3. La versión de Bun del runtime de MyFinanzas también debe
permanecer parcheada.

## Uso desde el VPS

El wrapper debe ejecutarse como el UID de la aplicación, no como root.

### TEST

```bash
sudo -u mftest scripts/datasette-admin start test \
  --state /srv/myfinanzas-test/data
```

### PROD

Detener MyFinanzas, ejecutar un backup age verificado y arrancar el editor:

```bash
sudo -u mfprod scripts/datasette-admin start prod \
  --state /srv/myfinanzas-prod/data \
  --writer-stopped \
  --backup-cmd '/ruta/backup-cli create /ruta/backup-nuevo /ruta/recipient.age' \
  --backup-verify-cmd '/ruta/backup-cli verify-restore /ruta/backup-nuevo' \
  --backup-ref '/ruta/backup-nuevo' \
  --restore-path /ruta/restore-nuevo
```

El comando de verificación recibe `VPS_ADMIN_RESTORE_PATH` y debe restaurar el
backup a ese destino **nuevo**, comprobar que la copia es legible/consistente y
terminar en 0. El wrapper exige que el destino no existiera antes y que contenga
un artefacto no vacío. Sustituir los ejemplos por la interfaz real de la CLI de
MyFinanzas. Si el backup o su verificación fallan, no se abre el editor.

### Desde el Mac

El comando `start` imprime el túnel y la URL de un solo uso:

```bash
ssh -N -L 18084:127.0.0.1:18084 <usuario>@<vps>
```

Abrir la URL `http://127.0.0.1:18084/-/auth-token?token=...`, ejecutar el SQL y
comprobar el cambio en la app. Para PROD, cerrar el editor y después reanudar la
app. Para una corrección técnica:

```bash
sudo -u mfprod scripts/datasette-admin start prod ... --maintenance
```

### Cierre y comprobación PROD

1. Cerrar el editor antes de reanudar la app.
2. Comprobar la base con el UID de la app:

   ```bash
   sudo -u mfprod sqlite3 /srv/myfinanzas-prod/data/database.sqlite \
     'PRAGMA integrity_check; PRAGMA foreign_key_check;'
   ```

   `integrity_check` debe devolver `ok` y `foreign_key_check` no debe devolver
   filas.
3. Arrancar MyFinanzas y ejecutar el smoke habitual.
4. Ante un incidente, restaurar el backup **solo a un destino nuevo**; no
   sobrescribir la base original.

### Parada

```bash
scripts/datasette-admin stop test
scripts/datasette-admin stop prod
```

## Límites

- Un único administrador/token por sesión; no hay multiusuario.
- `owner.password`, `owner.secret`, `sessions.hash/csrf`, `challenges.hash`,
  `recovery.hash` y `bootstrap.hash` se enmascaran en la vista HTML; el SQL/JSON
  directo sigue siendo una superficie sensible.
- El SQL directo no ejecuta validaciones ni auditoría de dominio de MyFinanzas.
  No se promete que un UPDATE sea funcionalmente válido solo por pasar
  `integrity_check`.
- El log privado registra actor, sesión, timestamp, operación, hash y forma del
  SQL, y en PROD la referencia de backup. No registra valores literales ni el
  resultado final de cada sentencia; los errores se muestran en la interfaz y en
  los logs del contenedor.
- `schema_version` y `database_origin` solo cambian por migración de la app.
- En PROD se usa una ventana de escritor único: app detenida antes de editar y
  editor detenido antes de reanudar. No se asume concurrencia de writers.
- `--security-opt label=disable` evita conflictos SELinux; la política de labels
  del VPS queda pendiente de validación.

## Pruebas

```bash
./scripts/test-datasette-admin
python3 -m pip install 'datasette==1.0a41'
./scripts/test-datasette-admin-integration
```

La primera suite cubre autorizador, parser string-aware, dos perfiles, auditoría
append-only y fail-closed, PRAGMAs, DDL/ATTACH, schema/origin, tablas desconocidas,
la matriz v27 completa (108 tablas; 72 protegidas y 36 de negocio) contrastada con
el fixture `infra/datasette-admin/v27_tables.json`, AUTOINCREMENT, triggers de
negocio y enmascarado. La segunda importa el plugin real en Datasette
1.0a41 y comprueba `Database.connect()`, `execute`, `execute_write`, escrituras
por callback, health y las rutas HTTP principales. Las pruebas de contenedor
rootless, SSH y backup age se ejecutan en un entorno Linux aislado antes de
desplegar.
