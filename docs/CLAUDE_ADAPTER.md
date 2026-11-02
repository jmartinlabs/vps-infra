# Claude Code adapter (v2.4 candidate)

The methodology is **model-neutral**. Codex and Claude Code can use the same
`AGENTS.md`, Skills, financial/functional gates, acceptance checks and
documentation. Claude-specific files only map commands and optional profiles;
they do not replace canonical rules.

## Entry points

- `CLAUDE.md` uses `@AGENTS.md` to load the canonical project instructions,
  including on older Claude Code versions that lack direct AGENTS.md support.
  Do not maintain separate, conflicting policies in these files.
- `.claude/skills/NAME/SKILL.md` enables `/orchestrate`, `/spec`, `/dev`,
  `/task`, `/tweak`, `/init-project`, `/bootstrap`, `/roadmap`, `/relay`,
  `/adopt-project` and `/handoff`. Each wrapper **reads the corresponding canonical** file
  under `.agents/skills/NAME/SKILL.md`; none automatically copies its contents. The
  relay wrapper adds no hook and never reads or publishes automatically.
- `.claude/agents/` exposes optional task-limited profiles for
  functional, implementation, QA/review and infrastructure work. A profile
  file is not a running worker or a license to delegate without checks.
- Manual client communication (identity, states, full return block and status) is the same
  [coordinator communication](../specs/methodology/coordinator-communication.md) contract for Claude Code.
  Only the client name changes: `HANDOFF → CLAUDE CODE`. Nothing is sent to OpenCode automatically.
- Call `/orchestrate` with a concrete task and let it choose Quick, Standard,
  or Full according to the already agreed scope. Native Claude Plan mode is
  separate from a Skill. Command names do not give approval or change models.

## Model per profile

All `.claude/agents/` profiles keep `model: inherit` on purpose:

| Profile | Model | Why |
|---|---|---|
| implementation | inherit | routine approved work is fine on the session model (balanced tier) |
| qa-review | inherit | independent critical review is the **advanced** tier in [model selection](../specs/methodology/model-selection.md); a cheaper fixed model would weaken QA |
| functional | inherit | specs carry ambiguity and approval questions |
| infrastructure | inherit | operational risk; keep the user's chosen model |

For cheap read-only searches, use Claude Code's built-in **Explore** subagent instead
of a custom profile. A derived project may pin a model (for example `model: sonnet`)
in its own profiles when its risk and quota justify it; record that decision there.

## Manual smoke test (required before claiming live Claude compatibility)

1. Open an authorized checkout in Claude Code and check `/skills` discovers
   `/orchestrate` and `/spec`. Run `/context` to confirm AGENTS instructions.
2. Run `/orchestrate` with a **planning-only** example, confirm it reads the
   canonical Skill and reports the approval gates; do not grant new scope.
3. Ask the coordinator to list available specialist profiles without launching
   them; check real delegation capability, optional workers and isolation.
4. Try evaluation scenarios with Claude or Codex and score the resulting
   structured decisions as described in [behavioral evals](AGENT_EVALS.md).
5. Report actual model, client version, date, results, resource usage, and
   checks not executed. Do not claim native subagents, hooks or model evals have
   been tested just because files exist.

No auto-merge, cloud automations or model API credentials are installed. The only hook
is the read-only `SessionStart` hook described below. A hook cannot prove an approval
without a trusted external record; the [approval policy](../specs/methodology/approvals.md)
remains instructional.

## SessionStart hook: load the orchestrate contract

`.claude/settings.json` runs one `SessionStart` hook that prints
`.agents/skills/orchestrate/SKILL.md` into the session context (on start, resume, clear
and after compaction). Without it, agents tend to work from the `AGENTS.md` summary and
never open the full contract unless the user types `/orchestrate`; the 2026-10-23
benchmark saw this in all 12 runs.

- **Cost:** about 1,300 tokens once per session, not per request.
- **Why it is allowed** although v2.4.2 installed no hooks: it executes no project code,
  calls no network, changes nothing and makes no approval decision. It only prints a
  tracked Markdown file.
- **Limits, enforced by `scripts/validate-template`:** every hook must be
  `cat "$CLAUDE_PROJECT_DIR/<path>.md"` for an existing file inside the repository
  (no `..`). Hooks that run code, fetch content, gate approvals or write files are not
  accepted in this template. Derived projects that need more must decide and document it.
- **Codex** has no equivalent; there, start with `$orchestrate`.
- Typing `/orchestrate` is still fine; it just reloads the same contract.

**Live check (2026-10-23, Claude Code CLI 2.1.301, Sonnet, `claude -p`, file and shell tools
disabled):** asked for the exact label of orchestrate step 9, a session with this hook answered
`**Gates.**` in 2/2 runs; a session on the previous `main` (no hook) answered `NOT LOADED` in 2/2.
The client's input-token totals did not show a clear difference between the two (about 36k
both ways), so the per-session cost above is an estimate from file size, not a measurement.
The repository's existing Codex workflow remains unchanged.

For official mechanics see:
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code project instructions](https://code.claude.com/docs/en/memory)

## Permission prompts

`.claude/settings.json` adds **`ask` rules only** (no `deny`) for protected Git/GitHub
operations: PR merge, force push, `git reset --hard`, repository create/edit/delete
and release creation. Claude Code then asks the user before running a matching Bash
command, so an approval comes from the user at execution time rather than from the
model's memory of "ok/dale". `ask` never blocks an approved action, which is why the
v2.4.2 objection to blanket `deny` rules does not apply.

Limits: matching is textual and covers only the Bash tool. Other paths (GitHub MCP or
API tools, scripts, aliases, `bypassPermissions` mode, user or managed settings with
broader `allow` rules) are not covered. These rules are defense in depth, not a
security boundary; the [approval policy](../specs/methodology/approvals.md) still
applies. Derived projects should add their own deployment commands to `ask` once
the stack is chosen. No live Claude session has verified these prompts for this change;
check effective permissions in the actual client (for example `/permissions`).

The QA profile offers `Read, Glob, Grep, Bash`: its read-only instruction is a role
contract, while Bash remains able to write. If an approved action is blocked, report
the restriction and resolve it through the authorized client configuration; do not
silently bypass it. Keep project-specific restrictions and the canonical approval policy.
