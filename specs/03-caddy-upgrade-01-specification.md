# 03 — VPS-CADDY-UPGRADE-01: actualización de Caddy a 2.11.9

Status: **DRAFT — preparación documental; nada ejecutado en el VPS.**
Fecha: 2026-11-05.
Contexto: [cierre de auditoría](../docs/auditorias/2026-11-05-infra-audit-vps-001-cierre.md), PR #13 MERGED.
Contrato host: PR #9, **DRAFT**; no adoptado.
Aplicación: `myfinanzas-app` SPEC34/PR #207; **no se modifica**.

Este documento **no autoriza** acceso al VPS, instalación, parada o reinicio de Caddy, cambios
de DNS/UFW/SSH, merges ni despliegues. Los comandos con `sudo` los ejecuta el usuario en una
ventana autorizada. El agente no los ejecuta.

## 1. Objetivo y alcance

Actualizar Caddy en Debian 13 desde `2.6.2-12+deb13u1` (vulnerable a CVE-2026-77281 y sin
actualización en trixie) a una versión estable corregida, preservando:

- el sitio `myfinanzas.pp.ua` y el contenido servido;
- los certificados y el estado de Caddy;
- la configuración, permisos y usuario actuales;
- DNS, UFW, SSH y el resto de servicios.

Fuera de alcance: hardening HTTP, Quadlet, Podman, backups de la aplicación, despliegue de
TEST y cualquier cambio de red o DNS.

## 2. Estado de partida

| Dato | Valor | Procedencia |
| --- | --- | --- |
| Paquete instalado | `caddy 2.6.2-12+deb13u1` (amd64), origen Debian trixie | Auditoría 2026-11-05 |
| Servicio | `caddy.service` activo, `NRestarts=0` | Auditoría 2026-11-05 |
| Config | `/etc/caddy/Caddyfile`, 68 B observados: sitio `myfinanzas.pp.ua` + `root` | Auditoría (contenido completo **no** leído) |
| Datos/certificados | `/var/lib/caddy`, usuario `caddy`, TLS Let's Encrypt válido hasta 2027-01-19 | Auditoría |
| Entrada pública | 80/443; UFW `deny` incoming | Comprobación manual del usuario |
| Actualizaciones | Sin candidato corregido en trixie/security | Debian tracker |

Se confirman en el baseline (§6.1): contenido y directivas del `Caddyfile`, ruta del `root`,
módulos cargados, pertenencia de `caddy` a `www-data`, estado de `caddy-api.service`, timers de
APT, baseline de UFW/SSH/DNS y espacio libre.

## 3. Opciones evaluadas y decisión

| Opción | Versión | Origen | CVE-2026-77281 (arreglado en 2.11.4) | Avisos 2026-11-04 (arreglados en 2.11.8) | Valoración |
| --- | --- | --- | --- | --- | --- |
| Debian stable/security | `2.6.2-12+deb13u1` | trixie | **No** (vulnerable, no-DSA) | **No** | No cumple el objetivo |
| Debian backports | `2.11.2-1~bpo13+1` | trixie-backports | **No** | **No** | No cumple el objetivo |
| Debian testing/unstable | `2.11.4-1` | forky/sid | Sí | **No** (≤ 2.11.7) | **Descartado** por seguridad y por prohibición de mezclar repositorios |
| Caddy oficial | `2.11.8` | Cloudsmith stable | Sí | Sí | Descartado: regresión de índices PHP y sin los arreglos de 2.11.9 |
| **Caddy oficial** | **`2.11.9`** | Cloudsmith stable | **Sí** | **Sí** | **Recomendado** |
| Binario estático | `2.11.9` | Descarga oficial | Sí | Sí | Alternativa; peor mantenimiento que el paquete |

**Decisión propuesta: paquete oficial `caddy 2.11.9` (amd64) desde el repositorio estable de
Caddy en Cloudsmith.** No se añaden repositorios testing/unstable ni se cambia la base Debian.

Justificación del cambio de origen: Debian 13 no ofrece versión corregida y backports
(`2.11.2`) tampoco. El repositorio oficial es el método documentado por el proyecto, con la
misma estructura de paquete, `Caddyfile` como `conffile`, usuario `caddy`, datos en
`/var/lib/caddy` y unidad `caddy.service`.

Justificación de **2.11.9**: los avisos publicados el 2026-11-04 (GHSA-jf74-f69g-hcj9,
GHSA-r766-rf9f-588h, GHSA-25cw-38mq-q7m6, GHSA-69hv-5jfc-mvmv, GHSA-f278-mgc7-46j3) afectan a
**≤ 2.11.7** y se corrigen en **2.11.8**; 2.11.9 (publicado 2026-11-05T01:30Z) corrige además
una regresión de 2.11.8 y varios problemas de seguridad, principalmente en FastCGI.
**2.11.7 queda descartado por vulnerable** y **2.11.8 por regresión**. Se elige **2.11.9 por
ser el último estable publicado**, asumiendo su novedad como riesgo (Medio-Alto). A fecha de
2026-11-05 no hay aviso publicado que afecte a versiones posteriores a 2.11.8; CVE-2026-92700 y
CVE-2026-92284 siguen `undetermined` en Debian y no cambian la decisión.

Paquete de referencia verificado por el agente (descarga HTTPS pública, sin instalar):

- URL: `https://dl.cloudsmith.io/public/caddy/stable/deb/any-distro/pool/any-version/main/c/ca/caddy_2.11.9/caddy_2.11.9_linux_amd64.deb`
- Tamaño: **18.049.414 bytes**; SHA-256:
  **`bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb`**
