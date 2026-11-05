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

Pendiente de confirmar **antes** de la ventana: contenido completo del `Caddyfile`, ruta real
del `root`, módulos en uso, estado de `caddy-api.service`, presencia de
`unattended-upgrades` y espacio libre. Se obtiene en el baseline (§6.1).

## 3. Opciones evaluadas y decisión

| Opción | Versión | Origen | ¿Corrige CVE-2026-77281? | Valoración |
| --- | --- | --- | --- | --- |
| Debian stable/security | `2.6.2-12+deb13u1` | trixie | **No** (vulnerable, no-DSA) | No cumple el objetivo |
| Debian backports | `2.11.2-1~bpo13+1` | trixie-backports | **No** (corregido en 2.11.4) | No cumple el objetivo |
| Debian testing/unstable | `2.11.4-1` | forky/sid | Sí | **Descartado**: prohíbe mezclar repositorios |
| Caddy oficial | **2.11.9** | Cloudsmith stable (Caddy) | **Sí** | **Recomendado** |
| Binario estático 2.11.9 | 2.11.9 | Descarga oficial | Sí | Alternativa; peor mantenimiento que el paquete |

**Decisión propuesta: paquete oficial `caddy 2.11.9` (amd64) desde el repositorio estable de
Caddy en Cloudsmith.** No se añaden repositorios testing/unstable ni se cambia la base Debian.

Justificación del cambio de origen: Debian 13 no ofrece versión corregida y backports
(`2.11.2`) tampoco. El repositorio oficial es el método documentado por el proyecto, con la
misma estructura de paquete, `Caddyfile` como `conffile`, usuario `caddy`, datos en
`/var/lib/caddy` y unidad `caddy.service`.

Justificación de **2.11.9** frente a 2.11.7/2.11.8: los avisos publicados el 2026-11-04
(GHSA-jf74-f69g-hcj9, GHSA-r766-rf9f-588h, GHSA-25cw-38mq-q7m6, GHSA-69hv-5jfc-mvmv,
GHSA-f278-mgc7-46j3) afectan a **≤ 2.11.7** y se corrigen en **2.11.8**; 2.11.9 (publicado
2026-11-05T01:30Z) corrige además una regresión de 2.11.8 y varios problemas de seguridad,
principalmente en FastCGI. **2.11.7 queda descartado por vulnerable.**

Paquete de referencia verificado por el agente (descarga HTTPS pública, sin instalar):

- URL: `https://dl.cloudsmith.io/public/caddy/stable/deb/any-distro/pool/any-version/main/c/ca/caddy_2.11.9/caddy_2.11.9_linux_amd64.deb`
- Tamaño: **18.049.414 bytes**
- SHA-256: **`bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb`**
- Clave de firma del repo: `Caddy Web Server <contact@caddyserver.com>`,
  fingerprint primaria `6576 0C51 EDEA 2017 CEA2 CA15 155B 6D79 CA56 EA34`.

El checksum se **recalcula en el VPS** antes de instalar; no se confía en el valor copiado de
este documento. Si no coincide, se aborta.

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

Comparación de los `.deb` (Debian `2.6.2-12+deb13u1` y oficial `2.11.9`), sin instalarlos:

