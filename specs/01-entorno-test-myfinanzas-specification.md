# 01 — INFRA-TEST-01: Entorno de pruebas de MyFinanzas — Specification

Status: DRAFT — pendiente de revisión y aprobación
Approval source/date: PENDING
Context and brainstorming: [01 — Brainstorming](01-entorno-test-myfinanzas-brainstorming.md)

## 1. Objetivo y alcance

Disponer de un entorno **TEST** de MyFinanzas en el VPS actual, accesible por
`https://test.myfinanzas.pp.ua`, con **datos exclusivamente ficticios**, sin exponer la
API ni la base de datos a Internet y sin interferir con el sitio `myfinanzas.pp.ua` ni
con el desarrollo paralelo de `myfinanzas-app`.

Esta especificación es una **propuesta revisable**. No autoriza:

- acceder al VPS, ni siquiera en modo lectura;
- crear DNS, certificados, usuarios, directorios, unidades o servicios reales;
- desplegar, actualizar, reiniciar o revertir nada;
- modificar `myfinanzas-app`;
- usar datos financieros reales, el Excel maestro o credenciales reales;
- iniciar la fase DEV;
- hacer merge de este PR.

La implementación posterior requiere autorizaciones separadas y expresas para cada
alcance: auditoría de solo lectura, aprovisionamiento del host, cambio de DNS, cambio de
Caddy y despliegue del candidato concreto. Los documentos de progreso y testplan se
crearán al iniciar la implementación, no en esta fase documental.

## 2. Hechos observados y requisitos de MyFinanzas

Consulta de solo lectura de `myfinanzas-app` el **2026-11-04** (remoto verificado:
`jmartinlabs/myfinanzas-app`). No se modificó el repositorio ni se ejecutaron sus pruebas.

Requisitos relevantes para el alojamiento:

| Área | Requisito observado |
| --- | --- |
| Runtime | Bun 1.4.3 fijado por digest en la imagen; aplicación web React/Vite + API Effect HTTP + SQLite. |
| Procesos | API en puerto `3001`; frontend estático generado por Vite; Vite de desarrollo en `5173` **no** debe publicarse. |
| Persistencia | SQLite y clave de autenticación en un directorio de estado privado; `DATABASE_PATH` y `AUTH_KEY_PATH` absolutos, mismos directorio, `0700`/`0600`, sin symlinks. |
| Identidad | Modo `production` con inicialización limpia, sin fixtures ni datos demo; alta de propietario único mediante token temporal; sin registro público. |
| Autenticación | Contraseña + TOTP, sesiones opacas, cookies `__Host-`/Secure en HTTPS, Origin y CSRF; límite de intentos por cuenta/origen declarado en la guía de seguridad de la app (verificar en el candidato; no es un rate limit de borde). |
| Salud | `GET /api/health` → `200` y JSON `{"ok":true}`; ruta protegida sin sesión → `401`. |
| Release | Paquete privado con `image.oci.tar`, `frontend/`, `manifest.json` y `manifest.sha256`; imagen identificada por ID inmutable; gate Rootless sobre el SHA exacto antes de desplegar. |
| Endurecimiento | UID/GID interno `10001`, `keep-id`, rootfs de solo lectura, `cap-drop=all`, `no-new-privileges`, memoria 1 GiB, CPU 1, 128 pids, tmpfs 64 MiB; sin `:U`, sin privilegios, sin socket de Podman. |
| Copias | Backup cifrado `age` con snapshot SQLite coherente y paquete de clave; restauración solo a destino nuevo; sin sobrescribir estado activo. |
| Estado del proyecto | El runbook de la aplicación declara el despliegue **NOT deployable** hasta cumplir sus gates. Esta especificación no rebaja ni sustituye esos gates. |

### 2.1 Fuente del contrato

Contrato observado en `jmartinlabs/myfinanzas-app`, `origin/main`
`0b8aade22cfb02f69f016e2418144dcb4ed9a763` (2026-11-04). **No es un candidato
congelado**: el SHA de despliegue se fija después y todos los valores se revalidan.

| Evidencia | Qué acredita |
| --- | --- |
| `infra/runtime.py` | UID interno `10001`, `keep-id`, publicación loopback, `APP_ORIGIN`, healthcheck, tmpfs y límites de recursos. |
| `infra/myfinanzas-api.container.example` y `infra/Containerfile` | Unidad de referencia, UID/GID, rootfs readonly, entrada Bun y `/app/healthcheck.mjs`. |
| `apps/api/src/server-config.ts` | `API_BIND_HOST` solo admite loopback por defecto o `0.0.0.0` explícito para namespace aislado. |
| `apps/api/src/main.ts` | API en `3001`, `APP_ORIGIN` y rutas por defecto. |
| `apps/api/src/private-state.ts` | Rutas absolutas canónicas, estado `0700`, DB/clave `0600`, sin symlinks y ancestros seguros. |
| `infra/RUNBOOK.md` | Inicialización productiva, `setup`, backup/restore, endurecimiento y gates previos al despliegue. |
| `infra/release.py` | Build reproducible, manifiesto, verificación por commit/SHA y render de unidad. |

El número de esquema y el SHA del candidato **no se fijan aquí**: se toman del manifiesto
y de la evidencia del release autorizado. A modo de trazabilidad, `origin/main` declara
`schemaVersion = 24` en `apps/api/src/database-identity.ts`; el runbook o los testplans de
la app pueden citar versiones anteriores. Cualquier cifra concreta debe verificarse en el
candidato y en su matriz de compatibilidad, no inferirse de este documento.

## 3. Arquitectura propuesta

