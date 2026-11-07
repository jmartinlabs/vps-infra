#!/usr/bin/env bash
# INFRA-TEST-01 · Fase 2B: rutas y permisos exclusivos de TEST.
#
# Ejecutar como root en UNA sola sesión controlada:
#   ssh mi-vps 'sudo bash -s' < scripts/phase2b-host-test.sh
#
# Alcance: crear la raíz privada, data, releases, backups, la raíz estática y los
# directorios Quadlet de mftest. No crea data/state, bases ni contenido dentro de
# releases/backups, y no crea unidades, servicios, DNS, Caddy, UFW, aplicación,
# Datasette ni PROD.
#
# No repite 2A: no ejecuta useradd, usermod, passwd, linger ni systemctl.
# No ejecuta recuperación automática: cualquier desviación imprime el estado y
# termina con código 1 para revisión. No repetir ni limpiar a ciegas.
#
# Evidencia: la salida PRE/POST se guarda fuera del repositorio. No imprime
# claves, contraseñas ni contenido de datos.
set -euo pipefail
umask 077

cd /

fail() {
  printf '\nBLOQUEO FASE2B: %s\n' "$*" >&2
  printf 'Estado actual (solo lectura):\n' >&2
  getent passwd mftest 2>/dev/null || true
  getent group mftest 2>/dev/null || true
  for p in \
    /srv/myfinanzas-test \
    /srv/myfinanzas-test/data \
    /srv/myfinanzas-test/releases \
    /srv/myfinanzas-test/backups \
    /var/www/myfinanzas-test \
    /home/mftest/.config \
    /home/mftest/.config/containers \
    /home/mftest/.config/containers/systemd; do
    if [ -e "$p" ] || [ -L "$p" ]; then
      stat -c '%A %a %U:%G %n' "$p" 2>/dev/null || true
    else
      echo "absent: $p"
    fi
  done
  exit 1
}

section() { printf '\n=== %s ===\n' "$*"; }

section "PRE · contexto"
date -u +%Y-%m-%dT%H:%M:%SZ
id
getent passwd mftest || true
getent group mftest || true
for p in \
  /srv/myfinanzas-test \
  /srv/myfinanzas-test/data \
  /srv/myfinanzas-test/releases \
  /srv/myfinanzas-test/backups \
  /var/www/myfinanzas-test \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    stat -c '%A %a %U:%G %n' "$p"
  else
    echo "absent: $p"
  fi
done

section "PRE · precondiciones"
[ "$(id -u)" -eq 0 ] || fail "se requiere root"
for c in getent id stat install find namei ss df awk; do
  command -v "$c" >/dev/null || fail "falta $c"
done

getent passwd mftest >/dev/null 2>&1 || fail "mftest no existe; 2A no está completa"
getent group mftest >/dev/null 2>&1 || fail "grupo mftest no existe; 2A no está completa"
UID_MFTEST="$(id -u mftest)"
GID_MFTEST="$(id -g mftest)"
HOME_MFTEST="$(getent passwd mftest | cut -d: -f6)"
SHELL_MFTEST="$(getent passwd mftest | cut -d: -f7)"
[ "$HOME_MFTEST" = "/home/mftest" ] || fail "home de mftest inesperado: $HOME_MFTEST"
[ "$SHELL_MFTEST" = "/usr/sbin/nologin" ] || fail "shell de mftest inesperada: $SHELL_MFTEST"
[ -d /home/mftest ] || fail "home de mftest ausente"
[ ! -L /home/mftest ] || fail "home de mftest es symlink"
[ "$(stat -c %U /home/mftest)" = mftest ] || fail "home de mftest no es de mftest"
[ "$(stat -c %a /home/mftest)" = 700 ] || fail "home de mftest no tiene modo 700"
echo "mftest uid=$UID_MFTEST gid=$GID_MFTEST home=$HOME_MFTEST"

[ -d /srv ] || fail "/srv ausente"
[ ! -L /srv ] || fail "/srv es symlink"
[ "$(stat -c %U /srv)" = root ] || fail "/srv no es root"
[ "$(stat -c %a /srv)" = 755 ] || fail "/srv no tiene modo 755"
[ -d /var/www ] || fail "/var/www ausente"
[ ! -L /var/www ] || fail "/var/www es symlink"
[ "$(stat -c %U /var/www)" = root ] || fail "/var/www no es root"
[ "$(stat -c %a /var/www)" = 755 ] || fail "/var/www no tiene modo 755"

for p in /srv/myfinanzas-test /var/www/myfinanzas-test; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    fail "ruta 2B ya existente: $p; preservar y revisar antes de continuar"
  fi
done
if [ -e /srv/myfinanzas-test/data/state ] || [ -L /srv/myfinanzas-test/data/state ]; then
  fail "data/state no debe existir antes de 2B"
fi

