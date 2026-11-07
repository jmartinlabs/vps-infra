# Evidencia — INFRA-TEST-01-HOST · Fase 2B

Fecha: 2026-11-07
Operador: usuario, en sesión SSH interactiva con `sudo` normal.
Alcance: rutas y permisos de aprovisionamiento TEST. Sin DNS, Caddy, UFW, aplicación,
Datasette, bases de datos, servicios ni PROD.
Resultado: **PASS**.

La evidencia procede del informe del usuario; la salida cruda se conserva fuera del
repositorio. No se han registrado secretos, claves, bases ni datos personales.

Script ejecutado: `scripts/phase2b-host-test.sh`
SHA-256: `9854e496e138cf27397959bf9f52a8e267b0df80925c2faae32ec841ae9dae82`

## Resultados verificados

| Comprobación | Resultado |
| --- | --- |
| Identidad | `mftest` UID/GID `1002:1002`; usuario y grupo existentes. |
| Raíz privada | `/srv/myfinanzas-test` de `mftest:mftest` `0700`. |
| Datos | `/srv/myfinanzas-test/data` de `mftest:mftest` `0700`; `data/state` ausente. |
| Releases y backups | `/srv/myfinanzas-test/releases` y `/srv/myfinanzas-test/backups` de `mftest:mftest` `0700`, vacíos. |
| Raíz estática | `/var/www/myfinanzas-test` de `root:root` `0755`; `current` ausente. |
| Quadlet | `~mftest/.config`, `~mftest/.config/containers` y `~mftest/.config/containers/systemd` de `mftest:mftest` `0700`. |
| Estado y despliegue | `data/state` y `current` siguen ausentes; no se crearon unidades, servicios ni puertos TEST. |
| Recursos | 35 GB libres; inodos utilizados 3 %. |
| Alcance respetado | Sin cambios en DNS, Caddy, UFW, MyFinanzas, Datasette ni PROD. |
| Recuperación | No se ejecutó recuperación destructiva ni limpieza. |

## Conclusión

- Checkpoint **2B: PASS**.
- AC04 de aprovisionamiento queda cubierto por esta evidencia.
- Fase 2 de **aprovisionamiento**: completada (2A + 2B).
- **No implica despliegue**: estado, DB, `auth.key`, `current`, unidad, seed, DNS, Caddy,
  smoke y copias siguen pendientes de las fases 3–7.
