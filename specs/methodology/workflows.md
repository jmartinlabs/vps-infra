# Adaptive workflow contract

Work starts from a natural-language request, optionally in the client's planning mode.
AGENTS.md recommends orchestrate; a planning mode never invokes a Skill by itself.

1. Inspect, then **propose** a classification.
2. Quick may proceed after a one-line plan only for a clearly requested, reversible,
   low-risk change with no protected gate or stricter project rule.
3. Standard and Full need the user to confirm before implementation, unless the same
   workflow and scope are already explicitly authorized. Reuse valid authorization.
4. Consultation/analysis and read-only planning mode never authorize edits.

| Workflow | Typical scope | Preparation | Verification |
| --- | --- | --- | --- |
| Quick | Low-risk bounded bug or tweak | Short plan, expected result | Focused tests, diff review, relevant regressions |
| Standard | Bounded feature | Short plan, edge cases, acceptance checks | Implementation, tests, code review |
| Full | New project, cross-cutting feature, major architecture | Discovery, approved decisions, roadmap if needed, approved feature spec | Incremental dev, QA, spec compliance, code review |

Risk matters more than size. Auth, payments, production configuration, migrations, data
deletion, security and incompatible contracts may need Full or extra approval even for tiny edits.

## Full workflow routing
- **New project:** init-project discovery (plus brainstorming if needed), architecture decision, bootstrap walking skeleton, roadmap approval, feature spec approval, dev and verification. A provisional roadmap may come earlier to pick a useful vertical slice.
- **Existing project, one complex feature:** reuse context; run spec and dev. No new project init or roadmap.
- **Several new epics:** propose or update the roadmap and confirm it. Each epic keeps its own spec and dev gates; independent brainstorming, implementation, QA and infrastructure lanes may overlap under epic orchestration.
- **Brainstorming** is for unresolved requirements. Keep decisions and open questions; skip it for straightforward changes.
- **Walking skeleton** is a real, minimal, end-to-end executable slice, not an interview. Use bootstrap only for a new project or a meaningful new architectural path.

## Model advice
With the classification, [model selection](model-selection.md) may suggest a capability tier and reasoning effort. It is advice, not an approval step or automatic switch, and never replaces tests, review or workflow confirmation. Skip it for straightforward Quick work.

## Approval gates
Confirm with the user: the initial classification (except the authorized Quick case or an existing explicit authorization), material product or architecture choices, a new or materially changed roadmap, Full specifications, and any significant rise in risk or scope. Ordinary code and tests inside the authorized scope need no approval; publication follows [approvals](approvals.md#branch-and-pr-publication). Approved specs stay authoritative. Protected actions follow [approvals](approvals.md).

## Multi-epic scheduling
Follow [epic orchestration](epic-orchestration.md) and [dynamic agent management](dynamic-agents.md). The coordinator keeps a dependency-aware board and picks the next independent ready work. A spec awaiting approval blocks only its own dev, not drafting another independent spec. An approved spec may go to dev and then QA within the active authorized run. Agents do not continue between sessions, and merges always need explicit approval.

## Delegation and portability
Skills describe workflows; they are not agents. Roles do not create permanent workers. The coordinator chooses how many bounded work packets to issue, based on real client capability, dependencies and isolation. When delegation is unavailable, work sequentially; multi-agent is an optional optimization. Each delegate gets file ownership, checks and review requirements. No concurrent writes to the same files, except the serialized Agent Relay branch file: writers publish without force and a rejected concurrent write stops instead of overwriting; work files keep disjoint ownership. Do not assume local tools, hooks or credentials exist in cloud tasks.

## Evidence
A successful build is not user acceptance. Report checks as passed, failed, blocked or unrun. Review diffs before local commits. CI is the portable enforcement layer; client hooks are optional extras, not a substitute for tests or approval.
