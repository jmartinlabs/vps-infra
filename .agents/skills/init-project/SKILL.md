---
name: init-project
description: Start or resume interactive project initialization, from identity to an approved roadmap.
---

# init-project

## Inputs
Read `AGENTS.md`, `specs/README.md`, existing state and applicable guidelines before acting.
## Outputs
`specs/project.md`, canonical guidelines, `specs/setup-progress.md`, a verified bootstrap
and an approved `specs/roadmap.md`. Never generate an application inside the template itself.
## Procedure
- Inspect existing code, references and documents first.
- In the template itself: help create or open an independent derived repository (publishing needs authorization).
- Already in a derived project: do not clone again. Prefer the current checkout; use the
  [local worktree policy](../../../specs/methodology/approvals.md#local-worktrees) if isolation helps.

### Resume protocol
- If `specs/setup-progress.md` exists, read it and follow its next action. Check that linked
  outputs still exist and match the evidence; reconcile stale or conflicting state with the
  user instead of restarting or trusting a ticked box.
- If it is missing, rebuild it from existing documents and code; confirm anything ambiguous.
- Save progress before every pause and after every completed stage, in this shape:

```markdown
# Setup progress
Current stage: 1
| Stage | Status | Evidence / canonical decision links |
| --- | --- | --- |
| 1 Identity | pending | |
| 2 Technology | pending | |
| 3 Architecture | pending | |
| 4 Bootstrap | pending | |
| 5 Guidelines | pending | |
| 6 Roadmap | pending | |
| 7 Handoff | pending | |
## Confirmed decisions
Links to canonical guideline sections and approval records only.
## Pending decisions
Unanswered questions; recommendations remain unapproved.
## Next action
One concrete action or exact question to resume.
```

- Status values: pending, awaiting-approval, in-progress, blocked, complete.
- Store each architectural choice once, in the guidelines; progress only links to it. Record the user's actual approvals.
- Ask in small rounds (1–3 related questions), skip known answers, explain trade-offs and recommend.
- A default, a recommendation or elapsed time is **never** an approval. Silence keeps a stage awaiting-approval.

### Stage 1 — Identity
Ask name, objective, target users, system type, main problem and existing code, documents or
references. Save confirmed product context in `specs/project.md`.
### Stage 2 — Technology
Discuss only relevant choices (frontend, backend, language, database, API, auth, testing, hosting).
Compare viable options and recommend with reasons. Record approved choices in the guidelines.
Wait for approval of material decisions.
### Stage 3 — Architecture
Propose structure, module responsibilities and communication, data ownership and persistence,
dependencies, security and testing. Record open issues. Get approval of material boundaries before code.
### Stage 4 — Bootstrap
Follow the bootstrap Skill. Verify the real end-to-end flow and tests before marking complete;
a running process alone is not enough.
### Stage 5 — Guidelines
Document the implemented architecture and approved rationale. Complete architecture, UI, quality
and security guidelines; mark inapplicable areas with reasons. Update AGENTS.md with the project
description, real commands and links. Add enforceable checks (tests, linters, CI) proven on valid
and invalid cases; do not invent agent hooks.
### Stage 6 — Roadmap
Follow the roadmap Skill. Get approval and commit the initial roadmap.
### Stage 7 — Handoff
Summarize decisions (by link), technologies, architecture, verified bootstrap, documentation,
roadmap and open questions. Explain the next steps: spec 01, then dev 01. Mark complete only when
every required stage has evidence and no blocking question remains.
## Stop conditions
Pause at each unanswered material choice, conflicting prior decision, missing prerequisite or
required authorization. Save the pending question and next action first, and resume at that
point, not from stage 1. No unapproved feature implementation.
