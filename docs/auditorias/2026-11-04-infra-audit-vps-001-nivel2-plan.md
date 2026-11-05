# INFRA-AUDIT-VPS-001 · Nivel 2 — Plan de auditoría

Status: **PREPARADO — NO EJECUTADO — ACCESO AL VPS NO AUTORIZADO PARA NIVEL 2**
Fecha: 2026-11-04
Base: informe de Nivel 1 ([2026-11-04](2026-11-04-infra-audit-vps-001-nivel1.md)), PR #10.
Contrato host: `specs/02-infra-test-01-host-specification.md`, PR #9, **DRAFT**; no aprobado.
Contrato de aplicación: SPEC34/PR #207, `myfinanzas-app`; no se modifica.

## 0. Regla de parada

Este documento **no autoriza** acceso al VPS. Cada bloque requiere autorización expresa y una
ventana. No se ejecutarán cambios intencionados, instalaciones, reinicios, recargas, merges ni
despliegues. Las comprobaciones con `sudo -n` solo se ejecutan si el usuario autoriza
específicamente esa elevación; si no, se registran como `BLOQUEADO`.

Efectos incidentales que se declaran y aceptan o se omiten:

- `podman` puede iniciar un proceso `podman-pause-*` transitorio. No se ejecutará
  `podman unshare` ni se creará un namespace de usuario en esta auditoría.
- Las conexiones TCP/HTTP y `dig` pueden dejar entradas en logs o en fail2ban; no se
  interpretan como exposición ni como cambio de configuración.
- `systemctl`, `ss`, `find`, `stat` y `loginctl` pueden actualizar atime.
- No se ejecutará `caddy validate` en la auditoría: puede escribir directorios de storage y
  reproducir configuración; la validación queda para una ventana de cambio separada.

## 1. Objetivo

Completar el inventario de Nivel 1 con los datos que no se pudieron verificar sin elevación o
que pertenecen a la publicación/recuperación de TEST:

1. UFW/nftables y exposición de puertos.
2. Caddy: configuración efectiva, dominios y TLS.
3. Podman rootless, Quadlet y diagnóstico de `podman info`.
4. SSH y fail2ban.
5. DNS actual.
6. Backups y recuperación.
7. Capacidad y requisitos para MyFinanzas TEST.

No se probará la aplicación, no se ejecutará el seed y no se desplegará nada.

## 2. Prioridad y permisos

| Bloque | Sin sudo | `sudo -n` | Justificación de la elevación |
| --- | --- | --- | --- |
| UFW/nftables | `ss`, `systemctl show`, intento de `ufw status` | `ufw status verbose`, `nft list ruleset` | Las reglas efectivas no son legibles por `mfadmin`; sin ellas no se puede afirmar la exposición. |
| Caddy | `caddy version`, `systemctl show`, `ss`, etiquetas/directivas del `Caddyfile` (0644) sin valores | Ninguno | La validación y los certificados internos quedan fuera; TLS público se verifica desde la estación. |
| Podman/Quadlet | `podman` como `mfadmin`, `systemctl --user`, `find` de metadatos, `loginctl` | Ninguno | El store es del usuario; no se usa Podman root. |
| SSH | Lectura de `/etc/ssh/sshd_config` si es legible, `systemctl show` | `sshd -T` | La configuración efectiva puede requerir root y claves de host; se filtra y redacta. |
| fail2ban | `systemctl show`, `find` de metadatos | `fail2ban-client status` | El socket de control suele ser root; se piden solo nombres de jail y conteos, no IPs. |
| DNS | `dig` desde la estación | Ninguno en el VPS | Es consulta pública; requiere autorización de red, no de host. |
| TLS/HTTP externos | `openssl s_client`, `curl` desde la estación | Ninguno | Verifica la exposición real; requiere autorización de red. |
| Backups | `systemctl list-timers`, `find` de metadatos si es legible | Metadatos `stat/find/du` si la raíz es 0700 | Solo metadatos; nunca contenido. La ruta la aporta el usuario. |

Cada comprobación con `sudo -n` se ejecutará una vez y con la salida filtrada; los bucles
explícitos sobre certificados o ficheros se documentan y se ejecutan con un único `sudo -n`
por fichero. Si `sudo -n` falla, no se pedirá contraseña en el chat ni se modificará sudoers.

