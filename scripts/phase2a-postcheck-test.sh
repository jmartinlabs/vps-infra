#!/usr/bin/env bash
# INFRA-TEST-01 · Fase 2A: postchecks de identidad rootless existente.
#
# Solo lectura. No crea usuarios, no modifica subuid/subgid, no cambia
# contraseñas, no habilita linger, no crea directorios ni toca servicios.
# `podman info` puede inicializar metadatos locales de storage si aún no
# existen; no elimina ni reemplaza datos.
#
# Ejecutar como root en UNA sola sesión controlada:
#   ssh mi-vps 'sudo bash -s' < scripts/phase2a-postcheck-test.sh
#
# Uso previsto: tras una ejecución parcial de phase2a-host-test.sh en la que
# mftest ya existe. No repite useradd/usermod/passwd/linger, no sustituye a 2A
# y no autoriza 2B.
set -euo pipefail
umask 077

# runuser hereda el cwd. Si el script se lanza desde /home/mfadmin, mftest no
# puede acceder y Podman falla con "cannot chdir". Fijamos un cwd accesible.
cd /

fail() {
  printf '\nBLOQUEO POSTCHECK 2A: %s\n' "$*" >&2
  printf 'Estado actual (solo lectura):\n' >&2
  getent passwd mftest 2>/dev/null || true
  getent group mftest 2>/dev/null || true
  grep -E '^mftest:' /etc/subuid /etc/subgid 2>/dev/null || true
  loginctl show-user mftest -p Linger 2>/dev/null || true
  exit 1
}

section() { printf '\n=== %s ===\n' "$*"; }

section "POSTCHECK · contexto"
date -u +%Y-%m-%dT%H:%M:%SZ
id
[ "$(id -u)" -eq 0 ] || fail "se requiere root para runuser"
for c in getent id stat grep loginctl systemctl runuser podman python3 ss find; do
  command -v "$c" >/dev/null || fail "falta $c"
done

section "POSTCHECK · identidad existente"
getent passwd mftest || fail "mftest no existe"
getent group mftest || fail "grupo mftest no existe"
UID_MFTEST="$(id -u mftest)"
GID_MFTEST="$(id -g mftest)"
[ -n "$UID_MFTEST" ] || fail "UID vacío"
[ -n "$GID_MFTEST" ] || fail "GID vacío"
[ "$(getent passwd "$UID_MFTEST" | wc -l)" -eq 1 ] || fail "UID duplicado"
[ "$(getent group "$GID_MFTEST" | wc -l)" -eq 1 ] || fail "GID duplicado"
echo "uid=$UID_MFTEST gid=$GID_MFTEST"

HOME_MFTEST="$(getent passwd mftest | cut -d: -f6)"
SHELL_MFTEST="$(getent passwd mftest | cut -d: -f7)"
[ "$HOME_MFTEST" = "/home/mftest" ] || fail "home inesperado: $HOME_MFTEST"
[ "$SHELL_MFTEST" = "/usr/sbin/nologin" ] || fail "shell inesperada: $SHELL_MFTEST"
[ -d "$HOME_MFTEST" ] || fail "home ausente"
[ "$(stat -c %U "$HOME_MFTEST")" = mftest ] || fail "home no es de mftest"
[ "$(stat -c %a "$HOME_MFTEST")" = 700 ] || fail "home no tiene modo 700"
[ ! -e "$HOME_MFTEST/.ssh/authorized_keys" ] || fail "authorized_keys inesperada"
if [ -n "$(find "$HOME_MFTEST" -maxdepth 2 -type l -print -quit)" ]; then
  fail "symlink inesperado en home"
fi

as_mftest() {
  runuser -u mftest -- env HOME="$HOME_MFTEST" USER=mftest LOGNAME=mftest \
    XDG_RUNTIME_DIR="/run/user/${UID_MFTEST}" "$@"
}

section "POSTCHECK · subuid/subgid"
grep -E '^mftest:' /etc/subuid || fail "subuid mftest ausente"
grep -E '^mftest:' /etc/subgid || fail "subgid mftest ausente"
[ "$(grep -c '^mftest:' /etc/subuid)" -eq 1 ] || fail "subuid duplicado"
[ "$(grep -c '^mftest:' /etc/subgid)" -eq 1 ] || fail "subgid duplicado"

python3 - <<'PY' || fail "validación subuid/subgid"
from pathlib import Path

def entries(path):
    rows = []
    for line in Path(path).read_text().splitlines():
        if line.strip():
            name, start, count = line.split(":")
            rows.append((name, int(start), int(count)))
    return rows

