# 03.1 — VPS-CADDY-UPGRADE-01: comprobación previa

Status: **DRAFT — preflight preparada; no ejecutada en el VPS.**
Fecha: 2026-11-05.
Procedimiento principal: [03 — actualización de Caddy](03-caddy-upgrade-01-specification.md).

Esta comprobación es **solo lectura** sobre el servicio y **no autoriza** acceso al VPS,
instalación, parada o reinicio de Caddy, cambios de configuración, DNS, UFW, SSH, merges ni
despliegues. Los comandos con `sudo` los ejecuta el usuario en una ventana autorizada.

## 1. Objetivo y límites

Confirmar, antes de la ventana, que:

- el `Caddyfile` es legible, comprensible y válido para la versión **actual**;
- los paquetes antiguo y nuevo están disponibles y son verificables;
- APT/dpkg está libre y los detectores fallan de forma segura;
- hay espacio y permisos suficientes;
- el servicio y su unidad están en el estado esperado;
- existen materiales suficientes para recuperar el servicio.

**No se copia `/var/lib/caddy` ni claves privadas.** La copia definitiva se hace en la ventana,
con Caddy detenido, según §6.4 del procedimiento principal, con permisos `0700` y retención
controlada.

**No se copia el `Caddyfile`.** Se revisa y valida en su ubicación real, sin escribir en
`/etc/caddy`.

La validación de esta preflight usa Caddy **2.6.2** y es **preliminar**. La validación
definitiva se hace con **Caddy 2.11.9 como usuario `caddy`**, después de `dpkg --unpack` y antes
de arrancar el servicio (§6.5 del procedimiento principal).

## 2. Verificaciones y condiciones de parada

| ID | Verificación | Condición de parada |
| --- | --- | --- |
| P-01 | Versión instalada, binario, servicio, unidad y journal | Versión distinta de `2.6.2-12+deb13u1`; servicio no activo; unidad inesperada |
| P-02 | APT/dpkg libre con detección fail-closed | Cualquier proceso, lock, error del detector, `dpkg --audit` con incidencias o `caddy` en `hold` |
| P-03 | Paquetes antiguo y nuevo: disponibilidad, tamaño, SHA-256, metadatos | Cualquier discrepancia o descarga fallida |
| P-04 | `Caddyfile`: hash, directivas, permisos, rutas y validación preliminar con 2.6.2 | No legible por `caddy`, validación fallida o ruta `root` inaccesible |
| P-05 | `/var/lib/caddy`: existencia, tamaño, propietario, permisos, ruta real de almacenamiento y espacio (sin copiar) | Falta el directorio, propietario/permisos incorrectos, no se localiza el almacenamiento o espacio insuficiente |
| P-06 | Espacio, inodos y permisos del sistema | Menos de 200 MB libres sobre el tamaño estimado, o inodos escasos |
| P-07 | HTTP/HTTPS, certificado, cuerpo y puertos | HTTPS distinto de 200, `verify` distinto de 0, HTTP sin redirección a HTTPS, certificado con menos de 24 h o listeners 80/443 ausentes |
| P-08 | Resumen de materiales de recuperación | Cualquier comprobación anterior fallida |

## 3. Comandos definitivos

Ejecutar en una sola sesión, tras `sudo -v`. El script no detiene, recarga ni reinicia Caddy; no
instala paquetes; no escribe en `/etc/caddy` ni en `/var/lib/caddy`.

La detección de locks usa `lsof`, presente en Debian 13. **`fuser` no está instalado en el
VPS**, por lo que no se usa. Un error de `lsof` o de los detectores aborta siempre.

