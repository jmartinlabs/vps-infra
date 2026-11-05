# INFRA-AUDIT-VPS-001 · Nivel 1 — Informe preliminar

Status: **Nivel 1 ejecutado; Nivel 2 no autorizado.** Sin cambios, sin `sudo`, sin despliegue.
Fecha de ejecución: 2026-11-04, ~20:16 UTC.
Autorización: mensaje explícito del usuario del 2026-11-04 para `ssh mi-vps` como `mfadmin`,
solo comandos revisados y sin `sudo`.
Candidato: no aplica; es una auditoría de host, sin artefacto de código ni PR/CI.
Evidencia: registro local cifrado, fuera del repositorio y no publicado. El texto plano se
eliminó tras verificar el descifrado. La clave se custodia en macOS Keychain.

## 1. Resumen ejecutivo

- Host Debian 13.7, kernel 6.12.113, 2 vCPU AMD EPYC, 3,8 GiB de RAM visibles, 512 MiB de
  swap, disco `sda` de 40 GB con raíz LVM/ext4 de 39 GB y 35 GB libres (7 % usado);
  2,5 M inodos libres (3 % usado).
- Sistema en reposo: carga 0,00, PSI 0, `MemAvailable` 3,4 GiB. **Estimación preliminar:
  capacidad de host suficiente para un TEST pequeño**, no una acreditación de que la
  aplicación quepa ni de que los límites propuestos sean aplicables.
- Servicios activos observados: Caddy, SSH, fail2ban, qemu-guest-agent,
  netavark-firewalld-reload, systemd y `user@1001`.
- Sockets en escucha: 22 (IPv4/IPv6), 80 y 443 en todas las interfaces; 2019 solo en
  loopback. **No se observan 3001 ni 18082.** La exposición desde Internet y las reglas de
  firewall **no están verificadas**.
- Podman 5.4.2 con store bajo `/home/mfadmin` (71 MB), 2 imágenes (`nginx`, `hello-world`),
  **sin contenedores, volúmenes ni pods observados**. No hay imagen MyFinanzas.
- **Rootless no confirmado**: `podman info` falló y no se verificaron `subuid`/`subgid`,
  user namespaces ni delegación cgroup.
- Caddy 2.6.2 activo; `Caddyfile` de 68 bytes y `Caddyfile.bak` de 769 bytes. **No se leyó
  el contenido**; dominios, rutas, TLS, cabeceras y certificados no están verificados.
- UFW: `ufw.service` cargada/activa (exited), pero `ufw` no está en el PATH de `mfadmin`.
  **Reglas y política no verificadas.**
- Sin reinicio pendiente observado. **Estado real de parches no verificado.**
- No se observan contenedores, pods ni imagen de MyFinanzas; no se verificaron rutas
  estáticas, unidades systemd ni la página de prueba. **Despliegue de MyFinanzas: no
  confirmado.**
- No se auditó `mftest`, DNS, TLS, backups, bases ni `myfinanzas-app` en este nivel.

## 2. Inventario observado

### 2.1 Sistema

| Dato | Observación | Clasificación |
| --- | --- | --- |
| SO | Debian GNU/Linux 13 (trixie), 13.7 | OBSERVADO |
| Kernel | 6.12.113+deb13-amd64 | OBSERVADO |
| Arquitectura | x86_64 | OBSERVADO |
| Virtualización | KVM / OpenStack Nova | OBSERVADO; proveedor no contrastado |
| Uptime | 2 semanas, 3 h; arranque indicado 2026-10-21 16:32 (zona del host) | OBSERVADO |
| Zona horaria | Europe/Rome (CET), NTP activo, reloj sincronizado | OBSERVADO |
| Reinicio pendiente | `/var/run/reboot-required` y `.pkgs` ausentes | OBSERVADO |
| Unidades fallidas | Ninguna en la consulta | OBSERVADO |
| Journal | 8 MB; `mfadmin` no está en `adm`/`systemd-journal` | OBSERVADO; acceso limitado |

### 2.2 Capacidad

