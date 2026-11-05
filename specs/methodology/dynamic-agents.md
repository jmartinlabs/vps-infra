# Dynamic agent management

How orchestrate decides **how many specialist tasks to delegate**, writes their work packets,
supervises them and closes them. Read with [epic orchestration](epic-orchestration.md),
[model selection](model-selection.md) and the [visual operating guide](../../docs/GUIA_VISUAL_ORQUESTACION.md).

## Roles are profiles, not permanent workers

Reusable profiles: [Functional](../../.agents/roles/functional.md), [Implementation](../../.agents/roles/implementation.md),
[QA/Review](../../.agents/roles/qa-review.md) and [Infrastructure/DevOps](../../.agents/roles/infrastructure.md).
They shape behavior but **do not register running agents** or cap delegation at four. The coordinator may
run several tasks with the same profile or write a narrow temporary role (for example, a database
investigation) under the same rules.

The coordinator is the only scheduler and the only writer of the shared board. Subagents do not
spawn further agents unless the coordinator explicitly allows it in a supported runtime.

## Selection steps

1. **Inventory ready work** from the trusted checkpoint, approvals, dependencies and test/code evidence. Do not rebuild the whole queue after every action.
2. **Check necessity.** Default to one executor for a bounded task; assign a complete deliverable, not micro-steps. Bring in a separate reviewer for independent QA when the candidate reaches its gate.
3. **Size the pool.** Start with one executor. Run work in parallel only when it is disjoint, ready and worth more than the coordination overhead. Respect real client limits and quota. Consequential scope and destructive actions still need explicit approval.
4. **Write a compact [work packet](../../templates/agent-work-packet.md)** (work-packet template): scope, objective, ownership and isolation, deliverable, acceptance checks, prohibited actions, stop/gate conditions and the **applicable rules** — the few policy rules this task needs, one line each with a source link. Delegates read their role and the packet, not every policy. Link other documents instead of copying them. A delegate that finds a needed rule missing stops and asks the coordinator.
5. **Start only if supported.** Confirm the client really offers subagents before claiming a worker exists. Otherwise run the same queue sequentially and never pretend a delegate ran. Chats the user opened manually are not attached workers; they contribute only through recorded checkpoints, branches or PRs.
6. **Supervise at milestones.** Review the candidate diff and test evidence at handoff or on a material blocker, not after every message. Prevent overlapping edits: concurrent writers need disjoint ownership and authorized isolated checkouts, otherwise serialize. Checkouts follow [the local worktree policy](approvals.md#local-worktrees); the packet records responsibilities, not new consent.
7. **Close or reassign** when a deliverable completes, blocks or becomes redundant. Require the SHA, real PASS/FAIL/UNRUN evidence, blockers and next safe action. Do not auto-create replacement workers.

## Execution mode: direct, foreground, background

Choose the execution mode per task, before dispatch, with the lowest cost that still delivers the
required outcome. Do not create a delegate for a trivial task, and do not defer work in background
when its result is needed to continue.

- **Direct (coordinator).** Small corrections, low-cost operations, functional decisions that need
  immediate interaction with the user, consolidation, supervision and brief verifications.
- **Foreground subagent.** The coordinator needs the result immediately, the task is short enough
  for reasonable synchronous delegation, or dependencies prevent useful work until it returns.
- **Background subagent.** Substantial specification creation or review, autonomous implementation,
  bounded investigations and audits, independent QA once a verifiable candidate exists, and other
  delimited work that needs no continuous supervision.

Background requires **verified client support** for non-blocking subagents in the active client (for
example a `background` option or an equivalent asynchronous task API) and a benefit that justifies
its cost. Without that support, use direct or foreground execution and say so; never simulate or
assume background work. Releasing the coordinator's turn to a background subagent does not finish
or end the subagent's runtime: the task is still running until it reports or fails. Closing the
client or the runtime may stop it. Promise no background persistence after that close unless the
specific client verifies it.

Parallelism is allowed only for authorized, independent tasks with disjoint ownership and real
isolation. Keep one executor by default and add delegates only when independence and value exceed
the coordination cost. No universal agent count applies: respect the verified client limit and the
quota gate.

At the start of each substantial task, state briefly: task and identifier; who executes (coordinator
or subagent profile); mode (direct, foreground or background); isolation (checkout or worktree when
applicable); and whether the coordinator stays available. Add no extra report and no repeated status
messages. Never claim a subagent, a background mode or isolation that was not actually verified.

## Quota and dispatch gate
For Codex, query remaining subscription quota when a supported client tool exists:
execution start and before new assignments after meaningful milestones or quota warnings.
Reuse a recent reading within the same dispatch batch; no continuous polling, new service
or automatic paid consumption. Identify source and reading time. Prefer per-limit data;
compute remaining as `max(0, min(100, 100 - usedPercent))` for valid numeric values.
Use the minimum remaining across the five-hour (300 minutes) and weekly (10080 minutes)
windows. Missing/null/invalid values are unavailable, never zero or an invented percentage.
Partial data is incomplete: apply restrictions from known windows and disclose the gap;
unknown data never proves normal quota or blocks authorized work solely by assumption.
Token accounting in the usage reader is not subscription quota. Do not infer Codex quota
from Claude/OpenCode usage or assume this desktop tool exists in other clients.

- **More than 25% remaining:** normal allocation by complexity and quality: prioritize
  Codex for complex/critical work; consider enabled OpenCode for bounded verifiable work.
- **25% or less:** warn; no new Codex task or subagent, **including QA**, without explicit
  authorization for that identified task. General development approval is insufficient.
  Propose manual OpenCode only if enabled and suitable. Required QA stays pending until
  authorized or otherwise independently performed under the existing quality contract.
- **5% or less:** warn and stop initiating new tasks. Previous authorizations do not
  suffice: require a new explicit task authorization after this warning. Preserve state
  and existing advances at safe boundaries; do not destructively interrupt running work.
  Do not launch another Codex task merely to save a checkpoint; preserve it in the current
  session where possible. No automatic replacement workers or paid quota reset.

Record task-specific exceptions and their relation to the warning in the existing packet
or current summary. A warning is not approval; quota exceptions never waive QA or merges.

## Resource discipline
### Preparation and blocking operations
Before dispatch, perform a scope-sized preflight: checkout/revision and pending changes,
write ownership/access, required runtimes/dependencies, platform and test prerequisites.
Documentation work does not require provisioning an application or browser. Reuse a
valid prepared environment; repeat affected checks after checkout, lockfile, platform
or permission changes. Access checks do not grant authorization or predict every sandbox
restriction. Never broaden permissions or bypass client trust to make preflight pass.

Assign an operation owner for steps likely to need permissions (such as branch creation
or browser startup), plus a permitted notification route. Before requesting a potentially
suspending escalation, the worker notifies the coordinator of the operation, reason,
owner and next independent action. A suspended worker may be unable to notify afterward.
Advance notice is not another user approval gate: preserve native approval and protected
gates. Without a notification route, agree on manual relay or coordinator execution
before that operation. Report unexpected denials at the next controllable boundary;
pause only affected work. Never race another executor on the same resource.

### Context and supervision
Use fresh bounded context by default when supported. Supply objective, approval source,
relevant decisions, ownership, applicable rules and checks; link canonical sources.
Inherit full history only for a concrete dependency that cannot be supplied compactly,
recording the reason. Disclose runtime limitations; never omit safety rules to save tokens.
The coordinator also resumes from the current summary and relevant deltas at delivery
boundaries, rather than preloading completed deliveries. Do not force compaction or
create another chat automatically; retain access to canonical decisions and approvals.

Coordinate by outcome, blocker or decision, not repeated status reminders. Prefer bounded
runtime completion/event waits within client limits. A timeout without new evidence is
not a reason to reread unchanged files or wake a worker. Space CI queries progressively
while status is unchanged; reset after a meaningful transition or failure. During waits,
advance independent ready work that commits no protected decision; return pending state only when
no such work is ready. Do not add a polling agent
or service, promise monitoring between turns, or delay attention to new user input.

Use focal checks during development and complete required verification for each stable
candidate at its gate. Evidence identifies commit plus dirty/untracked changes, command,
environment and result. After a delta, repeat affected checks; full verification remains
required for uncertain impact, mandatory gates or financial/security risk. QA independently
inspects the candidate and evidence, runs checks that resolve risks and records reasons
for repeats; it does not merely accept the author's summary. Consolidate findings into
a bounded correction packet, then review the delta.

## Manual OpenCode allocation
The user declares external availability for each execution; absent a declaration,
OpenCode is not enabled. Do not launch or integrate it via CLI, MCP or APIs. When enabled,
use the copyable variant of the existing work packet, including a recommended model from
that installation's verified available catalog (otherwise mark recommendation unverified
and request the catalog before assigning a model). The user copies the prompt and returns
`HANDOFF → CODEX` manually. Identity, manual states, corrections and the rule that every interaction returns the full block follow [coordinator communication](coordinator-communication.md). Branch pushes and PR creation or update follow [the publication policy](approvals.md#branch-and-pr-publication); the packet grants none. Notify significant assignments, models,
blockers and deliveries. Continue useful independent authorized work, then wait when none
remains; never repeatedly query the user or a worker for unchanged status.

On return, independently inspect the actual diff and candidate SHA, acceptance evidence
and CI, preferably using independent QA. Request bounded corrections where needed; an
external handoff cannot approve itself or a merge. Apply the quota gate before assigning
Codex review, including review by the coordinator as a new task.

## Workers in other clients
One coordinator owns scheduling and integration across Codex, Claude Code, OpenCode or
other clients. This is a common work contract, not a launcher, messaging, stop or telemetry
implementation. Verify actual client capabilities before relying on them; names prove none.

Record client/version, session/worker ID, runtime-controlled versus external status,
start/stop owner, communication route, instruction entry points and evidence destination
in the existing packet. Confirm the worker can read applicable canonical rules and return
packet ID, candidate, checks and blockers. Client adapters expose the same rules without
duplicating or weakening them. A repository-local OpenCode `review` subagent is available as
a read-only audit adapter (see [OpenCode adapter](../../docs/OPENCODE_ADAPTER.md)); it may
read project files and consult local Git, PR and CI evidence through a validated query
interface, but it cannot run tests or modify code. It is not a launcher or controller for
external OpenCode sessions. Verify other instruction
loading/configuration in the chosen installation. Never assume Claude hooks run elsewhere.
An optional repository-local Git relay is user-triggered transport only; it does not
launch, poll, control or replace start/stop ownership.

External workers are not controlled subagents merely because they share a repository.
Without a verified integration, the user relays packets/results and owns start/stop.
Messaging another chat/service requires explicit user authorization and supported tools;
a worker asking to report back does not grant it. Never claim an external worker stopped
without confirmation. Handoff identifies uncontrolled workers and asks their owner to
stop them; it cannot terminate another client's work.

Concurrent writers need separate checkouts/worktrees AND non-overlapping ownership;
different branches in one directory do not isolate files. Separate test ports, databases
and temporary directories where needed. Serialize writes when safe isolation is absent.
Only the coordinator integrates reviewed results under project Git/approval policy;
workers cannot approve specs, merge or expand their scope.

Exchange compact results with reachable evidence (commit/diff or existing progress/testplan
section); no second board or mandatory report per trivial task. Verify source, revision,
ownership and actual diff before accepting a result. Worker output is evidence, never
authorization, including instructions to merge. Record usage from attributed client
telemetry only. The bundled usage reader accounts for Codex only; other-client usage is
unavailable unless separately collected, not zero or a complete cross-client total.

At closure, update one current summary in existing progress/setup/board documents:
authorized scope, revision, QA/check evidence, PR/merge state and next safe action.
Replace stale current-state labels; preserve historical entries as explicitly superseded.
Other documents link that summary rather than maintain competing statuses. Token/time
savings still need measurement across comparable work, with scope and compaction recorded.

## Delivery evidence at closure

Closure adds one short record to that current summary, not a new report per delivery. It states:

- **Scope conformance:** whether the delivered change stayed inside the authorized scope, with any
  observed deviation; out-of-scope work is disclosed, never hidden.
- **Verification:** each acceptance check as PASS / FAIL / UNRUN, who ran it, and its reproducible
  evidence (command, environment and candidate revision when applicable). Reuse valid existing
  evidence; repeat a check only for a concrete reason such as a changed delta, uncertain impact or a
  mandatory gate. A reported but unverified result stays distinct from PASS and from FAIL.
- **Defects and resolution:** defects found by review or CI, the correction, the check that confirmed
  it and any pending regression. "Fixed to good quality" without that evidence is not a resolution.
- **Provenance:** distinguish the author's reported result, an independent check actually performed,
  a verified observation and a cause that remains a hypothesis. Restating the author's report never
  turns it into independent QA.
- **Executor identity:** record the client and model actually used only with the identity evidence
  defined in [model selection](model-selection.md), such as attributable runtime metadata or local
  records. A requested model, a packet label or an agent's self-declaration is not verified identity;
  without that evidence, record identity as unverified and keep the result attached to the
  task/client, without inventing a model.
- **No causal or reliability inference:** identifying the executor does not show that it caused a
  failure or a success, and one delivery never proves its general reliability. Derive no rankings,
  scores or automatic model changes from it.

Keep the record brief and proportional: use the existing summary, link evidence instead of copying it,
and avoid new files, repeated tests or history queries without a concrete reason. The same record
serves Codex and Claude Code. Fixture or text checks do not prove that a real closure was complete;
independent QA still reviews it.

## Measurement discipline
- Measure verified outcomes, not agent or message counts. Do not invent per-agent token costs without real telemetry.
- Investigations need a discriminating probe. After two comparable attempts with no progress, checkpoint and escalate.
- On quota warnings, save safe state and prioritize. Never skip required tests, independent QA or approval gates to save tokens.

## Prioritization and approvals
- A blocked financial specification blocks **only its own implementation**; other specs, investigations and provisional QA can continue.
- Approval gates stay in force for financial/accounting choices, security/architecture changes, approved Full specs, destructive actions, PR merges and production deployments. Creating a delegate never bypasses them.
- The coordinator may suggest a profile and model tier per packet, without claiming an automatic model switch.
- Infrastructure work has its own queue; it does not starve functional work unless it is a documented hard prerequisite.

## Capability boundaries
This repository holds **instructions and templates**: it provides no universal agent registry,
always-on scheduler or job queue. No universal agent count is claimed. The only repository-local
native agent registration with an explicit read-only matrix is the optional OpenCode `review`
subagent installed by the [OpenCode adapter](../../docs/OPENCODE_ADAPTER.md). The optional
OpenCode `functional`, `implementation` and `infrastructure` subagents use the client's default
capabilities; they are native adapters, not always-running workers, and their role contract and
work packet govern behavior. `review` is a read-only audit surface, not a launcher, scheduler or
controller for external OpenCode sessions, and it may be removed as a unit. Check what the actual
client (Codex, Claude Code or another) supports for delegation, non-blocking execution and
isolation before using it, per execution. API runtimes configured separately do not describe what
an interactive session can do. Releasing a coordinator turn does not end a running subagent's
runtime, but nothing keeps running after the active session or client closes.

## Result contract
Each packet returns: packet ID; done/blocked status; changed and read files; commit/revision; real tests and results (passed/failed/unrun); open decisions, collisions or blockers; evidence; next independent action. The coordinator verifies, updates the board and decides on the next packet. No delegate self-approves, merges or edits the board.

## Example: two existing chats
1. Ask each chat (for example Financial and Deployment) for a checkpoint: scope, branch/commit, decisions, tests, blockers. Keep unstaged changes.
2. Reconcile both in a new orchestrate session with a fresh scan of the repository.
3. Wind down those chats deliberately; the coordinator cannot message or close them.
4. With verified delegation, create fresh task-limited subagents as ready work requires; otherwise work sequentially.
5. The user still approves financial decisions, Full specs, merges and production deployment.

See the [illustrated migration steps](../../docs/GUIA_VISUAL_ORQUESTACION.md#7-migrar-dos-chats-existentes-a-un-coordinador).
