# INFRA-AUDIT-VPS-001 · Cierre de auditoría y evaluación de Caddy

Status: **Cierre documental de SSH, firewall y paquete Caddy; auditoría no ampliada.**
Fecha: 2026-11-05.
Informes base: [Nivel 1](2026-11-04-infra-audit-vps-001-nivel1.md), [Nivel 2](2026-11-05-infra-audit-vps-001-nivel2-result.md), [Plan Nivel 2](2026-11-04-infra-audit-vps-001-nivel2-plan.md).
Contrato host: `specs/02-infra-test-01-host-specification.md`, **solo en PR #9, DRAFT**.
Contrato de aplicación: SPEC34/PR #207, `myfinanzas-app`, MERGED en `58346e1`; no modificado.

Este documento no autoriza cambios, instalaciones, reinicios, DNS, Caddy, UFW, Podman,
merges ni despliegues. Cierra la verificación documental y propone los siguientes trabajos.

## 1. Resultados verificados

**Procedencia:** SSH y UFW/nftables provienen de la comprobación final manual ejecutada por
el usuario el 2026-11-05 con `sudo`; las salidas fueron redactadas y no se publican. El
agente no ejecutó esos comandos. Caddy, DNS y HTTP provienen de Nivel 2. La tabla SSH y el
firewall se registran como **proporcionados por el usuario**, no como observación del agente.

### SSH

| Comprobación | Resultado |
| --- | --- |
| `PermitRootLogin` | `no` |
| `PasswordAuthentication` | `no` |
| `KbdInteractiveAuthentication` | `no` |
| `PubkeyAuthentication` | `yes` |
| `MaxAuthTries` | `6` |
| `MaxSessions` | `10` |
| `MaxStartups` | `10:30:100` |
| `X11Forwarding` | `yes` |
| `AllowTcpForwarding` | `yes` |
| `AuthenticationMethods` | `any` |
| `AllowUsers` / `DenyUsers` | no definidos |
| `PermitOpen` / `PermitListen` | redactados; no evaluables |
| Drop-in | `0644 root:root`; anula `PermitRootLogin yes` de la base |

**Conclusión:** root y contraseñas deshabilitados; autenticación por clave pública. Quedan
mejoras de hardening, no bloqueos de la auditoría.

### Firewall

- UFW activo; entrada `deny`, salida `allow`, routed deshabilitado.
- Permitidos: **22, 80 y 443** en IPv4 e IPv6.
- No hay reglas para 2019, 3001 ni 18082.
- nftables confirma `policy drop` en INPUT/FORWARD y solo 22/80/443 en `ufw-user-input`.
- La cadena `f2b-table` de fail2ban está presente; el set `addr-set-sshd` aparece vacío.

**Conclusión:** la exposición pública observada coincide con UFW; no hay puertos públicos
inesperados.

### Caddy

- Paquete: `caddy 2.6.2-12+deb13u1` (`amd64`), binario `/usr/bin/caddy`.
- Origen: Debian `trixie/main` y `trixie-security`; candidato idéntico; sin actualización
  pendiente en los repositorios configurados.
- Servicio: activo, `running`, `NRestarts=0`.
- TLS de `myfinanzas.pp.ua`: válido, Let's Encrypt, CN/SAN del dominio, vigencia
  2026-10-21 a 2027-01-19.
- HTTP: `200`, `server: Caddy`; no se observaron HSTS, CSP, `X-Content-Type-Options` ni
  `Referrer-Policy`.
- `test.myfinanzas.pp.ua`: NXDOMAIN; ausencia esperada.

## 2. Evaluación de seguridad de Caddy

### 2.1 Versión instalada y parches Debian

La versión upstream es **2.6.2**, pero el paquete instalado es
**`2.6.2-12+deb13u1`**, mantenido por Debian. El changelog de `trixie-security` indica que
incluye retroportes de seguridad para:

- CVE-2026-27585
- CVE-2026-27587
- CVE-2026-27588
- CVE-2026-27589
- CVE-2026-27590
- CVE-2026-45692
- CVE-2026-52845
- CVE-2026-52846

**No se debe equiparar la versión upstream 2.6.2 con el paquete Debian**: el paquete incluye
parches que el upstream original no tenía. Que no haya actualización pendiente **no significa**
que no existan vulnerabilidades abiertas.