| Aspecto | Debian 2.6.2 | Oficial 2.11.9 | Efecto |
| --- | --- | --- | --- |
| Binario | `/usr/bin/caddy`, dinámico | `/usr/bin/caddy`, estático | Sin dependencias de runtime |
| Config | `/etc/caddy/Caddyfile` (`conffile`) | Igual (`conffile`) | Se conserva con `--force-confold` |
| Usuario/grupo | `caddy`/`caddy`, home `/var/lib/caddy` | Igual, y añade `caddy` a `www-data` si existe | Sin cambio de propietario |
| Datos/certificados | `/var/lib/caddy` | Igual | Se copian y conservan |
| Unidad | `/usr/lib/systemd/system/caddy.service` | `/lib/systemd/system/caddy.service` (mismo fichero en usr-merge) | Se reemplaza la unidad |
| Capacidades | `AmbientCapabilities=CAP_NET_BIND_SERVICE` | `CAP_NET_ADMIN CAP_NET_BIND_SERVICE` | Delta a aceptar y registrar |
| Límites | `LimitNPROC=512`, `LimitNOFILE=1048576` | `LimitNOFILE=1048576` | Se pierde `LimitNPROC` |
| `caddy-api.service` | Presente, no usado | Presente, no usado | Se mantiene deshabilitado |
| `postrm purge` | Borra `/var/lib/caddy`, `/var/log/caddy`, `/etc/caddy` | Añade `userdel -r caddy` | **Prohibido `apt purge caddy`**: destruye datos, configuración y usuario |

Notas de compatibilidad:

- Las directivas observadas (dirección de sitio + `root`) son válidas en 2.11.x. Los cambios
  incompatibles de 2.11.8/2.11.9 afectan a `client_auth` conflictivo y FastCGI/PHP, no
  observados.
- Los módulos compilados pueden diferir. Se comparan con `caddy list-modules` antes y después;
  si falta un módulo en uso, la validación falla y se revierte.
- El almacenamiento de certificados es compatible; no se fuerza reemisión ni se cambia DNS.
- El `postinst` oficial **arranca o reinicia** el servicio (`deb-systemd-helper was-enabled` →
  `start`; en actualización, `try-restart`). Además ejecuta `deb-systemd-helper unmask`, que
  **deshace un `systemctl mask` administrativo**. Por eso el control fiable no es `mask`, sino
  **desempaquetar sin configurar** (§6.5) y validar antes de que el `postinst` arranque nada.

## 5. Precondiciones

1. Autorización específica de ventana, de las operaciones con `sudo` y de la instalación.
2. `Caddyfile` completo revisado y sin directivas que requieran un módulo ausente.
3. Copia del paquete antiguo descargada y verificada; sin ella **no se instala**.
4. Espacio libre ≥ 200 MB en `/root` y `/`.
5. Ventana de baja actividad: el sitio puede interrumpirse unos segundos.
6. Confirmación de que no hay `unattended-upgrades` activo que pueda interferir.
7. Decisión sobre las capacidades de la unidad oficial (§10).

## 6. Procedimiento

> Lo ejecuta el usuario, con `sudo`, en la ventana autorizada. `<TS>` = marca UTC.
> No se ejecuta nada de esto en esta fase.

### 6.1 Baseline (solo lectura)

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
sudo install -d -m 0700 "/root/caddy-upgrade-$TS"
{
  date -u
  dpkg-query -W -f='${Package} ${Version} ${Architecture} ${Status}\n' caddy
  /usr/bin/caddy version
  sha256sum /etc/caddy/Caddyfile
  systemctl is-enabled caddy caddy-api 2>&1
  systemctl show caddy -p ActiveState -p SubState -p NRestarts -p FragmentPath -p User -p Group
  ss -ltnp | grep -E ':(80|443|2019)\b'
  df -h / /root
} | sudo tee "/root/caddy-upgrade-$TS/baseline.txt"
```

Además, guardar sin publicar contenido sensible:

```bash
sudo cp -a /etc/caddy/Caddyfile "/root/caddy-upgrade-$TS/Caddyfile.before"
sudo sha256sum /usr/bin/caddy | sudo tee "/root/caddy-upgrade-$TS/caddy-binary.sha256"
/usr/bin/caddy list-modules | sort | sudo tee "/root/caddy-upgrade-$TS/modules.before"
curl -fsS https://myfinanzas.pp.ua/ | sha256sum | sudo tee "/root/caddy-upgrade-$TS/body.before"
curl -sS -o /dev/null -w '%{http_code}\n' https://myfinanzas.pp.ua/ | sudo tee "/root/caddy-upgrade-$TS/http.before"
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256 \
  | sudo tee "/root/caddy-upgrade-$TS/cert.before"