## 3. Comandos exactos (`UNRUN`)

### 3.1 UFW/nftables y exposición

Sin sudo:

```bash
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath -p DropInPaths ufw.service
systemctl is-enabled ufw.service 2>&1
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath netavark-firewalld-reload.service
ss -ltn
ss -lun
ss -ltnp 2>&1
command -v ufw 2>&1
ls -l /usr/sbin/ufw /sbin/ufw 2>&1
ufw status 2>&1
```

Con autorización de `sudo -n`:

```bash
sudo -n ufw status verbose
sudo -n nft list ruleset
```

Filtrado local obligatorio: conservar `127.0.0.1`, `0.0.0.0`, `::1` y `::`; redactar el
resto de IPv4/IPv6, MAC y comentarios con IPs. No se ejecutan `ufw allow/deny/delete/reset`,
`nft add/delete/flush` ni `iptables` de cambio.

Evidencia: política por defecto, reglas de entrada/salida, puertos permitidos, loopback,
IPv6, y diferencia entre socket en escucha y exposición real. La exposición desde Internet
solo se acredita con las pruebas externas de §3.6.

### 3.2 Caddy: configuración, dominios y TLS

Sin sudo:

```bash
caddy version
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath -p DropInPaths -p ExecMainStartTimestamp caddy.service
systemctl is-enabled caddy.service 2>&1
ss -ltnp 2>&1 | grep -E ':(80|443|2019)\b' || true
ls -ld /etc/caddy /var/lib/caddy /var/log/caddy 2>&1
find /etc/caddy -maxdepth 2 -type f -printf '%M %u:%g %s %p\n' 2>&1
```

Lectura **sin valores sensibles** del Caddyfile (es 0644 root:root según Nivel 1; no requiere
sudo). Solo se imprimen etiquetas de sitio, nombres de directivas y destinos loopback
validados:

```bash
# Etiquetas de sitio: solo la parte anterior a "{"
grep -nE '^[^#[:space:]].*\{' /etc/caddy/Caddyfile 2>&1 | sed -E 's/\{.*$/ {/'

# Nombres de directivas, sin sus valores
grep -nE '^[[:space:]]*(reverse_proxy|root|file_server|try_files|handle|handle_path|redir|rewrite|encode|header|tls|basic_auth|basicauth|import)[[:space:]]' /etc/caddy/Caddyfile 2>&1 | sed -E 's/^([0-9]+:)[[:space:]]*([A-Za-z_]+).*/\1\2/'

# Destino reverse_proxy: se imprime solo si es loopback:puerto; el resto se redacta
awk '/^[[:space:]]*reverse_proxy[[:space:]]+/ {line=$0; sub(/^[[:space:]]*reverse_proxy[[:space:]]+/,"",line); sub(/[[:space:]].*$/,"",line); if (line ~ /^(127\.0\.0\.1|localhost|\[::1\]):[0-9]{1,5}$/) print "reverse_proxy_target=" line; else print "reverse_proxy_target=<redacted>"}' /etc/caddy/Caddyfile 2>&1

# Imports: solo rutas, sin contenido
grep -nE '^[[:space:]]*import[[:space:]]' /etc/caddy/Caddyfile 2>&1
```

No se lee `Caddyfile.bak` en esta fase: es un respaldo histórico y puede contener secretos
obsoletos. Si se necesita, requiere autorización y el mismo filtro por lista blanca.

No se ejecuta `caddy validate` en la auditoría: puede escribir directorios de storage y
reproducir configuración en errores. La validación queda para una ventana de cambio separada.
No se usa la API admin `127.0.0.1:2019`, ni `caddy reload`, ni `caddy stop/start`.

TLS público desde la estación, **solo para `test.myfinanzas.pp.ua`** (requiere autorización
de red):

```bash
openssl s_client -connect test.myfinanzas.pp.ua:443 -servername test.myfinanzas.pp.ua -showcerts </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
curl -sS -o /dev/null -D - --max-time 10 https://test.myfinanzas.pp.ua/ | grep -iE '^(HTTP/|location:|server:|strict-transport-security:|content-security-policy:|x-content-type-options:|referrer-policy:)'
```

