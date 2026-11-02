#!/usr/bin/env python3
"""Offline structural checks for the infrastructure-specific Claude adapters."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("init-project", "bootstrap", "roadmap", "spec", "dev", "orchestrate", "handoff", "relay", "task", "tweak", "adopt-project")

def validate(root):
    errors = []
    root = Path(root)
    for skill in SKILLS:
        source = root / ".agents" / "skills" / skill / "SKILL.md"
        adapter = root / ".claude" / "skills" / skill / "SKILL.md"
        if not source.is_file() or not adapter.is_file():
            errors.append(f"missing canonical or Claude skill: {skill}")
            continue
        text = adapter.read_text(encoding="utf-8")
        if not re.match(rf"\A---\nname: {skill}\ndescription: [^\n]+\n---\n", text):
            errors.append(f"invalid adapter frontmatter: {skill}")
        if f".agents/skills/{skill}/SKILL.md" not in text:
            errors.append(f"adapter disconnected: {skill}")
    for filename in ("AGENTS.md", "CLAUDE.md", "docs/harness.md", "docs/metodologia-agentes.md"):
        if not (root / filename).is_file():
            errors.append(f"missing required document: {filename}")
    agents = (root / "AGENTS.md").read_text(encoding="utf-8") if (root / "AGENTS.md").is_file() else ""
    if "No acceder al VPS" not in agents:
        errors.append("VPS access authorization gate missing")
    if "No ejecutar merges" not in agents:
        errors.append("merge approval gate missing")
    claude = (root / "CLAUDE.md").read_text(encoding="utf-8") if (root / "CLAUDE.md").is_file() else ""
    if "AGENTS.md" not in claude or "docs/metodologia-agentes.md" not in claude:
        errors.append("Claude entry point not connected to project policy")
    return errors

def main():
    errors = validate(ROOT)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print(f"vps-infra Claude adapter checks passed: {len(SKILLS)} skills and authorization links")
    return 0

if __name__ == "__main__":
    sys.exit(main())
