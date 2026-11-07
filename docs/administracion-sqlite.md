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
`VACUUM INTO`, `load_extension` y escritura de `schema_version`/`database_origin`.
La auditoría es append-only: nunca UPDATE/DELETE.

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
  --backup-cmd '/ruta/backup-cli create /ruta/backup-nuevo /ruta/recipient.age'
```

El wrapper comprueba que el comando termina en 0, pero la verificación real del
backup/restore es responsabilidad de la CLI de MyFinanzas. Si el backup falla, no
se abre el editor.

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
- `schema_version` y `database_origin` solo cambian por migración de la app.
- En PROD se usa una ventana de escritor único: app detenida antes de editar y
  editor detenido antes de reanudar. No se asume concurrencia de writers.
- `--security-opt label=disable` evita conflictos SELinux; la política de labels
  del VPS queda pendiente de validación.

## Pruebas

```bash
./scripts/test-datasette-admin
```

Cubren autorizador, dos perfiles, auditoría append-only, PRAGMAs, DDL/ATTACH,
schema/origin y enmascarado. Las pruebas de contenedor rootless, SSH y WAL se
ejecutan en un entorno Linux aislado antes de desplegar.
