# Explicit approvals for protected operations

This policy applies to orchestrate, every delegated agent and every workflow.
It is an **instruction-level gate**, not an independently enforced security control.
A project may add stricter rules; those always win.

## Protected decisions

Each of these needs its own user approval:

- merging a PR;
- approving a Full specification or wireframes, or a substantive financial or product decision;
- authorizing development, when the project has a separate development gate;
- material security or architecture changes;
- destructive actions;
- production deployment or operational data migration;
- any other approval the project requires.

Green CI, finished QA, a pre-approved plan, earlier scope authorization or finished code
**never imply** approval of a different protected action.

## Ordinary work (no new approval)

Inside a scope the user already authorized, these need no per-step approval unless the
project says otherwise: implementation, tests, using subagents, and local worktrees that
meet the policy below. Publication follows the next section. Treat them as continuing
authorized work, not as protected actions.

## Branch and PR publication

Authorization to do the work — code or documentation, including drafting or editing a
specification — also authorizes publishing its branch and creating or updating its pull
request in the existing repository. No separate publication approval is needed.

- Respect explicit instructions such as "local only" or "do not publish"; not every task
  needs a PR.
- Before pushing, review the diff, staged files, secrets and changes owned by others.
- A draft PR is allowed while checks or decisions are pending, naming them. An open PR does
  not end the task while executable checks remain; complete the required checks and QA
  before calling it ready for merge.
- Update the task's existing PR instead of opening a duplicate.
- Creating or merging a specification PR neither approves its content nor authorizes
  development when those are separate gates.
- A PR merge always needs its own explicit, identifiable approval for that PR and the
  approved candidate. Never enable auto-merge as a shortcut.

This policy does not cover creating repositories, changing visibility, direct pushes to
protected branches, force pushes, releases, packages or deployments. Those remain protected
or forbidden as the project requires. The handoff workflow keeps its own prohibition on
opening a PR.

## How to ask and what counts

- Ask for **one identifiable decision** at a time. Name the target: PR number and HEAD SHA,
  spec ID and revision, environment, or changed scope. Several pending decisions need
  separate answers.
- An approval needs an **explicit approval verb**: `Approve PR #34 merge`,
  `I approve specification 07`, `Apruebo PR #34`, `Aprobada la especificación 07`.
- A bare `Approved` / `Aprobado` / `Apruebo` counts **only** when it answers exactly one
  clearly identified request made immediately before.
- `ok`, `okk`, `dale`, `continúa`, `continue`, `go ahead`, `adelante`, silence, reactions
  or any generic assent **never approve a protected action**. They may continue work that
  is already authorized.
- Never bundle a merge, spec acceptance, deployment or development authorization into one
  inferred approval.
- If the target, revision, intent or source is unclear, ask one short question and pause
  only the affected action. Independent permitted work may continue.

## Recording and reuse

- Record the exact scope, target, revision/SHA and the user's message in the resumable
  project record. A commit message or agent note saying "user approved" is **not evidence**.
- Reuse a specific valid approval; do not ask again for the same unchanged decision.
- Before acting, re-verify the target, current Git state, tests and project gates.
- A material change after approval (new SHA, new content, new artifact) needs fresh approval.

## GitHub PR merge example

1. Report: `PR #34 ready, HEAD abc123, checks green. To authorize merge reply: Apruebo PR #34`.
2. `Dale` does not permit the merge. `Apruebo PR #34` permits that **one PR** only.
3. Before merging, recheck HEAD and required checks. If content changed, ask again.

## Local worktrees

A local worktree needs **no individual approval** when all of these hold:

- it supports work already authorized by the user;
- it provides useful isolation;
- it does not affect existing work.

Before creating one, check the authorized scope, Git status (including uncommitted/untracked changes),
existing worktrees, branch and destination. Use a new, non-conflicting location;
never overwrite, move or discard existing changes. If you cannot verify this, keep the
current checkout or stop that step.

A Work Packet assigns responsibilities and file ownership; a worktree provides isolation;
authorization comes from the user's granted scope. Neither the packet nor the worktree grants
new tasks, protected actions, publication or merges; publication remains ordinary only
inside the user's authorized scope. Preserve uncommitted changes and
never remove a worktree with pending work without user authorization.
Stricter derived-project restrictions always take precedence, including a rule that every
worktree needs approval.

Stronger enforcement (tool hooks, GitHub rulesets) needs separate configuration and an
authorization source agents cannot forge or edit.
