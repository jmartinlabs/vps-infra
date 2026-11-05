# Metodología de agentes · adopción completa

> **Estado:** harness completo adoptado en la revisión
> `71483712c4c25effa886d5433156c85246119667` de `agent-project-template` (2026-11-04),
> que incluye el adaptador OpenCode
> y sus validaciones. Validación estática en CI. Comportamiento real de Codex/Claude
> Code/OpenCode y cualquier acceso al VPS siguen **no verificados**.

> Actualización selectiva 2026-11-05: **ORCH-PROACTIVE-01** adoptado desde main
> `09a9935` (PR #44). No se declara adopción íntegra de esa revisión; se preservan
> las desviaciones locales y los gates del VPS.

> Actualización selectiva 2026-11-05: **AGENT-SIMPLIFICATION-01** adoptado desde
> `362e0e6` (PR #47) en lo aplicable: preferencia de delegación en trabajo autónomo
> sustancial, alcance DRAFT del rol funcional, adaptadores finos y campo de modo de
> ejecución en el paquete. Se conservan la revisión fijada, los gates del VPS, el
> adaptador de review y sus límites. No se adopta el resto de esa revisión.

## Origen

Fuente: [agent-project-template](https://github.com/jmartinlabs/agent-project-template),
revisión `71483712c4c25effa886d5433156c85246119667`. La revisión se fija para que una
actualización sea una decisión explícita, nunca un seguimiento automático de `main`.

## Qué se adopta

- Skills `init-project`, `bootstrap`, `roadmap`, `spec`, `dev`, `orchestrate`, `handoff`,
  `task`, `tweak`, `adopt-project` y `relay` en `.agents/skills/`.
- Perfiles `functional`, `implementation`, `qa-review` e `infrastructure` en `.agents/roles/`.
- Envoltorios de Claude Code en `.claude/skills/` y `.claude/agents/`, con `CLAUDE.md`.
- Metodología portable en `specs/methodology/`: flujos, aprobaciones, selección de modelo,
  épicas, agentes dinámicos (incluidos los modos directo/foreground/background),
  comunicación, escenarios de aceptación y política de CI.
- Plantillas de brainstorming, especificación, roadmap, progreso, testplan, tablero y
  paquete de trabajo.
- Evaluaciones deterministas en `evals/` y validadores en `scripts/`.
- Adaptador OpenCode opcional: `review` de solo lectura y especialistas `functional`,
  `implementation` e `infrastructure`, documentados en [OPENCODE_ADAPTER](OPENCODE_ADAPTER.md).
- Hooks locales de reporte de uso en `.codex/hooks.json` (advisory; no bloquean ni deciden).

## Desviaciones locales

- `AGENTS.md` conserva todas las restricciones de acceso al VPS, secretos, operaciones
  protegidas, merges y despliegues. La metodología no amplía ningún permiso.
- `specs/guidelines/` está adaptado a infraestructura; UI se declara **no aplicable** y las
  decisiones de arquitectura siguen en `docs/arquitectura.md`.
- No se copian `NEW_PROJECT_PROMPT.md` ni `ADOPT_EXISTING_PROJECT_PROMPT.md`: este proyecto
  no se reinicializa y no crea aplicaciones.
- La CI sigue siendo `.github/workflows/check-harness.yml` (job `validate`), ampliada con los
  validadores adoptados. No se sustituye por el workflow del template.
- `docs/`, `README.md` y los procedimientos operativos propios se mantienen como fuente local.

## Verificación

`python3 scripts/check_harness.py`, `./scripts/validate-template`, `./scripts/test-validator`,
`python3 scripts/eval-agent-behavior --self-test`, los tests de usage y el test de relay se
ejecutan en CI. `validate-template` incluye las comprobaciones estructurales del adaptador
OpenCode y de `scripts/review-read`; no se ejecutan los agentes. Son comprobaciones
estructurales y deterministas: no demuestran delegación real, aislamiento ni ahorro de tokens.

Pendiente: probar descubrimiento e invocación de cada Skill en Codex y Claude Code, observar
una delegación real si el cliente la soporta y auditar el VPS con autorización de solo lectura.

## Actualizaciones futuras

Comparar contra una revisión fijada y revisar el diff antes de aplicar. Las decisiones locales
y los gates de `AGENTS.md` prevalecen. Registrar aquí la nueva revisión y sus desviaciones.