No se consulta `myfinanzas.pp.ua` por HTTP/TLS en este nivel sin autorización específica por
dominio; un GET al sitio raíz podría alcanzar la aplicación si estuviera desplegada. La
consulta DNS de ambos nombres sí se incluye en §3.5.

No se leen `.key`, `private`, `acme` ni secretos de DNS. Si una ruta o dominio no se puede
determinar sin valores sensibles, se marca `NO VERIFICADO`; no se imprime el Caddyfile
completo.

Riesgo específico: Caddy 2.6.2 observado en Nivel 1; no se consultaron CVEs. La auditoría
solo documenta la versión y el origen que pueda verificarse; no actualiza.

### 3.3 Podman rootless, Quadlet y `podman info`

Sin sudo:

```bash
podman --version
podman info --format '{{json .Host}}' 2>&1 | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted(d)))' 2>&1
podman info --format '{{.Host.Security.Rootless}}' 2>&1
podman info --format '{{.Host.CgroupManager}}' 2>&1
cat /proc/self/cgroup
cat /sys/fs/cgroup/cgroup.controllers 2>&1
systemctl --user show -p Delegate 2>&1
podman info --format '{{json .Host.IDMappings}}' 2>&1
awk -F: '$1=="mfadmin"{print FILENAME":"$1":"$3}' /etc/subuid /etc/subgid 2>&1
command -v newuidmap newgidmap fuse-overlayfs slirp4netns pasta crun 2>&1
podman system df
podman ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
podman images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'
podman volume ls --format 'table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}'
podman network ls --format 'table {{.Name}}\t{{.Driver}}'
podman pod ps --format 'table {{.Name}}\t{{.Status}}\t{{.Containers}}'
```

`podman info --format '{{json .Host}}' | python3 ...` imprime solo las claves del objeto
Host; si falla, se registra y no se imprime el JSON completo. Los mapas UID/GID se consultan
con `podman info --format '{{json .Host.IDMappings}}'` y con `/etc/subuid`/`/etc/subgid`; no
se crea ningún namespace ni se ejecuta `podman unshare`.

