# INFRA-AUDIT-VPS-001 · Nivel 2 — Informe de resultados

Status: **Nivel 2 (2C) ejecutado parcialmente; sin cambios intencionados. Bloqueos de `sudo` documentados.**
Fecha de ejecución: 2026-11-05.
Autorización: mensaje explícito del usuario del 2026-11-05, modo 2C, una sesión.
Base: [Informe Nivel 1](2026-11-04-infra-audit-vps-001-nivel1.md), [Plan Nivel 2](2026-11-04-infra-audit-vps-001-nivel2-plan.md), PR #10 mergeada.
Contrato host: `specs/02-infra-test-01-host-specification.md`, PR #9, **DRAFT**; no aprobado.
Contrato de aplicación: SPEC34/PR #207, `myfinanzas-app`; no se modifica.

## 1. Sesión y evidencia

- **Intento previo:** `07:19:48 UTC`, falló antes de conectar porque `-F /dev/null` impedía resolver el alias `mi-vps`. No hubo acceso al VPS.
- **Sesión efectiva:** inicio `2026-11-05T07:20:22Z`, fin `2026-11-05T07:20:24Z`.
- **Comprobaciones externas:** `2026-11-05T07:21:14Z`–`2026-11-05T07:21:31Z`.
- **Evidencia:** cifrada en una ruta local fuera del repositorio; SHA-256 `afe4c0517774a49b1ada8c998c9ac275296f02d9894045a1eca98749251afa37`; texto plano eliminado; clave en macOS Keychain; retención hasta 2026-12-04.

## 2. Resultado ejecutivo

| Área | Resultado |
| --- | --- |
| UFW/nftables | **BLOQUEADO**: `sudo -n` pidió contraseña; reglas no verificadas. |
| SSH efectivo | **BLOQUEADO**: `sshd -T` no ejecutado; configuración base y drop-in requieren revisión. |
| fail2ban | **BLOQUEADO**: servicio activo; `fail2ban-client` no ejecutado. |
| Backups | **BLOQUEADO/PARCIAL**: directorio existe 0700; sin ficheros visibles en profundidad 2; metadatos con `sudo` bloqueados. |
| Caddy | Activo 2.6.2; sitio raíz; TLS válido; cabeceras de seguridad no observadas. |
| DNS | Apex con A; `test` NXDOMAIN; sin CAA. |
| TCP externo | 22/80/443 abiertos; 2019/3001/18082 cerrados/filtrados. |
| Podman/rootless | Rootless confirmado; sin contenedores; sin imágenes MyFinanzas. |
| Quadlet | **NO VERIFICADO** en Nivel 2; Nivel 1 no observó unidades propias. |
| Rutas TEST | `mftest`, `/srv/myfinanzas-test` y `/var/www/myfinanzas-test` no existen. |

## 3. UFW, nftables, SSH y fail2ban

- `sudo -n ufw status verbose`, `sudo -n nft list ruleset`, `sudo -n sshd -T`,
  `sudo -n fail2ban-client status` y `status sshd` **pidieron contraseña**. No se solicitó,
  no se modificó sudoers y no se reintentó.
- `ufw.service`: `active (exited)`, `enabled`; `ufw` no está en el PATH de `mfadmin`.
  Reglas y política por defecto **no verificadas**.
- `netavark-firewalld-reload.service`: activo.
- SSH: servicio activo; `/etc/ssh/sshd_config` legible. La configuración base muestra
  `PermitRootLogin yes`, `X11Forwarding yes`, `ChallengeResponseAuthentication no`,
  `UsePAM yes`, `Include /etc/ssh/sshd_config.d/*.conf` y `AcceptEnv` redactado.
  Existe `/etc/ssh/sshd_config.d/00-myfinanzas-hardening.conf` (102 bytes), pero **no se
  leyó**; la política efectiva no está verificada. No se puede afirmar que root login esté
  permitido o bloqueado.
- fail2ban: servicio `active`, `enabled`; jails y conteos **no verificados**.
- `ss` remoto: 2019 en loopback; 80/443 en todas las interfaces. La línea de SSH quedó
  afectada por el redactor local; la comprobación TCP externa confirma 22 abierto.

## 4. Caddy, TLS y HTTP

- Caddy **2.6.2**, servicio activo, `NRestarts=0`.
- `Caddyfile` de 68 bytes: se identificó el sitio `myfinanzas.pp.ua` y la directiva `root`;
  no se observó `reverse_proxy`. No se leyó el contenido completo; `Caddyfile.bak` no se tocó.
- TLS de `myfinanzas.pp.ua`: válido, Let's Encrypt, CN/SAN `myfinanzas.pp.ua`, vigencia
  2026-10-21 a 2027-01-19.