| Recurso | Observado | Nota |
| --- | --- | --- |
| CPU | 2 vCPU AMD EPYC-Milan, 1 thread/core, 2 cores, 1 socket | OBSERVADO |
| RAM | 3,8 GiB total; 3,4 GiB disponibles; 404 MiB usados | OBSERVADO |
| Swap | 512 MiB visibles en `/proc/meminfo`/`free`, 0 usados | `swapon` no disponible en PATH; dispositivo, persistencia y posible zram no verificados |
| Disco | `sda` 40 GB; raíz LVM/ext4 39 GB, 2,4 GB usados, 35 GB libres (7 %) | OBSERVADO |
| Inodos raíz | 2.571.504 totales, 60.677 usados (3 %), 2.510.827 libres | OBSERVADO |
| `/boot` | 447 MB, 198 MB usados (48 %), 220 MB libres | OBSERVADO; riesgo para kernel/initramfs |
| Carga | 0,00 / 0,00 / 0,00; PSI cpu/mem/io a 0 | OBSERVADO |
| Store Podman | 71 MB en `~/.local/share/containers`; 8 KB en `~/.config/containers` | OBSERVADO |

### 2.3 Servicios y puertos

Servicios activos observados: `caddy`, `ssh`, `fail2ban`, `cron`, `dbus`,
`qemu-guest-agent`, `netavark-firewalld-reload`, `systemd-*`, `user@1001`. No se observa
`myfinanzas`, `podman.service` de sistema ni un contenedor de aplicación.

| Puerto | Observación | Clasificación |
| --- | --- | --- |
| 22/tcp | Escucha en `0.0.0.0` y `[::]` | OBSERVADO; exposición externa no prueba |
| 80/tcp | Escucha en `*` | OBSERVADO; atribución a Caddy inferida |
| 443/tcp | Escucha en `*`; también UDP `*:443` | OBSERVADO; HTTP/3 inferido |
| 2019/tcp | Solo `127.0.0.1` | OBSERVADO; admin de Caddy inferido |
| 3001/tcp | No observado | OBSERVADO |
| 18082/tcp | No observado | OBSERVADO |

`ss -ltnp` no mostró propietarios de procesos por falta de privilegios. **La exposición
desde Internet, UFW/nftables y el firewall del proveedor no están verificados.** No se
realizaron pruebas externas.

### 2.4 Usuario y rootless

- `mfadmin`: UID/GID 1001, home `/home/mfadmin`, shell `/bin/bash`, grupos `mfadmin`,
  `sudo`, `users`. Pertenecer a `sudo` es una frontera de privilegio; no se verificó si
  sudo pide contraseña.
- `Linger=yes`; `user@1001.service` activo; sesiones 2, 383, 384 y 385.
- Store Podman bajo `/home/mfadmin`, **compatible con rootless**, pero rootless,
  `subuid`/`subgid`, user namespaces y delegación cgroup **no confirmados**.
- `podman info --format` falló; causa no diagnosticada. `podman.socket` de usuario
  deshabilitado; `podman-user-wait-network-online.service` activo/exited.
- `mftest` no se auditó; no consta en la evidencia limitada.

### 2.5 Podman y Quadlet

- Podman 5.4.2.
- Imágenes: `docker.io/library/nginx:stable-alpine` (69,8 MB) y
  `docker.io/library/hello-world:latest` (25,5 kB). Sin imagen MyFinanzas.
- Contenedores: 0. Volúmenes: 0. Pods: ninguno observable. Red: `podman`/`bridge`.
- `podman system df`: 69,81 MB reclamables (100 % de imágenes), 0 contenedores/volúmenes.
- Quadlet: no constan unidades propias en la salida limitada; no se verificó
  `~/.config/containers/systemd` con contenido. `podman-pause-*` transitorio observado;
  no se actuó sobre él.
- `nginx:stable-alpine` es una etiqueta flotante y `hello-world` parece un resto de prueba;
  no se limpió nada.

### 2.6 Caddy y UFW