```

Comprobar que `body.before` y `http.before` son estables (repetir una vez). Si el baseline no es
estable, no se inicia la ventana.

### 6.2 Copias de seguridad

```bash
sudo cp -a /etc/caddy "/root/caddy-upgrade-$TS/etc-caddy"
sudo cp -a /var/lib/caddy "/root/caddy-upgrade-$TS/var-lib-caddy"
sudo cp -a /lib/systemd/system/caddy.service "/root/caddy-upgrade-$TS/caddy.service.before"
sudo cp -a /etc/apt/sources.list.d "/root/caddy-upgrade-$TS/sources.list.d.before"
sudo cp -a /etc/apt/preferences.d "/root/caddy-upgrade-$TS/preferences.d.before" 2>/dev/null || true
sudo chmod -R go-rwx "/root/caddy-upgrade-$TS"
```

`/var/lib/caddy` contiene **claves privadas** de los certificados y estado de la instancia:
se trata como **secreto**. No se copia al repositorio, no se imprime, no se comparte y no sale
del VPS salvo decisión expresa. Retención: hasta 30 días después de la validación correcta;
después se elimina con confirmación del usuario.

### 6.3 Descargar y verificar el paquete antiguo (rollback)

```bash
sudo sh -c "cd '/root/caddy-upgrade-$TS' && apt-get download caddy=2.6.2-12+deb13u1"
sudo sh -c "cd '/root/caddy-upgrade-$TS' && sha256sum caddy_2.6.2-12+deb13u1_amd64.deb | tee old-caddy.sha256"
```

Valor de referencia verificado por el agente para ese `.deb` (Debian security pool):
tamaño **10.110.872 bytes**, SHA-256
**`f173515859f273c97219cc242d625a64650fefdd136a9570acb1b5f7581c9786`**.
Si `apt-get download` falla, alternativa pública equivalente:

```bash
sudo sh -c "cd '/root/caddy-upgrade-$TS' && curl -fsSLO https://security.debian.org/debian-security/pool/updates/main/c/caddy/caddy_2.6.2-12+deb13u1_amd64.deb"
```

Sin paquete antiguo verificado **no se continúa**: no hay rollback de binario.

### 6.4 Repositorio oficial (solo si se aprueba mantenerlo)

```bash
sudo apt-get install --yes ca-certificates curl gpg   # solo si faltan; comprobar con command -v
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo gpg --show-keys --with-fingerprint /usr/share/keyrings/caddy-stable-archive-keyring.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo chmod 0644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
apt-cache policy caddy
```

- Se añade **solo** la línea `deb`, no `deb-src` (menos superficie y descarga; desviación
  justificada del fichero publicado).
- El fingerprint debe coincidir con `6576 0C51 EDEA 2017 CEA2 CA15 155B 6D79 CA56 EA34`. Si no
  coincide, **abortar** y no instalar.
- El candidato debe ser `2.11.9` y la fuente `dl.cloudsmith.io`. Si el candidato es otro, se
  detiene la ventana y se revisa; no se instala una versión no evaluada.

Alternativa sin repo permanente: descargar el `.deb` 2.11.9 por HTTPS, verificar el SHA-256 y
omitir 6.4 y el `apt-mark hold`; el resto del procedimiento no cambia.

### 6.5 Descargar, desempaquetar y validar **sin arrancar** el servicio

```bash
sudo sh -c "cd '/root/caddy-upgrade-$TS' && apt-get download caddy=2.11.9"
sudo sh -c "cd '/root/caddy-upgrade-$TS' && sha256sum caddy_2.11.9_linux_amd64.deb | tee new-caddy.sha256"
```

Debe coincidir con `bbea4aeaadc86b233c168cc33bad9daa1cbce756dc08949b783b45398f8e65cb`.
Si no coincide, **abortar** (no se ha modificado nada todavía).

```bash
sudo dpkg --force-confold --unpack "/root/caddy-upgrade-$TS/caddy_2.11.9_linux_amd64.deb"
/usr/bin/caddy version
sha256sum /etc/caddy/Caddyfile
sudo -u caddy env HOME=/var/lib/caddy /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