```bash
#!/usr/bin/env bash
set -euo pipefail

TS=$(date -u +%Y%m%dT%H%M%SZ)
PF="/var/tmp/caddy-preflight-$TS"
URL_OLD="https://security.debian.org/debian-security/pool/updates/main/c/caddy/caddy_2.6.2-12+deb13u1_amd64.deb"
URL_NEW="https://dl.cloudsmith.io/public/caddy/stable/deb/any-distro/pool/any-version/main/c/ca/caddy_2.11.9/caddy_2.11.9_linux_amd64.deb"
OLD_SHA="f173515859f273c97219cc242d625a64650fefdd136a9570acb1b5f7581c9786"
NEW_SHA="bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb"
OLD_SIZE=10110872
NEW_SIZE=18049414

sudo install -d -m 0700 "$PF"
for t in curl openssl sha256sum dpkg-deb namei lsof; do
  command -v "$t" >/dev/null || { echo "Falta la herramienta $t: abortar"; exit 1; }
done

echo "== P-01 estado =="
{
  date -u
  dpkg-query -W -f='${Package} ${Version} ${Architecture} ${Status}\n' caddy
  /usr/bin/caddy version
  systemctl is-enabled caddy caddy-api 2>&1 || true
  systemctl is-active caddy caddy-api 2>&1 || true
  systemctl show caddy -p ActiveState -p SubState -p NRestarts -p FragmentPath \
    -p User -p Group -p MainPID -p AmbientCapabilities -p CapabilityBoundingSet -p LimitNPROC
  systemctl cat caddy
} | sudo tee "$PF/01-state.txt" >/dev/null

INSTALLED=$(dpkg-query -W -f='${Version}' caddy)
[ "$INSTALLED" = "2.6.2-12+deb13u1" ] || { echo "Versión instalada inesperada: $INSTALLED"; exit 1; }
[ "$(systemctl is-active caddy)" = "active" ] || { echo "caddy no está activo: abortar"; exit 1; }
if [ "$(systemctl is-active caddy-api 2>/dev/null || true)" = "active" ]; then
  echo "AVISO: caddy-api está activo; revisar antes de la ventana"
fi
sudo journalctl -u caddy -p warning --since '-24h' --no-pager | tail -30 \
  | sudo tee "$PF/01-journal.txt" >/dev/null || true

echo "== P-02 APT/dpkg (fail-closed) =="
BUSY=0
if pgrep -a -x 'apt|apt-get|dpkg' >/dev/null 2>&1; then
  BUSY=1
else
  rc=$?
  [ "$rc" -eq 1 ] || { echo "pgrep APT falló (rc=$rc): abortar"; exit 1; }
fi
if pgrep -a -f 'unattended-upgr' >/dev/null 2>&1; then
  BUSY=1
else
  rc=$?
  [ "$rc" -eq 1 ] || { echo "pgrep unattended falló (rc=$rc): abortar"; exit 1; }
fi
for f in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock /var/lib/apt/lists/lock; do
  sudo test -e "$f" || { echo "Falta el lock $f: abortar"; exit 1; }
done
ERR=$(mktemp)
if sudo lsof /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
    /var/cache/apt/archives/lock /var/lib/apt/lists/lock >/dev/null 2>"$ERR"; then
  BUSY=1
else
  rc=$?
  if [ -s "$ERR" ]; then echo "lsof falló: $(cat "$ERR"): abortar"; rm -f "$ERR"; exit 1; fi
  [ "$rc" -eq 1 ] || { echo "lsof rc=$rc: abortar"; rm -f "$ERR"; exit 1; }
fi
rm -f "$ERR"
[ "$BUSY" -eq 0 ] || { echo "APT/dpkg ocupado: abortar sin interrumpir"; exit 1; }
AUDIT=$(sudo dpkg --audit)
[ -z "$AUDIT" ] || { echo "dpkg --audit detectó problemas:"; echo "$AUDIT"; exit 1; }
if apt-mark showhold | grep -x caddy >/dev/null; then echo "caddy está en hold: abortar"; exit 1; fi
apt-mark showhold
apt-cache policy caddy
apt-cache madison caddy

echo "== P-03 paquetes =="
curl -fsSIL "$URL_OLD" | sed -n '1p;/content-length/Ip' | sudo tee "$PF/old.headers" >/dev/null
curl -fsSIL "$URL_NEW" | sed -n '1p;/content-length/Ip' | sudo tee "$PF/new.headers" >/dev/null
sudo curl -fsSL -o "$PF/old.deb" "$URL_OLD"
sudo curl -fsSL -o "$PF/new.deb" "$URL_NEW"
[ "$(sudo stat -c %s "$PF/old.deb")" = "$OLD_SIZE" ] || { echo "Tamaño old inesperado"; exit 1; }
[ "$(sudo stat -c %s "$PF/new.deb")" = "$NEW_SIZE" ] || { echo "Tamaño new inesperado"; exit 1; }
[ "$(sudo sha256sum "$PF/old.deb" | awk '{print $1}')" = "$OLD_SHA" ] || { echo "SHA old inesperado"; exit 1; }
[ "$(sudo sha256sum "$PF/new.deb" | awk '{print $1}')" = "$NEW_SHA" ] || { echo "SHA new inesperado"; exit 1; }
sudo dpkg-deb -f "$PF/old.deb" Package Version Architecture
sudo dpkg-deb -f "$PF/new.deb" Package Version Architecture
sudo dpkg-deb -I "$PF/old.deb" | sed -n '1,25p'
sudo dpkg-deb -c "$PF/new.deb" | sed -n '1,10p'
sudo dpkg --no-act -i "$PF/old.deb" | sudo tee "$PF/old-dryrun.txt" >/dev/null

echo "== P-04 Caddyfile (preliminar, sin copiar) =="
sudo sha256sum /etc/caddy/Caddyfile | sudo tee "$PF/04-caddyfile.sha256" >/dev/null
sudo namei -l /etc/caddy/Caddyfile
sudo stat -c '%A %U:%G %s %n' /etc/caddy/Caddyfile /etc/caddy
sudo grep -nE 'rewrite|hide|http\.request\.body|php_fastcgi|client_auth|basic_auth|bind |root|reverse_proxy|tls ' \
  /etc/caddy/Caddyfile
sudo -u caddy test -r /etc/caddy/Caddyfile || { echo "Caddyfile NO legible por caddy"; exit 1; }
VHOME=$(sudo mktemp -d /var/tmp/caddy-validate.XXXXXX)
sudo chown caddy:caddy "$VHOME"
sudo chmod 0700 "$VHOME"
sudo -u caddy env HOME="$VHOME" XDG_DATA_HOME="$VHOME/data" XDG_CONFIG_HOME="$VHOME/config" \
  /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo rm -rf "$VHOME"

echo "== P-05 /var/lib/caddy (solo metadatos, sin copiar) =="
sudo stat -c '%A %U:%G %s %n' /var/lib/caddy
sudo -u caddy test -r /var/lib/caddy || { echo "/var/lib/caddy NO legible por caddy"; exit 1; }
sudo find /var/lib/caddy -type f | wc -l
sudo find /var/lib/caddy -maxdepth 4 -printf '%y %m %u:%g\n' | sort | uniq -c
if sudo test -d /var/lib/caddy/.local/share/caddy; then
  echo "Ruta de almacenamiento por defecto presente"
  sudo stat -c '%A %U:%G %n' /var/lib/caddy/.local/share/caddy
else
  echo "AVISO: no existe /var/lib/caddy/.local/share/caddy; localizando almacenamiento real"
  STORAGE_ROOT=$(sudo find /var/lib/caddy -type d -name certificates -printf '%h\n' -quit)
  if [ -n "$STORAGE_ROOT" ]; then
    echo "Almacenamiento detectado: $STORAGE_ROOT"
    sudo stat -c '%A %U:%G %n' "$STORAGE_ROOT"
  else
    echo "No se localizó el almacenamiento de Caddy; confirmar la ruta real antes de continuar"
    exit 1
  fi
fi
CERTS=$(sudo find /var/lib/caddy -path '*certificates*' -type f | wc -l)
echo "Ficheros bajo certificates/: $CERTS"
[ "$CERTS" -gt 0 ] || echo "AVISO: no se encontraron ficheros de certificados; revisar antes de la ventana"
DATA_MB=$(sudo du -sm /var/lib/caddy | awk '{print $1}')
AVAIL_MB=$(df -Pm /var/lib/caddy | awk 'NR==2 {print $4}')
[ "$AVAIL_MB" -ge $((DATA_MB + 200)) ] || { echo "Espacio insuficiente: ${AVAIL_MB} MB libres"; exit 1; }
sudo du -sh /var/lib/caddy
df -h /var/lib/caddy

echo "== P-06 espacio y permisos =="
df -h / /root /var/tmp
df -i /
id caddy
sudo stat -c '%A %U:%G %n' /lib/systemd/system/caddy.service /etc/caddy /var/lib/caddy

echo "== P-07 servicio y sitio (solo lectura) =="
HTTPS=$(curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}' https://myfinanzas.pp.ua/)
HTTPS_CODE=${HTTPS% *}
HTTPS_VERIFY=${HTTPS#* }
printf 'https %s verify=%s\n' "$HTTPS_CODE" "$HTTPS_VERIFY" | sudo tee "$PF/07-https.txt" >/dev/null
[ "$HTTPS_CODE" = "200" ] || { echo "HTTPS inesperado: $HTTPS_CODE"; exit 1; }
[ "$HTTPS_VERIFY" = "0" ] || { echo "Certificado no válido: verify=$HTTPS_VERIFY"; exit 1; }

HTTP=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' http://myfinanzas.pp.ua/)
HTTP_CODE=${HTTP%% *}
HTTP_URL=${HTTP#* }
printf 'http %s -> %s\n' "$HTTP_CODE" "$HTTP_URL" | sudo tee "$PF/07-http.txt" >/dev/null
case "$HTTP_CODE" in
  301|302|303|307|308) ;;
  *) echo "HTTP no redirige a HTTPS: $HTTP_CODE"; exit 1 ;;
esac
case "$HTTP_URL" in
  https://myfinanzas.pp.ua|https://myfinanzas.pp.ua/*) ;;
  *) echo "Redirección inesperada: $HTTP_URL"; exit 1 ;;
esac

curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "$PF/07-body.sha256" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 \
  | sudo tee "$PF/07-cert.txt" >/dev/null
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -checkend 86400 >/dev/null \
  || { echo "El certificado caduca en menos de 24 h"; exit 1; }
ss -ltn | sudo tee "$PF/07-listen.txt" >/dev/null
ss -ltn | awk '{print $4}' | grep -E ':80$' >/dev/null || { echo "No hay listener en 80"; exit 1; }
ss -ltn | awk '{print $4}' | grep -E ':443$' >/dev/null || { echo "No hay listener en 443"; exit 1; }
sudo ss -ltnp | grep -E ':(80|443|2019)\b' | sudo tee "$PF/07-listen-pids.txt" >/dev/null || true

echo "== P-08 resumen =="
echo "Preflight: $PF"
echo "Paquete antiguo: $PF/old.deb ($OLD_SHA)"
echo "Paquete nuevo:   $PF/new.deb ($NEW_SHA)"
echo "Datos: solo metadatos; copia definitiva en la ventana (Caddy detenido)"
echo "Servicio: $(systemctl is-active caddy) / $(systemctl is-enabled caddy 2>&1 || true)"
echo "Rollback: materiales verificados; downgrade NO ensayado (UNRUN)"
```