- HTTP `https://myfinanzas.pp.ua/` (`HEAD` a `/`, sin cuerpo): `200`, `server: Caddy`,
  `text/html`. **No se observaron**
  HSTS, CSP, `X-Content-Type-Options` ni `Referrer-Policy`.
- `test.myfinanzas.pp.ua`: NXDOMAIN; sin TLS; ausencia esperada, no fallo.
- Caddy 2.6.2 es una versión antigua; no se consultaron CVEs ni se actualizó nada.

## 5. DNS

- `myfinanzas.pp.ua`: A presente, TTL 14400; sin AAAA, CNAME ni CAA; NS en `uadns.com`;
  SOA coherente.
- `test.myfinanzas.pp.ua`: **NXDOMAIN** en los resolvers públicos de Cloudflare y Google;
  esperado.
- `pp.ua`: NS y SOA presentes; sin CAA.
- No se hizo AXFR, `ANY` ni enumeración.

## 6. Exposición TCP externa

| Puerto | Resultado |
| --- | --- |
| 22 | abierto |
| 80 | abierto |
| 443 | abierto |
| 2019 | cerrado/filtrado |
| 3001 | cerrado/filtrado |
| 18082 | cerrado/filtrado |

No se amplió el escaneo. La UFW/nftables real sigue **BLOQUEADA**; la exposición observada
es coherente con lo esperado, pero no acredita las reglas internas.

## 7. Podman rootless, Quadlet y persistencia

- Podman **5.4.2**.
- **Rootless confirmado**: `podman info` devuelve `true`; cgroup manager `systemd`; ID
  mappings `1001→0` y `165536→1`; `/etc/subuid` y `/etc/subgid` de `mfadmin` con rango
  65536; `newuidmap`, `newgidmap`, `fuse-overlayfs`, `slirp4netns`, `pasta` y `crun`
  presentes; cgroup v2 con controladores.
- `systemctl --user show -p Delegate` no devolvió valor; delegación no confirmada.
- Store de 71 MB; imágenes `nginx` y `hello-world`; **sin contenedores, volúmenes ni pods**.
- **Quadlet:** el bloque específico no se reejecutó en Nivel 2; Nivel 1 no observó unidades
  propias. Queda **NO VERIFICADO** para Nivel 2.
- `mftest` no existe; `/srv/myfinanzas-test` y `/var/www/myfinanzas-test` no existen;
  no hay 18082/3001 ni contenedor `myfinanzas-test`. No se observan artefactos de un TEST
  previo; no se puede descartar por completo sin una búsqueda más amplia.

## 8. Backups

- `/home/mfadmin/myfinanzas/backups` existe, `0700 mfadmin:mfadmin`.
- No se observaron ficheros regulares en profundidad 2; el directorio parece vacío o solo
  con subdirectorios.
- `sudo -n stat/find/du` **BLOQUEADO** por contraseña; no se puede confirmar el inventario
  completo ni la retención.
- No se leyó contenido, no se descifró y no se restauró nada.

## 9. Capacidad

- RAM 3,8 GiB, disponibles 3,4 GiB; carga 0,00; 35 GB libres; 2,5 M inodos libres.
- Estimación de host **suficiente con límites** para TEST (1 GiB/1 CPU/128 pids, ≤5 GB),
  sin prueba de carga y sin verificar la delegación cgroup.

## 10. Bloqueos y riesgos

| Bloqueo / riesgo | Impacto | Estado |
| --- | --- | --- |
| `sudo -n` sin NOPASSWD | UFW/nftables, SSH efectivo, fail2ban y backups no verificados | **BLOQUEADO** |
| `PermitRootLogin yes` en config base | Riesgo si el drop-in no lo bloquea; efectivo no verificado | **BLOQUEADO/PARCIAL** |
| Caddy 2.6.2 | Versión antigua; CVEs/paquetes no evaluados | **NO VERIFICADO** |
| Sin HSTS/CSP/nosniff observados | Hardening del sitio actual incompleto | **OBSERVADO** |
| Sin CAA en apex/pp.ua | Menor control de emisión de certificados | **OBSERVADO** |
| Backups no verificados | Sin evidencia de retención/restauración | **BLOQUEADO** |
| Quadlet no revalidado | Persistencia no confirmada | **NO VERIFICADO** |
| `test` sin DNS | Esperado; sin despliegue | **OBSERVADO** |

## 11. Comprobación final acotada (no ejecutada)

Objetivo: cerrar solo SSH, firewall y versión/origen de Caddy, sin repetir Nivel 2.

### 11.1 Sin privilegios (agente, futura sesión autorizada)