- `--unpack` no ejecuta el `postinst`: **Caddy sigue corriendo con el binario antiguo**.
- La versión del binario en disco debe ser 2.11.9; el `Caddyfile` no debe cambiar.
- `validate` se ejecuta como `caddy` para detectar problemas de permisos. Debe terminar con
  `Valid configuration`.
- Comparar módulos: `/usr/bin/caddy list-modules | sort > .../modules.after` y `diff` con
  `modules.before`. Si falta un módulo en uso, **revertir** (§7.1).

Si la validación falla: revertir el binario (§7.1). El servicio no se ha detenido.

### 6.6 Configurar el paquete (arranque controlado)

```bash
sudo systemctl stop caddy
sudo systemctl reset-failed caddy
sudo dpkg --configure caddy
sudo systemctl daemon-reload
sudo systemctl show caddy -p ActiveState -p SubState -p NRestarts -p FragmentPath
sudo systemctl is-enabled caddy caddy-api
```

El `postinst` arranca `caddy.service` con el binario nuevo. Comprobar que queda `active
(running)` y que `caddy-api.service` sigue `disabled`/`inactive`.

Si no arranca: no insistir con reinicios repetidos (activa el *start limit*); recoger
`journalctl -u caddy -n 100 --no-pager` y revertir (§7).

### 6.7 Validación posterior

```bash
/usr/bin/caddy version
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' caddy
apt-cache policy caddy
systemctl is-active caddy
journalctl -u caddy -p warning --since '-15 min' --no-pager | tail -50
sudo ss -ltnp | grep -E ':(80|443|2019)\b'
curl -sS -o /dev/null -w 'https %{http_code} verify=%{ssl_verify_result}\n' https://myfinanzas.pp.ua/
curl -sS -o /dev/null -w 'http  %{http_code} -> %{redirect_url}\n' http://myfinanzas.pp.ua/
curl -fsS https://myfinanzas.pp.ua/ | sha256sum
echo | openssl s_client -connect myfinanzas.pp.ua:443 -servername myfinanzas.pp.ua 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256
sudo systemctl restart caddy
sudo systemctl is-active caddy
```

Criterios: `caddy version` = 2.11.9; HTTPS 200 con verificación 0; HTTP 308 hacia HTTPS;
`body` idéntico al baseline; certificado con el **mismo fingerprint**, SAN y fechas (sin
reemisión); solo 80/443 escuchando en público (sin 2019/3001/18082); reinicio limpio sin
errores y `NRestarts` coherente.

No se prueban puertos de la aplicación (`test.myfinanzas.pp.ua` sigue en NXDOMAIN) ni se
cambian DNS, UFW o SSH.

### 6.8 Fijar la versión

```bash
sudo apt-mark hold caddy
apt-mark showhold | grep '^caddy$'
```

Con el repo añadido, `hold` evita actualizaciones no revisadas. Revisión mensual del repo
oficial y del Debian Security Tracker; para actualizar se repite esta spec con ventana, QA y
`unhold` nuevos. Si se eligió la alternativa sin repo (§6.4), este paso es innecesario.

## 7. Rollback

### 7.1 Revertir solo el binario (validación fallida, servicio aún en marcha)

```bash
sudo dpkg --force-confold -i "/root/caddy-upgrade-$TS/caddy_2.6.2-12+deb13u1_amd64.deb"
sudo systemctl daemon-reload
/usr/bin/caddy version
systemctl is-active caddy
```

