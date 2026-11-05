# VPS-CADDY-UPGRADE-01 · Cierre de la actualización de Caddy

Status: **cierre documental; actualización realizada y evidencias proporcionadas por el usuario.
AC-17 y AC-18 siguen abiertos.**
Fecha: 2026-11-05.
Entorno: Aruba Cloud · Debian 13 · `myfinanzas.pp.ua`.
Especificación: [03 — actualización a Caddy 2.11.9](../../specs/03-caddy-upgrade-01-specification.md).
Preflight: [03.1 — comprobación previa](../../specs/03-caddy-upgrade-01-preflight.md).
PR documentales: [#14](https://github.com/jmartinlabs/vps-infra/pull/14) y
[#15](https://github.com/jmartinlabs/vps-infra/pull/15).
Auditoría base: [cierre INFRA-AUDIT-VPS-001](2026-11-05-infra-audit-vps-001-cierre.md).

Este documento registra el resultado. **El agente no accedió al VPS después de la
actualización**: los valores posteriores son evidencia proporcionada por el usuario y no una
verificación independiente. No autoriza nuevas operaciones, cambios, merges ni despliegues.

## 1. Resultado

| Comprobación | Antes | Después |
| --- | --- | --- |
| Paquete | `2.6.2-12+deb13u1` (Debian trixie) | **`2.11.9`** (amd64, repositorio estable oficial Cloudsmith) |
| `caddy version` | 2.6.2 | **v2.11.9** |
| `caddy.service` | activo | **`active`** |
| Arranque automático | `enabled` | **`enabled`** |
| `apt-daily.timer` | activo | **`active`** |
| `apt-daily-upgrade.timer` | activo | **`active`** |
| HTTPS | 200 / TLS válido | **200, `ssl_verify_result=0`** |
| HTTP | 308 a HTTPS | **308 a HTTPS** |
| Configuración | validada con 2.6.2 | **validada con 2.11.9** |
| Certificado y contenido | referencia previa | **coinciden con los valores anteriores** |
| Capacidades del proceso | `CAP_NET_BIND_SERVICE` | **solo `CAP_NET_BIND_SERVICE`** |
| Versión fijada | no | **`apt-mark hold caddy` aplicado** |
| Rollback | — | **no fue necesario** |

La actualización se realizó manualmente con autorización expresa del usuario. El sitio y el
certificado se conservaron; no se cambió DNS, UFW, SSH, Podman ni `myfinanzas-app`.

## 2. systemd

- Paquete oficial 2.11.9; unidad `caddy.service` en `/lib/systemd/system` (usr-merge con
  `/usr/lib/systemd/system`).
- *Drop-in* `99-local-capabilities.conf` en `caddy.service.d` y `caddy-api.service.d`:
  - `AmbientCapabilities=` y `CapabilityBoundingSet=` vaciados y redefinidos solo con
    `CAP_NET_BIND_SERVICE`;
  - `LimitNPROC=512`.
- Verificación indicada: el proceso de Caddy conserva **solo** `CAP_NET_BIND_SERVICE`; no
  `CAP_NET_ADMIN`.
- `caddy-api.service` sigue sin uso según la preflight previa.

## 3. Mantenimiento

- Caddy está en **`apt-mark hold`**. Esto evita actualizaciones no revisadas, pero **no debe
  dejar Caddy sin parches**.
- Revisión **mensual** de:
  - repositorio estable oficial de Caddy/Cloudsmith;
  - avisos de seguridad de Caddy;
  - Debian Security Tracker para `caddy`.
- Si hay una versión corregida: `unhold` solo en una ventana autorizada, repetir la
  [especificación](../../specs/03-caddy-upgrade-01-specification.md) y la
  [preflight](../../specs/03-caddy-upgrade-01-preflight.md), con QA y rollback disponible.
- Registrar la fecha de cada revisión y la decisión adoptada.

## 4. Recuperación

Directorio protegido en el VPS:

```text
/root/caddy-upgrade-20261105T151652Z
```

- Contiene los paquetes verificados, la configuración y la copia consistente de los datos de
  Caddy.
- Permisos: `0700 root:root`.
- Retención prevista: **hasta 2026-12-05**.
- **No borrar ni modificar sin autorización expresa.**
- No copiar certificados, claves privadas, datos sensibles ni logs completos a GitHub.

El rollback no fue necesario. La copia no se ha restaurado ni ensayado en un entorno aislado.

## 5. Pruebas realizadas y pendientes

**Realizadas y evidenciadas por el usuario:**

- arranque y servicio `active`, `enabled`;
- HTTPS 200 con TLS válido y HTTP 308 a HTTPS;
- validación de configuración con 2.11.9;
- conservación de certificado y contenido;
- capacidades efectivas limitadas a `CAP_NET_BIND_SERVICE`;
- timers de APT activos;
- `hold` aplicado.

**No realizadas / pendientes:**

- **AC-17:** arranque del VPS tras reboot — **UNRUN**.
- **AC-18:** ensayo real de rollback — **UNRUN**.
- Restauración real desde `/root/caddy-upgrade-20261105T151652Z` — no ejecutada.
- Revisión independiente del VPS posterior a la actualización — no realizada por el agente.

No se presentan AC-17 ni AC-18 como ejecutados.

## 6. Riesgos residuales

- Rollback no ensayado: si 2.11.9 fallara, la recuperación depende de los materiales y comandos
  documentados, no de una prueba real.
- Arranque tras reboot no verificado.
- `hold` puede dejar Caddy sin parches si se abandona la revisión mensual.
- Nuevas vulnerabilidades o regresiones de 2.11.9: revisar avisos y el repositorio oficial.
- La copia de recuperación caduca el 2026-12-05; antes de esa fecha hay que decidir su
  renovación o borrado con autorización.

## 7. Vínculos

- [Especificación 03](../../specs/03-caddy-upgrade-01-specification.md)
- [Preflight 03.1](../../specs/03-caddy-upgrade-01-preflight.md)
- [PR #14 — especificación y preflight](https://github.com/jmartinlabs/vps-infra/pull/14)
- [PR #15 — corrección `lsof`](https://github.com/jmartinlabs/vps-infra/pull/15)
- [Estado actual](../estado-actual.md)
- [Operaciones y recuperación](../operaciones.md)
