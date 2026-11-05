# Operaciones y recuperación · Borrador de procedimientos

> **Salvo la actualización de Caddy de 2026-11-05 ([cierre](auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md)), no ejecutado ni validado en el VPS.** Este documento fija los controles que deberá tener cada procedimiento. La auditoría de solo lectura y cualquier actuación posterior requieren autorizaciones distintas.

## Ciclo de cambio controlado

1. Definir objetivo, sistemas afectados, responsable, ventana y riesgos compartidos.
2. Verificar inventario real y contratos con aplicaciones; identificar cambios de DNS, firewall, SSH, Caddy, Podman/Quadlet, datos o permisos.
3. Preparar cambios reproducibles en rama y PR, con prueba aislada y revisión de diferencias y secretos.
4. Diseñar restauración/rollback **antes** de cualquier cambio con riesgo de impacto.
5. Solicitar aprobación explícita del merge y **otra autorización de operación/despliegue** si aplica.
6. Aplicar solo el cambio autorizado, comprobar healthchecks, HTTPS y regresiones de otros servicios.
7. Registrar resultado real, alertas y plan de vuelta atrás actualizado.

No usar un rollback que pierda escrituras confirmadas; cambios de aplicación, esquema y datos pueden exigir restauración o procedimiento de recuperación coordinado.

## Auditoría solo lectura (futura)

- Comprobar SO, acceso administrativo, puertos, reglas efectivas, servicios y logs **sin cambiar estado**.
- Revisar Caddy/TLS, Podman rootless, Quadlet y volúmenes desde metadatos seguros; no volcar secretos, bases o contenidos de backups.
- Evaluar consumo de disco/inodos, memoria, ciclo de parches y caducidad de certificados.
- Entregar informe con evidencia, fecha, riesgos y diferencia entre configuración real y documentada.
- Detenerse ante solicitudes de elevación, acceso no contemplado o información sensible; requerir nuevo permiso.

## Copias y recuperación (diseño pendiente)

Antes de usar datos importantes definir:
- **Alcance:** datos persistentes de cada aplicación, configuración necesaria para restaurar, metadatos de versión/esquema y claves bajo custodia separada.
- **Consistencia:** mecanismos compatibles con cada motor; para SQLite no equiparar una copia directa del archivo en uso con backup consistente bajo WAL.
- **Destino:** al menos una copia **fuera del VPS**, cifrada, acceso de mínimos privilegios y protección ante eliminación accidental/compromiso.
- **Política:** frecuencia, retención, límites del disco de 40 GB, RPO/RTO, comprobación de integridad y alertas de fallos.
- **Verificación:** restauración periódica en un entorno aislado con datos ficticios; comprobar que la aplicación recupera datos y acceso sin afectar producción.
- **Responsables:** dónde viven los procedimientos específicos de MyFinanzas frente a la política común; sin almacenar claves privadas en Git ni en informes.

No afirmar «backup funcionando» hasta comprobar copias recientes y al menos un restore con criterios definidos.

## Despliegue de nueva aplicación (borrador)

Confirmar owner y repositorio, imagen/versiones verificadas, usuario rootless, puertos internos, rutas de persistencia, secretos fuera de Git, límites de recursos y disponibilidad de backup/rollback. Acordar con `vps-infra` solo la entrada Caddy, dominio y controles comunes.

La recepción y activación de releases por tag se rige por el
[contrato de despliegue por tags](despliegue-por-tags.md). Es un **diseño no habilitado**:
hasta su aprobación e implementación, el despliegue sigue siendo manual y conserva todos
los gates de esta guía y del runbook de la aplicación.

Probar de forma aislada los cambios de Quadlet/Caddy y simular recuperación. Solicitar autorización específica antes de poner el servicio en marcha, cambiar DNS, publicar puertos o sustituir la página de prueba.

## Incidencias

Prioridad inicial: proteger datos y aplicaciones existentes, constatar alcance y preservar evidencia redactada; evitar acciones automáticas destructivas. Registrar síntomas, inicio, servicios afectados, cambios recientes, decisiones, resultado y medidas preventivas. Cualquier intervención que modifique el VPS requiere el alcance de autorización correspondiente.

## Mantenimiento y observabilidad

Tras la auditoría concretar responsables y periodicidad de revisión de parches, logs, caducidad TLS, espacio/inodos, memoria, disponibilidad y fallos de copia. Preferir checks simples y útiles antes que desplegar una pila completa de observabilidad.

## Caddy: versión fijada y revisión

Caddy **2.11.9** (repositorio estable oficial Cloudsmith) está en `apt-mark hold` desde el
2026-11-05. Revisar **mensualmente** el repositorio oficial, los avisos de seguridad de Caddy y
el Debian Security Tracker. Si hay una versión corregida, `unhold` solo en una ventana
autorizada y repetir la [especificación](../specs/03-caddy-upgrade-01-specification.md) y la
[preflight](../specs/03-caddy-upgrade-01-preflight.md), con QA y rollback disponible. No dejar
el `hold` sin revisión. Detalle: [cierre VPS-CADDY-UPGRADE-01](auditorias/2026-11-05-vps-caddy-upgrade-01-cierre.md).
