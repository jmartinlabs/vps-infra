@AGENTS.md

# Claude Code adapter

This repository's canonical methodology remains in `AGENTS.md`, `specs/methodology/`,
`.agents/skills/` and `.agents/roles/`. Do not fork or duplicate their decisions.

- Adopción y desviaciones locales: [docs/metodologia-agentes.md](docs/metodologia-agentes.md).
- For Claude Code, invoke `/orchestrate` (rather than Codex `$orchestrate`).
  Use the `.claude/skills/` wrappers to read the canonical Skill.
- To stop and transfer a session, invoke `/handoff`; it loads the canonical `$handoff` Skill. It does not resume or approve new work.
- The `.claude/agents/` files provide optional specialist **profiles**, not
  four permanent running agents. Delegate only after checking readiness, real
  client capabilities, permissions, ownership, cost and checkout isolation.
- Follow [adapter usage](docs/CLAUDE_ADAPTER.md). Never claim a Codex-specific
  action, Claude hook, GitHub safeguard or model evaluation ran without evidence.
