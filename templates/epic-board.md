# Epic execution board

> Copy to `specs/epic-board.md` **only if concurrent epic/workstream coordination is needed**. Example rows below are field guidance, not real approved tasks; remove them when initializing.

Repository: UNDECIDED
Last reconciled (date + source commit/PR): UNVERIFIED
Coordinator next action: Inspect canonical spec/roadmap/progress before assigning work.
Current summary owner/link: this board or the existing progress document; no competing statuses.
External clients / IDs / start-stop owners / notification routes: NONE VERIFIED.

| Item | Priority | Spec status / approval evidence | Dev status | QA status | Hard dependencies | Owner / isolated branch | Blocker / decision needed | Next independent action | Evidence / last verified |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1.6 (EXAMPLE ONLY) | P1 | awaiting-approval / none | not-ready | test-design | user approves E1.6 | functional / none | unresolved financial rule | draft decision options; do not code | unverified |
| E1.7 (EXAMPLE ONLY) | P2 | drafting / none | not-ready | planned | clarify E1.6 contract if required | functional / none | pending dependency review | prepare independent brainstorming | unverified |

## Approvals needed

- PENDING: Identify exact question, decision owner and canonical document. Never assume approval.

## Ready queue

- PENDING: List ready actions by stage, priority, independent write scope and gate status.

## Technical investigations

| ID | Question and exit criteria | Priority | Blocking which item and why | Owner | Status / evidence |
| --- | --- | --- | --- | --- | --- |
| NONE | | | | | |

## Handoffs and checks

- PENDING: Spec approved? source/date; Dev tests? command/result; QA? evidence; PR? published/updated within the authorized scope; merge? explicit user approval.

After confirmed integration, update current PR/merge/SHA/check fields, explicitly
superseding historical pending states. Preserve history behind links.

## Next-session resume

- Read canonical documents and Git/PR state, reconcile stale entries, select the next independent ready task. Do not claim any agent continues working while this session is closed.
