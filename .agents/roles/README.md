# Epic orchestration specialist role contracts

These files are **reusable role profiles**, not registered or permanent agents. The coordinator can assign zero, one or several independent tasks using the same role; see [dynamic agent management](../../specs/methodology/dynamic-agents.md). Read them when constructing bounded subagent tasks. If delegation is unavailable, the coordinator performs the same roles sequentially.

OpenCode additionally offers optional native subagents for `review`, `functional`, `implementation` and `infrastructure`, each a thin client adapter over its canonical role. The specialized agents use OpenCode's default subagent capabilities; the work packet and role contract govern behavior, not a technical permission matrix. `review` remains a separate read-only adapter. Adapters stay thin: client-specific configuration, canonical-role link and minimum loading instructions. They are client adapters, not new roles or always-running workers. See the [OpenCode adapter](../../docs/OPENCODE_ADAPTER.md).

- [Functional](functional.md): discovery, brainstorming, DRAFT specifications and acceptance criteria without self-approval
- [Implementation](implementation.md): approved-spec-only development
- [QA / Review](qa-review.md): independent acceptance and regression checks
- [Infrastructure / DevOps](infrastructure.md): Docker, CI, data environment and bounded deployment preparation

For each new instance the coordinator provides an [agent work packet](../../templates/agent-work-packet.md) with file ownership, applicable rules and expected evidence. The coordinator owns dependency scheduling and `specs/epic-board.md`. Parallel read-only preparation is safe; parallel writes need non-overlapping ownership and authorized isolation.
