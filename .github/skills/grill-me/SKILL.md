---
name: grill-me
description: "Optional requirements interrogation for ambiguous features, architecture decisions, and explicit 'grill me' requests before GitHub Spec Kit planning."
---
# Grill Me — Requirements Challenge

Use this skill only when the developer explicitly asks to be grilled, challenged or questioned about a design, or when a substantial feature has material unanswered requirements and the developer opts into a review. Never trigger it as a mandatory gate for a straightforward bug fix, narrow refactor, or documentation update.

## Interaction contract
1. Briefly restate the desired outcome and known constraints, separating facts from assumptions.
2. Ask **one high-impact question at a time**. Prioritize business objective, users, acceptance criteria, failure cases, data ownership, security, operational constraints and trade-offs. Avoid trivia and questions already answered in the repository.
3. Challenge contradictions with evidence; offer concrete options and explain the consequences. Do not invent answers.
4. Stop when the developer says stop, enough, or proceed. Avoid endless questioning: normally aim for 3–7 substantive questions, fewer when the request is already clear.
5. Summarize decisions, unresolved questions, risks and testable acceptance criteria. Explicitly mark unknowns.
6. Hand the resulting clarified requirements to **GitHub Spec Kit** for planning. Do not replace Spec Kit, authorize changes, edit code, or claim verification.

## Safety and compatibility
- Repository-local, advisory, no scripts, network calls, MCP server, or marketplace dependency.
- Do not request passwords, API keys or confidential production data.
- Policy A0–A4 still controls authorization. Only the harness verification engine produces completion evidence.
- This is independently authored harness guidance inspired by the interaction pattern; it does not copy or install upstream skill files.