files = {}
for path in ("/etc/subuid", "/etc/subgid"):
    rows = entries(path)
    mine = [r for r in rows if r[0] == "mftest"]
    assert len(mine) == 1, (path, mine)
    start, count = mine[0][1], mine[0][2]
    assert start > 0, (path, start)
    assert count == 65536, (path, count)
    end = start + count - 1
    for name, other_start, other_count in rows:
        if name == "mftest":
            continue
        other_end = other_start + other_count - 1
        assert end < other_start or start > other_end, (
            path, name, other_start, other_count
        )
    files[path] = (start, count)

assert files["/etc/subuid"] == files["/etc/subgid"], files
start, count = files["/etc/subuid"]
print(f"subuid/subgid efectivos: {start}:{count} (fin={start + count - 1})")
print("un solo rango por fichero, sin solapamiento")
PY

section "POSTCHECK · contraseña y linger"
passwd -S mftest || fail "passwd -S"
passwd -S mftest | grep -q '^mftest L ' || fail "contraseña no bloqueada"
loginctl show-user mftest -p Linger || fail "loginctl show-user"
loginctl show-user mftest -p Linger | grep -q 'Linger=yes' || fail "Linger no activo"

section "POSTCHECK · systemd --user"
systemctl show "user@${UID_MFTEST}.service" -p ActiveState,SubState,Delegate \
  || fail "systemctl show"
systemctl is-active --quiet "user@${UID_MFTEST}.service" \
  || fail "user manager no activo"
[ "$(systemctl show "user@${UID_MFTEST}.service" -p Delegate --value)" = "yes" ] \
  || fail "delegación cgroup no activa"

set +e
USER_STATE="$(as_mftest systemctl --user is-system-running 2>&1)"
USER_RC=$?
set -e
echo "systemd_user_state=${USER_STATE} rc=${USER_RC}"

if [ "$USER_STATE" = "degraded" ]; then
  as_mftest systemctl --user --failed --no-pager 2>&1 || true
  fail "systemd --user degraded; investigar antes de continuar"
fi
[ "$USER_RC" -eq 0 ] || fail "systemd --user rc=${USER_RC}: ${USER_STATE}"
[ "$USER_STATE" = "running" ] || fail "systemd --user no está running: ${USER_STATE}"
as_mftest systemctl --user show -p Version | grep -q 'Version=' \
  || fail "systemd --user show"

section "POSTCHECK · Podman rootless y cgroups"
PODMAN_INFO="$(as_mftest podman info \
  --format 'rootless={{.Host.Security.Rootless}} cgroup={{.Host.CgroupManager}}')" \
  || fail "podman info"
echo "$PODMAN_INFO"
grep -q 'rootless=true' <<<"$PODMAN_INFO" || fail "Podman no rootless"
grep -q 'cgroup=systemd' <<<"$PODMAN_INFO" || fail "Podman no usa systemd"

CONTROLLERS_FILE="/sys/fs/cgroup/user.slice/user-${UID_MFTEST}.slice/user@${UID_MFTEST}.service/cgroup.controllers"
[ -r "$CONTROLLERS_FILE" ] || fail "no se puede leer $CONTROLLERS_FILE"
CONTROLLERS="$(cat "$CONTROLLERS_FILE")"
echo "cgroup_controllers=${CONTROLLERS}"
for c in cpu memory pids; do
  echo "$CONTROLLERS" | grep -qw "$c" || fail "controlador cgroup ausente: $c"
done

section "POSTCHECK · estado del host sin 2B"
for p in /srv/myfinanzas-test /var/www/myfinanzas-test /srv/myfinanzas-test/data/state; do
  if [ -e "$p" ] || [ -L "$p" ]; then fail "ruta 2B inesperada: $p"; fi
done
if ss -ltn | grep -Eq '18082|3001'; then fail "puerto TEST inesperado"; fi
echo "sin rutas 2B y sin puertos TEST"

section "POSTCHECK · evidencia final"
id mftest
getent passwd mftest
getent group mftest
grep -E '^mftest:' /etc/subuid /etc/subgid
loginctl show-user mftest -p Linger
systemctl show "user@${UID_MFTEST}.service" -p ActiveState,SubState,Delegate
stat -c '%A %a %U:%G %n' "$HOME_MFTEST"

section "POSTCHECK 2A COMPLETADO"
echo "Sin cambios: no se repitieron useradd/usermod/passwd/linger. 2B no ejecutada."
