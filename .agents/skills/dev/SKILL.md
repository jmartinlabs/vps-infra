---
name: dev
description: Implement an approved specification in verified increments with progress, acceptance mapping and appropriate visual checks.
---

# dev

## Inputs
Read `AGENTS.md`, `specs/README.md`, existing state and applicable guidelines before acting.
## Outputs
Working increments, `specs/{nr}-{slug}-progress.md`, `specs/{nr}-{slug}-testplan.md`,
verified acceptance evidence, relevant documentation updates and local commits.
## Procedure
1. Locate the requested two-digit specification; ask if ambiguous. Confirm explicit recorded approval and satisfied hard dependencies before any code changes; never implement a draft spec. Read its approval,
   brainstorming, roadmap and applicable guidelines. Inspect code and Git status.
   Review acceptance checks and identify contradictions; stop on important conflicts.
2. Start/resume progress and test plan using their templates. Create coherent tasks and
   map every acceptance ID to an automated/manual check, expected result, command and
   evidence location, local/CI platform, owner and negative/integration cases before code.
   Preserve previous evidence with run dates and label stale results.
3. Preflight the affected environment and assign permission-sensitive operation owners.
   Follow [coordination](../../../specs/methodology/dynamic-agents.md) for advance
   escalation notices, external workers and shared test resources; never bypass approval.
   Implement small working increments. Maintain task state, relevant errors and next
   action. Run relevant automated tests and required build/type/lint checks. Inspect
   errors and regressions, correct defects and repeat affected checks. Complete required
   checks on each stable candidate; reuse evidence only for unchanged inputs/environment,
   recording reasons for repeats. Incompatible local runs never replace CI gates.
   Follow the [CI contract](../../../specs/methodology/ci-policy.md) for local-full,
   fast-CI and critical-CI profiles. Independent QA verifies candidate/base/environment
   and reachable raw logs, not a PASS declared by the author; stale evidence blocks integration.
4. Verify actual functionality, not just compilation or a process/port. For non-visual
   applications assert API/CLI/library/integration behavior and error cases.
5. For web applications operate all browser acceptance flows using Playwright; run
   complementary regression tests where useful. Capture screenshots at viewport widths
   390px and 1440px, record paths and inspect both. Review spacing, hierarchy, readability,
   accessibility and responsiveness. Identify the five most valuable visual improvements
   (or explain why fewer are justified); apply justified in-scope corrections and repeat
   affected browser/screenshot checks. Record findings and evidence in the test plan.
   If Playwright/browser capability is missing, install supported tooling or report a
   blocker; do not silently substitute screenshots or claim browser checks passed.
6. Update architecture when confirmed boundaries change; obtain approval before material
   deviations. Update progress/test results and documentation. Review own diff and staged
   files for regressions, secrets and unrelated changes, then commit each working increment.
7. Finish only when every acceptance check passes with current evidence and required
   regression checks pass. Summarize commands/results, commits, limitations and next action. In orchestrated work hand verified candidate evidence to independent QA; the coordinator alone updates the board, and branch/PR publication follows the authorized scope and the packet's ownership. Update
   one current checkpoint with SHA/pending changes, check/QA evidence, PR/merge state
   and next action; supersede stale current labels without deleting history.
## Stop conditions
Never deploy to production or perform destructive operations without explicit permission.
Branch/PR publication follows [approvals](../../../specs/methodology/approvals.md#branch-and-pr-publication);
respect local-only instructions. Stop on important conflicts or missing required authorization. Record blockers;
failed, skipped and unrun checks remain open. Do not finish as complete while acceptance
checks fail. Preserve enough progress to resume in another session.
