# Epic orchestration

For Full work, or Standard work with several independent workstreams. It extends
[adaptive workflows](workflows.md); roadmap, spec and dev still apply. Quick stays single-stream.

## Board and single writer

- Keep `specs/epic-board.md` only when several live epics or workstreams need scheduling. A single bounded feature uses its own progress and testplan.
- The coordinator is the **single writer** of the board. Delegates return outcomes, SHA and test evidence; they never edit the board.
- Reconcile the board at session start and at major gates against approved specs, checkpoints, Git and tests. Mark missing evidence `unknown` or `unverified`; never infer approval.
- Update only fields that materially change (ownership, authorization, candidate, QA verdict, blocker, PR state), not on every worker message.
- Link one current summary; after integration replace stale pending labels with verified
  SHA/PR/check state and retain the historical record as superseded.
- Each row: unique feature ID, stage, scope and hard dependencies, approval, assigned role, isolated branch/checkout, blockers, evidence link, next action, last verification.
- A ready task is not an approved spec. An open PR is not a merge.

## Stages and gates

- **spec:** planned → drafting → awaiting-approval → approved. Drafts and brainstorming may be prepared autonomously; **only the user approves** functional or financial decisions and the final spec.
- **dev:** not-ready → ready → implementing → testing/review → verified. Ready only with a recorded **approved** spec, satisfied hard dependencies and authorization for the scope. Without an approved spec, implementation cannot start; QA may still draft test cases.
- **QA:** planned → test-design → awaiting-implementation → verifying → passed/failed/blocked. Never report a pass before running against the actual candidate.
- **merge:** published or draft PR → ready-for-user-review → user-approved → merged. Never auto-merge. Merging is a separate approval gate per [approvals](approvals.md).

## Scheduler (at milestones, not every message)

1. On resume, check Git/PR/approval changes since the last trusted checkpoint; read only what the next gate needs. Reload full sources when stale, conflicting or needed for safety.
2. Mark work blocked only for a real hard dependency; name the prerequisite and its owner. Separate "waiting on user" from technical blockers.
3. Recompute **ready** work when gates change: approved and authorized implementation; candidate QA; independent spec drafting up to approval; bounded investigations.
4. Follow user priorities and the critical path. When something is blocked, pick the next independent ready item.
5. Prefer one complete development packet per feature, then independent QA on the candidate. Parallelize only distinct ready work worth the overhead; concurrent edits need disjoint ownership and authorized isolated checkouts.
6. At milestones (approved spec, candidate, QA verdict, PR) update only changed state. Approved spec + dev authorization → dev; candidate → independent QA; checks and QA green → publish/update the PR within the authorized scope; merge remains a separate approval.
7. End an active run with a short board summary: done, underway, waiting on user, blocked, newly ready, next action. Nothing runs between sessions.

Delegation sizing follows [dynamic agent management](dynamic-agents.md): default to one executor plus required independent QA.

## Bounded investigations
Start with a falsifiable hypothesis, one discriminating probe and expected evidence. After two comparable attempts without new findings, keep logs and state, and escalate for a new hypothesis or scope decision. This never waives QA, regression checks or urgent safety containment.

## Work packets
Each delegate gets a [work packet](../../templates/agent-work-packet.md) and a [role contract](../../.agents/roles/README.md). Specialists never promote a draft to approved, merge a PR or update the board.
Mixed-client workers, preflight, advance escalation notices, fresh context and resource
isolation follow [dynamic agent management](dynamic-agents.md); no parallel scheduler.

## Financial and security decisions
Never infer approval from a checked option, silence, an earlier related approval or a PR review. Accounting semantics, financial calculations, migrations, security, published contracts, material scope, production changes and merges need explicit user approval. Research, test planning and drafts that commit none of these may continue.

## Example: MyFinanzas (illustrative only)
- E1.6 `spec=awaiting-approval`: the functional agent prepares decision questions; **dev E1.6 is blocked**.
- E1.7 `spec=drafting`: independent requirements are analysed; contracts that depend on E1.6 are marked `pending`.
- QA maps E1.6 draft acceptance checks to provisional tests.
- A SQLite investigation is its own lane; it blocks E1.6 only if a documented hard dependency exists.
- Once E1.6 is explicitly approved, the coordinator starts dev for E1.6 within that scope; E1.7 drafting may continue if write isolation is safe.

This is not a real status report; always inspect the actual repository before filling the board.
The [Spanish visual guide](../../docs/GUIA_VISUAL_ORQUESTACION.md) has eight Mermaid diagrams of this flow.

## Resume and verification
Resume from AGENTS.md and the last verified checkpoint; reconcile Git, approval and test changes; load the full board, spec or roadmap only when needed. Report passed, failed, blocked and unrun checks accurately. Template CI does not prove live agent behavior.
