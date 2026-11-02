---
name: handoff
description: Stop and consolidate this session without continuing development.
---

# /handoff — Claude Code adapter

Read and follow the canonical Skill `.agents/skills/handoff/SKILL.md`; the only addition
is the Claude note below. Arguments: `$ARGUMENTS`. Codex `$name` maps to `/name` here; a
slash command grants no approval, model change or delegation by itself.

Use only real Claude runtime capabilities to cancel owned subagents; do not
claim a worker stopped without confirmation. Other sessions are outside its control.
