# Metodología de agentes para infraestructura

> **Propuesta de adopción documental en PR #2**. No desplegada ni probada en un cliente Codex real. Ningún permiso nuevo para operar el VPS.

## Origen y adaptación

Fuente: [agent-project-template](https://github.com/josemartin2000/agent-project-template), revisión `c8fd38522b449f7cdc463a9f248a46a125fdd324`, documentada como **v2.3.1**.

Componentes adaptados:
- Skills `orchestrate`, `task` y `tweak` en `.agents/skills/`.
- Perfiles `infrastructure` y `qa-review` en `.agents/roles/`.
- Este contrato ligero; conservamos `AGENTS.md` y los documentos de arquitectura/operaciones existentes.

No se copiaron `$init-project`, `$bootstrap`, `$roadmap`, `$spec`, `$dev`, `$adopt-project`, los perfiles financieros/funcionales, el tablero de épicas, la CI de plantilla ni dependencias nuevas: **no son necesarios para la auditoría inicial**. El alcance Full se puede gestionar mediante planificación, decisiones, pruebas y PR sin esas skills. Si surge una necesidad real, evaluar después la importación selectiva.

## Uso desde Codex

1. Abrir `vps-infra` en Codex con el repositorio sincronizado tras la integración aprobada.
2. Leer `AGENTS.md` y la documentación de estado. En cliente que reconozca skills locales, solicitar `$orchestrate`. Si no aparece, pedir que lea explícitamente `.agents/skills/orchestrate/SKILL.md`. **El reconocimiento en Codex Desktop/Web todavía no está verificado**.
3. Antes de ejecutar, clasificar la tarea y confirmar límites, pruebas, permisos y autorizaciones. La primera auditoría prevista requiere **autorización separada para acceso remoto de solo lectura**.
4. Preparar cambios Git solo dentro del alcance aprobado; PR a revisión, sin merge autónomo.
5. Si Codex no soporta subagentes en la sesión, seguir las mismas reglas en una única ejecución secuencial.

## Niveles de trabajo

| Nivel | Ejemplo | Pruebas y autorización |
| --- | --- | --- |
| Quick → `$tweak` | Corregir un enlace o documento del repositorio | Verificar alcance, diff y política de PR |
| Standard → `$task` | Preparar checklist, informe o automatización local aislada | Plan breve, criterios y comprobaciones |
| Full → `$orchestrate` + plan específico | Seguridad, cambio de Caddy/UFW, despliegue, backup/restore | Decisiones aprobadas, plan de recuperación, pruebas, PR y permiso operativo separado |

**El riesgo manda, no las líneas cambiadas.** Una sola instrucción de firewall puede ser Full. Las skills no constituyen permiso de SSH ni activan subagentes o despliegues automáticamente.

## Delegación

Los perfiles son descripciones de funciones, no agentes residentes. El coordinador puede usar el perfil de Infraestructura para inventario/implementación y QA para inspeccionar evidencias de forma independiente **solo si el cliente soporta delegación real y el trabajo lo justifica**.

Cada encargo incluye:
- Identificador, objetivo y resultado verificable.
- Fuente de aprobación y dependencias.
- Entorno/repo/rama, **lecturas permitidas** y **escrituras permitidas**.
- Aislamiento/ownership y prohibiciones (SSH, secretos, producción, merge, etc.).
- Comprobaciones y formato de retorno (PASS/FAIL/BLOCKED/NO EJECUTADO, commit y observaciones).

Coordinar siempre antes de escribir en paralelo; sin aislamiento efectivo, serializar. No confundir otro chat con un agente gestionado por Codex.

## Controles que prevalecen

`AGENTS.md` es la política local: el usuario conserva control explícito de accesos, cambios en la infraestructura, decisiones materiales, merges y despliegues. Aprobar especificación, implementación o PR no implica autorización de la etapa siguiente. Nada se ejecuta remotamente durante la adopción de metodología.

## Validaciones pendientes

- Probar descubrimiento/invocación de cada skill en un cliente Codex **después de integrar** el PR.
- Si se pretende delegar, verificar que el cliente realmente inicia agentes y aísla escrituras.
- Validar flujo simulado Quick/Standard/Full con datos ficticios antes de tareas operativas reales.

Este documento no reemplaza `docs/operaciones.md` ni declara el VPS auditado.
