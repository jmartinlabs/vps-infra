#!/usr/bin/env bash
# INFRA-TEST-01 · Fase 2A: identidad rootless mftest.
#
# Ejecutar como root en UNA sola sesión controlada:
#   ssh mi-vps 'sudo bash -s' < scripts/phase2a-host-test.sh
#
# Alcance: crear mftest, validar/asignar un único subuid/subgid, bloquear
# contraseña/login, habilitar linger, iniciar systemd --user y comprobar
# Podman rootless/cgroups. No crea /srv/myfinanzas-test ni toca DNS, Caddy,
# UFW, aplicaciones, Datasette, bases de datos o PROD.
#
# No ejecuta recuperación automática: cualquier desviación imprime el estado y
# termina con código 1 para revisión. No repetir ni limpiar a ciegas.
#
# Este script es para un host sin mftest. Si mftest ya existe tras una ejecución
# parcial, no repetir 2A: usar scripts/phase2a-postcheck-test.sh.
#
# Evidencia: la salida PRE/POST se guarda fuera del repositorio. No imprime
# claves, contraseñas ni contenido de datos.
set -euo pipefail
umask 077

# runuser hereda el cwd. Si el script se lanza desde /home/mfadmin, mftest no
# puede acceder y Podman falla con "cannot chdir". Fijamos un cwd accesible.
cd /

fail() {
  printf '\nBLOQUEO FASE2A: %s\n' "$*" >&2
  printf 'Estado actual (solo lectura):\n' >&2
  getent passwd mftest 2>/dev/null || true
  getent group mftest 2>/dev/null || true
  grep -E '^mftest:' /etc/subuid /etc/subgid 2>/dev/null || true
  loginctl show-user mftest -p Linger 2>/dev/null || true
  exit 1
}

section() { printf '\n=== %s ===\n' "$*"; }

section "PRE · identidad"
date -u +%Y-%m-%dT%H:%M:%SZ
id
getent passwd mftest || true
getent group mftest || true
grep -E '^mftest:' /etc/subuid /etc/subgid || true
loginctl show-user mftest -p Linger 2>&1 || true
for p in /home/mftest /srv/myfinanzas-test /var/www/myfinanzas-test; do
  if [ -e "$p" ] || [ -L "$p" ]; then stat -c '%A %a %U:%G %n' "$p"; else echo "absent: $p"; fi
done
cat /etc/subuid
cat /etc/subgid

section "PRE · precondiciones"
[ "$(id -u)" -eq 0 ] || fail "se requiere root"
for c in useradd usermod loginctl systemctl runuser python3; do
  command -v "$c" >/dev/null || fail "falta $c"
done
if getent passwd mftest >/dev/null 2>&1; then
  fail "mftest ya existe; usar scripts/phase2a-postcheck-test.sh, no repetir 2A"
fi
if getent group mftest >/dev/null 2>&1; then fail "grupo mftest ya existe"; fi
if grep -q '^mftest:' /etc/subuid; then fail "subuid mftest ya existe"; fi
if grep -q '^mftest:' /etc/subgid; then fail "subgid mftest ya existe"; fi
for p in /home/mftest /srv/myfinanzas-test /var/www/myfinanzas-test; do
  if [ -e "$p" ] || [ -L "$p" ]; then fail "ruta existente: $p"; fi
done
[ "$(stat -c %U /srv)" = root ] || fail "/srv no es root"
[ "$(stat -c %a /srv)" = 755 ] || fail "/srv no tiene modo 755"
df -P / | awk 'NR==2 { if ($4 < 5*1024*1024) exit 1 }' || fail "menos de 5 GB libres"
df -Pi / | awk 'NR==2 { if ($4 < 500000) exit 1 }' || fail "menos de 500k inodos libres"

section "2A · useradd"
useradd --create-home --home-dir /home/mftest \
  --shell /usr/sbin/nologin --user-group mftest || fail "useradd"
chmod 700 /home/mftest || fail "chmod home"
passwd -l mftest >/dev/null || fail "passwd -l"

UID_MFTEST="$(id -u mftest)"
GID_MFTEST="$(id -g mftest)"
SUBUID_MFTEST="$(grep '^mftest:' /etc/subuid || true)"
SUBGID_MFTEST="$(grep '^mftest:' /etc/subgid || true)"

as_mftest() {
  runuser -u mftest -- env HOME=/home/mftest USER=mftest LOGNAME=mftest \
    XDG_RUNTIME_DIR="/run/user/${UID_MFTEST}" "$@"
}

