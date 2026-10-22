# AGENTS.md · Mi VPS / Infraestructura

Estas instrucciones aplican a todo el repositorio `vps-infra` y a cualquier agente que trabaje en él. Su ámbito es la **infraestructura compartida**, no la lógica ni el código interno de las aplicaciones alojadas.

## Antes de trabajar

1. Leer `README.md`, `docs/arquitectura.md`, `docs/estado-actual.md`, `docs/roadmap.md` y, si corresponde, `docs/operaciones.md`.
2. Consultar el estado **real** del repositorio, ramas, PR, dependencias y autorizaciones. La documentación del servidor es una hipótesis hasta ser verificada.
3. Registrar objetivo, alcance, riesgo, dependencias, pruebas y vía de recuperación. Separar hechos observados, información recibida y propuestas.
4. Prioridad de fuentes: última decisión expresa del usuario → estado real verificado → documentación y código vigentes → antecedentes. No extrapolar autorizaciones.

## Responsabilidades y límites

- **Usuario:** aprueba decisiones materiales, creación/integración de repositorios, acceso al VPS, merges, despliegues y cambios operativos.
- **Álex:** coordina, revisa arquitectura, seguridad, dependencias y evidencias; recomienda la opción sencilla y segura.
- **Codex:** prepara cambios, pruebas y PR dentro del alcance expresamente autorizado.
- **Repositorios de aplicaciones:** tienen sus propios `AGENTS.md`, decisiones y pruebas. No modificar aplicaciones ajenas para resolver infraestructura sin causa justificada y autorización.

## Autorización y seguridad: barreras obligatorias

- **No acceder al VPS (ni siquiera para leerlo)** sin autorización expresa para el alcance de acceso. Una aprobación documental o un PR no autoriza acceso.
- No aplicar cambios en servidor, firewall/UFW, SSH, usuarios/permisos, DNS, dominio, Caddy, certificados, Podman, Quadlet, almacenamiento, tareas programadas o servicios activos sin autorización específica.
- No ejecutar merges, releases, despliegues, borrados, migraciones, restauraciones ni rollback operativo sin aprobación expresa. No activar auto-merge.
- No crear ni utilizar secretos reales, claves privadas, credenciales o datos personales/financieros en el repositorio, PR, logs o chat; utilizar nombres ficticios, valores redactados y referencias externas seguras.
- Nunca eliminar recursos ni sobrescribir datos sin inventario de impacto y plan de recuperación comprobable. Priorizar ensayos aislados y reversibles.
- Respetar disponibilidad y datos de **todas** las aplicaciones existentes. No dar por supuesto que el VPS está dedicado a MyFinanzas.
- La autorización de una tarea **no** habilita automáticamente otras, aunque compartan tecnología o los tests pasen.

## Git y pull requests

- Verificar la rama base, sus cambios recientes y los PR abiertos antes de actuar. Preservar commits y trabajo de terceros.
- Trabajar en una rama específica por entrega, **nunca directamente en `main`**, salvo inicialización mínima del repositorio expresamente autorizada.
- Revisar archivos cambiados, **todos los commits que se publicarán**, su contenido y el diff final para impedir publicación de secretos o datos; no confiar exclusivamente en `.gitignore` o en un escáner.
- Ejecutar validaciones pertinentes al cambio; distinguir pruebas ejecutadas, no ejecutadas y resultados fallidos. No maquillar fallos.
- Publicar rama y PR con alcance, riesgos, pruebas, evidencia, dependencias, posibles efectos en aplicaciones y rollback. No fusionar sin aprobación explícita **de ese PR**.
- Tras un merge autorizado, comprobar su resultado y el estado del repositorio. Despliegue al VPS sigue siendo otra autorización.

## Coordinación, skills y subagentes

- Leer [metodología adaptada](docs/metodologia-agentes.md) y las skills locales [`$orchestrate`](.agents/skills/orchestrate/SKILL.md), [`$task`](.agents/skills/task/SKILL.md), [`$tweak`](.agents/skills/tweak/SKILL.md). Están versionadas en este repositorio, pero **su descubrimiento/invocación en Codex no está verificado**. Si el cliente no reconoce una skill, leer su archivo expresamente; no suponer que hay subagentes activos.
- Un coordinador puede descomponer y delegar tareas **ya autorizadas**; cada paquete define objetivo, propiedad de archivos, dependencias, alcance de escritura, criterios de salida y límites.
- Usar el menor número de especialistas útil. Las revisiones de seguridad y QA pueden ser independientes, pero **un perfil documental no equivale a un agente activo**.
- Lecturas paralelas pueden compartir checkout. Para escrituras paralelas exigir propiedad disjunta **y aislamiento efectivo** (worktrees/checkouts separados) dentro del alcance ya autorizado; comprobar estado y cambios preexistentes. Si no es seguro, serializar.
- En una tarea Git autorizada, gestionar ramas/worktrees temporales propios y limpios es una operación ordinaria; no implica permiso para acceso al VPS, despliegue, merge o destrucción. No descartar trabajo ajeno; limpiar solo recursos propios sin trabajo pendiente.
- No crear servicios residentes, frameworks de orquestación ni nuevas dependencias sin justificación y aprobación de arquitectura.
- Sin herramientas de delegación reales, ejecutar en secuencia. No fingir subagentes ni trabajo entre sesiones.

## Calidad y operación

- Diferenciar siempre **diseño**, **implementación**, **validación local/CI**, **integración** y **despliegue verificado**.
- Configuración compartida: evaluar aislamiento, privilegios, exposición de red, persistencia, secretos, límites de recursos, backups y reversibilidad.
- Aplicaciones: definir contratos mínimos de despliegue; sus pruebas de negocio, esquema y datos corresponden a su repositorio.
- No afirmar que una configuración documentada está operativa; para verificaciones remotas pedir el alcance de acceso antes de actuar.
- Documentación útil y mínima: actualizar inventario, decisiones y procedimientos cuando exista evidencia, no duplicar extensamente historiales de chat.

## Entrega y parada

Informar qué se ha preparado, qué se ha probado, qué sigue sin verificar, riesgos y acciones propuestas. Detenerse al agotar el alcance autorizado o ante riesgos materiales, conflictos, acceso insuficiente o cambios ajenos no reconciliados.