El servicio no llegó a detenerse; el `postinst` antiguo hará `try-restart` y dejará el binario
2.6.2 activo. Verificar sitio y certificado.

### 7.2 Revertir tras un arranque fallido

```bash
sudo systemctl stop caddy
sudo systemctl reset-failed caddy
sudo apt-mark unhold caddy 2>/dev/null || true
sudo dpkg --force-confold -i "/root/caddy-upgrade-$TS/caddy_2.6.2-12+deb13u1_amd64.deb"
sudo systemctl daemon-reload
sudo systemctl start caddy
/usr/bin/caddy version
systemctl is-active caddy
curl -sS -o /dev/null -w '%{http_code}\n' https://myfinanzas.pp.ua/
```

Neutralizar el repo para que un `apt upgrade` posterior no reintroduzca 2.11.9:

```bash
sudo mv /etc/apt/sources.list.d/caddy-stable.list "/root/caddy-upgrade-$TS/caddy-stable.list.disabled"
sudo apt-get update
sudo apt-mark hold caddy
```

### 7.3 Revertir configuración o datos

Solo si el fallo es de configuración o estado. **No borrar** nada: mover a un directorio de
fallo y restaurar la copia.

```bash
sudo systemctl stop caddy
sudo mv /etc/caddy "/root/caddy-upgrade-$TS/etc-caddy.failed"
sudo cp -a "/root/caddy-upgrade-$TS/etc-caddy" /etc/caddy
sudo mv /var/lib/caddy "/root/caddy-upgrade-$TS/var-lib-caddy.failed"
sudo cp -a "/root/caddy-upgrade-$TS/var-lib-caddy" /var/lib/caddy
sudo systemctl daemon-reload
sudo systemctl start caddy
```

`cp -a` conserva propietario y permisos (`caddy:caddy`). Verificar TLS y contenido.

### 7.4 Instalación parcial

Si el sistema queda en estado `iU`/`iF` (interrupción entre desempaquetar y configurar):

```bash
dpkg -l caddy
sudo dpkg --force-confold -i "/root/caddy-upgrade-$TS/caddy_2.6.2-12+deb13u1_amd64.deb"
sudo systemctl daemon-reload
```

Nunca dejar el paquete en estado `iF`. Si el rollback no funciona, detenerse, no purgar, no
borrar datos y solicitar decisión.

## 8. Criterios de aceptación

Todos **UNRUN** hasta la ventana autorizada.

| ID | Comprobación | Esperado | Estado |
| --- | --- | --- | --- |
| AC-01 | Baseline estable y guardado | HTTP/body/cert/módulos coherentes | UNRUN |
| AC-02 | Backups de `/etc/caddy`, `/var/lib/caddy`, unidad y fuentes | `0700`, verificables; secretos no expuestos | UNRUN |
| AC-03 | Paquete antiguo descargado y verificado | SHA-256 `f1735158…` | UNRUN |
| AC-04 | Repo oficial y clave verificados (si aplica) | Fingerprint `6576 0C51 … EA34`; candidato 2.11.9 | UNRUN |
| AC-05 | `.deb` 2.11.9 verificado | SHA-256 `bbea4aea…`, 18.049.414 B | UNRUN |
| AC-06 | `dpkg --unpack` sin arranque | Servicio sigue con binario antiguo y activo | UNRUN |
| AC-07 | `caddy validate` como `caddy` | Config válida; Caddyfile sin cambios | UNRUN |
| AC-08 | Módulos compatibles | Sin módulos en uso ausentes | UNRUN |
| AC-09 | Configurar y arrancar | `caddy version` 2.11.9; `active (running)` | UNRUN |
| AC-10 | HTTPS y certificado | 200; verify=0; mismo fingerprint/SAN/fechas | UNRUN |
| AC-11 | HTTP y contenido | 308 a HTTPS; hash del cuerpo idéntico | UNRUN |
| AC-12 | Puertos y servicios | Solo 80/443 públicos; UFW/SSH/DNS intactos | UNRUN |
| AC-13 | Reinicio limpio | `systemctl restart` correcto, sin errores | UNRUN |
| AC-14 | Versión fijada | `apt-mark hold caddy` (si hay repo) | UNRUN |
| AC-15 | Rollback ensayado | Ver §10: en VM desechable o `UNRUN` declarado | UNRUN |