Si HTTPS no devuelve `200` con `verify=0`, HTTP no redirige a `https://myfinanzas.pp.ua` o
faltan los listeners 80/443, el script **aborta**. No se modifica el `Caddyfile` ni se recarga
Caddy para corregirlo.

### Ruta del sitio y permisos

Tras revisar el `Caddyfile` completo en local (`sudo sed -n '1,200p' /etc/caddy/Caddyfile`),
comprobar que `caddy` puede leer y atravesar la ruta servida. Sustituir la ruta real:

```bash
sudo namei -l "<ruta-del-root>"
sudo -u caddy test -r "<ruta-del-root>" || { echo "root no legible por caddy"; exit 1; }
sudo -u caddy test -x "<ruta-del-root>" || { echo "root no atravesable por caddy"; exit 1; }
```

No pegar el contenido del `Caddyfile` ni la salida de `grep` en la PR, el chat o un ticket: puede
contener rutas internas o hashes de credenciales.

## 4. Permisos

| Sin `sudo` | Con `sudo` | Con `sudo -u caddy` |
| --- | --- | --- |
| `caddy version`, `dpkg-query`, `apt-cache`, `apt-mark showhold`, `systemctl is-active/is-enabled/show/cat`, `ss -ltn`, `df`, `id`, `curl`, `openssl` | Crear `PF`, `lsof` y locks, `dpkg --audit`, `dpkg --no-act`, descargas a `PF`, `sha256sum`/`stat`/`namei` de configuración y datos, `journalctl`, `ss -ltnp`, `mktemp` de validación | Leer el `Caddyfile`, validar con 2.6.2 y comprobar la ruta servida |

