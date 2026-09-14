# Verification Contract

The Verification Contract defines what evidence is required before Copilot or a developer may describe work as complete, ready, validated or safe to merge.

**Generated output is not evidence. Execution evidence is evidence.**

## Evidence states

Every applicable verification item must have one state:

- `PASS` — executed successfully with evidence.
- `FAIL` — executed and failed or produced an unacceptable result.
- `BLOCKED` — required verification could not execute because a prerequisite/environment is unavailable.
- `SKIPPED` — intentionally omitted with a documented reason and owner/risk decision.
- `NOT RUN` — no execution evidence exists yet.

Only `PASS` means the check passed.

## Verification levels

### V0 — Scope and diff

Required for every implementation change.

Verify:
- active Spec Kit task/acceptance criteria are identifiable;
- changed files are within intended scope;
- unrelated changes are not silently included;
- secrets and generated noise are not introduced.

### V1 — Static correctness

Run the narrowest applicable static checks:
- PowerShell parse/validation for `.ps1` changes;
- compiler/type-checking for .NET/TypeScript changes;
- linting where configured;
- schema/configuration validation where tooling exists.

### V2 — Automated behavior

Run the narrowest relevant automated tests first, then broader suites when justified:
- unit tests;
- integration tests;
- API/component tests;
- regression tests for changed behavior;
- deterministic harness smoke tests.

### V3 — Integration / data / security

Required when the change crosses the relevant boundary:
- API compatibility and auth/role behavior;
- database migration/schema/backfill/rollback validation;
- MongoDB/Snowflake/Parquet compatibility;
- GitHub SAST/status checks;
- JFrog compliance/security scans;
- Azure/infrastructure validation;
- failure/retry/concurrency/data-integrity scenarios.

### V4 — Acceptance and release

Required for release readiness:
- acceptance criteria mapped to automated or manual evidence;
- QA scenarios and outstanding risks visible;
- release test plan uses `PASS/FAIL/BLOCKED/SKIPPED/NOT RUN` truthfully;
- required CI/security/compliance checks are green or explicitly blocked/skipped by an authorized decision;
- release notes and version impact are correct.

## Change-type matrix

| Change type | Minimum evidence |
| --- | --- |
| Documentation/instructions | V0 + syntax/format checks where applicable |
| PowerShell harness scripts | V0 + parse + smoke/unit behavior |
| .NET code | V0 + build/type correctness + relevant tests |
| Angular/TypeScript | V0 + type/lint + relevant tests/build |
| API contract | Above + compatibility/auth/integration checks |
| SQL/Mongo/Snowflake/Parquet | Above + schema/data compatibility + rollback/recovery reasoning and executable validation where available |
| CI/Azure/JFrog/GitHub workflow | Above + configuration validation + execution evidence in an appropriate environment |
| Security-sensitive change | Above + applicable SAST/compliance/security evidence |
| Release | V0–V4 as applicable + versioned release test plan |

## Evidence record

Verification summaries should be concise and machine-readable enough for Copilot, QA and reviewers to reuse:

```text
Check: dotnet test tests/MyProject.Tests
State: PASS
Scope: changed service behavior
Evidence: 42 passed, 0 failed
Source: local execution / CI run
```

Do not paste enormous logs into permanent context. Preserve the command, state, concise outcome and a durable run/reference when one exists.

## Completion rules

Copilot must not say `done`, `verified`, `all tests pass`, `ready to merge` or equivalent when a required check is `FAIL`, `BLOCKED` or `NOT RUN`.

`SKIPPED` may be compatible with completion only when the reason, residual risk and authorization are explicit.

If execution is unavailable, report what was implemented and list the exact verification that remains `NOT RUN` or `BLOCKED`.

## Failure feedback loop

A failed verification is input to the next reasoning cycle:

1. preserve the failure evidence;
2. identify whether failure is caused by the change, environment or unrelated baseline;
3. make the smallest justified correction;
4. rerun the failed check;
5. rerun affected regression checks;
6. update the evidence state.

Never weaken, delete or bypass a legitimate check merely to turn it green.