Los AC de ejecución remota no pueden declararse PASS sin salida real de la ventana.

## 9. Riesgos y mitigaciones

| Riesgo | Nivel | Mitigación |
| --- | --- | --- |
| 2.11.9 es muy reciente (publicado horas antes) | Medio | Es un seguimiento pequeño de 2.11.8; validar y tener rollback listo; opción de posponer la ventana |
| `postinst` arranca el servicio y deshace `mask` | Alto | `dpkg --unpack` + validar antes de `--configure`; no usar `mask` como control |
| Caddyfile incompatible o módulo ausente | Medio | `validate` y `diff` de módulos antes de configurar; rollback de binario sin caída |
| Pérdida de certificados/claves | Alto | Copia `0700` de `/var/lib/caddy`; prohibido `purge`; no tocar DNS |
| Reemplazo del `Caddyfile` | Medio | `--force-confold` y hash antes/después |
| Rollback imposible | Alto | `.deb` antiguo verificado antes de empezar; si falta, no se instala |
| Reintroducción por `apt upgrade` | Medio | `apt-mark hold`; repo desactivado en rollback |
| Capacidades distintas en la unidad oficial | Bajo | Registrar el delta; decisión en §10; verificar arranque |
| `purge` o `autoremove` accidental | Alto | Prohibido en la ventana; `postrm purge` de ambos paquetes borra `/etc/caddy`, `/var/lib/caddy`, `/var/log/caddy` y el paquete oficial además ejecuta `userdel -r caddy` |
| Interrupción breve del sitio | Bajo | Ventana de baja actividad; parada < 10 s |

## 10. Decisiones pendientes

1. **Versión:** aprobar 2.11.9 o posponer la ventana unos días por su novedad.
2. **Origen:** mantener el repositorio oficial Cloudsmith o instalar solo el `.deb` verificado
   sin repo permanente.
3. **Capacidades:** aceptar `CAP_NET_ADMIN` de la unidad oficial o añadir un *drop-in* que
   conserve `CAP_NET_BIND_SERVICE` (requiere probar que Caddy arranca).
4. **Rollback:** ¿se ensaya en una VM Debian 13 desechable antes de la ventana? Si no, AC-15
   queda **UNRUN** y se acepta el riesgo.
5. **Ventana y `sudo`:** fecha, duración y quién ejecuta cada bloque.
6. **Retención** de la copia con claves privadas y fecha de borrado.
7. Confirmar que el `Caddyfile` completo no requiere cambios y que no hay `hide`/`rewrite`/
   `{http.request.body}` (mitiga también CVE-2026-77281 residual).

## 11. Evidencia a conservar

- `baseline.txt`, hashes de Caddyfile y binario, `modules.before/after`, `body.before`, `http.before`.
- `cert.before` y `cert.after` (público, sin claves).
- Versiones y estado de `dpkg`/`systemd` antes y después.
- Salida de `validate`, `journalctl` y pruebas HTTP.
- Confirmación de rollback disponible (hash del `.deb` antiguo).

No se publican claves, contenido de `/var/lib/caddy`, IPs ni el `Caddyfile` completo.

## 12. Fuera de alcance

- Ejecutar cualquier comando de esta spec ahora.
- Acceder al VPS, instalar, parar o reiniciar servicios.
- Cambiar DNS, UFW, SSH, Podman, Quadlet o `myfinanzas-app`.
- Añadir cabeceras de seguridad o hardening HTTP (entrega separada).
- Desplegar MyFinanzas TEST.
