# Document ownership and workflow

`vps-infra` no es una aplicación: es la fuente versionada de la plataforma compartida. La
política local está en [`AGENTS.md`](../AGENTS.md); la arquitectura, el estado real, el roadmap
y los procedimientos viven en [`docs/`](../docs). Este directorio contiene contratos
metodológicos y, cuando una entrega Full lo justifique, documentos de feature.

Para clasificar trabajo: [Quick / Standard / Full](methodology/workflows.md),
[épicas](methodology/epic-orchestration.md) y [agentes dinámicos](methodology/dynamic-agents.md).
Los escenarios manuales están en [acceptance-scenarios](methodology/acceptance-scenarios.md).
El contrato de verificación y CI es [ci-policy](methodology/ci-policy.md).

| Documento | Posee | Actualizado por |
| --- | --- | --- |
| `docs/arquitectura.md` | Modelo de plataforma y fronteras | Usuario + revisión técnica |
| `docs/estado-actual.md` | Inventario y evidencias verificadas o pendientes | Cualquier tarea con evidencia |
| `docs/roadmap.md` | Prioridades y condiciones de aceptación | Roadmap/orchestrate |
| `docs/operaciones.md` | Procedimientos operativos y recuperación | Cambios operativos aprobados |
| `docs/metodologia-agentes.md` | Adopción del harness y desviaciones locales | Adopción/orchestrate |
| `specs/methodology/` | Contratos portables de coordinación | Cambios metodológicos aprobados |
| `specs/guidelines/` | Restricciones de arquitectura, UI, calidad y seguridad | Decisiones aprobadas |
| `specs/NN-slug-*.md` | Brainstorming, especificación, progreso y testplan de una entrega Full | `$spec` / `$dev` |
| `specs/epic-board.md` | Cola multiépica; nunca aprobaciones canónicas | Solo el coordinador |
| `specs/session-handoff.md` | Checkpoint de parada opcional; retirar tras una restauración correcta y consolidada; si está versionado, eliminarlo en el mismo cambio de la tarea, nunca en un PR independiente; no autoriza reanudar | `$handoff` |

Usa identificadores de dos dígitos y slugs en minúsculas; no sobrescribas documentos de otra
entrega. Las plantillas están en [`templates/`](../templates). Una recomendación no es una
aprobación: registra fuente y fecha en su ubicación canónica. El tablero y los checkpoints son
evidencia, nunca permiso.

El paquete de trabajo reutilizable está en [agent-work-packet](../templates/agent-work-packet.md).
Un único resumen vigente en el documento de progreso, setup o tablero posee el estado
operativo; los demás documentos lo enlazan.
