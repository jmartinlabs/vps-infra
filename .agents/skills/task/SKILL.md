---
name: task
description: Deliver a medium scoped feature through a short plan, concise acceptance criteria, implementation and verification.
---

# task

## Inputs
Read AGENTS.md, approved Standard classification, relevant guidelines, existing code, related specs and roadmap if present.
## Outputs
Concise task plan and acceptance checks, incremental implementation, verification and review evidence. Persist a task note only if work spans sessions or needs traceability.
## Procedure
1. Confirm scope, contracts, edge cases and acceptance criteria in a brief plan. Resolve material uncertainty before coding. Reuse existing approved documents.
2. Identify affected modules, tests, dependencies, execution platform and operation owners before code; preflight only what the scope needs. Follow [coordination](../../../specs/methodology/dynamic-agents.md) when delegating or a permission-sensitive step may suspend work. Prefer a short in-conversation mini-spec; use a persistent specs task document only when justified.
3. Implement in small steps. Write or update behavior-based tests and verify regressions. Report tests with commands, candidate/environment and actual results. Use focal checks per delta and required checks at the stable candidate gate; preserve independent QA and mandatory controls.
4. Inspect diff for security, correctness, maintainability and unrelated edits; update documentation if contracts changed.
5. If complexity rises to a new architectural boundary, multiple epics or unresolved product decisions, propose Full and await confirmation.
## Stop conditions
Stop at scope changes, security or destructive operations, conflicting requirements, or failed mandatory acceptance checks that cannot be corrected inside the authorized scope. Investigate and correct a correctable failure, then rerun the affected verification. Do not deploy or perform destructive operations without authorization; branch/PR publication follows [approvals](../../../specs/methodology/approvals.md#branch-and-pr-publication).
