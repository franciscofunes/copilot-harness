---
name: session-handoff
description: "Optional compact, evidence-aware handoff for a new Copilot session or another developer."
---
# Session Handoff

Use when asked to hand off, resume later, create a continuation note, or summarize engineering state for another developer. Do not trigger for routine completion messages.

## Output contract
- **Goal and scope:** what the task is trying to achieve.
- **Verified state:** branch, commit, PR, checks and results only if supported by current evidence. Otherwise write `not verified`.
- **Changes made:** concrete paths and behavior; separate proposed from committed work.
- **Decisions and constraints:** authoritative repository policies, security and environment limitations.
- **Open questions and blockers:** what remains unknown.
- **Next safe action:** the smallest actionable step, with the exact verification command when known.

Use concise Markdown suitable for a repository issue or continuation prompt. Avoid unnecessary transcript copying, personal data, secrets or large file dumps. Ask permission before saving to a repository file.

## Boundaries
Handoff is descriptive, not approval. GitHub Spec Kit owns planning, policy gates own authorization, and the verification engine owns acceptance evidence. No scripts, external calls, MCP or marketplace dependency.
