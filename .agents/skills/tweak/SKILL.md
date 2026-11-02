---
name: tweak
description: Implement a small low-risk change or straightforward bug fix with minimal process and proportionate verification.
---

# tweak

## Inputs
Read AGENTS.md, affected code and applicable project guidelines. Use an authorized orchestrate Quick scope if available; load workflow or approval policy when classification or a gate is uncertain.
## Outputs
Minimal diff, relevant tests or clearly reported limitations, brief summary. No mandatory brainstorm/spec/progress files.
## Procedure
1. Verify the user clearly requested this change and it is understood, bounded, reversible, low risk and classified Quick, with no protected gate or stricter project restriction. State a one-line plan and proceed without additional confirmation only when these conditions hold. A consultation/analysis request or read-only Plan mode does not authorize implementation. Escalate if auth, payments, data migrations, public contracts, destructive operations or broad dependencies make it risky.
2. Identify expected behavior and a failing check when practical; inspect Git status and avoid unrelated files.
3. Implement minimal changes, run focused tests and relevant lint/type/build checks. For visual changes verify the affected UI if browser tooling is available; report inability plainly.
4. Review diff and regressions; report evidence and open limitations. Commit locally only if project workflow authorizes it.
## Stop conditions
Do not expand scope or declare unrun tests passed; do not deploy or destroy resources without explicit permission. Branch/PR publication follows [approvals](../../../specs/methodology/approvals.md#branch-and-pr-publication); respect local-only instructions.
