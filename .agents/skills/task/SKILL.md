---
name: task
description: Ejecuta una tarea acotada de infraestructura aprobada con plan breve, pruebas y revisión.
---

# Task · VPS

## Entradas
Leer `AGENTS.md`, `docs/metodologia-agentes.md` y documentación aplicable; confirmar clasificación Standard, alcance exacto y permisos del usuario.

## Procedimiento
1. Describir objetivo, sistemas afectados, dependencias, criterios de aceptación, riesgos y reversión en un plan breve. Verificar repositorio y trabajo ajeno.
2. Separar preparación local/documental de **acceso al VPS** y de **cambios en servicios reales**: cada uno exige autorización específica. Una tarea de desarrollo no concede permisos remotos implícitos.
3. Preparar cambio mínimo en rama, o inspección autorizada de solo lectura; no almacenar credenciales ni volcar datos sensibles en evidencias.
4. Ejecutar únicamente pruebas permitidas y pertinentes. Cuando existan datos/servicios importantes, comprobar que el plan no los pone en riesgo.
5. Revisar todos los commits a publicar y el diff, documentar resultados PASS/FAIL/BLOCKED/NO EJECUTADO y crear PR según `AGENTS.md`. El merge necesita aprobación propia.

## Parada
Escalar a Full ante autenticación, firewall, exposición a Internet, despliegue, migración, backups/restore, eliminación, cambios irreversibles o impacto transversal. Detenerse antes de operaciones no autorizadas o cuando falte evidencia.
