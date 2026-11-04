# 01 — INFRA-TEST-01: Entorno de pruebas de MyFinanzas — Brainstorming

Status: DRAFT — propuesta, sin respuestas confirmadas
Roadmap/context: [roadmap](../docs/roadmap.md), [arquitectura](../docs/arquitectura.md),
[estado actual](../docs/estado-actual.md), [contrato 01](01-entorno-test-myfinanzas-specification.md)
Next action: revisar las decisiones D1–D9 y confirmar o corregir; después aprobar la especificación 01.

## Round 1 — 2026-11-04

Objetivo de la ronda: fijar la arquitectura más sencilla para un entorno TEST aislado,
público por HTTPS y con datos exclusivamente ficticios, sin tocar el VPS en esta fase.

### D1 — Alcance del entorno

Pregunta: ¿un único entorno TEST en el VPS actual, separado del futuro PROD?

- [x] **Un único entorno TEST** en el mismo VPS, con estado, usuario, unidad, puerto y
  sitio Caddy propios; PROD no se crea en esta entrega — menor coste y permite validar
  el camino real de release, HTTPS, backup y recuperación.
- [ ] Un VPS o proveedor distinto para TEST — mayor aislamiento físico, pero añade coste,
  otra superficie de administración y no es necesario para datos ficticios.
- [ ] Reutilizar el sitio `myfinanzas.pp.ua` para TEST — riesgo de confundir entornos y
  de mezclar el placeholder actual con una aplicación; descartado como opción simple.

Confirmed answer: PENDING; source/date: PENDING

### D2 — Aislamiento de identidad rootless

Pregunta: ¿qué identidad de sistema ejecuta el contenedor TEST?

- [x] **Usuario dedicado `mftest`**, sin login SSH, con `subuid`/`subgid` propios y
  `linger`; el contenedor usa UID/GID interno 10001 mediante `keep-id`. Evita que TEST
  comparta identidad de host con un futuro PROD y limita el acceso accidental a datos
  ajenos. Coste: crear usuario y habilitar el gestor de usuario de systemd.
- [ ] Reutilizar `mfadmin` — menos pasos, pero TEST y PROD compartirían UID de host y
  la barrera entre ambos sería débil; no se considera aislamiento suficiente.
- [ ] Ejecutar como root o con `--privileged` — descartado: contradice la arquitectura
  y el runbook de la aplicación.

Confirmed answer: PENDING; source/date: PENDING

### D3 — Topología de red y puertos

Pregunta: ¿cómo llega el tráfico desde Caddy a la API?

- [x] **Caddy → `127.0.0.1:18082` → contenedor `3001`**. La API escucha
  `API_BIND_HOST=0.0.0.0` solo dentro de su namespace aislado; el host publica
  exclusivamente en loopback. No se publica la API ni SQLite en Internet.
- [ ] Publicar directamente `3001` o usar `--network=host` — expone superficie y rompe
  el aislamiento; descartado.
- [ ] Usar un socket Unix entre Caddy y la API — requiere cambios en la aplicación y no
  aporta una ventaja proporcionada para este caso.

Confirmed answer: PENDING; source/date: PENDING

### D4 — DNS y HTTPS

Pregunta: ¿cómo se publica `test.myfinanzas.pp.ua`?

- [x] **Registro DNS `test` (A, y AAAA si el VPS tiene IPv6) a la IP pública del VPS**,
  TTL bajo (300 s), sin wildcard y sin modificar el registro raíz. Si el dominio raíz
  usa un proxy/CDN, **no** se copia su destino al subdominio TEST. Caddy emite el
  certificado automáticamente por HTTP-01/TLS-ALPN con los puertos 80/443 ya previstos.
- [ ] Wildcard `*.myfinanzas.pp.ua` — amplía el alcance y el riesgo de certificado sin
  necesidad.
- [ ] Certificado manual — añade renovación y custodia manual; Caddy ya resuelve ACME.

Confirmed answer: PENDING; source/date: PENDING

### D5 — Exposición pública y control de acceso

Pregunta: ¿el entorno TEST será accesible desde cualquier red?

- [x] **HTTPS público con la autenticación propia de la aplicación** (contraseña + TOTP,
  sin registro público), más `X-Robots-Tag: noindex, nofollow`. Es lo más simple y
  permite revisar la aplicación desde cualquier ubicación. Los datos son ficticios; la
  app limita intentos por cuenta/origen, pero no se asume un rate limit de borde.
- [ ] Añadir allowlist de IP o Basic Auth en Caddy — reduce la superficie, pero añade
  un secreto de borde y puede impedir revisiones legítimas; queda como opción si el
  usuario prefiere restringir el acceso antes de publicar.
- [ ] Mantener TEST detrás de VPN — máximo aislamiento, pero añade infraestructura y
  complejidad no proporcionada para esta fase.

Confirmed answer: PENDING; source/date: PENDING

### D6 — Persistencia y datos ficticios

Pregunta: ¿cómo se crea y conserva el estado de TEST?

