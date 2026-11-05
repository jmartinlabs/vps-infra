---
name: spec
description: Specify a roadmap epic by number or a new feature by name through resumable brainstorming; never implement code.
---

# spec

## Inputs
Read `AGENTS.md`, `specs/README.md`, existing state and applicable guidelines before acting.
Functional delegates also follow [the functional role](../../roles/functional.md) and their work packet.
## Outputs
`specs/{nr}-{slug}-brainstorming.md` and `specs/{nr}-{slug}-specification.md`,
with a two-digit number, approved decisions and a local documentation commit.
## Procedure
1. Read roadmap, product context, architecture, quality, security and applicable UI
   guidelines. Resolve the requested epic number or feature name. Ask if ambiguous.
   Reuse its existing identifier/files; otherwise allocate the next unused two-digit
   number and unique lowercase slug. Never overwrite another feature.
2. Start or resume brainstorming from `templates/brainstorming.md`. Read all prior
   questions/confirmed answers. Append one question round at a time; never rewrite
   history. Use Markdown checkboxes, e.g. `- [x] Recommended option — rationale` and
   `- [ ] Alternative — trade-off`. A checked recommendation is a proposal, not a user
   answer. Separately record confirmed answers and their approval source/date. A functional
   delegate may create and append to these brainstorming files within its packet; it never
   marks them approved or rewrites confirmed history.
3. Stop and wait for the user after each unanswered round. Do not invent answers. Under orchestrated multi-epic work, return the exact unanswered decision to the coordinator, which may schedule other independent preparation or QA.
   Cover functional requirements, screens/interactions, data read/written, APIs/external
   dependencies, validation, errors and edge cases. Ask only unresolved questions.
4. For visual applications append ASCII wireframes and obtain feedback before finalizing.
   For non-visual systems describe the relevant interfaces without requiring screens.
5. Once required decisions are confirmed, use `templates/specification.md`: expected
   functionality, data model/contracts, interfaces, empty/loading/error states, API
   behavior when applicable, validation, exclusions and numbered acceptance checks.
   Every check says what to do and what result to expect; assign stable AC-01 style IDs.
   A functional delegate may write draft specification sections and acceptance criteria
   within its packet; the user still approves.
6. Request approval of the complete specification. Only the user approves. After approval,
   review the diff and commit approved brainstorming/specification files only; a functional
   delegate returns the approval request and draft evidence to the coordinator, which records
   approval and commits the approved documents. Never self-approve or commit a draft as
   approved. Preserve unrelated user changes. Return approval evidence and dependency changes
   to the coordinator, which owns the shared epic board.
## Stop conditions
Pause on unanswered questions, unapproved wireframes/specification or important conflicts.
Preserve history and next action for resumption. Do not implement the feature. After the
approved documentation commit, stop and return the spec ID and approval evidence. In an orchestrated run, the coordinator starts `$dev` when dependencies and authorizations allow, without another manual user command.