- Caddy 2.6.2, servicio activo, `NRestarts=0`, unit de sistema.
- `/etc/caddy`: `Caddyfile` 68 bytes y `Caddyfile.bak` 769 bytes, `root:root`, modo 0644;
  **contenido no leído**.
- `/var/lib/caddy`: `0700 caddy:caddy`; `/var/log/caddy`: `0755 caddy:caddy`.
- No se verificaron dominios, imports, rutas, certificados, cabeceras ni TLS. No se
  consultaron CVEs ni el origen del paquete Caddy 2.6.2.
- UFW: `ufw.service` cargado/activo (exited); `ufw` no disponible en PATH para `mfadmin`.
  Reglas y política por defecto **no verificadas**.
- `netavark-firewalld-reload` activo; no se inspeccionaron reglas nftables/firewalld.
- `fail2ban` activo; **jails y reglas no verificados**.

## 3. Diferencias frente a la documentación

| Documentado / informado | Observado en Nivel 1 | Clasificación |
| --- | --- | --- |
| Debian 13, 2 vCPU/4 GB/40 GB | Debian 13.7, 2 vCPU, 3,8 GiB visibles, disco `sda` 40 GB; raíz 39 GB | Parcialmente confirmado |
| `mfadmin`, SSH por claves | Usuario y servicio SSH activos; política de autenticación y claves no verificadas | Parcial |
| UFW | Unidad activa; reglas no verificables sin elevación | BLOQUEADO |
| Caddy + HTTPS | Caddy 2.6.2 activo; HTTPS/TLS/rutas no verificados | Parcial |
| Podman rootless + Quadlet | Podman 5.4.2 y store bajo home; rootless no confirmado; sin Quadlet propio observado | Parcial |
| Página estática de prueba | No verificada: no se leyó Caddyfile ni se hizo HTTP externo | NO VERIFICADO |
| MyFinanzas no desplegada | Sin contenedores, pods ni imagen MyFinanzas; rutas estáticas/unidades no auditadas | No confirmado |
| Backups / retención / restore | No auditados en Nivel 1 | FUERA DE ALCANCE |
| DNS / `test.myfinanzas.pp.ua` | No auditado; sin pruebas externas | FUERA DE ALCANCE |

## 4. Capacidad para MyFinanzas TEST

**Estimación preliminar de capacidad del host en reposo, solo para un TEST pequeño.** No es
un PASS de alojamiento, seguridad ni operación.

- `MemAvailable` 3,4 GiB y carga 0,00: hay margen para un límite propuesto de 1 GiB/1 CPU,
  pero **no se verificó** que ese límite sea el requisito real ni que cgroup v2/delegación
  permitan aplicarlo en rootless.
- 35 GB libres y 2,5 M inodos libres: el presupuesto propuesto de **≤ 5 GB de disco** para
  TEST cabe ampliamente.
- `/boot` al 48 %: vigilar antes de actualizaciones de kernel/initramfs.
- No se hizo prueba de carga, ni de contenedores, ni de la aplicación.

Veredicto provisional: **SUFICIENTE CON LÍMITES para capacidad de host**, condicionado a
verificar UFW/firewall, Caddy/TLS, rootless/Quadlet, límites reales y comportamiento bajo
carga. **No acredita** que MyFinanzas TEST funcione ni que sea seguro exponerlo.

## 5. Riesgos y limitaciones