Quadlet, sin leer valores sensibles:

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
systemctl --user is-system-running 2>&1
systemctl --user list-units --type=service --all --no-pager --no-legend 2>&1
systemctl --user list-unit-files --no-pager --no-legend 2>&1 | sed -n '1,120p'
systemctl --user list-timers --all --no-pager --no-legend 2>&1
find "$HOME/.config/containers/systemd" -maxdepth 2 -type f -printf '%M %u:%g %s %p\n' 2>&1
find "$HOME/.config/containers/systemd" -maxdepth 2 -type f -exec sh -c 'for f; do echo "== $f"; grep -E "^(Description|Image|ContainerName|PublishPort|Network|User|Group|WantedBy|Restart|Health)" "$f"; done' sh {} + 2>&1
```

Solo se imprimen claves seleccionadas; nunca `Environment`, `EnvironmentFile`, `Secret`,
`Volume`, `Exec` o `Entrypoint`.

Diagnóstico de `podman info`: Nivel 1 falló al evaluar `.Host.CgroupVersion`; la causa no se
diagnosticó. Se comprobará si la clave existe con el listado de claves y se consultarán solo
campos escalares. No se modificará la configuración de Podman para “arreglar” el formato.

### 3.4 SSH y fail2ban

Sin sudo:

```bash
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath -p DropInPaths -p ExecMainStartTimestamp ssh.service
ss -ltn | grep -E ':22\b' || true
ls -l /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>&1
find /etc/ssh/sshd_config.d -maxdepth 1 -type f -printf '%M %u:%g %p\n' 2>&1
sed -n '1,200p' /etc/ssh/sshd_config 2>&1 | grep -vE '^[[:space:]]*(#|$)' | sed -E 's/^(setenv|acceptenv|authorizedkeyscommand|authorizedkeyscommanduser) .*/\1 <redacted>/I'
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath fail2ban.service
systemctl is-enabled fail2ban.service 2>&1
ls -ld /etc/fail2ban /var/lib/fail2ban 2>&1
```

Con autorización de `sudo -n`:

```bash
sudo -n sshd -T | grep -E '^(port|listenaddress|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|pubkeyauthentication|permitemptypasswords|usepam|x11forwarding|allowusers|allowgroups|denyusers|denygroups|maxauthtries|logingracetime|clientaliveinterval|clientalivecountmax|authorizedkeysfile|hostkey|banner|gatewayports|permittunnel|permituserenvironment|allowtcpforwarding|permitopen|permitlisten|forcecommand|chrootdirectory|authenticationmethods|maxsessions|maxstartups|pubkeyacceptedalgorithms|hostbasedauthentication|ignoreuserknownhosts|gssapiauthentication|kerberosauthentication|usedns|revokedkeys|trustedusercakeys|authorizedkeyscommand|authorizedkeyscommanduser|acceptenv|setenv)' | sed -E 's#(/etc/ssh/ssh_host_[a-z0-9_]+_key)#<hostkey-path>#g; s/^(setenv|acceptenv|authorizedkeyscommand|authorizedkeyscommanduser) .*/\1 <redacted>/I' | redact_net
sudo -n fail2ban-client status
sudo -n fail2ban-client status sshd 2>&1 | grep -E 'Currently banned|Total banned'
```

Aplicar `redact_net` de Nivel 1 a `listenaddress`, `allowusers`, `permitopen` y
`permitlisten`. `fail2ban-client status` solo devuelve jails; la consulta de `sshd` se
filtra a conteos, sin lista de IPs. No se ejecutan `fail2ban-client set/unban` ni `reload`.

`sshd -T` es configuración derivada de archivos; puede no coincidir con el demonio en
ejecución. Se compara el `mtime` de los archivos con `ExecMainStartTimestamp` y se clasifica
como `OBSERVADO` o `INFERIDO`.

### 3.5 DNS actual

Desde la estación, sin sudo:

```bash
for n in myfinanzas.pp.ua test.myfinanzas.pp.ua; do
  echo "== $n"
  dig +noall +answer A "$n"
  dig +noall +answer AAAA "$n"
  dig +noall +answer CNAME "$n"
  dig +noall +answer CAA "$n"
  dig +noall +answer NS "$n"
  dig +noall +answer SOA "$n"
done
dig +short NS pp.ua
dig +short SOA pp.ua
dig +short CAA pp.ua
dig +noall +answer TXT _dmarc.myfinanzas.pp.ua
```

Sin AXFR, `ANY`, enumeración de subdominios ni consultas a dominios no indicados. Si se
autoriza, comparar el A/AAAA con la IP pública del VPS sin publicarla en el informe.

### 3.6 Exposición externa y TLS/HTTP

Solo con autorización de red expresa; desde la estación, sin sudo:

```bash
for p in 22 80 443 2019 3001 18082; do
  nc -z -G 4 <VPS_IP> "$p" >/dev/null 2>&1 && echo "$p open" || echo "$p closed/filtered"
