# Estado actual e inventario por verificar

**Fecha de referencia documental:** 22-10-2026. **Actualizado:** 2026-11-05 con auditoría de
solo lectura (Niveles 1/2 y comprobación final; ver [cierre](auditorias/2026-11-05-infra-audit-vps-001-cierre.md))
y con la actualización de Caddy a 2.11.9 (evidencia del usuario; ver
[cierre VPS-CADDY-UPGRADE-01](auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md)). No cubre
todos los extremos.

Distinguimos:
- **Informado por el usuario:** antecedente útil, no verificación técnica actual.
- **Verificado en GitHub:** consulta del repositorio, no prueba de despliegue.
- **Observado en el VPS:** auditoría de solo lectura, con fecha y alcance limitados.
- **Pendiente:** debe comprobarse con autorización expresa de acceso de solo lectura.

## Auditoría de solo lectura — 2026-11-05 (previa a la actualización)

Evidencia detallada: [Nivel 1](auditorias/2026-11-04-infra-audit-vps-001-nivel1.md),
[Nivel 2](auditorias/2026-11-05-infra-audit-vps-001-nivel2-result.md) y
[cierre/evaluación Caddy](auditorias/2026-11-05-infra-audit-vps-001-cierre.md).

| Área | Estado observado | Límite |
| --- | --- | --- |
| Sistema | Debian 13.7, kernel 6.12.113, x86_64, KVM/OpenStack | Proveedor Aruba no verificado de forma independiente |
| Recursos | 2 vCPU, 3,8 GiB RAM visibles, disco `sda` 40 GB; raíz 39 GB con 35 GB libres; inodos al 3 % | Sin prueba de carga |
| Administración | `mfadmin` UID/GID 1001, grupos `sudo`/`users`, `Linger=yes` | `sudo -n` pidió contraseña; NOPASSWD no verificado para otros comandos |
| SSH | `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`; drop-in `00-myfinanzas-hardening.conf` | `X11Forwarding yes`, `AllowTcpForwarding yes`, `AuthenticationMethods any`, sin `AllowUsers`; `PermitOpen`/`PermitListen` redactados |
| Firewall | UFW activo; entrada `deny`; solo 22/80/443 IPv4/IPv6; nftables coherente | Reglas verificadas manualmente por el usuario |
| Caddy | `2.6.2-12+deb13u1` activo; TLS apex válido; sin actualización Debian pendiente | Estado **antes** de la actualización; ver §Actualización de Caddy. CVE-2026-77281 abierto entonces; cabeceras HSTS/CSP no observadas |
| Contenedores | Podman 5.4.2 rootless; sin contenedores/volúmenes/pods; imágenes `nginx`/`hello-world` | Quadlet no revalidado; delegación cgroup no confirmada |
| DNS | Apex con A y TTL 14400; sin AAAA/CAA; `test` NXDOMAIN | Sin cambios de DNS |
| Backups | `/home/mfadmin/myfinanzas/backups` existe `0700`; sin ficheros regulares visibles a profundidad 2 | Inventario completo y restore no verificados |
| Despliegue | Sin contenedores ni imagen MyFinanzas; página estática no verificada por completo | Caddyfile no leído en la auditoría; validado con 2.11.9 en la actualización |

## Actualización de Caddy — 2026-11-05

Evidencia proporcionada por el usuario; el agente no accedió al VPS después de la actualización.
Cierre: [VPS-CADDY-UPGRADE-01](auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md).

| Comprobación | Resultado |
| --- | --- |
| Paquete | `2.11.9` (amd64), repositorio estable oficial Cloudsmith; antes `2.6.2-12+deb13u1` |
| Servicio | `caddy.service` `active` y `enabled` |
| Timers APT | `apt-daily.timer` y `apt-daily-upgrade.timer` `active` |
| HTTPS / HTTP | 200, TLS verify 0; HTTP 308 a HTTPS |
| Configuración | validada con Caddy 2.11.9 |
| Certificado y contenido | coinciden con los valores previos |
| Capacidades | solo `CAP_NET_BIND_SERVICE` |
| Versión fijada | `apt-mark hold caddy` |
| Rollback | no necesario |

