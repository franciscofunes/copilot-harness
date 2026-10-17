---
name: grill-with-docs
description: "Optional decision-capture companion to requirements questioning; produce reviewable decisions, assumptions and acceptance criteria before Spec Kit planning."
---
# Grill With Docs — Decision Capture

Use when explicitly asked to document a Grill Me session, write up clarified requirements, or preserve a design decision. Do not silently create or overwrite files.

## Workflow
1. Read only context available in the current session or repository. Distinguish confirmed facts, proposals and unanswered questions.
2. Ask one question if a blocking decision remains; otherwise write a compact decision record.
3. Include: objective, scope/non-goals, constraints, options considered, decisions with rationale, risks, unresolved questions, and measurable acceptance criteria.
4. Propose a filename under `docs/decisions/` or the repository's existing ADR location. Show the draft and ask for confirmation before writing to disk.
5. Hand the record to GitHub Spec Kit as **input**, not as a replacement for the formal specification or constitution.
6. Never assert that proposed choices were approved unless the developer explicitly approved them.

## Boundaries
No network, shell, plugin or MCP requirement. Do not copy secrets into records. Policy A0–A4 controls writes and actions. Deterministic verification owns completion evidence.