Fuentes:
- [Debian Security Tracker — caddy](https://security-tracker.debian.org/tracker/source-package/caddy)
- [DSA-6429-1](https://security-tracker.debian.org/tracker/DSA-6429-1)
- [Changelog de `2.6.2-12+deb13u1`](https://metadata.ftp-master.debian.org/changelogs/main/c/caddy/caddy_2.6.2-12+deb13u1_changelog)

### 2.2 Vulnerabilidades abiertas o no determinadas

| CVE | Estado Debian trixie | Versión corregida | Aplicabilidad observada |
| --- | --- | --- | --- |
| **CVE-2026-77281** (GHSA-j8px-rmrx-76h9) | **vulnerable (no DSA, minor)** | 2.11.4 upstream; bookworm `+deb12u1`; forky/sid 2.11.4 | Configuración dependiente. El advisory GHSA agrupa tres problemas; no se observaron `rewrite` con `?`, `{http.request.body}` ni `hide` en la parte leída. |
| CVE-2026-92700 | **undetermined** | — | El tracker no detalla mecanismo; no se asume aplicabilidad. |
| CVE-2026-92284 | **undetermined** | — | El tracker no detalla mecanismo; no se asume aplicabilidad. |

CVE-2026-77281 tiene CVSS 3.1 **6.5 (medio)**. El advisory **GHSA-j8px-rmrx-76h9** agrupa
tres problemas configuración-dependientes (re-expansión de placeholders en `rewrite`, lectura
sin límite de cuerpo y bypass de `fileHidden` por mayúsculas); Debian registra además
CVE-2026-92700 y CVE-2026-92284 como `undetermined`. La descripción oficial indica que el
conjunto afecta a **Caddy < 2.11.4**. Debian marca CVE-2026-77281 como `no-dsa`/minor en
trixie; el paquete trixie instalado sigue vulnerable según el tracker, aunque las condiciones
de explotación no se observaron en la configuración actual.

Fuentes:
- [Debian CVE-2026-77281](https://security-tracker.debian.org/tracker/CVE-2026-77281)
- [CVE.org CVE-2026-77281](https://www.cve.org/CVERecord?id=CVE-2026-77281)
- [GitHub Advisory GHSA-j8px-rmrx-76h9](https://github.com/advisories/GHSA-j8px-rmrx-76h9)
- [Debian CVE-2026-92700](https://security-tracker.debian.org/tracker/CVE-2026-92700)
- [Debian CVE-2026-92284](https://security-tracker.debian.org/tracker/CVE-2026-92284)

### 2.3 Aplicabilidad a nuestra configuración

El `Caddyfile` observado es pequeño (68 bytes): sitio `myfinanzas.pp.ua` y directiva `root`;
no se observó `reverse_proxy`, `rewrite`, `hide` ni `{http.request.body}`. No se leyó el
contenido completo, por lo que la aplicabilidad es **condicional**:

- Si el Caddyfile final no usa `rewrite` con `?`, ni `{http.request.body}`, ni reglas `hide`,
  el riesgo del grupo GHSA/CVE-2026-77281 (y de 92700/92284 si se confirman) es **bajo para
  la configuración actual**.
- Si se añaden esas directivas, el riesgo pasa a **aplicable** y debe resolverse antes de
  publicar TEST.
- La versión `2.6.2-12+deb13u1` no tiene actualización disponible en trixie; no se debe
  asumir que está libre de vulnerabilidades.

### 2.4 Recomendaciones, sin implementar

1. **Antes de publicar TEST:** revisar el Caddyfile completo y confirmar que no contiene
   `rewrite` con URI terminada en `?`, `{http.request.body}` ni reglas `hide` dependientes de
   mayúsculas. Si aparecen, bloquear la publicación hasta mitigar o actualizar.
2. **Mantener secretos fuera del `root` estático:** `.env`, `.git`, claves y backups no deben
   estar bajo `/var/www`; no depender de `hide` como único control.
3. **Evaluar actualización a Caddy 2.11.4 o superior** (Debian forky/sid, backport estable o
   paquete upstream verificado) en una ventana separada, con validación de configuración,
   TLS, cabeceras, rollback y prueba del sitio raíz. No se actualiza ahora.
4. **Añadir cabeceras de seguridad** (HSTS, CSP, `X-Content-Type-Options`,
   `Referrer-Policy`, `noindex`) en una fase de hardening separada.
5. **Monitorizar** el Debian Security Tracker por si trixie recibe un DSA para
   CVE-2026-77281 o se resuelven CVE-2026-92700/92284.

**Veredicto para TEST:** no hay un bloqueo general por Caddy 2.6.2 si la configuración final
evita las directivas afectadas; sí hay un **riesgo abierto que debe confirmarse y mitigarse**
antes de publicar. No se declara Caddy libre de vulnerabilidades. **Esto no autoriza TEST**;
requiere las decisiones de §5 y la aprobación del usuario.

## 3. Riesgos pendientes y prioridades

| Prioridad | Riesgo | Tratamiento propuesto |
| --- | --- | --- |
| Alta | CVE-2026-77281/92700/92284 si el Caddyfile usa `rewrite`/body/`hide` | Confirmar configuración; evitar directivas afectadas o actualizar Caddy antes de TEST. |
| Alta | SSH `X11Forwarding yes`, `AllowTcpForwarding yes`, `AuthenticationMethods any`, sin `AllowUsers` | Hardening recomendado antes de TEST; decisión del usuario. No bloquea la auditoría. |
| Media | Cabeceras HTTP de seguridad no observadas | Añadir en Caddy antes de publicar TEST. |
| Media | Caddy 2.6.2 upstream antiguo | Evaluar actualización; no asumir seguridad por no haber actualización Debian. |
| Media | Backups/restauración no verificados | Coordinar con MyFinanzas; probar restore aislado antes de TEST. |
| Media | Quadlet no revalidado | Definir unidad TEST y probar en host de ensayo; no en VPS sin autorización. |
| Baja | `PermitOpen`/`PermitListen` redactados | Confirmar valores con el usuario; si son `any`, restringir. |
| Baja | fail2ban sin conteos de jail | `fail2ban-client status` manual en una comprobación posterior, si se requiere. |

## 4. Próximos trabajos, sin ejecutar

### 4.1 Backups cifrados y restauración verificable

Coordinar con `myfinanzas-app` antes del despliegue:

- CLI/argumentos definitivos de `backup-cli`/`restore`.
- Datos persistentes: SQLite y `auth.key`/`access-key.age`; `test-instance.json` pendiente.
- Estado temporal de autenticación: puede estar en el snapshot; el restore debe limpiarlo o
  revocarlo; confirmar tablas y contrato.
- Secretos: identidad `age`, contraseña, TOTP y códigos de recuperación con custodia separada.
- Destino externo, retención, RPO/RTO y prueba de restore aislada.

### 4.2 Podman rootless y Quadlet

- Definir unidad TEST, UID 10001/`keep-id`, publicación `127.0.0.1:18082:3001`, límites
  1 GiB/1 CPU/128 pids y persistencia.
- Validar en host de ensayo o runner Linux; no en el VPS sin autorización.
- Confirmar delegación cgroup, Quadlet y arranque tras reinicio.

### 4.3 SPEC de alojamiento TEST — PR #9

- PR #9/spec 02 sigue **DRAFT**; no es contrato aprobado.
- Reconciliar con los resultados de auditoría: Caddy, UFW, SSH, Podman, backups y puertos.
- Revisar, aprobar y publicar por separado; no merge automático.

### 4.4 Hardening SSH y Caddy

- SSH: `X11Forwarding no`, `AllowTcpForwarding no`/`local`, `AuthenticationMethods publickey`,
  `AllowUsers mfadmin`, revisar `PermitOpen`/`PermitListen`.
- Caddy: confirmar CVE/configuración, valorar 2.11.4+, añadir cabeceras de seguridad.
- Todo en ventanas y PR separados, con rollback y validación; no ahora.

## 5. Decisiones pendientes

1. ¿Se acepta el riesgo residual de Caddy 2.6.2 para TEST tras confirmar que el Caddyfile
   evita las directivas afectadas, o se exige actualización antes?
2. ¿Qué versión/destino de actualización de Caddy se autorizaría y con qué ventana?
3. ¿Se prioriza hardening SSH antes o después del primer TEST?
4. ¿Qué destino externo, retención y custodia de identidad `age` se aprueban?
5. ¿Se adopta/actualiza PR #9 como contrato host antes de provisionar?

## 6. Cierre

La auditoría de SSH, firewall y paquete Caddy queda cerrada documentalmente. No se han
realizado cambios intencionados en el servidor; los efectos incidentales están documentados
en Nivel 2 §13. No se ha actualizado Caddy, no se ha leído contenido de backups, bases ni
secretos, y no se ha desplegado nada. La publicación de TEST queda condicionada a la
revisión de la configuración completa de Caddy, a los backups/restauración y a la aprobación
de la SPEC host.
