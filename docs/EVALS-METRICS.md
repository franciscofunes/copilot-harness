# Harness Evals & Metrics

The eval layer measures deterministic harness behavior without treating model opinion as proof.

## Baseline

`evals/scenarios.json` defines small repository fixtures with expected stack detection and curated-skill selection. `scripts/eval.ps1` creates isolated temporary fixtures, executes the real selector, compares actual results with explicit expectations, and emits machine-readable metrics.

Current baseline scenarios cover:

- .NET debugging → stack detection + systematic debugging
- Angular feature work → stack detection + test-driven development
- release completion → verification-before-completion guidance

## Metrics

The runner reports total scenarios, pass/fail counts, pass rate, expected vs actual skills, and expected vs actual stacks.

These are harness regression metrics, not developer productivity scores and not LLM quality scores.

## Evidence boundary

A deterministic assertion may produce PASS or FAIL. No LLM judge is required for baseline acceptance. Future evals may measure context selection, policy decisions, verification states, and evidence completeness while preserving the same rule: generated reasoning is not execution evidence.

## Usage

```powershell
.\scripts\eval.ps1
.\scripts\eval.ps1 -Json
.\scripts\eval.ps1 -OutputPath .\.copilot-harness\evals\latest.json
```