```text
Internet
   |
   | HTTPS 443 / HTTP 80 (redirección)
   v
[Caddy del host]
   |-- test.myfinanzas.pp.ua
   |     |-- /            -> /var/www/myfinanzas-test/current (frontend estático)
   |     `-- /api/*       -> 127.0.0.1:18082
   |
   |   (el sitio myfinanzas.pp.ua y su placeholder no se modifican)
   v
[Podman rootless, usuario mftest]
   |
   `-- contenedor myfinanzas-test-api (UID 10001)
         |-- API 3001, bind 0.0.0.0 solo dentro del namespace
         |-- SQLite + clave en /var/lib/myfinanzas/state
         `-- volumen /srv/myfinanzas-test/data
```

Componentes y decisiones propuestas:

| ID | Decisión | Propuesta | Estado |
| --- | --- | --- | --- |
| D1 | Alcance | Un único TEST en el VPS actual; sin PROD. | Pendiente de confirmación |
| D2 | Identidad | Usuario dedicado `mftest`, rootless, sin login SSH, con `linger`. | Pendiente de confirmación |
| D3 | Red | Caddy → loopback `18082` → contenedor `3001`; sin publicar API/DB. | Pendiente de confirmación |
| D4 | DNS/HTTPS | `test` A/AAAA a la IP pública del VPS; TLS automático de Caddy; no copiar un proxy/CDN del dominio raíz sin decisión. | Pendiente de confirmación |
| D5 | Exposición | HTTPS público + autenticación de la app + `noindex`; allowlist opcional. | Pendiente de confirmación |
| D6 | Datos | Estado productivo limpio; datos ficticios manuales; sin Excel ni datos reales. | Pendiente de confirmación |
| D7 | Copias | Copia cifrada local bajo demanda + copia fuera del VPS en destino del usuario + simulacro de restauración. | Pendiente de confirmación |
| D8 | Frontera | `vps-infra` posee host/Caddy/unidad TEST; `myfinanzas-app` posee runtime/release. | Pendiente de confirmación |
| D9 | Operación | systemd de usuario, healthcheck y logs; sin monitorización residente nueva. | Pendiente de confirmación |

## 4. Fronteras de responsabilidad y contrato entre repositorios

### 4.1 Responsabilidades

| Elemento | Repositorio / responsable | Límite |
| --- | --- | --- |
| DNS, Caddy, TLS, rutas públicas y cabeceras del sitio TEST | `vps-infra` | El usuario aprueba y ejecuta el cambio en su proveedor DNS; no se toca el sitio raíz. |
| Usuario de sistema, `subuid`/`subgid`, `linger`, UFW, discos y permisos del host | `vps-infra` | Requiere acceso autorizado y ruta administrativa (sudo o consola del proveedor). |
| Unidad Quadlet específica de TEST, puerto, rutas, límites y activación | `vps-infra` | Debe revisarse contra el contrato de runtime de la app en cada release. |
| Frontend estático servido por Caddy | `vps-infra` (copia) + `myfinanzas-app` (artefacto) | Se sirve el `frontend/` del paquete verificado; nunca el servidor Vite. |
| Imagen, código, dependencias, esquema, migraciones, tests | `myfinanzas-app` | No se modifica en esta fase. |
| `production-init`, `setup`, healthcheck, backup/restore, autenticación | `myfinanzas-app` | Se invocan como CLI/imagen; no se reimplementan en `vps-infra`. |
| Evidencia Rootless, manifiesto, SHA, compatibilidad y rollback de aplicación | `myfinanzas-app` | Debe estar asociada al SHA exacto del candidato. |
| Aprobación de spec, acceso, DNS, despliegue, actualización y retirada | Usuario | Cada autorización es independiente; «ok» o «continúa» no sustituyen una aprobación protegida. |
| Revisión de arquitectura y seguridad | Álex / revisión independiente | Recomendación, no autorización. |

### 4.2 Contrato de despliegue TEST

| Campo | Valor propuesto |
| --- | --- |
| `environment` | `test` (metadato de este contrato; la app recibe `NODE_ENV=production` y `APP_ORIGIN`, no una variable `ENVIRONMENT` inventada) |
| `public_host` | `test.myfinanzas.pp.ua` |
| `public_origin` | `https://test.myfinanzas.pp.ua` |
| `dns_record` | `test` A/AAAA a la IP pública del VPS (no a un proxy/CDN del dominio raíz salvo decisión expresa); TTL 300; sin wildcard |
| `caddy_site` | Bloque independiente para `test.myfinanzas.pp.ua`; ubicación según auditoría de Caddy |
| `static_root` | `/var/www/myfinanzas-test/current` |
| `api_path` | `/api/*` |
| `api_host_loopback` | `127.0.0.1:18082` |
| `api_container_port` | `3001` |
| `health_path` | `/api/health` → `200` `{"ok":true}` |
| `protected_probe` | Una ruta autenticada, por ejemplo `GET /api/saldos` → `401` sin sesión |
| `host_user` | `mftest` (UID de host asignado dinámicamente; se registra, no se fija aquí) |
| `container_uid_gid` | `10001:10001` con `keep-id:uid=10001,gid=10001` |
| `data_root` | `/srv/myfinanzas-test/data` (0700, `mftest`) |
| `state_dir` | `/srv/myfinanzas-test/data/state` (0700, `mftest`) |
| `database_path` | `/srv/myfinanzas-test/data/state/database.sqlite` (0600) |
| `auth_key_path` | `/srv/myfinanzas-test/data/state/auth.key` (0600) |
| `release_root` | `/srv/myfinanzas-test/releases` (0700, `mftest`) |
| `backup_root` | `/srv/myfinanzas-test/backups` (0700, `mftest`) |
| `backup_mount` | `/srv/myfinanzas-test/backups:/backup:rw` solo en la tarea de copia; `:ro` en restore |
| `offsite_copy` | Destino controlado por el usuario fuera del VPS; cifrado y verificado antes de habilitar Caddy |
| `disk_budget` | ≤ 5 GB para TEST; margen mínimo 20 % libre y 10 % de inodos antes de desplegar |
| `unit_name` | `myfinanzas-test-api` |
| `container_name` | `myfinanzas-test-api` |
| `image` | `sha256:<ID inmutable del manifiesto>`; `Pull=never` |
| `resources` | memoria 1 GiB, CPU 1, pids 128, tmpfs 64 MiB |
| `secrets` | Fuera de Git/PR/logs; clave de auth en archivo 0600; identidad `age` fuera del VPS |
| `retention` | Release actual + release anterior; copia local y externa actual + anterior; sin poda global ni automática |

### 4.3 Secuencia de cambio

1. `myfinanzas-app` fija el candidato por SHA, ejecuta sus gates y entrega el paquete
   verificado con manifiesto, frontend, imagen y evidencia Rootless.
2. `vps-infra` revisa esta spec y la unidad TEST contra el contrato de la app.
3. El usuario autoriza la auditoría de solo lectura.
4. El usuario autoriza por separado el aprovisionamiento del host y los cambios de DNS
   y Caddy.
5. `vps-infra` aprovisiona y despliega el candidato exacto.
6. El usuario/propietario de la aplicación verifica el acceso y los datos ficticios.
7. Se registra evidencia de despliegue, verificación, backup y rollback. El registro no
   autoriza la siguiente fase.

## 5. Modelo de estado y datos

### 5.1 Rutas y permisos

| Ruta | Propietario | Modo | Contenido | Notas |
| --- | --- | --- | --- | --- |
| `/srv/myfinanzas-test` | `mftest` | 0700 | Raíz privada del entorno | Ancestro no escribible por terceros |
| `/srv/myfinanzas-test/data` | `mftest` | 0700 | Raíz de datos montada en `/var/lib/myfinanzas` | No montar solo el archivo SQLite |
| `/srv/myfinanzas-test/data/state` | `mftest` | 0700 | Estado operativo | Creado por `production-init`; no debe existir antes |
| `.../state/database.sqlite` | `mftest` | 0600 | SQLite | Sin symlinks/hardlinks; WAL/SHM con las mismas garantías |
| `.../state/auth.key` | `mftest` | 0600 | Clave de 32 bytes | No regenerar si se pierde; restaurar la pareja |
| `/srv/myfinanzas-test/releases` | `mftest` | 0700 | Paquetes OCI y manifiestos | Solo releases verificadas; conservar anterior |
| `/srv/myfinanzas-test/backups` | `mftest` | 0700 | Copias cifradas | Sin identidad `age` permanente |
| `/var/www/myfinanzas-test` | `root` | 0755 | Raíz estática pública | `releases/<sha>/` y symlink `current` |
| `/var/www/myfinanzas-test/current` | `root` | symlink | Release estática activa | Cambio atómico; no apunta fuera de la raíz |
| `~mftest/.config/containers/systemd` | `mftest` | 0700 | Unidad Quadlet | Sin secretos en la unidad |

`/var/www/myfinanzas-test` y sus archivos son públicos por diseño (son activos web).
No se aplica el modo 0700 a la raíz estática porque Caddy debe leerla. No se copian
secretos, mapas de fuente ni datos de estado a esa raíz.

### 5.2 datos ficticios

- No se copia el Excel `MyFinanzas2026_v5.11(7).xlsx`, bases reales, exportaciones,
  capturas ni credenciales reales.
- La base se inicializa limpia en modo `production`; no se usan fixtures demo ni se
  convierte una base demo en TEST.
- El conjunto ficticio se crea manualmente desde la UI tras el alta del propietario:
  Saldos, Categorías/Subcategorías/Partidas y unos pocos Movimientos con importes
  redondos, fechas fijas y nombres que incluyan `TEST` cuando sea útil.
- El conjunto se documenta en el expediente privado del operador (sin datos sensibles).
  No se versiona la base ni la clave.
- Antes de habilitar Caddy se crea una copia cifrada de línea base y se copia fuera del
  VPS; después de crear el conjunto ficticio se repite la copia y se verifica al menos
  una restauración aislada.
- Si apareciera cualquier dato real, se detiene la operación, se preserva evidencia y se
  solicita autorización antes de borrar o recrear el estado.

### 5.3 Secretos y custodia

| Secreto | Ubicación permitida | Prohibido |
| --- | --- | --- |
| Contraseña de TEST | Gestor de contraseñas del usuario | Repo, PR, chat, logs, capturas |
| Secreto TOTP y códigos de recuperación | Aplicación autenticadora y custodia del usuario | Repo, PR, chat, imagen, variables de entorno |
| Clave `auth.key` | Estado privado del host, 0600 | Git, imagen, logs, copia en claro |
| Identidad privada `age` | Fuera del VPS; montaje temporal 0600 solo para restore | Almacenamiento permanente en el VPS, repo, chat |
| Copias cifradas externas | Destino controlado por el usuario fuera del VPS | Repo, PR, chat, almacenamiento público |
| Token inicial de `setup` | Archivo exclusivo 0600 dentro del estado, leído por canal local privado | stdout/stderr, chat, logs, capturas |

## 6. Interfaces y configuración propuesta

### 6.1 DNS

Añadir, con autorización del usuario:

```text
test.myfinanzas.pp.ua. 300 IN A    <IP pública actual del VPS>
test.myfinanzas.pp.ua. 300 IN AAAA <IPv6 pública actual, si existe>
```

No crear wildcard. No modificar `myfinanzas.pp.ua`. Si el dominio raíz usa un proxy/CDN,
**no** copiar su registro al subdominio TEST: `test` debe apuntar a la IP del VPS, salvo
decisión expresa. Verificar A y AAAA (si existe) con resolutores públicos antes de
habilitar Caddy.

### 6.2 Caddy

Contenido propuesto; la ubicación exacta (bloque en el `Caddyfile` o fichero importado)
se decide **después** de auditar la configuración real. No sustituir el sitio raíz.

```caddyfile
test.myfinanzas.pp.ua {
    encode zstd gzip

    header {
        Strict-Transport-Security "max-age=300"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        X-Frame-Options "DENY"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'"
        X-Robots-Tag "noindex, nofollow"
    }

    handle /api/* {
        reverse_proxy 127.0.0.1:18082
    }

    handle /assets/* {
        header Cache-Control "public, max-age=31536000, immutable"
        root * /var/www/myfinanzas-test/current
        file_server
    }

    handle {
        header Cache-Control "no-store"
        root * /var/www/myfinanzas-test/current
        try_files {path} /index.html
        file_server
    }
}
```

Notas:

- `/api/*` no debe tener fallback a `index.html`; un 404 de API debe seguir siendo 404.
- Caddy conserva el `Host` y añade `X-Forwarded-Proto`; la aplicación decide cookies
  Secure por `APP_ORIGIN=https://test.myfinanzas.pp.ua`.
- HSTS se limita a `max-age=300` para un entorno efímero; no se usa `includeSubDomains`
  ni `preload`.
- `style-src 'unsafe-inline'` se mantiene como margen para estilos de la UI; si la
  build no los necesita, se puede retirar tras verificación en navegador.
- No se habilita listado de directorios ni se publican mapas de fuente.
- La ruta real del `Caddyfile` puede no ser `/etc/caddy/Caddyfile`; los comandos usan
  `<CADDYFILE>` como placeholder hasta la auditoría. El backup debe incluir el fichero
  principal y los imports que afecten al sitio, y la recarga debe verificar también el
  sitio raíz.

### 6.3 Unidad Quadlet propuesta

Fichero: `~mftest/.config/containers/systemd/myfinanzas-test-api.container` (dentro del
directorio de configuración del usuario `mftest`)

```ini
[Unit]
Description=MyFinanzas TEST rootless API
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Container]
Image=sha256:REPLACE_WITH_VERIFIED_IMAGE_ID
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

Condiciones:

- `Image` es el ID inmutable verificado del manifiesto; nunca una etiqueta móvil.
- `18081` es el puerto de referencia que usa el runbook de la app para PROD; TEST usa
  `18082` para poder coexistir sin colisión. El puerto interno de la API sigue siendo
  `3001`.
- No se usa `Network=host`, `--privileged`, socket de Podman, `:U` ni montajes de
  dispositivos. El namespace de red propio del contenedor es suficiente para un único
  servicio; no se comparte red con otras aplicaciones.
- La unidad no contiene secretos. La clave de auth es solo el archivo persistente.
- `ReadOnly=true` y `--read-only-tmpfs=false` mantienen el rootfs de solo lectura y el
  `/tmp` temporal controlado; la aplicación usa `TMPDIR=/tmp/private` de la imagen.
- `HealthCmd` usa el Bun fijado de la imagen y el healthcheck incluido.
- La CLI `render-unit` de `myfinanzas-app` no se usa como generador automático mientras
  mantenga valores fijos de PROD (`APP_ORIGIN`, rutas o puerto). La unidad TEST se escribe
  y revisa en `vps-infra` contra el contrato de runtime; parametrizar esa CLI es una
  mejora futura de la app, no un requisito de esta entrega.
- Cualquier cambio de estos valores debe revisarse contra el contrato de la app y quedar
  registrado; no se copia una plantilla `.example` sin revisión.
- La auditoría debe confirmar que la versión instalada de Quadlet acepta
  `StartLimitIntervalSec`/`StartLimitBurst` en `[Unit]`, que `network-online.target`
  existe en el gestor de usuario y que `HealthCmd` se ejecuta. Si no, se ajusta la unidad
  con una alternativa equivalente revisada, sin relajar el endurecimiento.
- Verificar en la prueba que `/run`, `/var/tmp` y el tmpfs `/tmp` no necesitan escritura
  adicional. Si la app la requiere, se revisa el contrato y se documenta; no se amplía
  `ReadOnly` a ciegas.

### 6.4 Frontend estático

- Se sirve el directorio `frontend/` del paquete verificado, no el servidor Vite.
- Publicación atómica: `releases/<sha>/` y symlink `current`.
- Permisos: directorios `0755`, archivos `0644`, propietario `root:root`; sin escritura
  para el usuario de aplicación.
- No se copian `node_modules`, fuentes, tests, `.env`, claves ni bases. Antes de publicar,
  comprobar que el `frontend/` no contiene `*.map`, `.env*` ni archivos de estado; si
  aparecen, bloquear la publicación y corregir el artefacto.
- La release anterior se conserva hasta verificar la nueva.

## 7. Procedimiento de despliegue

> Los comandos son un **borrador de runbook**. No se ejecutan en esta fase. Requieren
> autorización expresa, revisión del diff y sustitución de placeholders. No incluir
> secretos en el historial del shell ni en la salida.

### 7.1 Precondiciones y gates

1. Esta spec revisada y aprobada, y alcance de implementación autorizado.
2. Auditoría de solo lectura completada: host, Caddy, UFW, Podman rootless, `linger`,
   puertos libres, disco, usuarios, DNS y ruta administrativa.
3. Candidato de `myfinanzas-app` fijado por SHA completo de 40 caracteres, integrado y
   con **todos** los gates de deployabilidad aplicables del runbook de la app en
   `SUCCESS` sobre ese mismo SHA, incluido Rootless.
4. Paquete verificado con `--expected-commit` y `--expected-manifest-sha256`; imagen
   cargada y seleccionada por ID inmutable.
5. Evidencia de compatibilidad/rollback de la app si se actualiza una release existente;
   sin prueba del par exacto no se hace rollback de código sobre datos.
6. Datos exclusivamente ficticios; sin Excel, bases reales ni credenciales reales.
7. Destino externo de copia aprobado por el usuario y accesible por canal privado; sin
   destino, el despliegue se bloquea. Una excepción exige aprobación explícita y registro.
8. Ventana y autorización de despliegue; coordinación con el desarrollo de la app para
   no interferir.

Si falta cualquier gate, **detenerse**; no sustituirlo por una ejecución en verde de
otro commit.

### 7.2 Auditoría de solo lectura (fase separada)

Comprobar sin modificar y sin capturar secretos:

- `hostnamectl`, versión Debian, recursos, disco libre e inodos.
- `ss -ltnp` y UFW: 80/443 públicos, 18082 libre y solo loopback, sin API/DB pública.
- `caddy version`, configuración efectiva, sitios, TLS, imports y método de recarga.
- Podman rootless, `subuid`/`subgid`, cgroup v2, `systemctl --user`, `linger` y
  persistencia tras reinicio; comprobar que los rangos de `mftest` no solapan con otros
  usuarios rootless.
- Existencia de `mftest`, rutas `/srv/myfinanzas-test` y `/var/www/myfinanzas-test`.
- DNS actual del dominio raíz; no asumir IP ni proveedor.
- Ruta administrativa disponible (sudo de `mfadmin` o consola del proveedor).

Entregable: evidencia redactada, diferencias frente a lo documentado, riesgos y
solicitudes de autorización. Cero cambios remotos.

### 7.3 Aprovisionamiento del host (fase separada)

1. Crear `mftest` sin login SSH, con home 0750, `subuid`/`subgid` sin solapar con otros
   usuarios y shell no interactiva. La ejecución de tareas como `mftest` se hace con
   `sudo -H -u`/`runuser` y `XDG_RUNTIME_DIR`; si `systemctl --user` no conecta, usar la
   consola autorizada, sin abrir SSH al usuario de aplicación ni asumir que una shell
   `nologin` admite `machinectl shell`.
2. Habilitar `linger` y verificar `Linger=yes`; sin esto la unidad no arranca al reiniciar.
3. Crear `/srv/myfinanzas-test/{data,releases,backups}` con propietario `mftest` y modo
   0700; no crear `state` (lo crea la inicialización).
4. Crear `/var/www/myfinanzas-test/releases` como `root:root` 0755; no crear `current`
   hasta tener una release verificada.
5. Confirmar que UFW conserva solo 80/443 públicos y que 18082 no se abre.
6. Registrar UID/GID de host, versiones y evidencia; no modificar otros servicios.

### 7.4 Preparar el release

En el entorno autorizado de `myfinanzas-app`:

```sh
python3 infra/release.py build --ref <SHA40> --output /ruta/privada/release-<SHA40>
python3 infra/release.py verify /ruta/privada/release-<SHA40> \
  --expected-commit <SHA40> \
  --expected-manifest-sha256 <MANIFEST_SHA256>
```

Transportar por canal privado autorizado, conservar la carpeta 0700 y verificar de nuevo
en el VPS antes de cargar. La verificación completa con `release.py verify` se ejecuta en
el entorno de la app antes del transporte; en el VPS se hace una comprobación independiente
de checksums y del manifiesto, sin clonar el repositorio de la aplicación:

El manifiesto generado por `infra/release.py` usa las claves `inputs.source`,
`oci_archive_sha256` y `frontend_files` (mapa ruta→sha256). Si un candidato cambia ese
esquema, se actualiza este verificador y se revisa antes de desplegar; no se ignora el
fallo.

```sh
cd /srv/myfinanzas-test/releases/<SHA40>
test "$(sha256sum manifest.json | cut -d' ' -f1)" = "$(cat manifest.sha256)"
python3 - <<'PY'
import hashlib, json, pathlib
def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()
root = pathlib.Path('.')
manifest = json.loads((root / 'manifest.json').read_text())
assert manifest['inputs']['source'] == '<SHA40>'
assert digest(root / 'image.oci.tar') == manifest['oci_archive_sha256']
for relative, expected in manifest['frontend_files'].items():
    assert digest(root / 'frontend' / relative) == expected
print('manifest and frontend checksums OK')
PY
```

No publicar el paquete como artifact de CI.

```sh
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman load --input /srv/myfinanzas-test/releases/<SHA40>/image.oci.tar
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman image inspect --format '{{.Id}}' sha256:<IMAGE_ID>
```

Seleccionar el ID inmutable que declare el manifiesto y comprobar que coincide con el ID
cargado y que no hay otra imagen con ese ID. Guardar el SHA, el SHA del manifiesto y el ID
de imagen en el expediente privado del operador, junto con PASS/FAIL/UNRUN; nunca en el
repositorio ni en el chat.

### 7.5 Inicializar el estado limpio

Con `state` inexistente y el mount completo de la raíz de datos:

```sh
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman run --rm --pull=never --http-proxy=false --network=none \
    --userns=keep-id:uid=10001,gid=10001 --user=10001:10001 \
    --cap-drop=all --security-opt=no-new-privileges \
    --read-only --read-only-tmpfs=false --memory=1g --cpus=1 --pids-limit=128 \
    --tmpfs=/tmp:rw,noexec,nosuid,nodev,tmpcopyup,mode=0711,size=64m \
    --volume=/srv/myfinanzas-test/data:/var/lib/myfinanzas:rw \
    --env=NODE_ENV=production \
    --env=APP_ORIGIN=https://test.myfinanzas.pp.ua \
    --env=DATABASE_PATH=/var/lib/myfinanzas/state/database.sqlite \
    --env=AUTH_KEY_PATH=/var/lib/myfinanzas/state/auth.key \
    sha256:<IMAGE_ID> apps/api/src/production-init.ts
```

Resultado esperado: `state/` nuevo con DB y clave 0600, sin usuario y sin fixtures. Si
el comando rechaza por estado existente o permisos, **no borrar** ni forzar: preservar y
diagnosticar.

### 7.6 Alta del propietario de TEST

Mismos flags, montaje y entorno, con el comando:

```text
apps/api/src/setup.ts /var/lib/myfinanzas/state/alta.txt
```

El token se entrega solo en ese archivo 0600. El operador lo lee por canal local privado,
completa contraseña y TOTP en la UI y elimina el archivo. Nunca mostrar el token en
stdout, chat, logs o capturas. Guardar los códigos de recuperación fuera del VPS. Antes de
habilitar Caddy, crear la copia cifrada de línea base y su copia fuera del VPS (§9.3); el
archivo de token no debe existir en ninguna copia.

### 7.7 Activar la unidad

1. Escribir la unidad revisada con el ID de imagen verificado.
2. Validar el texto y los permisos; no copiar `.example` sin sustituir placeholders.
3. Ejecutar:

```sh
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  systemctl --user daemon-reload
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  systemctl --user start myfinanzas-test-api.service
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  systemctl --user show myfinanzas-test-api.service -p ActiveState -p NRestarts -p Result
```

4. Comprobar `ActiveState=active`, `NRestarts=0` y el healthcheck del contenedor.
5. Verificar en el host: `curl -fsS http://127.0.0.1:18082/api/health` → `{"ok":true}`;
   `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18082/api/saldos` → `401`.

No usar `reset-failed` repetidamente para ocultar un start-limit; diagnosticar primero.

### 7.8 Publicar el frontend

```sh
sudo install -d -m 0755 -o root -g root /var/www/myfinanzas-test/releases/<SHA40>
sudo rsync -a --delete <release>/frontend/ /var/www/myfinanzas-test/releases/<SHA40>/
sudo chown -R root:root /var/www/myfinanzas-test/releases/<SHA40>
sudo chmod -R a+rX,go-w /var/www/myfinanzas-test/releases/<SHA40>
sudo ln -sfn releases/<SHA40> /var/www/myfinanzas-test/current.new
sudo mv -Tf /var/www/myfinanzas-test/current.new /var/www/myfinanzas-test/current
```

`ln -sfn` no es atómico; `mv -Tf` sobre el symlink nuevo sí lo es en Linux. Comprobar que
`current` apunta a la release verificada y que no hay enlaces fuera de la raíz. No copiar
el servidor Vite ni archivos de estado.

### 7.9 Habilitar Caddy y DNS

Orden recomendado: DNS → app/static listos → Caddy. Así el certificado se emite cuando
la aplicación ya responde y no se publica un 502 evitable.

1. El usuario crea el registro DNS `test` con TTL 300, sin tocar el dominio raíz.
2. Verificar propagación A/AAAA con resolutores públicos y comparar con la IP del VPS.
3. Copiar `<CADDYFILE>` y los imports afectados a un backup fechado y solo root.
4. Añadir el bloque de `test.myfinanzas.pp.ua` en el lugar que determine la auditoría.
5. `sudo caddy validate --config <CADDYFILE> --adapter caddyfile`.
6. `sudo systemctl reload caddy` y comprobar `systemctl is-active caddy`.
7. Verificar TLS, las rutas de TEST y que `myfinanzas.pp.ua` sigue respondiendo; si falla,
   restaurar el backup y recargar.

### 7.10 Verificación posterior

Ejecutar, como mínimo, las comprobaciones de la sección 8 y registrar resultados
PASS/FAIL/UNRUN con el SHA, el ID de imagen, la fecha y el comando aplicable. El
expediente es privado del operador (fuera del repositorio); si se resume en
`docs/estado-actual.md`, debe hacerse sin secretos, IPs privadas, credenciales ni datos
financieros. No declarar operativo lo que solo está documentado.

## 8. Verificación

### 8.1 Comprobaciones mínimas

```sh
dig +short A test.myfinanzas.pp.ua @1.1.1.1
dig +short AAAA test.myfinanzas.pp.ua @1.1.1.1
dig +short A myfinanzas.pp.ua @1.1.1.1

curl -fsS -D- https://test.myfinanzas.pp.ua/api/health
curl -sS -o /dev/null -w '%{http_code}\n' https://test.myfinanzas.pp.ua/api/saldos
curl -sS -o /dev/null -w '%{http_code}\n' https://test.myfinanzas.pp.ua/api/ruta-inexistente
curl -sS -o /dev/null -w '%{http_code}\n' http://test.myfinanzas.pp.ua/
curl -fsSI https://test.myfinanzas.pp.ua/
openssl s_client -connect test.myfinanzas.pp.ua:443 -servername test.myfinanzas.pp.ua \
  </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
find /var/www/myfinanzas-test/current -name '*.map' -o -name '.env*'
```

Resultados esperados:

- DNS de `test` resuelve a la IP pública del VPS; si el dominio raíz usa proxy/CDN, no
  se ha copiado ese destino. El registro raíz no cambió.
- `/api/health` → `200` y `{"ok":true}`.
- Ruta protegida sin sesión → `401`.
- `http://` → redirección a HTTPS.
- `https://` → `200`, sin listado de directorios, con CSP, `noindex`, `nosniff`,
  `Referrer-Policy` y HSTS corto.
- Certificado válido para `test.myfinanzas.pp.ua`, cadena y fecha correctas.
- `127.0.0.1:18082` escucha solo en loopback; desde una red externa el puerto no responde.
- La UI carga, el login con contraseña+TOTP funciona y una mutación ficticia se guarda.
- Un `/api/*` desconocido devuelve 404 de API, no `index.html`.
- La búsqueda de `*.map` o `.env*` en el frontend no devuelve resultados.
- En el navegador, cookies de sesión `__Host-`, Secure, HttpOnly, SameSite=Strict y sin
  atributo `Domain`; una petición con Origin ajeno es rechazada.

No se guardan credenciales, cookies, TOTP, importes ni respuestas autenticadas en logs,
capturas o artifacts. Las comprobaciones que requieren login las realiza el usuario o un
operador autorizado por canal privado.

### 8.2 Persistencia y arranque

- `systemctl --user restart` de la unidad: vuelve `active`, health 200, datos intactos.
- Reinicio del VPS (autorización y ventana separadas): `linger` mantiene el gestor de
  usuario, la unidad arranca y los datos persisten. Un `restart` no sustituye esta prueba.
- No se borran WAL/SHM ni se copia solo la DB durante la prueba.

## 9. Actualización, rollback, recuperación y retirada

### 9.1 Actualización

1. Verificar el nuevo release y **todos** los gates de deployabilidad del SHA exacto.
2. Copia cifrada deliberada antes del cambio y copia fuera del VPS; registrar corte.
3. Detener la unidad y comprobar que no queda escritor ni puerto publicado.
4. Cargar la nueva imagen por ID inmutable; conservar la anterior.
5. Publicar el nuevo frontend en `releases/<sha>` y actualizar `current` de forma atómica.
6. Actualizar la unidad y `daemon-reload`; arrancar y verificar salud, login y una
   escritura ficticia.
7. Conservar release, imagen y datos anteriores hasta que la verificación sea completa.

Sin auto-update, sin `prune` global y sin sustituir la release anterior antes de verificar.

### 9.2 Rollback

- **Caddy:** restaurar el backup, validar y recargar. Si el sitio TEST falla, se puede
  retirar su bloque sin afectar al dominio raíz.
- **Aplicación:** solo al par exacto release/imagen/esquema con evidencia de
  compatibilidad y escrituras; no se revierte el esquema a la fuerza ni se reemplaza el
  estado activo por una copia. Reposicionar también `current` al frontend de la release
  anterior con `mv -Tf`, no solo la unidad/imagen.
- **Sin prueba de compatibilidad:** no hacer rollback de código sobre los datos actuales.
  Preservar el estado, detener la unidad y elegir entre una release compatible o una
  reconstrucción de TEST con un estado nuevo, con autorización.
- **DNS:** corregir o retirar el registro `test`; nunca tocar el registro raíz.
- **Usuario/datos:** no eliminar `mftest`, `/srv/myfinanzas-test` ni copias sin
  inventario de impacto y autorización.

### 9.3 Copia externa y recuperación

La copia externa es obligatoria antes de habilitar Caddy. El destino lo indica el usuario
(equipo personal o almacenamiento ya aprobado); no se crea un proveedor nuevo. Sin destino
externo aprobado, D7 bloquea el despliegue. Cualquier excepción requiere aprobación
explícita del usuario, justificación y registro de la desviación; no se presume por
silencio ni por una autorización genérica.

#### Crear la copia local

```sh
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman run --rm --pull=never --http-proxy=false --network=none \
    --userns=keep-id:uid=10001,gid=10001 --user=10001:10001 \
    --cap-drop=all --security-opt=no-new-privileges \
    --read-only --read-only-tmpfs=false --memory=1g --cpus=1 --pids-limit=128 \
    --tmpfs=/tmp:rw,noexec,nosuid,nodev,tmpcopyup,mode=0711,size=64m \
    --volume=/srv/myfinanzas-test/data:/var/lib/myfinanzas:rw \
    --volume=/srv/myfinanzas-test/backups:/backup:rw \
    --env=NODE_ENV=production \
    --env=APP_ORIGIN=https://test.myfinanzas.pp.ua \
    --env=DATABASE_PATH=/var/lib/myfinanzas/state/database.sqlite \
    --env=AUTH_KEY_PATH=/var/lib/myfinanzas/state/auth.key \
    sha256:<IMAGE_ID> apps/api/src/backup-cli.ts create \
      /backup/<COPIA_NUEVA> <DESTINATARIO_PUBLICO_AGE>
```

`/backup` se corresponde con `/srv/myfinanzas-test/backups`; no se monta la identidad
privada en la tarea de copia. El destinatario `age` es público. Comprobar que la copia
nueva no existía y que no se ha sobrescrito una anterior.

#### Copiar fuera del VPS

Transportar el paquete `database.age` + `access-key.age` por canal privado al destino
externo acordado y verificar checksums en origen y destino:

```sh
sudo -H -u mftest sha256sum /srv/myfinanzas-test/backups/<COPIA_NUEVA>/*
# comparar los mismos valores en el destino externo
```

La copia externa se guarda cifrada; la identidad privada `age` no viaja con ella. Mantener
al menos la copia actual y la anterior, sin poda automática. Registrar fecha, ruta,
checksums y resultado.

#### Restaurar en un destino nuevo

1. Copiar el paquete de vuelta a `/srv/myfinanzas-test/backups/<COPIA>` (solo lectura en
   la tarea).
2. Colocar la identidad privada en un archivo temporal 0600 propiedad de `mftest` bajo
   `/run/user/<uid>/mf-age-identity`; se monta read-only y se elimina al terminar.
3. Restaurar a un directorio nuevo, nunca sobre el estado activo:

```sh
RESTORE_TS=$(date -u +%Y%m%dT%H%M%SZ)
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman run --rm --pull=never --http-proxy=false --network=none \
    --userns=keep-id:uid=10001,gid=10001 --user=10001:10001 \
    --cap-drop=all --security-opt=no-new-privileges \
    --read-only --read-only-tmpfs=false --memory=1g --cpus=1 --pids-limit=128 \
    --tmpfs=/tmp:rw,noexec,nosuid,nodev,tmpcopyup,mode=0711,size=64m \
    --volume=/srv/myfinanzas-test/data:/var/lib/myfinanzas:rw \
    --volume=/srv/myfinanzas-test/backups/<COPIA>:/backup:ro \
    --volume=/run/user/$(id -u mftest)/mf-age-identity:/run/keys/identity:ro \
    --env=NODE_ENV=production \
    --env=APP_ORIGIN=https://test.myfinanzas.pp.ua \
    --env=DATABASE_PATH=/var/lib/myfinanzas/restore-${RESTORE_TS}/database.sqlite \
    --env=AUTH_KEY_PATH=/var/lib/myfinanzas/restore-${RESTORE_TS}/auth.key \
    sha256:<IMAGE_ID> apps/api/src/backup-cli.ts restore \
      /backup /var/lib/myfinanzas/restore-${RESTORE_TS} /run/keys/identity
```

4. Verificar integridad, esquema, clave, contraseña/TOTP y lectura de datos ficticios.
   Para no tocar la unidad activa, arrancar un contenedor temporal en
   `127.0.0.1:18083` con el estado restaurado, comprobar health y login, y retirar solo
   ese contenedor propio:

```sh
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman run -d --rm --name myfinanzas-test-restore-check \
    --pull=never --http-proxy=false \
    --userns=keep-id:uid=10001,gid=10001 --user=10001:10001 \
    --cap-drop=all --security-opt=no-new-privileges \
    --read-only --read-only-tmpfs=false --memory=1g --cpus=1 --pids-limit=128 \
    --tmpfs=/tmp:rw,noexec,nosuid,nodev,tmpcopyup,mode=0711,size=64m \
    --publish=127.0.0.1:18083:3001 \
    --volume=/srv/myfinanzas-test/data:/var/lib/myfinanzas:rw \
    --env=NODE_ENV=production \
    --env=APP_ORIGIN=https://test.myfinanzas.pp.ua \
    --env=DATABASE_PATH=/var/lib/myfinanzas/restore-${RESTORE_TS}/database.sqlite \
    --env=AUTH_KEY_PATH=/var/lib/myfinanzas/restore-${RESTORE_TS}/auth.key \
    --env=API_BIND_HOST=0.0.0.0 \
    sha256:<IMAGE_ID> apps/api/src/main.ts
curl -fsS http://127.0.0.1:18083/api/health
sudo -H -u mftest env XDG_RUNTIME_DIR=/run/user/$(id -u mftest) \
  podman rm -f myfinanzas-test-restore-check
```
5. Si la restauración falla, preservar origen, copia y destino; no borrar ni reintentar
   sobrescribiendo. Escalar con evidencia.
6. Registrar el RTO observado. TEST no promete RPO/RTO de producción ni la retención
   7/4/3; la copia externa mínima y la restauración sí son requisitos de esta entrega.

Pérdida de la clave `auth.key`: no se regenera. Se restaura la pareja DB+clave desde una
copia; si no existe, se reconstruye TEST con autorización. Pérdida total de TOTP: usar
códigos de recuperación; si tampoco existen, reconstruir TEST; no hay bypass.

### 9.4 Retirada

Con autorización específica: detener y deshabilitar la unidad, validar y retirar el bloque
Caddy y recargar, comprobar que `myfinanzas.pp.ua` sigue respondiendo, retirar el registro
DNS `test`, deshabilitar `linger` y preservar datos/copias hasta que el usuario autorice su
borrado. El dominio raíz y otros servicios no se tocan. La retirada no borra evidencia ni
copias sin inventario y plan de recuperación.

## 10. Estados vacíos, de carga y de error

No hay estados de UI nuevos; la UI y sus mensajes pertenecen a `myfinanzas-app`. Para la
infraestructura:

| Estado | Comportamiento esperado |
| --- | --- |
| Sin desplegar | No existe sitio Caddy TEST, unidad ni DNS `test`; el dominio raíz sigue igual. |
| Aprovisionando | DNS puede existir, pero Caddy no se habilita hasta que app y frontend estén listos. |
| App parada | Caddy devuelve `502` en `/api/*`; el frontend puede cargar y mostrar el error de red de la app. |
| Salud degradada | systemd reinicia según `Restart=on-failure`; tras el límite queda `failed`; no se fuerza `reset-failed` sin diagnosticar. |
| DNS no propagado | Caddy no emite certificado; no se declara el entorno operativo. |
| Certificado inválido | Detener la publicación, revisar DNS/80/443/Caddy y restaurar configuración si hace falta. |
| `401` | Esperado en ruta protegida sin sesión. |
| `403` | Revisar Origin/CSRF; no relajar la política para «hacer que funcione». |
| `500` | Revisar logs con `requestId`, sin payload financiero; no publicar logs crudos. |
| `state` ya existe | La inicialización debe rechazar; no borrar el estado para reintentar. |
| Permisos/UID incorrectos | Detenerse; no aplicar `chmod`/`chown` reparadores ni `:U`. |
| Manifiesto no coincide | No cargar la imagen; detener y repetir la verificación. |
| Disco lleno | Detener despliegue, preservar estado/copias y liberar solo releases propias verificadas con autorización. |

## 11. Comportamiento de API y dependencias externas

- La API no se publica directamente: solo Caddy accede a `127.0.0.1:18082`.
- `/api/health` es público y mínimo; las rutas financieras exigen sesión MFA.
- Caddy no reescribe el cuerpo ni añade CORS comodín; conserva el origen esperado.
- Dependencias externas: proveedor DNS, Aruba Cloud (consola/ruta administrativa),
  GitHub Actions (gate Rootless), Podman/Quadlet/systemd, Caddy, `age` y el registro
  paquete privado de release transportado (no un registry público). No se añaden
  servicios de terceros ni monitorización residente.
- La release de la app es la única fuente de imagen/frontend; `vps-infra` no reconstruye
  la aplicación ni modifica su código.

## 12. Validación y casos límite

| Caso | Respuesta esperada |
| --- | --- |
| El candidato no tiene gate Rootless sobre el SHA exacto | Bloquear el despliegue. |
| El manifiesto o el checksum no verifican | No cargar la imagen; detener. |
| Se intenta reutilizar una imagen por etiqueta | Rechazar; usar el ID inmutable del manifiesto. |
| Se intenta montar solo `database.sqlite` | Rechazar; montar la raíz de datos completa. |
| Se usa `0.0.0.0` en el host público | Rechazar; solo dentro del namespace; publicar en loopback. |
| Se intenta `:U`, `--privileged` o socket de Podman | Rechazar por el contrato de seguridad. |
| Se intenta arrancar con estado existente o demo | La app debe rechazar; no borrar ni convertir. |
| Se intenta usar datos reales o el Excel | Detener; no hay autorización. |
| Se pierde la clave de auth | Restaurar pareja DB+clave; no regenerar. |
| Se pierde TOTP | Códigos de recuperación o reconstrucción autorizada; sin bypass. |
| Rollback sin prueba de compatibilidad | Bloquear; preservar datos y escalar. |
| Reinicio del VPS sin `linger` | La unidad no vuelve; corregir con autorización y repetir la prueba. |
| Caddy mal configurado | Restaurar backup validado; el dominio raíz no se toca. |
| Disco por debajo del margen acordado | No desplegar; preservar y liberar solo recursos propios verificados. |
| Acceso no autorizado al VPS | No ejecutar; pedir autorización específica. |

## 13. Exclusiones

- Fase DEV, PROD, migración de datos reales, importación del Excel o promoción de TEST.
- Acceso al VPS, auditoría, DNS, Caddy, SSH, UFW, Podman o despliegue reales en esta fase.
- Modificación del código, tests, esquema o configuración de `myfinanzas-app`.
- Publicación de API, SQLite, panel administrativo o servidor Vite en Internet.
- Kubernetes, orquestadores, monitorización residente nueva, auto-update o auto-merge.
- Scheduler, alertas, retención 7/4/3 o SLA/RPO/RTO de producción en TEST. La copia
  externa mínima **sí** está incluida; no se excluye.
- Multiusuario, registro público, recuperación administrativa o bypass de MFA.
- Certificación de seguridad, auditoría WCAG, prueba de carga o alta disponibilidad.
- Cualquier merge o despliegue derivado de este PR.

## 14. Riesgos y decisiones abiertas

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| VPS pequeño compartido (2 vCPU/4 GB/40 GB) | Contención o falta de disco | Límites 1 GiB/1 CPU/128 pids, presupuesto de disco y margen libre; medir antes de ampliar. |
| Login TEST público | Fuerza bruta o abuso | MFA, límite de intentos de la app, `noindex`, contraseña de TEST robusta; si no se acepta exposición pública, allowlist/Basic Auth o rate limit de borde antes de publicar (D5). |
| Configuración real de Caddy desconocida | Interrumpir el sitio actual | Auditoría previa, backup, `caddy validate`, recarga y rollback. |
| Proveedor DNS desconocido | Retraso o error de propagación | El usuario ejecuta el cambio; verificación con resolutores públicos. |
| Ruta administrativa no disponible | Bloqueo del aprovisionamiento | Confirmar sudo/consola antes de empezar; no improvisar acceso root. |
| App aún «NOT deployable» | Despliegue prematuro | Exigir gates de app y SHA exacto; esta spec no los rebaja. |
| Deriva entre unidad TEST y contrato de app | Debilidad de seguridad | Revisión campo a campo en cada release; documentar diferencias. |
| Pérdida de identidad `age` o `auth.key` | Imposibilidad de restaurar | Custodia fuera del VPS, copia cifrada y simulacro; no regenerar. |
| Datos ficticios contaminados con reales | Riesgo de privacidad | Procedimiento explícito, revisión y parada ante cualquier dato real. |
| Aislamiento rootless limitado frente a root del host | Compromiso del host | Aceptado y documentado; no se presenta como frontera frente a root. |

Decisiones que el usuario debe confirmar antes de implementar:

1. D1: un único TEST en el VPS actual.
2. D2: usuario dedicado `mftest` frente a reutilizar `mfadmin`.
3. D3: loopback `18082` frente a otro puerto libre.
4. D4: DNS `test` a la IP del VPS y TLS automático de Caddy.
5. D5: acceso público con auth de la app frente a allowlist/Basic Auth.
6. D6: estado productivo limpio y datos ficticios manuales.
7. D7: copia externa mínima y destino concreto controlado por el usuario; sin destino
   aprobado no se habilita Caddy. Una excepción requiere aprobación explícita del usuario
   y registro de la desviación.
8. D8: `vps-infra` posee la unidad TEST; `myfinanzas-app` posee el runtime y el release.
9. D9: operación con systemd/healthcheck/logs, sin monitorización residente nueva.
10. Ubicación real del bloque Caddy y de sus imports, tras la auditoría.
11. Umbral de disco (propuesta: 20 % libre / 10 % inodos; presupuesto TEST ≤ 5 GB).
12. Ventana y autorización de reinicio del VPS para la prueba de persistencia.

## 15. Acceptance checks

| ID | Acción / precondiciones | Resultado observable esperado |
| --- | --- | --- |
| AC-01 | Ejecutar `./scripts/validate-template` y `python3 scripts/check_harness.py`, revisar el diff y comprobar que el alcance excluye VPS, DNS, Caddy, despliegue y merge. | Los checks pasan; el diff solo contiene documentación autorizada; no se ejecuta ningún cambio remoto. |
| AC-02 | Con autorización de solo lectura, auditar host, UFW, Caddy, Podman, `linger`, puertos, disco y DNS. | Inventario redactado con diferencias y riesgos; ningún cambio remoto. |
| AC-03 | Crear el registro DNS `test` (A/AAAA) con TTL 300 y verificar desde resolutores públicos. | `test.myfinanzas.pp.ua` resuelve a la IP pública del VPS (no a un proxy/CDN del raíz salvo decisión expresa); el registro raíz no cambió. |
| AC-04 | Crear `mftest` sin login SSH, con `subuid`/`subgid`, home 0750 y `linger`; verificar. | Usuario existe, `Linger=yes`, sin acceso SSH interactivo; UID/GID registrados. |
| AC-05 | Crear `/srv/myfinanzas-test/{data,releases,backups}` como `mftest` 0700 y `/var/www/myfinanzas-test` como root 0755. | Rutas existen con propietario y modos esperados; `state` aún no existe. |
| AC-06 | Verificar el paquete de release con commit y manifiesto esperados; cargar la imagen por ID inmutable. | `verify` pasa, el ID coincide con el manifiesto y no se usa una etiqueta móvil. |
| AC-07 | Comprobar que **todos** los gates de deployabilidad aplicables del runbook, incluido Rootless, se ejecutaron en `SUCCESS` sobre el SHA exacto del candidato. | Evidencia enlazada con SHA y run; sin gates no se continúa. |
| AC-08 | Ejecutar `production-init` en estado nuevo y revisar permisos. | `state/`, DB y clave creados; 0700/0600; sin usuario, fixtures ni datos reales. |
| AC-09 | Ejecutar `setup`, entregar el token por archivo privado, completar alta y eliminar el archivo. | Propietario creado; token consumido y eliminado; ningún secreto en stdout/logs/chat/repo. |
| AC-10 | Escribir la unidad TEST con el ID verificado, `daemon-reload` y `start`. | Unidad `active`, `NRestarts=0`, contenedor saludable y `Image` igual al ID inmutable verificado. |
| AC-11 | Consultar health y ruta protegida en loopback. | `/api/health` → 200 `{"ok":true}`; ruta protegida → 401. |
| AC-12 | Publicar el frontend verificado en `releases/<sha>` y actualizar `current` con `mv -Tf` sobre el symlink nuevo. | La raíz estática sirve la release correcta; Vite no está publicado; no hay enlaces fuera de la raíz ni `*.map`/`.env*`. |
| AC-13 | Añadir el bloque Caddy tras backup del fichero e imports, validar y recargar. | `caddy validate` y recarga correctos; el sitio raíz sigue funcionando; se registran ruta y hash del backup para restaurar. |
| AC-14 | Acceder por HTTPS al dominio TEST y revisar cabeceras, certificado y redirección. | TLS válido, HTTP→HTTPS, CSP/noindex/nosniff/HSTS corto; sin listado de directorios. |
| AC-15 | Verificar login, cookies y una mutación con datos ficticios. | Login MFA correcto; cookies `__Host-` Secure/HttpOnly/SameSite=Strict; Origin/CSRF activos; escritura ficticia guardada. |
| AC-16 | Comprobar exposición desde fuera del host. | 80/443 responden; 18082 no es accesible externamente; API/DB no publicadas; SSH conserva su configuración existente. |
| AC-17 | Reiniciar la unidad y, con autorización, el VPS; verificar persistencia, `linger` y `PRAGMA integrity_check`. | Servicio vuelve `active`, health 200, integridad `ok` y los conteos ficticios se conservan tras reinicio. |
| AC-18 | Crear una copia cifrada, copiarla fuera del VPS y restaurarla en un destino nuevo; verificar en puerto 18083. | Copia local y externa verificadas por checksum; restauración aislada íntegra; estado activo no modificado; RTO observado registrado. |
| AC-19 | Simular un rollback de Caddy y uno de aplicación sin prueba de compatibilidad. | Caddy vuelve al backup sin afectar al dominio raíz; el rollback de app se bloquea y preserva datos si falta evidencia. |
| AC-20 | Retirar TEST con autorización: parar unidad, retirar Caddy/DNS, deshabilitar `linger` y preservar datos. | Dominio raíz intacto; TEST deja de responder; datos/copias preservados hasta autorización de borrado. |
| AC-21 | Actualizar a una release nueva verificada conservando la anterior y la copia previa. | La nueva release arranca, health/login/escritura ficticia pasan; la anterior y sus datos siguen disponibles para rollback. |
| AC-22 | Probar gates negativos: manifiesto alterado, SHA sin Rootless, imagen por etiqueta o `state` existente. | Cada intento se bloquea sin desplegar, sin borrar estado y sin sustituir la release activa. |
| AC-23 | Medir memoria, CPU, pids y disco de TEST con la unidad en marcha. | La unidad respeta 1 GiB/1 CPU/128 pids; el uso de TEST queda dentro de 5 GB; hay ≥20 % de disco y ≥10 % de inodos libres. |
| AC-24 | Revisar el estado y la UI para confirmar que solo hay datos ficticios y que el Excel/base real no están presentes. | El conjunto ficticio es identificable; no hay Excel, bases reales ni datos personales/financieros reales en el host, repo o copias. |
| AC-25 | Comparar la configuración SSH/UFW previa y posterior; comprobar usuarios y puertos nuevos. | SSH conserva su configuración y acceso por clave; UFW no abre 18082/3001; `mftest` no tiene login SSH; no hay otros servicios modificados. |