- [x] **Estado productivo limpio en `/srv/myfinanzas-test/data`**, inicializado con la
  CLI de producción de la aplicación; sin fixtures demo, sin Excel y sin datos reales.
  El propietario único se da de alta con el flujo de token temporal. Los datos ficticios
  se crean manualmente desde la UI y se documentan como conjunto de prueba reproducible.
- [ ] Arrancar con base demo y semillas de desarrollo — más rápido, pero no ejercita el
  camino productivo de identidad, setup, backup y restauración.
- [ ] Importar una copia de datos reales anonimizada — prohibido en esta fase; no hay
  autorización ni garantía de anonimización verificable.

Confirmed answer: PENDING; source/date: PENDING

### D7 — Copias y recuperación

Pregunta: ¿qué nivel de copia exige TEST?

- [x] **Copia cifrada local bajo demanda + copia fuera del VPS** antes de cada cambio
  relevante, con la CLI `age` de la aplicación y simulacro de restauración aislada. La
  copia externa va a un destino ya controlado por el usuario (equipo personal o
  almacenamiento aprobado), sin crear un proveedor nuevo ni un scheduler en TEST. La
  identidad privada `age` se custodia fuera del VPS y solo se monta temporalmente para
  restaurar. Sin copia externa no se despliega, salvo excepción expresa y registrada.
- [ ] Solo copia local — más simple, pero contradice el criterio de copia fuera del VPS
  de [operaciones](../docs/operaciones.md) y del [roadmap](../docs/roadmap.md).
- [ ] Copia externa con retención 7/4/3 y RPO 24 h/RTO 2 h — es el objetivo de PROD y
  añade proveedor, coste y custodia que no son necesarios para datos ficticios; TEST
  mantiene una copia externa mínima verificable, no un SLA de producción.
- [ ] Sin copias — reduce trabajo, pero impide verificar el procedimiento de recuperación
  que luego se exigirá en PROD; descartado.

Confirmed answer: PENDING; source/date: PENDING

### D8 — Frontera entre repositorios

Pregunta: ¿quién posee la unidad Quadlet y el sitio Caddy de TEST?

- [x] **`vps-infra` posee la configuración específica del host** (usuario, rutas, unidad
  TEST, sitio Caddy, DNS y runbook). **`myfinanzas-app` posee el contrato de runtime**
  (imagen, UID, hardening, healthcheck, variables, CLI de init/setup/backup, esquema y
  evidencia de release). `vps-infra` revisa su unidad contra el contrato de la app en
  cada release. Evita un cambio de código de la aplicación solo para un entorno.
- [ ] Extender `infra/runtime.py` de la app para parametrizar origen/puerto/nombre — útil
  si aparecen más entornos, pero exige una entrega en `myfinanzas-app` y no es necesaria
  para un único TEST; queda como mejora futura.
- [ ] Duplicar la unidad sin revisión contra el contrato de la app — riesgo de deriva de
  seguridad; descartado.

Confirmed answer: PENDING; source/date: PENDING

### D9 — Operación y observabilidad

Pregunta: ¿qué operación mínima se implanta?

- [x] **systemd de usuario + healthcheck de la aplicación + logs de Caddy/systemd**,
  con verificación manual y sin nueva plataforma de monitorización. Mantiene el coste y
  la superficie mínimos en 2 vCPU/4 GB.
- [ ] Añadir Prometheus/Grafana o alertas residentes — no proporcionado para TEST y
  consume recursos del VPS compartido.
- [ ] No verificar salud ni logs — impide detectar fallos de despliegue; descartado.

Confirmed answer: PENDING; source/date: PENDING

## Coverage

- **Requisitos funcionales:** servir la aplicación MyFinanzas en
  `https://test.myfinanzas.pp.ua`; autenticación de propietario único; datos ficticios;
  healthcheck; frontend estático; API bajo `/api/*`.
- **Interfaces:** DNS, Caddy/HTTPS, loopback 18082, puerto interno 3001, unidad Quadlet,
  raíz estática, CLI de inicialización/setup/backup/restore.
- **Datos leídos/escritos:** SQLite y clave de autenticación en el estado privado;
  frontend estático; copias cifradas; logs técnicos. Nunca datos reales, Excel, secretos
  en Git/PR/chat.
- **APIs y dependencias externas:** release de `myfinanzas-app`, gate Rootless de GitHub
  Actions, Podman/Quadlet/systemd, Caddy, DNS del proveedor, `age`.
- **Validación:** criterios AC-01–AC-25 de la [especificación](01-entorno-test-myfinanzas-specification.md).
- **Errores y casos límite:** DNS no propagado, certificado no emitido, 502, 401/403,
  start-limit, estado ya existente, permisos/UID incorrectos, manifiesto no verificado,
  disco lleno, reinicio, pérdida de clave/TOTP, rollback incompatible, decommission.

## Wireframes

No aplica: no se diseña una interfaz nueva. La UI es la de `myfinanzas-app`; esta
especificación solo fija el contrato no visual de despliegue. No se requieren wireframes.

## Append-only clarifications

No hay respuestas confirmadas todavía. Las opciones marcadas `[x]` son **propuestas
técnicas**, no aprobaciones del usuario. Cualquier respuesta posterior se añadirá aquí
con su fuente y fecha, sin reescribir las preguntas anteriores.