# Los padres de ~/.config pueden existir por useradd o por el postcheck de 2A.
# Solo se aceptan directorios reales de mftest; el contenido de containers se conserva.
for p in /home/mftest/.config /home/mftest/.config/containers /home/mftest/.config/containers/systemd; do
  if [ -L "$p" ]; then
    fail "symlink inesperado: $p"
  fi
  if [ -e "$p" ]; then
    [ -d "$p" ] || fail "no es un directorio: $p"
    [ "$(stat -c %U "$p")" = mftest ] || fail "propietario inesperado: $p"
    [ "$(stat -c %G "$p")" = mftest ] || fail "grupo inesperado: $p"
  fi
done
if [ -d /home/mftest/.config/containers/systemd ] \
  && [ -n "$(find /home/mftest/.config/containers/systemd -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  fail "contenido inesperado en ~/.config/containers/systemd"
fi
if [ -d /home/mftest/.config ] \
  && [ -n "$(find /home/mftest/.config -maxdepth 3 -type l -print -quit)" ]; then
  fail "symlink inesperado en ~/.config"
fi

df -P / | awk 'NR==2 { if ($4 < 5*1024*1024) exit 1 }' || fail "menos de 5 GB libres"
df -Pi / | awk 'NR==2 { if ($4 < 500000) exit 1 }' || fail "menos de 500k inodos libres"
if ss -ltn | grep -Eq '18082|3001'; then fail "puerto TEST inesperado"; fi

section "2B · configuración Quadlet de mftest"
install -d -m 0700 -o mftest -g mftest \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd \
  || fail "crear directorios Quadlet"
chown mftest:mftest \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd \
  || fail "propietario de directorios Quadlet"
chmod 700 \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd \
  || fail "permisos de directorios Quadlet"

section "2B · rutas privadas de TEST"
install -d -m 0700 -o mftest -g mftest \
  /srv/myfinanzas-test \
  /srv/myfinanzas-test/data \
  /srv/myfinanzas-test/releases \
  /srv/myfinanzas-test/backups \
  || fail "crear rutas /srv"

section "2B · raíz estática"
install -d -m 0755 -o root -g root /var/www/myfinanzas-test \
  || fail "crear raíz estática"

check_dir() {
  local path="$1" owner="$2" group="$3" mode="$4"
  [ -d "$path" ] || fail "falta $path"
  [ ! -L "$path" ] || fail "symlink inesperado: $path"
  [ "$(stat -c %U "$path")" = "$owner" ] || fail "propietario inesperado: $path"
  [ "$(stat -c %G "$path")" = "$group" ] || fail "grupo inesperado: $path"
  [ "$(stat -c %a "$path")" = "$mode" ] || fail "modo inesperado: $path"
}

section "2B · verificación posterior"
namei -l /srv/myfinanzas-test/data
stat -c '%A %a %U:%G %n' \
  /srv/myfinanzas-test \
  /srv/myfinanzas-test/data \
  /srv/myfinanzas-test/releases \
  /srv/myfinanzas-test/backups \
  /var/www/myfinanzas-test \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd

check_dir /srv/myfinanzas-test mftest mftest 700
check_dir /srv/myfinanzas-test/data mftest mftest 700
check_dir /srv/myfinanzas-test/releases mftest mftest 700
check_dir /srv/myfinanzas-test/backups mftest mftest 700
check_dir /var/www/myfinanzas-test root root 755
check_dir /home/mftest/.config mftest mftest 700
check_dir /home/mftest/.config/containers mftest mftest 700
check_dir /home/mftest/.config/containers/systemd mftest mftest 700

if [ -n "$(find /srv/myfinanzas-test /var/www/myfinanzas-test /home/mftest/.config -xdev -type l -print -quit)" ]; then
  fail "symlink inesperado en rutas TEST"
fi
if [ -n "$(find /srv/myfinanzas-test -xdev -type f -print -quit)" ]; then
  fail "archivo inesperado en /srv/myfinanzas-test"
fi
for d in \
  /srv/myfinanzas-test/data \
  /srv/myfinanzas-test/releases \
  /srv/myfinanzas-test/backups \
  /var/www/myfinanzas-test \
  /home/mftest/.config/containers/systemd; do
  if [ -n "$(find "$d" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    fail "contenido inesperado en $d"
  fi
done
if [ -e /srv/myfinanzas-test/data/state ] || [ -L /srv/myfinanzas-test/data/state ]; then
  fail "data/state no debe existir en 2B"
fi
if [ -e /var/www/myfinanzas-test/current ] || [ -L /var/www/myfinanzas-test/current ]; then
  fail "current no debe existir en 2B"
fi
if ss -ltn | grep -Eq '18082|3001'; then fail "puerto TEST inesperado"; fi

section "2B · evidencia posterior"
date -u +%Y-%m-%dT%H:%M:%SZ
id mftest
getent passwd mftest
getent group mftest
stat -c '%A %a %U:%G %n' \
  /srv/myfinanzas-test \
  /srv/myfinanzas-test/data \
  /srv/myfinanzas-test/releases \
  /srv/myfinanzas-test/backups \
  /var/www/myfinanzas-test \
  /home/mftest/.config \
  /home/mftest/.config/containers \
  /home/mftest/.config/containers/systemd
df -h /
df -i /

section "2B COMPLETADA"
echo "2A no repetida; data/state no creado; sin DNS, Caddy, servicios, app, Datasette, DB ni PROD."
