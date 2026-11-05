# AGENTS.md · Mi VPS / Infraestructura

Estas instrucciones aplican a todo el repositorio `vps-infra` y a cualquier agente que trabaje en él. Su ámbito es la **infraestructura compartida**, no la lógica ni el código interno de las aplicaciones alojadas.

## Antes de trabajar
1. Leer `README.md`, `docs/arquitectura.md`, `docs/estado-actual.md`, `docs/roadmap.md` y, si corresponde, `docs/operaciones.md`.
2. Consultar el estado real del repositorio, ramas, PR, dependencias y autorizaciones. La documentación del servidor es una hipótesis hasta verificarla.
3. Cargar on demand solo lo aplicable: [arquitectura](specs/guidelines/architecture.md), [UI](specs/guidelines/ui.md), [calidad](specs/guidelines/quality.md) y [seguridad](specs/guidelines/security.md).
4. Registrar objetivo, alcance, riesgo, dependencias, pruebas y vía de recuperación. Separar hechos observados, información recibida y propuestas.
5. Consultation/analysis nunca autoriza cambios. Project-specific restrictions prevalecen sobre atajos genéricos.

## Responsabilidades y límites
- **Usuario:** aprueba decisiones materiales, creación/integración de repositorios, acceso al VPS, merges, despliegues y cambios operativos.
- **Álex:** coordina, revisa arquitectura, seguridad, dependencias y evidencias; recomienda la opción sencilla y segura.
- **Codex:** prepara cambios, pruebas y PR dentro del alcance expresamente autorizado.
- **Repositorios de aplicaciones:** tienen sus propios `AGENTS.md`, decisiones y pruebas. No modificar aplicaciones ajenas sin causa justificada y autorización.

## Autorización y seguridad
- **No acceder al VPS (ni para leerlo)** sin autorización expresa para ese alcance. Un PR o una aprobación documental no autoriza acceso.
- Sin cambios en servidor, firewall/UFW, SSH, usuarios/permisos, DNS, dominio, Caddy, certificados, Podman/Quadlet, almacenamiento, tareas programadas o servicios activos sin autorización específica.
- No ejecutar merges, releases, despliegues, borrados, migraciones, restauraciones ni rollback operativo sin aprobación expresa. Nunca auto-merge.
- Sin secretos, claves, credenciales ni datos personales/financieros reales en repositorio, PR, logs o chat.
- Nunca eliminar recursos ni sobrescribir datos sin inventario de impacto y plan de recuperación comprobable.
- Respetar disponibilidad y datos de todas las aplicaciones del VPS.
- «ok», «dale» o «continúa» no autorizan merge, despliegue, acceso remoto ni operaciones protegidas.

## Git y pull requests
- Rama por entrega, nunca en `main` salvo inicialización expresa. Preservar commits y trabajo de terceros.
- Revisar rutas, commits y diff completo antes de publicar; no confiar solo en `.gitignore`.
- Publicar rama y PR es trabajo ordinario dentro del alcance autorizado, conforme a [publicación](specs/methodology/approvals.md#branch-and-pr-publication); el merge exige aprobación explícita e identificable de ese PR.
- Distinguir pruebas ejecutadas, no ejecutadas y fallidas. No maquillar fallos.
- Tras un merge autorizado, verificar el resultado y dejar el checkout limpio. El despliegue sigue siendo otra autorización.

## Coordinación
- [$orchestrate](.agents/skills/orchestrate/SKILL.md), [flujos](specs/methodology/workflows.md), [aprobaciones](specs/methodology/approvals.md) y [comunicación](specs/methodology/coordinator-communication.md).
- [Agentes dinámicos](specs/methodology/dynamic-agents.md), [modelos](specs/methodology/model-selection.md), [épicas](specs/methodology/epic-orchestration.md) y [roles](.agents/roles/README.md) on demand.
- El coordinador mantiene identificados los siguientes trabajos del roadmap y sus dependencias; mientras algo avanza o espera, prepara SPEC, investigación, paquete DEV ya autorizado o diseño QA sin cruzar gates. Replanifica ante resultados o bloqueos y deja una siguiente acción verificable; no crees trabajo artificial ni un segundo scheduler.
- Un ejecutor por defecto; QA independiente al candidato. Escritores concurrentes necesitan ownership disjunto y aislamiento efectivo; worktrees según [la política canónica](specs/methodology/approvals.md#local-worktrees); si no hay aislamiento, serializar.
- Continue authorized work hasta completar o encontrar un bloqueo real, según [execution-continuity](.agents/skills/orchestrate/SKILL.md#execution-continuity).
- Sin subagentes fingidos, servicios residentes ni trabajo prometido entre sesiones.
- [$handoff](.agents/skills/handoff/SKILL.md) consolida y detiene; Agent Relay es transporte solo bajo petición explícita.

## Calidad y operación
- Diferenciar diseño, implementación, validación local/CI, integración y despliegue verificado.
- Configuración compartida: evaluar aislamiento, privilegios, exposición, persistencia, secretos, límites, backups y reversibilidad.
- No afirmar que una configuración documentada está operativa; para verificaciones remotas pedir antes el alcance de acceso.
- Documentación útil y mínima; no duplicar historiales de chat.

## Entrega y parada
Informar qué se preparó, qué se probó, qué sigue sin verificar, riesgos y siguientes acciones. Detenerse al agotar el alcance autorizado o ante riesgos materiales, conflictos o acceso insuficiente.
