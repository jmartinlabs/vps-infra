---
name: handoff
description: Stop an active agent session safely, consolidate recoverable work and preserve a verifiable checkpoint for another session.
---

# handoff — consolidate and stop

An explicit **shutdown/transfer command**. It does not resume, finish the feature or start
new work, and it grants no new permissions. It covers the current authorized session only.

## Inputs
Only what is needed to stop safely: current progress/checkpoint, `git status`, active worker
handles in this session, and existing task, branch, worktree, PR and approval evidence.

## Outputs
- A small durable checkpoint in the existing progress file, setup-progress file or coordinator
  board; otherwise `specs/session-handoff.md` (one current handoff).
- A short receipt: checkpoint path, branch/commit SHA, pending changes, real worker-stop status,
  next-session instruction.

## Procedure
1. **Freeze scope now.** Stop issuing new development, research, long tests, delegation,
   scheduling, PR or merge actions. Override any automatic ready queue. Only reach a safe
   boundary; do not try to finish acceptance criteria or a "quick fix".
2. **Stop controlled workers.** Where the runtime supports it, request stop and a short final
   checkpoint. Record each as `stopped`, `stop requested` or `unconfirmed`, based on evidence.
   Other chats, separately launched tasks and workers without accessible controls are
   **not controlled** here: never report them as stopped; tell the user to interrupt them.
3. **Inventory, never destroy.** Check `git status`, branch/HEAD SHA, worktrees, PR, uncommitted
   files and who owns each change. Do not reset, discard, overwrite, delete worktrees, stash
   files of unclear ownership or amend others' commits.
4. **Preserve authorized work.** If safe and permitted, review owned changes (including secret
   or data leaks) and commit a labeled WIP checkpoint on the existing feature branch. Push only
   if the project allows it. Never merge, deploy or open a PR. If work cannot be committed or
   pushed, list the pending files and mark remote portability **unverified**.
5. **Write the minimum handoff.** Reuse the existing progress or board file. Include:
   `STOP REQUESTED — NO AUTO-RESUME`; feature and authorized scope; repo, branch, worktree, HEAD,
   PR; decisions and their sources; worker stop status; done vs partial work and uncommitted changes; checks as PASS/FAIL/UNRUN
   with evidence and candidate SHA; open bugs and blocked gates; approvals still valid vs pending;
   **one next safe action**. Link specs instead of copying them. If nothing can be persisted,
   print the checkpoint and mark it `not persisted`. Make this the linked current
   summary, superseding stale labels without deleting history. Include external client
   IDs, start/stop owners and uncontrolled workers; do not imply cross-client control.
6. **Verify persistence and continuation.** Reread the written checkpoint and verify its
   path, HEAD, pending changes and evidence links against the inventory. Report failures
   as unverified, never claim a durable checkpoint from a write attempt alone. Provide a
   complete copyable next-chat instruction with repository/path, checkpoint location,
   candidate branch/SHA/PR, authorized scope and decisions, valid versus pending approvals,
   evidence, risks/blockers, pending work and one next safe action. Ask the next coordinator
   to inspect Git drift and approvals before proposing continuation; the checkpoint itself
   grants no authorization. The user opens the new chat manually.
7. **Conclude.** Confirm no new execution started and the checkpoint is reachable. Report
   `stopped` only with runtime confirmation, otherwise `unconfirmed`. The final message must not
   trigger more tasks or agents.

## Next session
A new user request (for example orchestrate: "inspect the latest handoff, verify its SHA and
approvals, report state before proposing continuation") may reopen planning. The checkpoint
grants **no** permission to resume automatically.

## Quota exhaustion
If quota ran out before handoff could run, nothing was guaranteed. When quota returns, run
handoff **before** asking to continue: rebuild what Git and worker state can verify and mark
the rest `unknown`. Interrupt any visibly running task with the client's stop control first.

## Stop conditions
Stop once the minimum safe, non-destructive consolidation is done, or earlier if access,
ownership or authorization prevents safe persistence. Never merge, and never bypass QA,
approvals or security checks by labeling unfinished work complete.
