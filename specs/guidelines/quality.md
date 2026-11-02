# Quality guidelines

## Comandos canónicos
- `python3 scripts/check_harness.py` — estructura y restricciones del harness local.
- `./scripts/validate-template` — estructura, enlaces, manifiestos y contratos.
- `./scripts/test-validator` — fixtures positivos y negativos del validador.
- `python3 scripts/eval-agent-behavior --self-test` — evaluador determinista y fixtures.
- `python3 scripts/test-agent-usage` y `python3 scripts/test-auto-agent-usage`.
- `python3 scripts/test-agent-relay` — protocolo de relay de dos participantes.
- `node scripts/check-mermaid.mjs docs/GUIA_VISUAL_ORQUESTACION.md` — requiere los paquetes
  Node fijados en CI (`mermaid@11.12.1`, `jsdom@26.1.0`).

Todo se ejecuta en CI mediante `.github/workflows/check-harness.yml`; no se sustituye por
un workflow distinto ni se permite `continue-on-error`.

## Evidencia
Distinguir PASS, FAIL y UNRUN; identificar candidato (commit), entorno y comando. Un test
estático no demuestra comportamiento real de un cliente ni acceso al VPS. La QA
independiente revisa el candidato; no basta el informe del autor.

## Definition of Done
Cambio dentro del alcance autorizado, diff revisado, checks aplicables en PASS, riesgos y
verificaciones pendientes declarados y PR publicado. El merge y el despliegue son
aprobaciones separadas.

## Clasificación de checks
La selección de perfiles vive en [ci-policy](../methodology/ci-policy.md). La evidencia es el
actual classifier and workflow behavior, no el nombre de un archivo: A Markdown extension alone is insufficient. Las
exclusiones protegidas prevalecen (protected exclusions taking precedence) y no se omite un
check crítico por una allowlist. Aplicar one canonical verification command, reusing an adequate existing one; si el riesgo lo exige, usar forced full mode.
