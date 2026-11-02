# Adaptive model selection

The user controls the coordinator model; never change it as a consequence of delegation.
Verify client capabilities before selecting subagent settings. Unknown availability is not
permission to inherit an unchecked model. Model choice never replaces verification,
independent QA or protected approvals. Report savings only from real telemetry.

## Codex subagents: absolute ceiling
The maximum permitted combination is `gpt-6.1-sol` + `low` (UI: GPT-6.1 Sol Light).
Never automatically escalate model or reasoning above this ceiling, including for QA.
Use an explicitly selected economical available model for straightforward bounded work;
reserve `gpt-6.1-sol` + `low` for complex or critical work. There is no numeric cost or
capability ordering across model families: use a verified permitted economical option,
not an inferred ranking. Never substitute Astra or another unverified family/version.

Before dispatch, record requested model/effort, available controls and the selection
assurance supplied by the runtime. In this Codex runtime, explicit `model` and
`reasoning_effort` overrides require fresh context (`fork_turns="none"`); full-history
forks inherit settings. Recheck this capability in other clients/versions. If selection
cannot be guaranteed within the ceiling, do not spawn; record the limitation and work
sequentially within authorization, or propose a manual permitted alternative. Never
silently inherit an unchecked coordinator model. Do not raise the coordinator model.

After dispatch, verify observed model/effort from attributable runtime metadata or local
records when exposed. Record requested versus observed values and evidence; an agent's
self-report is insufficient. Missing metadata means **effective selection unverified**,
not a passed check. A mismatch stops further dispatch and requires investigation at a
safe boundary; never compensate by escalating.

## Portable advice
| Work | Suggested tier | Suggested reasoning |
| --- | --- | --- |
| Straightforward Quick | efficient | low |
| Bounded Standard implementation | balanced | within client policy |
| Architecture, ambiguous debugging or critical review | advanced | within client policy |

These are advisory capability labels, not permission to exceed the Codex ceiling.
Keep the current coordinator model when adequate. In Claude Code retain existing
`model: inherit` profiles unless an authorized client-specific selection is supported;
Claude model/effort names are not equivalent to GPT settings. Codex limits apply to
Codex subagents even when another client coordinates them. Do not invent cross-client
quota or telemetry. When unavailable, use smaller verifiable increments or report a blocker.

Load this document when model advice matters, normally Standard / Full. Report one compact
line: task, client, requested model/effort, assurance and observed evidence (or
`suggested, availability unverified`). Add no separate approval gate beyond quota and
existing project approvals. Native client settings remain subject to actual availability.