- Sin campo `Depends` (binario estático).
- Clave de firma del repo: `Caddy Web Server <contact@caddyserver.com>`,
  fingerprint primaria `6576 0C51 EDEA 2017 CEA2 CA15 155B 6D79 CA56 EA34`.

El checksum se **recalcula en el VPS** antes de instalar; si no coincide, se aborta.

Fuentes:
- [Caddy — Install](https://caddyserver.com/docs/install#debian-ubuntu-raspbian)
- [Cloudsmith Caddy stable](https://cloudsmith.io/~caddy/repos/stable/)
- [Release 2.11.9](https://github.com/caddyserver/caddy/releases/tag/v2.11.9)
- [Release 2.11.8](https://github.com/caddyserver/caddy/releases/tag/v2.11.8)
- [Advisories de Caddy](https://github.com/caddyserver/caddy/security/advisories)
- [Debian tracker caddy](https://tracker.debian.org/pkg/caddy)
- [Debian Security Tracker caddy](https://security-tracker.debian.org/tracker/source-package/caddy)
- [CVE-2026-77281](https://security-tracker.debian.org/tracker/CVE-2026-77281)

## 4. Compatibilidad analizada

Comparación directa de los `.deb` (Debian `2.6.2-12+deb13u1` y oficial `2.11.9`), sin
instalarlos:

| Aspecto | Debian 2.6.2 | Oficial 2.11.9 | Efecto |
| --- | --- | --- | --- |
| Binario | `/usr/bin/caddy`, dinámico | `/usr/bin/caddy`, estático | Sin dependencias de runtime |
| Config | `/etc/caddy/Caddyfile` (`conffile`) | Igual (`conffile`) | Se conserva con `--force-confold` |
| Usuario/grupo | `caddy`/`caddy`, home `/var/lib/caddy`; añade `caddy` a `www-data` | Idéntico | Sin delta; verificar en baseline |
| Datos | `/var/lib/caddy` | Igual | Se copia y conserva |
| Unidad | `/usr/lib/systemd/system/caddy.service` | `/lib/systemd/system/caddy.service` (mismo fichero en usr-merge) | Se reemplaza |
| `postrm purge` | Borra `/etc/caddy`, `/var/lib/caddy`, `/var/log/caddy` | Añade `userdel -r caddy` | **Prohibido purgar** |

`diff` de unidades: solo dos diferencias, idénticas en `caddy.service` y `caddy-api.service`.

```text
-LimitNPROC=512
-AmbientCapabilities=CAP_NET_BIND_SERVICE
+AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
```

El resto (`Type=notify`, `User/Group`, `ExecStart/ExecReload`, `Requires=network-online.target`,
`PrivateTmp`, `ProtectSystem=full`, `LimitNOFILE`) es idéntico. La instalación amplía
privilegios con `CAP_NET_ADMIN`, que un sitio estático en 80/443 no necesita: se recomienda un
*drop-in* que conserve solo `CAP_NET_BIND_SERVICE` (§6.6), reversible.

Otros puntos:

- Las directivas observadas (dirección de sitio + `root`) son válidas en 2.11.x. Los cambios
  incompatibles de 2.11.8/2.11.9 afectan a `client_auth` conflictivo y FastCGI/PHP, no
  observados.
- Los módulos compilados pueden diferir: se comparan con `caddy list-modules` y se bloquea si
  falta un módulo en uso.
- El almacenamiento de certificados es compatible; no se fuerza reemisión ni se cambia DNS.
- El `postinst` oficial **deshace un `systemctl mask` administrativo**
  (`deb-systemd-helper unmask`), hace `enable` y `start` si estaba habilitado y, en
  actualización, `try-restart`. Por tanto `mask` **no** es un control fiable. El control es
  **desempaquetar sin configurar** y validar antes de ejecutar el `postinst` (§6.5).
- Si el paquete estuviera `disabled`, el `postinst` no arrancaría; el procedimiento lo
  comprueba y arranca explícitamente si hace falta.
- El `Caddyfile` que instalan **ambos** paquetes es idéntico (769 B, SHA-256
  `66177d46fa761acb07208065db9b0274cb1b12c02ac43b9bfc9857b698b1ccfe`); el local observado
  (68 B) es un `conffile` modificado. `dpkg` compara con la versión registrada por el paquete
  anterior, no con la nueva: al no cambiar entre paquetes **no hay conflicto ni pregunta**. Se
  usa `--force-confold` igualmente como defensa y se verifica el hash antes y después.

## 5. Precondiciones

1. Autorización específica de ventana, de las operaciones con `sudo` y de la instalación.
2. `Caddyfile` revisado (§6.1) sin directivas no evaluadas ni módulos ausentes.
3. Copia del paquete antiguo descargada y verificada; sin ella **no se instala**.
4. Espacio libre ≥ 200 MB en `/root` y `/`; `du -sh /var/lib/caddy` razonable.
5. Ventana de baja actividad: el sitio se interrumpe durante la copia, el desempaquetado y la
   validación (estimado < 2 minutos).
6. Timers de APT (`apt-daily`, `apt-daily-upgrade`, `unattended-upgrades`) detenidos y sin otro
   proceso `apt`/`dpkg` (§6.1).
7. Decisión sobre capacidades de la unidad (§10) y sobre el ciclo de vida del repo (§10).
8. Herramientas presentes: `curl`, `openssl`, `gpg`, `fuser`, `sha256sum`, `dpkg-deb`. Si falta
   alguna, detenerse y decidir antes de la ventana.

## 6. Procedimiento

> Lo ejecuta el usuario, con `sudo`, en la ventana autorizada. No se ejecuta nada en esta fase.
> Todo el procedimiento asume **una sola sesión de shell** con `set -euo pipefail`.
> Si se abre otra shell, redefinir `CASE_DIR` con el valor ya creado. Cada bloque de riesgo
> incluye una guardia `: "${CASE_DIR:?...}"` para no operar con la variable vacía.

### 6.1 Baseline, estado previo y preparación de APT

```bash
set -euo pipefail
TS=$(date -u +%Y%m%dT%H%M%SZ)
CASE_DIR="/root/caddy-upgrade-$TS"
sudo install -d -m 0700 "$CASE_DIR"
sudo cp -a /etc/apt/sources.list.d "$CASE_DIR/sources.list.d.before"
sudo cp -a /etc/apt/preferences.d "$CASE_DIR/preferences.d.before" 2>/dev/null || true
{
  echo "TS=$TS"
  date -u
  dpkg-query -W -f='${Package} ${Version} ${Architecture} ${Status}\n' caddy
  /usr/bin/caddy version
  sudo sha256sum /etc/caddy/Caddyfile /usr/bin/caddy
  id caddy
  systemctl is-enabled caddy caddy-api 2>&1 || true
  systemctl is-active caddy caddy-api 2>&1 || true
  systemctl show caddy -p ActiveState -p SubState -p NRestarts -p FragmentPath -p User -p Group
  systemctl show caddy -p MainPID -p ExecMainStartTimestamp -p AmbientCapabilities
  dpkg-query -W -f='${Conffiles}\n' caddy
  apt-cache policy caddy
  dpkg --audit || true
  systemctl is-enabled apt-daily.timer apt-daily-upgrade.timer 2>&1 || true
  systemctl is-active apt-daily.timer apt-daily-upgrade.timer \
    apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>&1 || true
  sudo ss -ltnp
  sudo systemctl list-timers 'apt-*' --no-pager || true
  df -h / /root
  sudo du -sh /var/lib/caddy
} 2>&1 | sudo tee "$CASE_DIR/baseline.txt" >/dev/null
sudo ss -ltnp | sudo tee "$CASE_DIR/ss.before" >/dev/null

/usr/bin/caddy list-modules | sort | sudo tee "$CASE_DIR/modules.before" >/dev/null
curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "$CASE_DIR/body.before" >/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' https://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/http.before" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 \
  | sudo tee "$CASE_DIR/cert.before" >/dev/null

sudo ufw status verbose | sudo tee "$CASE_DIR/ufw.before" >/dev/null
sudo sshd -T | sudo tee "$CASE_DIR/sshd.before" >/dev/null || true
getent ahosts myfinanzas.pp.ua | sed -n '1,5p' | sort | sudo tee "$CASE_DIR/dns.before" >/dev/null
```

Revisión de directivas del `Caddyfile` (salida local; **no publicar**, puede contener rutas o
hashes de credenciales). Revisar también el fichero completo en local antes de continuar:

```bash
sudo grep -nE 'rewrite|hide|http\.request\.body|php_fastcgi|client_auth|basic_auth|bind |root|reverse_proxy|tls ' \
  /etc/caddy/Caddyfile | sudo tee "$CASE_DIR/directives.txt" >/dev/null || true
```

**Condición de parada:** si aparecen `rewrite` (URI terminada en `?`), `{http.request.body}`,
`hide`, `php_fastcgi` o `client_auth`, **no se continúa** con esta spec: requiere revisión de
compatibilidad/seguridad específica. Si `id caddy` no incluye `www-data`, anotarlo para la
validación de permisos.

Comprobar que `body.before` y `http.before` son estables (repetir una vez). Si no lo son, no se
inicia la ventana.

Detener los timers de APT y verificar que no hay concurrencia:

```bash
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer
sudo systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
sudo fuser -v /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>&1 || true
pgrep -a 'apt|dpkg|unattended' || true
```

`fuser` y `pgrep` no deben mostrar procesos activos. Los timers se restauran en §6.9.

### 6.2 Repositorio oficial (solo si se aprueba mantenerlo)

Si se elige la alternativa sin repo, saltar a §6.3.

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
if [ -e /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
  sudo cp -a /usr/share/keyrings/caddy-stable-archive-keyring.gpg "$CASE_DIR/keyring.before"
fi
if [ -e /etc/apt/sources.list.d/caddy-stable.list ]; then
  sudo cp -a /etc/apt/sources.list.d/caddy-stable.list "$CASE_DIR/caddy-stable.list.before"
fi
KEY_SRC="$(mktemp)"
curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' -o "$KEY_SRC"
FPR=$(gpg --show-keys --with-colons "$KEY_SRC" | awk -F: '/^fpr:/ {print $10; exit}')
[ "$FPR" = "65760C51EDEA2017CEA2CA15155B6D79CA56EA34" ] || { rm -f "$KEY_SRC"; echo "fingerprint inesperado: $FPR"; exit 1; }
sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg "$KEY_SRC"
rm -f "$KEY_SRC"
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
sudo chmod 0644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
sudo touch "$CASE_DIR/repo-added"
sudo apt-get update
apt-cache policy caddy
```

- El fingerprint se verifica **antes** de instalar la clave en el sistema; si no coincide, el
  script sale sin escribir nada.
- Se añade **solo** la línea `deb`, no `deb-src` (menos superficie y descarga; desviación
  justificada del fichero publicado).
- El candidato debe ser `2.11.9` desde `dl.cloudsmith.io`. Si es otro, detenerse y revisar.
- `ca-certificates`, `curl` y `gpg` deben existir antes de la ventana. Si falta alguno, se
  detiene y se decide; no se instalan paquetes adicionales dentro de la ventana.

### 6.3 Descargar y verificar paquetes

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo sh -c "cd '$CASE_DIR' && apt-get download caddy=2.6.2-12+deb13u1" \
  || sudo sh -c "cd '$CASE_DIR' && curl -fsSLO https://security.debian.org/debian-security/pool/updates/main/c/caddy/caddy_2.6.2-12+deb13u1_amd64.deb"
printf '%s  %s\n' 'f173515859f273c97219cc242d625a64650fefdd136a9570acb1b5f7581c9786' 'caddy_2.6.2-12+deb13u1_amd64.deb' \
  | sudo tee "$CASE_DIR/old.expected" >/dev/null
sudo sh -c "cd '$CASE_DIR' && sha256sum -c old.expected"
sudo sh -c "cd '$CASE_DIR' && stat -c '%s %n' caddy_2.6.2-12+deb13u1_amd64.deb"
```

Referencia verificada del `.deb` Debian (security pool): **10.110.872 bytes**, SHA-256
**`f173515859f273c97219cc242d625a64650fefdd136a9570acb1b5f7581c9786`**.

```bash
if [ -f /etc/apt/sources.list.d/caddy-stable.list ]; then
  sudo sh -c "cd '$CASE_DIR' && apt-get download caddy=2.11.9"
else
  sudo sh -c "cd '$CASE_DIR' && curl -fsSLO https://dl.cloudsmith.io/public/caddy/stable/deb/any-distro/pool/any-version/main/c/ca/caddy_2.11.9/caddy_2.11.9_linux_amd64.deb"
fi
printf '%s  %s\n' 'bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb' 'caddy_2.11.9_linux_amd64.deb' \
  | sudo tee "$CASE_DIR/new.expected" >/dev/null
sudo sh -c "cd '$CASE_DIR' && sha256sum -c new.expected"
sudo sh -c "cd '$CASE_DIR' && stat -c '%s %n' caddy_2.11.9_linux_amd64.deb"
```

El tamaño debe ser **18.049.414 bytes** y el SHA-256
**`bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb`** (`sha256sum -c` debe
responder `OK`). Si no coincide, abortar sin haber modificado el sistema. Sin paquete antiguo
verificado **no se continúa**.

### 6.4 Detener, copiar y verificar

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo systemctl stop caddy
sudo systemctl stop caddy-api 2>/dev/null || true
sudo systemctl is-active caddy caddy-api || true
sudo pgrep -a caddy || true
sudo cp -a /etc/caddy "$CASE_DIR/etc-caddy"
sudo cp -a /var/lib/caddy "$CASE_DIR/var-lib-caddy"
sudo cp -a /lib/systemd/system/caddy.service "$CASE_DIR/caddy.service.before"
sudo cp -a /lib/systemd/system/caddy-api.service "$CASE_DIR/caddy-api.service.before" 2>/dev/null || true
if [ -e /etc/systemd/system/caddy.service.d/10-local-capabilities.conf ]; then
  sudo cp -a /etc/systemd/system/caddy.service.d/10-local-capabilities.conf "$CASE_DIR/dropin.before"
fi
sudo systemctl cat caddy | sudo tee "$CASE_DIR/unit.before" >/dev/null
sudo chmod 0700 "$CASE_DIR"
sudo stat -c '%A %U:%G %n' "$CASE_DIR" /etc/caddy /etc/caddy/Caddyfile /var/lib/caddy
```

`/var/lib/caddy` contiene **claves privadas** y estado de la instancia: se trata como
**secreto**. El directorio `$CASE_DIR` es `0700 root:root`, lo que protege todo su contenido sin
alterar los permisos originales de `etc-caddy` (necesarios para una restauración correcta). No
se copia al repositorio, no se imprime y no sale del VPS. Es un **snapshot de rollback local**,
no un backup de recuperación: vive en el mismo disco y no está cifrado. Retención: hasta 30 días
después de la validación correcta; después se elimina con confirmación del usuario.

La copia se hace con el servicio detenido para que sea consistente. Si algo falla aquí, basta
`systemctl start caddy`: aún no se ha modificado nada.

### 6.5 Desempaquetar sin configurar y validar

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo sh -c "cd '$CASE_DIR' && sha256sum -c new.expected"
sudo dpkg --force-confdef --force-confold --unpack "$CASE_DIR/caddy_2.11.9_linux_amd64.deb"
dpkg -l caddy
/usr/bin/caddy version
sudo sha256sum /etc/caddy/Caddyfile
sudo systemctl is-active caddy caddy-api || true
sudo pgrep -a caddy || true
```

- `dpkg -l caddy` debe mostrar `iU` (desempaquetado, sin configurar). **No se exige
  `dpkg --audit` limpio en este punto**: un paquete `iU` aparece como “unpacked but not yet
  configured” por diseño. La auditoría limpia se exige tras `--configure` (§6.6).
- El `Caddyfile` no debe cambiar respecto a `baseline.txt`; el hash se vuelve a comprobar
  después de `--configure`.
- No debe haber proceso de Caddy en ejecución (el servicio se detuvo en §6.4).
- `--unpack` **no ejecuta el `postinst`**: no hay arranque ni reinicio.
- Los paquetes traen el mismo `Caddyfile`, así que no debe haber conflicto de `conffile` ni
  aparecer `Caddyfile.dpkg-new`/`.dpkg-dist`. Si aparecen, **no continuar** y revisar.

```bash
sudo -u caddy env HOME=/var/lib/caddy /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
/usr/bin/caddy list-modules | sort | sudo tee "$CASE_DIR/modules.after" >/dev/null
sudo diff -u "$CASE_DIR/modules.before" "$CASE_DIR/modules.after" || true
```

Debe terminar en `Valid configuration`. Si en el baseline `id caddy` no incluía `www-data` y el
`postinst` lo añadirá después, validar también con ese grupo para evitar un falso negativo de
permisos:

```bash
sudo -u caddy -g www-data env HOME=/var/lib/caddy /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Si la validación falla o falta un módulo en uso: revertir el binario (§7.2). El sitio sigue
detenido; no se ha ejecutado el `postinst`.

### 6.6 Unidad, capacidades y arranque

Si se aprueba el mínimo privilegio (§10), crear el *drop-in* **antes** del primer arranque para
que el `postinst` ya lo aplique. Un *drop-in* preexistente ya quedó respaldado en §6.4:

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo install -d -m 0755 /etc/systemd/system/caddy.service.d
printf '%s\n' '[Service]' 'AmbientCapabilities=CAP_NET_BIND_SERVICE' 'LimitNPROC=512' \
  | sudo tee /etc/systemd/system/caddy.service.d/10-local-capabilities.conf >/dev/null
sudo systemctl daemon-reload
```

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo dpkg --force-confdef --force-confold --configure caddy
dpkg -l caddy
dpkg --audit
sudo sha256sum /etc/caddy/Caddyfile
sudo find /etc/caddy \( -name '*.dpkg-new' -o -name '*.dpkg-dist' \) -print
sudo systemctl daemon-reload
sudo systemctl is-active caddy || sudo systemctl start caddy
sudo systemctl show caddy -p ActiveState -p SubState -p NRestarts -p FragmentPath -p MainPID -p AmbientCapabilities
sudo systemctl is-enabled caddy caddy-api || true
sudo systemctl is-active caddy-api || true
```

El `postinst` hace `enable`, `start` y, en actualización, `try-restart`. Si el paquete estaba
`disabled`, no arranca solo: el `systemctl start` explícito lo cubre. Si el baseline estaba
`enabled`, comprobar que sigue `enabled` para el arranque tras reinicio (AC-17).
`caddy-api.service` debe seguir `disabled`/`inactive`.

El hash del `Caddyfile` debe coincidir con el de `baseline.txt` y `find` no debe devolver
`.dpkg-new`/`.dpkg-dist`. Si el `Caddyfile` cambió, **no continuar**: detener, restaurar
`$CASE_DIR/etc-caddy/Caddyfile` y revisar antes de arrancar.

Si Caddy no arranca con el *drop-in*, retirarlo (decisión documentada) y aceptar la unidad
oficial:

```bash
sudo rm /etc/systemd/system/caddy.service.d/10-local-capabilities.conf
sudo systemctl daemon-reload
sudo systemctl reset-failed caddy
sudo systemctl start caddy
```

Si no arranca ni con la unidad oficial: no insistir con reinicios (activa el *start limit*);
recoger `journalctl -u caddy -n 100 --no-pager` y revertir (§7).

### 6.7 Validación posterior

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
/usr/bin/caddy version
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' caddy
apt-cache policy caddy
systemctl is-active caddy
sudo journalctl -u caddy -p warning --since '-15 min' --no-pager | tail -50 | sudo tee "$CASE_DIR/journal.after" >/dev/null
sudo ss -ltnp | sudo tee "$CASE_DIR/ss.after" >/dev/null
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/https.after" >/dev/null
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n' http://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/http.after" >/dev/null
curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "$CASE_DIR/body.after" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 \
  | sudo tee "$CASE_DIR/cert.after" >/dev/null
sudo ufw status verbose | sudo tee "$CASE_DIR/ufw.after" >/dev/null
sudo sshd -T | sudo tee "$CASE_DIR/sshd.after" >/dev/null || true
getent ahosts myfinanzas.pp.ua | sed -n '1,5p' | sort | sudo tee "$CASE_DIR/dns.after" >/dev/null
sudo diff -u "$CASE_DIR/ufw.before" "$CASE_DIR/ufw.after" || true
sudo diff -u "$CASE_DIR/sshd.before" "$CASE_DIR/sshd.after" || true
sudo diff -u "$CASE_DIR/dns.before" "$CASE_DIR/dns.after" || true
sudo diff -u "$CASE_DIR/body.before" "$CASE_DIR/body.after"
sudo diff -u "$CASE_DIR/cert.before" "$CASE_DIR/cert.after"
sudo systemctl reset-failed caddy
sudo systemctl restart caddy
sudo systemctl is-active caddy
sudo journalctl -u caddy -p err --since '-5 min' --no-pager | tail -30
```

Criterios: `caddy version` = 2.11.9; HTTPS 200 con verificación 0; HTTP 308 hacia HTTPS;
`body.after` y `cert.after` **idénticos** a los del baseline (mismo fingerprint, SAN y fechas,
sin reemisión); `dpkg -l` en `ii` y `dpkg --audit` sin incidencias; Caddy solo escucha en 80/443
en direcciones públicas; 2019 solo en `127.0.0.1`/`::1` si está habilitado; 3001/18082 ausentes;
reinicio limpio sin errores; UFW/SSH/DNS sin diferencias respecto al baseline.

No se prueban puertos de la aplicación (`test.myfinanzas.pp.ua` sigue en NXDOMAIN) ni se
cambian DNS, UFW o SSH.

### 6.8 Fijar la versión y ciclo de vida

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
if [ -f /etc/apt/sources.list.d/caddy-stable.list ]; then
  sudo apt-mark hold caddy
  apt-mark showhold | grep '^caddy$'
fi
```

`hold` evita actualizaciones no revisadas **mientras el repo oficial esté activo**. Revisión
mensual del repo y del Debian Security Tracker.

Ciclo de vida: `2.11.9` es mayor que cualquier `2.6.2-…` de Debian, por lo que el backport
actual (`2.11.2`) no se instalará por comparación de versiones. Una versión Debian **futura
superior** (por ejemplo `2.11.9-1~deb13u1`) sí podría competir; con `hold` no se instalará
hasta que se autorice. Actualizar exige repetir esta spec con ventana, QA y `unhold` nuevos.

Alternativa sin repo: no se aplica `hold`; las actualizaciones son manuales y hay que registrar
explícitamente que Caddy no recibirá parches automáticos.

Cerrar la ventana en §6.9.

### 6.9 Cierre de la ventana

Ejecutar **siempre**, tanto tras una actualización correcta como tras cualquier rollback:

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
if systemctl is-enabled --quiet apt-daily.timer; then sudo systemctl start apt-daily.timer; fi
if systemctl is-enabled --quiet apt-daily-upgrade.timer; then sudo systemctl start apt-daily-upgrade.timer; fi
systemctl is-active apt-daily.timer apt-daily-upgrade.timer || true
```

Comparar con el estado registrado en `baseline.txt`: si un timer estaba inactivo o deshabilitado
antes de la ventana, restaurar ese estado. Los comandos anteriores arrancan los timers
habilitados; si el baseline muestra uno habilitado pero inactivo, volver a pararlo con
`systemctl stop`. `unattended-upgrades.service` no se arranca a mano: lo dispara
`apt-daily-upgrade.timer`.

## 7. Rollback

### 7.1 Bloque común (antes de probar el servicio)

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo systemctl stop caddy 2>/dev/null || true
sudo apt-mark unhold caddy 2>/dev/null || true
apt-mark showhold | grep '^caddy$' || true
if [ -e /etc/apt/sources.list.d/caddy-stable.list ]; then
  sudo mv /etc/apt/sources.list.d/caddy-stable.list "$CASE_DIR/caddy-stable.list.disabled"
fi
if [ -e "$CASE_DIR/keyring.before" ]; then
  sudo cp -a "$CASE_DIR/keyring.before" /usr/share/keyrings/caddy-stable-archive-keyring.gpg
elif sudo test -e "$CASE_DIR/repo-added"; then
  sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
fi
sudo apt-get update
apt-cache policy caddy
```

El candidato debe volver a ser Debian `2.6.2-12+deb13u1`. **No se restaura un
`caddy-stable.list` preexistente**: si lo hubiera, se deja desactivado para que el candidato sea
Debian y para que un `hold` posterior no congele una versión vulnerable. **No dejar
`apt-mark hold`** sobre la versión Debian: bloquearía futuros DSA de trixie, incluido uno para
CVE-2026-77281. Si se prefiere conservar el `.list`, crear en su lugar un pin negativo y no
aplicar `hold`:

```text
# /etc/apt/preferences.d/caddy-no-cloudsmith.pref
Package: caddy
Pin: origin "dl.cloudsmith.io"
Pin-Priority: -1
```

### 7.2 Revertir el binario y la unidad

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo sh -c "cd '$CASE_DIR' && sha256sum -c old.expected"
sudo dpkg --force-downgrade --force-confdef --force-confold -i "$CASE_DIR/caddy_2.6.2-12+deb13u1_amd64.deb"
dpkg -l caddy
dpkg --audit
sudo systemctl daemon-reload
sudo systemctl show caddy -p FragmentPath
sudo sha256sum /usr/lib/systemd/system/caddy.service "$CASE_DIR/caddy.service.before"
sudo systemctl start caddy
/usr/bin/caddy version
systemctl is-active caddy
```

El `postinst` antiguo hará `start` (y `try-restart`); el `start` explícito cubre el caso
`disabled`. `--force-downgrade` hace explícito el descenso de versión; es inocuo si `dpkg` ya
lo aceptara. Comprobar `FragmentPath` y que el hash de la unidad coincide con
`caddy.service.before`.

El *drop-in* creado en §6.6 se retira **siempre**; si existía uno previo, se restaura:

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo rm -f /etc/systemd/system/caddy.service.d/10-local-capabilities.conf
if sudo test -e "$CASE_DIR/dropin.before"; then
  sudo cp -a "$CASE_DIR/dropin.before" /etc/systemd/system/caddy.service.d/10-local-capabilities.conf
fi
sudo systemctl daemon-reload
sudo systemctl restart caddy
sudo systemctl show caddy -p FragmentPath -p AmbientCapabilities
```

Si el hash de la unidad no coincide, restaurar también el fichero de unidad:

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo systemctl stop caddy
sudo cp -a "$CASE_DIR/caddy.service.before" /usr/lib/systemd/system/caddy.service
sudo cp -a "$CASE_DIR/caddy-api.service.before" /usr/lib/systemd/system/caddy-api.service 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl start caddy
sudo systemctl restart caddy
sudo systemctl show caddy -p FragmentPath -p AmbientCapabilities
```

Verificación final del rollback (mismos criterios que §6.7, comparados con el baseline):

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/rollback.https" >/dev/null
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n' http://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/rollback.http" >/dev/null
curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "$CASE_DIR/rollback.body" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 \
  | sudo tee "$CASE_DIR/rollback.cert" >/dev/null
sudo diff -u "$CASE_DIR/body.before" "$CASE_DIR/rollback.body"
sudo diff -u "$CASE_DIR/cert.before" "$CASE_DIR/rollback.cert"
```

El rollback solo se considera correcto con HTTPS 200 (`verify=0`), cuerpo y certificado
idénticos al baseline. Si el sitio no vuelve, detenerse y solicitar decisión. Cerrar la ventana
en §6.9.

### 7.3 Revertir configuración o datos

Solo si el fallo es de configuración o estado. **No borrar** nada: mover a un directorio de
fallo y restaurar la copia.

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
sudo systemctl stop caddy
sudo mv /etc/caddy "$CASE_DIR/etc-caddy.failed"
sudo cp -a "$CASE_DIR/etc-caddy" /etc/caddy
sudo mv /var/lib/caddy "$CASE_DIR/var-lib-caddy.failed"
sudo cp -a "$CASE_DIR/var-lib-caddy" /var/lib/caddy
sudo chown -R caddy:caddy /var/lib/caddy
sudo stat -c '%A %U:%G %n' /etc/caddy /etc/caddy/Caddyfile /var/lib/caddy
sudo find /etc/caddy \( -name '*.dpkg-dist' -o -name '*.dpkg-new' \) -print
sudo -u caddy env HOME=/var/lib/caddy /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl daemon-reload
sudo systemctl start caddy
```

Comprobar que no quedan `.dpkg-dist`/`.dpkg-new` en `/etc/caddy` **antes** de arrancar.
`cp -a` conserva propietario y permisos originales porque el snapshot no fue alterado con
`chmod` recursivo; el `chown` es una salvaguarda. Verificar HTTP/TLS/cuerpo/certificado como en
§7.2 y cerrar la ventana en §6.9.

### 7.4 Instalación parcial

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
dpkg -l caddy
sudo apt-mark unhold caddy 2>/dev/null || true
if [ -e /etc/apt/sources.list.d/caddy-stable.list ]; then
  sudo mv /etc/apt/sources.list.d/caddy-stable.list "$CASE_DIR/caddy-stable.list.disabled"
fi
sudo apt-get update
sudo systemctl stop caddy 2>/dev/null || true
sudo sh -c "cd '$CASE_DIR' && sha256sum -c old.expected"
sudo dpkg --force-downgrade --force-confdef --force-confold -i "$CASE_DIR/caddy_2.6.2-12+deb13u1_amd64.deb"
dpkg -l caddy
dpkg --audit
sudo systemctl daemon-reload
sudo systemctl start caddy
/usr/bin/caddy version
systemctl is-active caddy
```

Si `dpkg` se niega o el estado `iF` persiste, **detenerse y escalar**. Nunca improvisar
`--purge`: el `postrm purge` borra `/etc/caddy`, `/var/lib/caddy`, `/var/log/caddy` y ejecuta
`userdel -r caddy`.

Verificación de §7.4 (mismos criterios que §7.2):

```bash
: "${CASE_DIR:?Ejecuta §6.1 y define CASE_DIR}"
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/rollback.https" >/dev/null
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n' http://myfinanzas.pp.ua/ | sudo tee "$CASE_DIR/rollback.http" >/dev/null
curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "$CASE_DIR/rollback.body" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 \
  | sudo tee "$CASE_DIR/rollback.cert" >/dev/null
sudo diff -u "$CASE_DIR/body.before" "$CASE_DIR/rollback.body"
sudo diff -u "$CASE_DIR/cert.before" "$CASE_DIR/rollback.cert"
```

Cerrar la ventana en §6.9.

## 8. Criterios de aceptación

Todos **UNRUN** hasta la ventana autorizada.

| ID | Comprobación | Esperado | Estado |
| --- | --- | --- | --- |
| AC-01 | Baseline estable y guardado | HTTP/body/cert/módulos/unidades/UFW/SSH/DNS coherentes | UNRUN |
| AC-02 | Directivas del Caddyfile revisadas | Sin `rewrite ?`, body, `hide`, `php_fastcgi`, `client_auth` | UNRUN |
| AC-03 | Copia consistente y permisos | Servicio detenido; `CASE_DIR` `0700`; secretos no expuestos | UNRUN |
| AC-04 | Paquete antiguo verificado | SHA-256 `f1735158…`, 10.110.872 B | UNRUN |
| AC-05 | Repo y clave (si aplica) | Fingerprint verificado antes de instalar; candidato 2.11.9 | UNRUN |
| AC-06 | `.deb` 2.11.9 verificado | SHA-256 `bbea4aea…`, 18.049.414 B | UNRUN |
| AC-07 | `unpack` sin arranque | `dpkg -l` en `iU`; sin proceso Caddy; Caddyfile intacto | UNRUN |
| AC-08 | `validate` como `caddy` | Config válida; sin errores de permisos | UNRUN |
| AC-09 | Módulos compatibles | Ningún módulo en uso ausente | UNRUN |
| AC-10 | Configurar y arrancar | `caddy version` 2.11.9; `ii`; `dpkg --audit` limpio; `active` | UNRUN |
| AC-11 | HTTPS y certificado | 200; verify=0; mismo fingerprint/SAN/fechas | UNRUN |
| AC-12 | HTTP y contenido | 308 a HTTPS; hash del cuerpo idéntico | UNRUN |
| AC-13 | Puertos y servicios | Caddy solo 80/443 públicos; 2019 loopback; 3001/18082 ausentes; UFW/SSH/DNS iguales al baseline | UNRUN |
| AC-14 | Reinicio limpio | `reset-failed` + `restart` correctos, sin errores | UNRUN |
| AC-15 | Unidad y capacidades | Decisión aplicada; `active` con la configuración elegida | UNRUN |
| AC-16 | Versión fijada / ciclo de vida | `hold` con repo, o actualización manual declarada; timers restaurados | UNRUN |
| AC-17 | Arranque tras reinicio del VPS | Servicio activo y `enabled` tras reboot | UNRUN (decisión §10) |
| AC-18 | Rollback ensayado | En VM Debian 13 desechable, con HTTP/TLS/cuerpo/certificado verificados | UNRUN (decisión §10) |

Los AC de ejecución remota no pueden declararse PASS sin salida real de la ventana.

## 9. Riesgos y mitigaciones

| Riesgo | Nivel | Mitigación |
| --- | --- | --- |
| 2.11.9 es del mismo día y sucede a una versión con regresión | Medio-Alto | Validar, preparar rollback y considerar ensayo en VM o posponer la ventana; si se pospone, CVE-2026-77281 sigue abierto |
| `postinst` arranca el servicio y deshace `mask` | Alto | `dpkg --unpack` + validar antes de `--configure`; `mask` no se usa como control |
| Otro `apt`/`dpkg` configura el paquete antes de validar | Alto | Timers detenidos, `fuser`/`pgrep` sin procesos, ventana exclusiva |
| Caddyfile incompatible o módulo ausente | Medio | Revisión de directivas, `validate` y `diff` de módulos antes de configurar |
| Reemplazo del `Caddyfile` en `--configure` | Medio | `--force-confold` en `--unpack` **y** `--configure`; hash y ausencia de `.dpkg-dist` |
| Pérdida de certificados/claves | Alto | Snapshot `0700` de `/var/lib/caddy`; prohibido purgar; no tocar DNS |
| Rollback imposible | Alto | `.deb` antiguo verificado con `sha256sum -c` antes de empezar; si falta, no se instala |
| `dpkg` rechaza el descenso de versión | Alto | `--force-downgrade` explícito; ensayo previo en VM (AC-18) |
| Conflicto de `conffile` | Bajo | Ambos paquetes traen el mismo `Caddyfile`; `--force-confold` y hash antes/después |
| Timers de APT no restaurados | Medio | Cierre de ventana en §6.9, también tras rollback |
| `CAP_NET_ADMIN` añadido por la unidad oficial | Medio | *Drop-in* con `CAP_NET_BIND_SERVICE`; probar arranque y revertir si falla |
| Reintroducción por `apt upgrade` | Medio | `hold` con repo activo; en rollback, desactivar repo o pin negativo |
| `hold` sobre Debian bloquea futuros DSA | Medio | No dejar hold tras el rollback a Debian |
| Ciclo de vida: versión oficial mayor que Debian | Medio | Revisión mensual; actualizaciones solo por ventana autorizada |
| `purge` o `autoremove --purge` | Alto | Prohibido; el `postrm purge` oficial borra datos y usuario |
| Snapshot local no cifrado en el mismo disco | Medio | Tratar como secreto, directorio `0700`, borrado a 30 días |
| `journalctl`/`baseline` con IPs o rutas | Bajo | No publicar; redactar antes de adjuntar |
| Interrupción breve del sitio | Bajo | Ventana de baja actividad; parada estimada < 2 min |
| Reboot no probado | Medio | AC-17 UNRUN hasta que se pruebe; aceptar o programar |

## 10. Decisiones pendientes

1. **Versión:** aprobar 2.11.9 o posponer la ventana unos días por su novedad (dejando
   CVE-2026-77281 abierto mientras tanto).
2. **Origen:** repositorio oficial Cloudsmith con `hold` y revisión mensual, o `.deb` verificado
   sin repo asumiendo actualizaciones manuales sin parches automáticos.
3. **Capacidades:** aplicar el *drop-in* con `CAP_NET_BIND_SERVICE` (recomendado) o aceptar
   `CAP_NET_ADMIN` de la unidad oficial.
4. **Rollback:** ensayar en VM Debian 13 desechable (AC-18) o aceptar `UNRUN`.
5. **Reboot:** probar el arranque tras reinicio (AC-17) o aceptar `UNRUN`.
6. **Ventana y `sudo`:** fecha, duración y quién ejecuta cada bloque; timers de APT detenidos.
7. **Retención** del snapshot con claves privadas y fecha de borrado.
8. Confirmar que el `Caddyfile` completo no requiere cambios (§6.1).

## 11. Evidencia a conservar

- `baseline.txt`, hashes de Caddyfile y binario, `modules.before/after`, `body.before/after`,
  `http.before/after`, `cert.before/after`, `https.after`, `ss.before/after`, `journal.after`.
- `directives.txt` (no publicar sin redactar).
- `ufw.before/after`, `sshd.before/after`, `dns.before/after`.
- `old.expected`/`new.expected` y sus `sha256sum -c`.
- `rollback.https/http/body/cert` si se ejecuta el rollback.
- Versiones y estado de `dpkg`/`systemd` antes y después; `dpkg --audit`.
- Salida de `validate` y de las pruebas HTTP/HTTPS.
- Confirmación de rollback disponible (hash del `.deb` antiguo).

No se publican claves, contenido de `/var/lib/caddy`, IPs, `journalctl`, `baseline.txt`,
`sshd.*`, `ss.*` ni el `Caddyfile` completo sin redactar.

## 12. Fuera de alcance

- Ejecutar cualquier comando de esta spec ahora.
- Acceder al VPS, instalar, parar o reiniciar servicios.
- Cambiar DNS, UFW, SSH, Podman, Quadlet o `myfinanzas-app`.
- Añadir cabeceras de seguridad o hardening HTTP (entrega separada).
- Desplegar MyFinanzas TEST.