section "2A · subuid/subgid efectivos tras useradd"
echo "uid=$UID_MFTEST gid=$GID_MFTEST"
echo "subuid=${SUBUID_MFTEST:-<none>}"
echo "subgid=${SUBGID_MFTEST:-<none>}"

if [ -n "$SUBUID_MFTEST" ] && [ -n "$SUBGID_MFTEST" ]; then
  echo "useradd asignó ambos rangos; no se ejecutará usermod"
elif [ -z "$SUBUID_MFTEST" ] && [ -z "$SUBGID_MFTEST" ]; then
  RANGE="$(python3 - <<'PY'
from pathlib import Path

def ranges(path):
    out = []
    for line in Path(path).read_text().splitlines():
        if line.strip():
            _, start, count = line.split(":")
            out.append((int(start), int(start) + int(count) - 1))
    return out

existing = ranges("/etc/subuid") + ranges("/etc/subgid")
start = 231072
size = 65536
while any(not (start + size - 1 < a or start > b) for a, b in existing):
    start += size
print(f"{start}-{start + size - 1}")
PY
)" || fail "cálculo de rango"
  echo "rango libre calculado: $RANGE"
  usermod --add-subuids "$RANGE" --add-subgids "$RANGE" mftest || fail "usermod subids"
else
  fail "solo existe uno de subuid/subgid; no se añade el segundo"
fi

[ "$(grep -c '^mftest:' /etc/subuid)" -eq 1 ] || fail "subuid inesperado"
[ "$(grep -c '^mftest:' /etc/subgid)" -eq 1 ] || fail "subgid inesperado"

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
print("subuid/subgid: un solo rango por fichero, 65536 IDs, sin solapamiento")
PY

section "2A · linger y systemd --user"
loginctl enable-linger mftest || fail "enable-linger"
loginctl show-user mftest -p Linger | grep -q 'Linger=yes' || fail "Linger no activo"
systemctl start "user@${UID_MFTEST}.service" || fail "systemd user manager start"
systemctl show "user@${UID_MFTEST}.service" -p ActiveState,SubState \
  || fail "systemctl show user manager"

set +e
USER_STATE="$(as_mftest systemctl --user is-system-running 2>&1)"
USER_RC=$?
set -e
echo "systemd_user_state=${USER_STATE} rc=${USER_RC}"

if [ "$USER_STATE" = "degraded" ]; then
  as_mftest systemctl --user --failed --no-pager 2>&1 || true
  fail "systemd --user degraded; investigar antes de continuar"
fi
if [ "$USER_RC" -ne 0 ] || [ "$USER_STATE" != "running" ]; then
  fail "systemd --user no responde en estado running: ${USER_STATE} rc=${USER_RC}"
fi
as_mftest systemctl --user show -p Version | grep -q 'Version=' \
  || fail "systemd --user show"

section "2A · Podman rootless y cgroups"
PODMAN_INFO="$(as_mftest podman info \
  --format 'rootless={{.Host.Security.Rootless}} cgroup={{.Host.CgroupManager}}')" \
  || fail "podman info"
echo "$PODMAN_INFO"
grep -q 'rootless=true' <<<"$PODMAN_INFO" || fail "Podman no rootless"
grep -q 'cgroup=systemd' <<<"$PODMAN_INFO" || fail "Podman no usa systemd"

systemctl show "user@${UID_MFTEST}.service" -p Delegate | grep -q 'Delegate=yes' \
  || fail "cgroup delegation no activa"
CONTROLLERS="$(cat "/sys/fs/cgroup/user.slice/user-${UID_MFTEST}.slice/user@${UID_MFTEST}.service/cgroup.controllers")" \
  || fail "cgroup controllers"
echo "cgroup_controllers=${CONTROLLERS}"
for c in cpu memory pids; do
  echo "$CONTROLLERS" | grep -qw "$c" || fail "controlador cgroup ausente: $c"
done

section "2A · evidencia posterior"
id mftest
getent passwd mftest
getent group mftest
grep -E '^mftest:' /etc/subuid /etc/subgid
loginctl show-user mftest -p Linger
systemctl show "user@${UID_MFTEST}.service" -p ActiveState,SubState,Delegate
passwd -S mftest | grep -q '^mftest L ' || fail "contraseña no bloqueada"
[ ! -e /home/mftest/.ssh/authorized_keys ] || fail "authorized_keys inesperada"
stat -c '%A %a %U:%G %n' /home/mftest
if ss -ltn | grep -Eq '18082|3001'; then fail "puerto TEST inesperado"; fi

section "2A COMPLETADA"
echo "No se ha creado /srv/myfinanzas-test ni /var/www/myfinanzas-test; 2B no ejecutada."
