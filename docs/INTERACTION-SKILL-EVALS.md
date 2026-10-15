# Interaction Skill Evaluation

The harness evaluates deterministic **skill selection**, not the subjective quality of Copilot's generated responses.

Run locally on Windows with PowerShell 7:

```powershell
.\scripts\eval.ps1 -Json
.\tests\evals-smoke.ps1
```

`evals/scenarios.json` contains positive scenarios (`expectedSkills`) and negative scenarios (`forbiddenSkills`). The runner fails if any required skill is missing, a forbidden skill activates, or a required stack signal is absent. Existing scenarios without `forbiddenSkills` remain supported.

## Current coverage

- Explicit opt-in to Grill Me, decision documentation and session handoff
- Routine bug, docs and generic feature requests must **not** activate the interaction skills
- Existing .NET debugging, Angular TDD and release verification scenarios remain in the suite

## Interpretation and limitations

These tests do **not** prove that the model asks good questions, produces accurate ADRs, respects all runtime instructions, or reduces token usage. They verify selector behavior only. Human-reviewed response-quality evals and real VS/VS Code acceptance tests should be added separately, without calling an LLM in required CI.

The authority boundaries remain: Spec Kit plans; policy gates authorize; deterministic verification owns evidence.