## 5. Qué no hace la preflight

- No ejecuta `systemctl stop/restart/reload`, `caddy reload`, `dpkg -i`, `apt install` ni
  `apt-get upgrade`.
- No escribe en `/etc/caddy` ni en `/var/lib/caddy`.
- No copia claves privadas ni datos persistentes.
- No añade repositorios ni modifica fuentes de APT.
- No modifica DNS, UFW, SSH, Podman ni otras aplicaciones.
- No hace merge ni despliegue.

La copia definitiva de `/var/lib/caddy` se hará en la ventana, con Caddy detenido, `0700` y
retención de 30 días (§6.4). La validación definitiva del `Caddyfile` se hará con el binario
2.11.9 como `caddy`, tras `dpkg --unpack` y antes de arrancar (§6.5).

## 6. Límites de la evidencia

- `dpkg --no-act` confirma preliminarmente que el archivo del paquete antiguo se puede procesar;
  **no es una prueba de rollback**.
- La validación con 2.6.2 no garantiza que 2.11.9 acepte la configuración; eso se comprueba con
  el binario nuevo antes de arrancar.
- Sin copia de datos en la preflight, la recuperación de datos se apoya en el estado actual y en
  la copia que se hará en la ventana.
- El downgrade real y el arranque posterior siguen **UNRUN** (AC-18).