done
curl -sSI --connect-timeout 5 --max-time 10 https://myfinanzas.pp.ua/ | grep -iE '^(HTTP/|location:|server:|strict-transport-security:|content-security-policy:|x-content-type-options:|referrer-policy:)'
curl -sSI --connect-timeout 5 --max-time 10 https://test.myfinanzas.pp.ua/ | grep -iE '^(HTTP/|location:|server:|strict-transport-security:|content-security-policy:|x-content-type-options:|referrer-policy:)'
```

Solo se consulta la raíz `/` con `HEAD`; no se accede a `/api`, rutas autenticadas ni
contenido de la aplicación. La ausencia de `test.myfinanzas.pp.ua` es un resultado esperado,
no un fallo. No se amplía la lista de puertos ni se usa `nmap`. Si no se autoriza, la
exposición queda `NO VERIFICADA`.

### 3.7 Backups y recuperación

Solo metadatos; nunca contenido. Sustituir `<BACKUP_ROOT>` por la ruta que autorice el
usuario. Sin sudo primero:

```bash
systemctl list-timers --all --no-pager --no-legend | grep -Ei 'backup|restic|borg|rsync|rclone' || true
find /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly -maxdepth 1 -type f -printf '%M %u:%g %p\n' 2>&1
ls -ld <BACKUP_ROOT> 2>&1
find <BACKUP_ROOT> -xdev -maxdepth 2 -type f -printf '%M\t%u:%g\t%s\t%T@\n' 2>&1
find <BACKUP_ROOT> -xdev -maxdepth 2 -type f -name '*.*' -printf '%f\n' 2>&1 | sed 's/.*\.//' | sort | uniq -c
```

Si la raíz no es legible, con autorización de `sudo -n`:

```bash
sudo -n stat -c '%A %U:%G %s %y %n' <BACKUP_ROOT>
sudo -n find <BACKUP_ROOT> -xdev -maxdepth 2 -type f -printf '%M\t%u:%g\t%s\t%T@\n'
sudo -n du -sxb <BACKUP_ROOT>
```

Prohibido: `restic snapshots`, `borg list`, `rclone lsd`, `tar -t`, `gpg --decrypt`,
`rsync` contra el destino, abrir el repositorio, leer contenido o restaurar. El destino
externo y la prueba de restauración se acreditan con evidencia del usuario o una autorización
separada; esta auditoría no restaura.

### 3.8 Capacidad y requisitos para MyFinanzas TEST

Sin sudo:

```bash
free -h
df -hT -x tmpfs -x devtmpfs
df -i -x tmpfs -x devtmpfs
podman system df
podman info --format '{{.Host.Security.Rootless}}' 2>&1
loginctl show-user mfadmin -p Linger,State,RuntimePath
cat /sys/fs/cgroup/cgroup.controllers 2>&1
systemctl --user show -p Delegate 2>&1
```

Criterios propuestos, pendientes de aprobación: TEST 1 GiB RAM/1 CPU/128 pids y ≤ 5 GB de
disco; `MemAvailable` ≥ 1,75 GiB, ≥ 20 % disco libre y ≥ 10 % inodos. El Nivel 1 dejó 3,4 GiB
disponibles, 35 GB libres y 3 % de inodos; el margen parece suficiente, pero no se acredita
sin cgroup v2/delegación, límites reales y prueba de carga.

### 3.9 Usuario y rutas TEST

Sin sudo, solo metadatos:

```bash
getent passwd mftest 2>&1
id mftest 2>&1
getent group mftest 2>&1
loginctl show-user mftest -p Linger,State,RuntimePath 2>&1
awk -F: '$1=="mftest"{print FILENAME":"$1":"$3}' /etc/subuid /etc/subgid 2>&1
stat -c '%A %U:%G %n' /srv/myfinanzas-test /srv/myfinanzas-test/data /srv/myfinanzas-test/releases /srv/myfinanzas-test/backups /var/www/myfinanzas-test 2>&1
find /srv/myfinanzas-test -maxdepth 2 -printf '%M %u:%g %p\n' 2>&1
find /var/www/myfinanzas-test -maxdepth 2 -printf '%M %u:%g %p -> %l\n' 2>&1
find "$HOME/.config/containers/systemd" /etc/containers/systemd -maxdepth 2 -type f -iname '*myfinanzas*' -printf '%M %u:%g %s %p\n' 2>&1
ss -ltn | grep -E ':(18082|3001)\b' 2>&1
podman ps -a --format '{{.Names}}' 2>&1 | grep -Ei 'myfinanzas-test' || true
```

Si `mftest` no existe, el store rootless no es auditable y se marca `NO VERIFICADO`. Una
salida vacía por permiso se registra como `BLOQUEADO`, no como ausencia. No se ejecuta Podman
como `mftest` sin autorización específica.

## 4. Evidencias que se obtendrán

- UFW/nftables: política por defecto, reglas de entrada/salida, puertos permitidos, loopback,
  IPv6 y comparación con los sockets en escucha.
- Caddy: etiquetas de sitio, nombres de directivas, destinos loopback validados, imports y
  TLS público; sin valores sensibles, sin certificados internos y sin validación en esta fase.
- Podman: campos de `Host` (solo claves y escalares), rootless, cgroups, mapas UID/GID,
  subuid/subgid, binarios auxiliares, contenedores/imágenes/volúmenes/redes y Quadlet.
- SSH/fail2ban: configuración derivada, `mtime` frente a `ExecMainStartTimestamp`, jails y
  conteos; sin claves, `authorized_keys` ni IPs de baneos.
- DNS: A/AAAA/CNAME/CAA/NS/SOA, TTL y diferencias; sin AXFR.
- Exposición: puertos alcanzables desde la estación, TLS y cabeceras; sin escaneo amplio.
- Backups: rutas, permisos, conteo, tamaño, edades y extensión resumida si el nombre es
  seguro; sin nombres completos ni contenido.
- Capacidad: métricas de host y contenedores, con veredicto limitado a capacidad.

Custodia de evidencias: se aplica el estándar de Nivel 1. La salida cruda se cifra
(AES-256-CBC/PBKDF2 600.000), la clave se custodia en macOS Keychain fuera del repositorio y
el texto plano se elimina tras verificar el descifrado. La evidencia cifrada se conserva
hasta el **2026-12-04**; esa fecha se revisará su necesidad y se solicitará autorización
antes de eliminarla. **No se elimina al integrar PR #10.** Durante esta tarea **no se
descifra, muestra, copia ni elimina** la evidencia; el descifrado de verificación inicial ya
se realizó una vez y no se repetirá. Solo se publica el extracto redactado; no se incluyen
IPs, secretos, claves, cookies, bases ni datos reales.

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
| --- | --- |
| Exposición de secretos en Caddyfile/`sshd -T` | Filtros de redacción; no imprimir valores de `tls`, tokens, `setenv` ni claves |
| Cambio accidental o efecto incidental | Lista de solo lectura; `sudo -n` solo para lectura; sin reload/restart/UFW; declarados `podman-pause`, atime y logs/fail2ban por probes |
| Caída de SSH/UFW | No se tocan SSH/UFW; consola del proveedor solo con autorización separada |
| `fail2ban-client` muestra IPs | Filtrar a conteos; no imprimir lista de baneos |
| DNS/HTTPS interpretado como ataque | Consultas mínimas, sin AXFR/enumeración/escaneo |
| Backups con contenido | Solo metadatos; prohibido abrir/descifrar/restaurar |
| Caddy 2.6.2 antiguo | Documentar; no actualizar; evaluar en una fase separada |
| Falsos negativos por permisos | Registrar `BLOQUEADO/NO VERIFICADO`; no interpretar salida vacía |

## 6. Autorización solicitada para Nivel 2

Se solicita autorización separada para:

1. Ventana UTC y host/IP; misma sesión `mi-vps` como `mfadmin`.
2. `sudo -n` para UFW/nftables, `sshd -T`, `fail2ban-client status` y metadatos de backups si
   la ruta es 0700; o aceptación de auditoría parcial sin elevación.
3. Lectura redactada del `Caddyfile` y, opcionalmente, certificados `.crt` internos.
4. Consultas DNS/TLS/HTTP y conexiones TCP dirigidas solo a 22/80/443/2019/3001/18082 desde
   la estación.
5. Rutas de backup y evidencia del destino externo.
6. Confirmación de que no se lee contenido de bases/backups, no se accede a
   `myfinanzas-app`, no se hacen cambios, instalaciones, reinicios, merges ni despliegues.

No se ejecutará Nivel 2 hasta recibir esa autorización.

## 7. Bloqueos y decisiones pendientes

- **B1:** `sudo -n` para UFW/nftables, SSH y fail2ban; sin él, esas áreas quedan bloqueadas.
- **B2:** rutas de backup y estado del destino externo; el usuario debe aportarlos.
- **B3:** Caddy 2.6.2: decidir si se evalúa una actualización antes de TEST, en fase separada.
- **B4:** PR #9/spec host sigue DRAFT; no es contrato aprobado.
- **B5:** `mftest`, rutas `/srv/myfinanzas-test`, unidad/puerto 18082 y seed no existen o no
  están verificados; la provisión es otra fase.
- **B6:** la prueba de restauración real requiere el artefacto de backup/restore de la app y
  una autorización independiente.