**Pendiente:** AC-17 y AC-18 (`UNRUN`), revisión mensual de Caddy por el `hold`, Quadlet,
backups/restore, hardening SSH, PR #9 DRAFT y autorizaciones de TEST. Caddy 2.11.9 incorpora la
corrección de CVE-2026-77281 (corregido upstream en 2.11.4); no implica ausencia de nuevas
vulnerabilidades. No se han realizado cambios intencionados fuera de la actualización
autorizada; los efectos incidentales de la auditoría están en Nivel 2 §13.

## Inventario inicial informado — estado a 22-10-2026

Esta tabla es **histórica**. Los datos verificados están en la sección anterior.

| Área | Información recibida | Estado de verificación remota |
| --- | --- | --- |
| Proveedor | Aruba Cloud | Pendiente |
| Sistema | Debian 13 | Pendiente |
| Recursos | 2 vCPU, 4 GB RAM y 40 GB de almacenamiento | Pendiente |
| Administración | Usuario `mfadmin`; SSH con claves, sin contraseña | Pendiente |
| Firewall | UFW | Pendiente |
| Entrada web | Caddy como proxy inverso y HTTPS | Pendiente |
| Contenedores | Podman rootless y Quadlet | Pendiente |
| Dominio inicial | `myfinanzas.pp.ua` | Pendiente |
| Persistencia | Directorios privados para datos y backups | Pendiente |
| Despliegue | Página estática de prueba; aplicación MyFinanzas no desplegada | Pendiente |

No constan aquí pruebas de que haya reglas de firewall correctas, copias restaurables, TLS válido, políticas de retención o servicios persistentes arrancando al reiniciar.

## MyFinanzas: dependencia externa

Repositorio de aplicación: [jmartinlabs/myfinanzas-app](https://github.com/jmartinlabs/myfinanzas-app).

Consulta GitHub del 22-10-2026, **no estado congelado ni autorización de despliegue**:
SPEC34/testplan fue aprobada y mergeada en `main` `58346e1` (PR #207); el resto de esta
sección conserva el contexto histórico de Dev 31/32 y debe contrastarse antes de coordinar
una entrega nueva.
- Dev 31 integrado; PR [#31](https://github.com/jmartinlabs/myfinanzas-app/pull/31) integrada.
- Spec Dev 32: PR [#29](https://github.com/jmartinlabs/myfinanzas-app/pull/29) abierta, aprobación documental comunicada; pendiente de integración.
- Implementación Dev 32: PR [#30](https://github.com/jmartinlabs/myfinanzas-app/pull/30) abierta/Draft, checkpoint 23/24 AC; AC-22 y riesgos de concurrencia/durabilidad pendientes. No equivale a estar preparada para producción.
- Adopción metodológica PR [#32](https://github.com/jmartinlabs/myfinanzas-app/pull/32) y política de aislamiento PR [#33](https://github.com/jmartinlabs/myfinanzas-app/pull/33) integradas en la aplicación; **no suponen instalación de `$orchestrate` en `vps-infra`**.

Antes de coordinar una entrega relacionada, **volver a comprobar** estos enlaces y los criterios vigentes en el repositorio de aplicación.

## Alcance de la auditoría ejecutada — solo lectura

Los resultados verificados están en la sección anterior y en los informes enlazados. SSH y
UFW/nftables se cerraron con la comprobación manual del usuario; Caddy se actualizó a 2.11.9
con evidencia del usuario; siguen pendientes Quadlet y backups/restore. El siguiente era el alcance previsto:

Comprobar sin exponer secretos:
- Identidad del anfitrión, versión de SO, fecha de actualización y estado de reinicio pendiente.
- Servicios y sockets activos, puertos escuchando y exposición pública esperada.
- Configuración/estado efectivos de SSH, UFW, Caddy (dominios, TLS y rutas) sin revelar material privado.
- Usuarios, UID/GID, rootless Podman, Quadlet y servicios `systemd --user`; persistencia tras reboot.
- Disco, inodos, particiones, memoria, CPU, logs y riesgos de falta de espacio.
- Inventario de rutas/propietarios para datos, copias locales, rotación y cifrado; sin leer contenidos sensibles.
- Estado de copias externas, restauración, alertas y mantenimiento (puede ser «no implantado»).

Entregable de la auditoría: evidencia redactada, diferencias frente a lo informado, riesgos ordenados por impacto, próximos pasos y solicitudes explícitas de autorización. No hacer correcciones durante la inspección.
