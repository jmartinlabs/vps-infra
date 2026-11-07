# Administración SQLite TEST/PROD con Datasette

Editor privado para ejecutar SELECT/INSERT/UPDATE/DELETE **directamente** sobre la
base SQLite real de TEST o PROD. No hay snapshots editables, change sets ni una
segunda fase de aplicación.

## Arquitectura

- Datasette corre como el UID de la aplicación (`mftest`/`mfprod`) en Podman rootless.
- Se usa `--network=host` y Datasette escucha en `127.0.0.1` en el puerto del
  entorno. No se publica con `-p`; el puerto queda solo en loopback y el acceso
  desde Mac es por túnel SSH.
- Se monta el **directorio real** de estado; SQLite crea y recrea WAL/SHM en él.
- `auth.key` se sustituye solo dentro del namespace del contenedor por un fichero
  dummy; el original no se mueve, copia ni modifica.
- El estado conserva 0700/0600 y no usa ACL.
- Sin Caddy, sin UFW nuevo y sin puerto público.

Perfiles:

| Perfil | Uso | DML |
| --- | --- | --- |
| habitual | cambios de negocio | permitido en tablas de negocio; denegado en protegidas |
| `--maintenance` | correcciones técnicas excepcionales | permitido en protegidas, salvo `schema_version`/`database_origin`; auditoría solo INSERT |
| `--read-only` | consulta con MyFinanzas funcionando | denegado; sin backup ni parada de la app |

Siempre denegados desde el visor: DDL, migraciones, `ATTACH`, `PRAGMA` peligroso,
`VACUUM INTO`, `load_extension`, CTE de escritura, scripts multi-sentencia, tablas
no clasificadas y escritura de `schema_version`, `user_version`, `application_id`
o `database_origin`. La auditoría es append-only: nunca UPDATE/DELETE ni
`INSERT OR REPLACE`/upsert.

El mismo filtro se aplica al editor SQL, a las rutas HTTP de escritura por filas y
a las conexiones de escritura usadas por callbacks de Datasette. No se puede
saltar la política usando una ruta distinta del formulario SQL. Si el log de
auditoría no se puede escribir, la sentencia se interrumpe antes de confirmar el
cambio. El log registra el intento y el resultado de las operaciones del editor
SQL (`ok`, `error` o `rejected`) sin valores literales.

## Construcción

```bash
podman build -t localhost/vps-datasette-admin:latest infra/datasette-admin
podman run --rm localhost/vps-datasette-admin:latest sqlite3 --version
```

La imagen compila SQLite 3.53.4 desde la amalgama oficial, posterior al fix
WAL-reset 3.51.3. La versión de Bun del runtime de MyFinanzas también debe
permanecer parcheada.

## Uso desde el VPS

El wrapper debe ejecutarse como el UID de la aplicación, no como root. El puerto
solo escucha en loopback; el túnel es la única entrada desde Mac.

### TEST de escritura

```bash
sudo -u mftest scripts/datasette-admin start test \
  --state /srv/myfinanzas-test/data
```

### Lectura con la app funcionando

Válido para TEST y PROD; monta el estado en solo lectura y no exige backup,
mantenimiento ni parada de MyFinanzas:

```bash
sudo -u mfprod scripts/datasette-admin start prod \
  --state /srv/myfinanzas-prod/data \
  --read-only
```

### PROD de escritura

El wrapper comprueba que el servicio systemd del escritor no está activo y ejecuta
la CLI de backup/restore de la imagen de MyFinanzas. El backup y el restore usan
directorios nuevos; la identidad age se monta solo para la verificación:

```bash
sudo -u mfprod scripts/datasette-admin start prod \
  --state /srv/myfinanzas-prod/data \
  --writer-stopped \
  --app-service myfinanzas-api.service \
  --myfinanzas-image sha256:<id-verificado> \
  --app-origin https://myfinanzas.pp.ua \
  --backup-path /home/mfprod/backups/copia-2026-11-07 \
  --restore-path /home/mfprod/restores/restore-2026-11-07 \
  --backup-identity /run/keys/identity \
  --backup-recipient age1...
```

`--backup-path` y `--restore-path` deben ser directorios nuevos. El backup crea
`database.age` y `access-key.age`; el restore crea `database.sqlite` y `auth.key`
en un directorio nuevo. La CLI de MyFinanzas valida el esquema, la identidad
DB/auth.key, las invariantes y la recuperación; Infraestructura solo comprueba
que los artefactos existen con modos privados y que el servicio escritor está
inactivo. No se duplican esas reglas de dominio.

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

### Cierre y recuperación PROD

1. Cerrar el editor antes de reanudar la app.
2. Arrancar MyFinanzas y ejecutar su smoke habitual y sus comprobaciones de
   dominio.
3. Si hace falta una verificación o recuperación, usar la CLI de restore de
   MyFinanzas a un directorio nuevo; no sobrescribir la base original.

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
- El log privado registra actor, sesión, timestamp, operación, hash, forma del
  SQL, fase de intento/resultado y, en PROD, referencia de backup. No registra
  valores literales; el resultado se registra de forma best-effort después de la
  operación.
- `schema_version` y `database_origin` solo cambian por migración de la app.
- En PROD se usa una ventana de escritor único. El wrapper consulta
  `systemctl --user show <servicio> -p ActiveState` y rechaza `active`,
  `activating`, `deactivating` o `unknown`; `--writer-stopped` sigue siendo una
  confirmación adicional del operador. No se asume concurrencia de writers.
- `--security-opt label=disable` evita conflictos SELinux; la política de labels
  del VPS queda pendiente de validación.
- El backup/restore real y la validación de identidad dependen de la imagen y la
  CLI de MyFinanzas; se prueban de forma aislada y se delegan a su agente.

## Pruebas

```bash
./scripts/test-datasette-admin
python3 -m pip install 'datasette==1.0a41'
./scripts/test-datasette-admin-integration
```

La primera suite (**31 pruebas**) cubre autorizador, parser string-aware, dos
perfiles, solo lectura con WAL vivo, auditoría append-only/fail-closed y
resultado, PRAGMAs, DDL/ATTACH, schema/origin, tablas desconocidas, la matriz v27
completa (108 tablas; 72 protegidas y 36 de negocio) contrastada con
`infra/datasette-admin/v27_tables.json`, el esquema y los 176 triggers reales de
`v27_schema.sql`, AUTOINCREMENT, triggers de negocio y enmascarado. La segunda
(**12 pruebas**) importa el plugin real en Datasette 1.0a41 y comprueba
`Database.connect()`, `execute`, `execute_write`, escrituras por callback, health,
rutas HTTP, `_internal`, auditoría (incluidos rechazos DDL/PRAGMA/VACUUM) y solo
lectura.

Las pruebas de backup/restore con la imagen real de MyFinanzas, SSH y age
requieren el entorno aislado autorizado y se delegan al agente de MyFinanzas.