## 7. Validaciones de esta preflight

| ID | Validación | Resultado |
| --- | --- | --- |
| V-01 | `bash -n` del bloque de comandos | PASS |
| V-02 | `./scripts/validate-template` | PASS |
| V-03 | `python3 scripts/check_harness.py` | PASS |
| V-04 | `./scripts/test-validator` (185 tests) | PASS |
| V-05 | Detector APT con dobles (rc 0/1/2, `lsof` con error y lock ausente) | PASS |
| T-01…T-12 | Ensayo en VM Debian 13 | BLOQUEADO / UNRUN |

V-05 se probó con `lsof` real (libre, ocupado y ruta ausente) y con un doble que devuelve 2.
Las validaciones estáticas no sustituyen a la ejecución en el VPS ni al ensayo de rollback.

## 8. Riesgos pendientes

- Rollback no ensayado: AC-18 y T-01…T-12 en `UNRUN`.
- La preflight no prueba la copia/restauración real de datos; solo su viabilidad y espacio.
- La validación del `Caddyfile` con 2.6.2 es preliminar.
- 2.11.9 es del mismo día y sucede a una versión con regresión.
- Concurrencia de APT: se detecta, pero puede aparecer durante la ventana.
- Certificado y exposición real solo se validan en la ventana.
- AC-17 (arranque tras reboot) pendiente.

## 9. Ejecución desde el Mac

El script es específico de Linux; no se ejecuta en macOS.

1. Extraer el bloque de §3 a `caddy-preflight.sh` en el Mac.
2. Copiarlo al VPS: `scp caddy-preflight.sh mfadmin@<host>:/var/tmp/caddy-preflight.sh`.
3. Conectar con `ssh -t mfadmin@<host>`.
4. En el VPS: `chmod 700 /var/tmp/caddy-preflight.sh`, `sudo -v` y
   `bash /var/tmp/caddy-preflight.sh`.
5. Si el script aborta, **no continuar**: anotar el mensaje y revisar la causa.
6. Revisar la salida y `$PF`. No publicar `01-journal.txt`, la salida de `grep` ni el
   `Caddyfile`; redactar IPs, rutas internas y datos personales.
7. Conservar `$PF/old.deb` y `$PF/new.deb` hasta la ventana; el resto puede borrarse con
   autorización. La copia de datos no existe en la preflight: se hará en la ventana.

La ejecución no detiene, recarga ni reinicia Caddy y no instala ni actualiza paquetes.