| Riesgo / limitación | Impacto | Estado |
| --- | --- | --- |
| UFW no verificable sin sudo | No se puede afirmar la exposición prevista | **BLOQUEADO** |
| Caddyfile no leído | No se conocen dominios, rutas, imports, TLS ni cabeceras | **BLOQUEADO** |
| Caddy 2.6.2 | Versión observada; origen, CVEs y parches no verificados | **NO VERIFICADO** |
| `podman info` fallido | Rootless/cgroups no confirmados | **BLOQUEADO/PARCIAL** |
| `ss -ltnp` sin propietarios | Atribución de 80/443 a Caddy es inferencia | **PARCIAL** |
| `mfadmin` en `sudo` | Frontera de privilegio; no se verificó sudo sin contraseña | **OBSERVADO** |
| `/boot` al 48 % | Riesgo para actualizaciones de kernel/initramfs | **OBSERVADO** |
| Journal 8 MB y acceso limitado | Retención y diagnóstico limitados | **OBSERVADO** |
| fail2ban activo | Jails/reglas no verificadas | **PARCIAL** |
| Imágenes `nginx`/`hello-world` | Etiqueta flotante y restos de prueba; sin limpieza | **OBSERVADO** |
| `/var/log/caddy` 0755 | Lectura local de logs por otros usuarios | **OBSERVADO** |
| Zona horaria Europe/Rome | La app usa Europe/Madrid; mismo offset actual, distinta zona | **OBSERVADO** |
| Parches no verificados | `apt list` no acredita actualización real | **NO VERIFICADO** |
| Sin backups/DNS/TLS | No se puede evaluar recuperación ni publicación | **FUERA DE NIVEL 1** |

No se ha modificado nada. No se ha accedido a bases, secretos, credenciales, backups ni
`myfinanzas-app`. No se han hecho pruebas externas ni merges.

## 6. Alcance candidato para una eventual Nivel 2, no autorizada

1. UFW/nftables, política de firewall y exposición desde Internet.
2. Caddy: configuración real, imports, dominios, TLS, cabeceras y procedimiento de recarga.
3. SSH: política efectiva y accesos.
4. DNS público y TLS/HTTP de `myfinanzas.pp.ua` y `test.myfinanzas.pp.ua`.
5. Backups: metadatos locales y evidencia del destino externo.
6. `mftest`, rutas `/srv/myfinanzas-test`, unidad/puerto `18082` y colisiones.
7. Rootless/Quadlet con el UID correcto, cgroup v2 y tareas efímeras.
8. Evaluación de Caddy 2.6.2 y de los restos de imágenes.

Nada de esto se ejecutará sin autorización expresa.

## 7. Evidencia y comandos

Se ejecutó exactamente la lista aprobada de Nivel 1: identidad/SO/kernel, actualizaciones,
capacidad, almacenamiento de contenedores, usuario, servicios/puertos, Caddy, UFW, Podman
y Quadlet. `apt list --upgradable` formaba parte de la lista autorizada; devolvió
`Listing...` sin líneas de paquetes, lo que **no acredita** que el sistema esté parcheado.
No se ejecutaron comandos adicionales de diagnóstico.

El registro local contiene la salida completa; no se publica. Custodia aplicada:

- Cifrado: `AES-256-CBC` con `PBKDF2` (600.000 iteraciones).
- Clave: custodiada en macOS Keychain, fuera del repositorio.
- Fichero cifrado: ruta local fuera del repositorio; no se publica.
- SHA-256 del cifrado: `fae53483c13a9344e281c0033a079c2cb38803847b5952240b969de1212743b1`.
- SHA-256 del texto plano original: registrado en el metadato local junto al cifrado.
- Texto plano eliminado tras verificar que el descifrado coincide.
- Retención: conservar hasta el **2026-12-04**, para poder contrastarla durante el Nivel 2.
  Esa fecha se revisará si sigue siendo necesaria y se solicitará autorización antes de
  eliminarla. **No se elimina automáticamente al integrar PR #10.** No se publica en GitHub.
- Durante esta tarea **no se descifra, muestra, copia ni elimina** la evidencia. El
  descifrado de verificación inicial ya se realizó una vez; no se repetirá.

Este informe omite IP, hostname completo, machine ID, boot ID y cualquier secreto. No
actualiza `docs/estado-actual.md`; es un resultado parcial de Nivel 1. La revisión
independiente `qa-review` se ha realizado sobre la versión final de este informe y su
veredicto fue **APTO PARA PRESENTAR**.

## 8. Plan de Nivel 2

El alcance candidato para una eventual Nivel 2, con comandos, permisos y riesgos, está en
[2026-11-04 · Plan de Nivel 2](2026-11-04-infra-audit-vps-001-nivel2-plan.md). Ese documento
**no autoriza** acceso ni ejecución; requiere aprobación separada.
