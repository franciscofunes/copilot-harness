# Data Skill Selection Benchmark

The v1.2.0 benchmark validates that the existing `scripts/skills.ps1` selector activates native SQL Server, MongoDB and Snowflake skills in representative repositories.

## Coverage

Eight deterministic fixtures cover three positive selections, three anti-trigger exclusions, an unrelated request and a multi-database repository. Fixtures use `*.sqlproj`, `package.json` MongoDB dependency, and a Snowflake TOML dependency. No database credentials, live connections or LLM calls are required.

Run:

```powershell
pwsh ./tests/data-skill-selection-benchmark.ps1
```

CI fails when an expected skill is missing, an excluded skill is selected or a data skill is activated outside the expected set.

## Context-efficiency metric

The benchmark reports selected native skill **character counts** versus the sum of all three native data skill documents, representing a theoretical payload reduction when only selected skills are supplied to an agent.

This **does not** measure tokenizer-specific token counts, Copilot's actual injected context, response quality, latency, or API cost. Such claims require IDE-level observation and controlled trials. The character proxy must never be presented as observed token savings.

## Follow-up

Collect actual VS Code and Visual Studio invocation traces using `docs/IDE-ADOPTION-ACCEPTANCE.md`, record context inclusion where observable, and compare task quality and response cost under the same test prompts. Keep private source and credentials out of evidence.