```bash
caddy version
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' caddy
command -v caddy
readlink -f "$(command -v caddy)"
dpkg -S "$(command -v caddy)"
apt-cache policy caddy | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#g'
systemctl show -p ActiveState -p SubState -p NRestarts -p FragmentPath -p ExecMainStartTimestamp caddy.service
stat -c '%A %U:%G %n' /etc/ssh/sshd_config.d/00-myfinanzas-hardening.conf
if [ -r /etc/ssh/sshd_config.d/00-myfinanzas-hardening.conf ]; then
  grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|KbdInteractiveAuthentication|UsePAM|X11Forwarding|AllowUsers|AllowGroups|ListenAddress)' /etc/ssh/sshd_config.d/00-myfinanzas-hardening.conf | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g'
else
  echo "BLOQUEADO: drop-in no legible sin sudo"
fi
ss -ltn
```

`ss -ltn` es solo contexto de sockets; no acredita UFW/nftables. `ss -ltnp` y las consultas
de unidades ya se hicieron en Nivel 2 y no se repiten en esta comprobación acotada.

### 11.2 Manual, con `sudo` por el usuario

El usuario ejecuta estos comandos localmente; la salida no se publica sin redactar IPs,
usuarios y valores de `setenv`/`acceptenv`.

```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers|allowgroups|maxauthtries|allowtcpforwarding|permitopen|permitlisten|authenticationmethods|maxsessions|maxstartups|x11forwarding|acceptenv|setenv)' | sed -E 's#(/etc/ssh/ssh_host_[a-z0-9_]+_key)#<hostkey-path>#g; s/^(setenv|acceptenv|authorizedkeyscommand|authorizedkeyscommanduser) .*/\1 <redacted>/I; s/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g'
sudo ufw status verbose | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g'
sudo nft list ruleset | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g'
```

El agente **no ejecutará ninguno de estos tres comandos**: todos requieren elevación y el
usuario ha indicado que no se solicite contraseña. No se modifica `sshd_config`, UFW,
nftables, Caddy ni paquetes.

### 11.3 Criterios

- Caddy: confirmar versión, origen del paquete y binario; no actualizar.
- SSH: confirmar si el drop-in `00-myfinanzas-hardening.conf` anula `PermitRootLogin yes`.
- Firewall: confirmar política y reglas; si no se ejecuta, sigue **BLOQUEADO**.
- Cualquier cambio observado se documenta; no se corrige.

## 12. Coordinación con MyFinanzas: backups y restauración

Requisitos que deben acordarse antes del despliegue TEST (no modifican `myfinanzas-app`):

1. **CLI propuesta, pendiente de confirmar:** `backup-cli create` y `restore` según
   SPEC34/RUNBOOK; la release, el artefacto de seed y los argumentos definitivos de TEST
   aún no están implementados.
2. **Alcance:** DB+clave, manifiesto, `test-instance.json`, dataset `FT-1`; no incluir
   sesiones, TOTP ni datos reales.
3. **Destino externo:** ubicación, custodia, identidad `age`, responsable y autorización de
   restauración; el directorio local actual parece vacío.
4. **Programación y retención:** quién ejecuta, frecuencia, 7/4/3 o política TEST, RPO/RTO
   (24 h/2 h es objetivo de la app, no acreditado).
5. **Verificación:** restore a destino nuevo, health 200, 401, `FT-1`, revocación de
   sesiones/códigos y RTO observado.
6. **Ownership:** MyFinanzas posee CLI/formato/manifiesto; `vps-infra` posee host, rutas,
   permisos, transporte y ejecución autorizada.
7. **Evidencia:** checksums, rutas lógicas, fechas y resultado; sin contenido ni secretos.

Preguntas para MyFinanzas:

- ¿Comando y argumentos definitivos para TEST?
- ¿Tamaño esperado y ventana de copia?
- ¿Destino externo y custodia de la identidad `age`?
- ¿Retención/RPO/RTO para TEST y criterio de restauración?
- ¿Quién ejecuta y revisa el restore?

No se ha contactado al equipo ni modificado `myfinanzas-app`; el `HEAD` a la raíz pública
de `myfinanzas.pp.ua` no accedió a rutas de aplicación y no se observó proxy ni contenedor
de la app. Esta sección es una propuesta de coordinación.

## 13. Conclusión

Nivel 2 aporta información suficiente para preparar TEST en capacidad, DNS, TLS del dominio
actual, exposición externa y Podman rootless. No cierra UFW/nftables, SSH efectivo, fail2ban
ni backups por falta de `sudo -n`; esos bloqueos deben resolverse con la comprobación final
acotada o con ejecución manual del usuario. No se han hecho cambios intencionados en el
servidor; los efectos incidentales declarados (atime, posible `podman-pause-*`, logs y
fail2ban por probes) no alteran configuración ni datos. No se ha desplegado nada.
