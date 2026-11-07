# Evidencia — INFRA-TEST-01-HOST · Fase 2A

Fecha: 2026-11-07
Operador: usuario, en sesión SSH interactiva con `sudo` normal.
Alcance: identidad rootless `mftest`. Sin DNS, Caddy, UFW, aplicación, Datasette, bases de
datos ni PROD.
Resultado: **PASS**.

La evidencia procede del informe del usuario; la salida cruda se conserva fuera del
repositorio. No se han registrado secretos, claves, bases ni datos personales.

## Contexto

La primera ejecución de 2A se detuvo en la comprobación de Podman porque `runuser` heredaba
un cwd inaccesible para `mftest` (`~mfadmin`). El script se corrigió para fijar `cd /`
y un entorno explícito, y se preparó un postcheck de solo lectura. El usuario ejecutó el
postcheck sin repetir `useradd`, `usermod`, `passwd` ni `linger`.

Script de postcheck revisado: `scripts/phase2a-postcheck-test.sh`
SHA-256: `e44c8c147860c569c0144e0daae383c77ae40ab529a05ab5f67567f183d30411`

## Resultados verificados

| Comprobación | Resultado |
| --- | --- |
| Identidad | `mftest` UID/GID `1002:1002`; usuario y grupo existen; no se reutiliza `mfadmin`. |
| Home y login | `~mftest` `0700` de `mftest:mftest`; shell `/usr/sbin/nologin`; contraseña bloqueada; sin `authorized_keys`. |
| subuid/subgid | `231072:65536` en ambos ficheros; 65536 IDs; sin duplicados ni solapamiento con `debian:100000:65536` ni `mfadmin:165536:65536`. |
| Linger | `Linger=yes`. |
| systemd --user | `systemd_user_state=running`, `rc=0`. |
| Podman | `rootless=true`, `cgroup=systemd`. |
| Delegación cgroup | `Delegate=yes`; controladores `cpu memory pids`. |
| Rutas 2B | `/srv/myfinanzas-test`, `/var/www/myfinanzas-test` y `data/state` ausentes. |
| Puertos TEST | `18082` y `3001` ausentes. |
| Recuperación | No se ejecutó recuperación destructiva ni limpieza. |

La revisión de `sshd_config`/`AllowUsers` no formó parte de 2A; no se modificó SSH. La
ausencia de `authorized_keys`, el shell `nologin` y la contraseña bloqueada cubren el
resultado de no login para esta evidencia.

## Conclusión

- Checkpoint **2A: PASS**.
- AC03 del test plan host queda cubierto por esta evidencia.
- **2B no está ejecutada ni autorizada**: no se han creado rutas `/srv` ni `/var/www`.
- DNS, Caddy, UFW, aplicación, Datasette, bases de datos y PROD siguen fuera de alcance.
