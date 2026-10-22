---
name: orchestrate
description: Coordina trabajos autorizados de infraestructura VPS con flujo Quick Standard Full, aprobaciones y verificación.
---

# Orchestrate · VPS compartido

Adaptación selectiva de `agent-project-template` v2.3.1. No es un servicio residente y **no implica que el cliente admita subagentes reales**.

## Entradas

Leer `AGENTS.md`, `README.md`, `docs/arquitectura.md`, `docs/estado-actual.md`, `docs/roadmap.md`, `docs/operaciones.md`, `docs/metodologia-agentes.md`, estado Git, PR y autorizaciones vigentes.

## Procedimiento

1. Comprobar alcance y permisos **antes** de abrir conexiones, ejecutar comandos remotos o proponer escrituras. Para inventarios históricos distinguir afirmaciones del usuario, evidencia de GitHub y observaciones verificadas del servidor.
2. Clasificar por riesgo: **Quick** (documentación/corrección local pequeña sin impacto operativo), **Standard** (tarea delimitada con pruebas), **Full** (seguridad, accesos, firewall, Caddy, despliegues, datos, backups/restore u otra operación con efectos relevantes). Proponer alcance, evidencias, pruebas, dependencias, rollback y autorizaciones; pedir confirmación del flujo antes de actuar. No reabrir decisiones aprobadas sin incompatibilidad demostrada.
3. Quick puede ir a `$tweak`, Standard a `$task`. Full utiliza análisis, especificación del cambio y plan de reversión apropiados en este repositorio: **no requiere instalar `$spec`/`$dev`** ni reconstruir el proyecto. Para cualquier cambio material exigir aprobación expresa de la decisión correspondiente.
4. Determinar si existen trabajos independientes. Usar el menor grupo que aporte valor; perfiles en `.agents/roles/`. Pasar a cada delegado un contrato acotado: objetivo, autorización, entorno, límites de lectura/escritura, rutas, propietario, aislamiento, evidencias, prohibiciones, condiciones de salida y reporte. Si no existen subagentes reales, ejecutar secuencialmente sin fingir delegación.
5. Leer en paralelo solo cuando sea seguro; escrituras simultáneas necesitan archivos disjuntos y aislamiento real. Si no puede verificarse, serializar. La creación de un subagente **no amplía** la autorización de acceso al VPS ni a repositorios ajenos.
6. Tras cada trabajo, comprobar salidas, pruebas y diff reales. Separar PASS/FAIL/BLOCKED/NO EJECUTADO. Actualizar documentación canónica cuando corresponda y preparar PR revisable.
7. Antes de merge, acceso remoto, cambios operativos y despliegues, aplicar las barreras de `AGENTS.md`. **Una PR aprobada y fusionada no autoriza un despliegue.** Ninguna tarea prosigue entre sesiones por el hecho de existir una skill.

## Resultado

Clasificación, alcance autorizado, ejecución y evidencias, riesgos abiertos, PR/commit si procede, dependencias y próximo paso. Detenerse si el permiso es insuficiente, aparecen secretos, hay conflicto o surge un riesgo material no aprobado.
