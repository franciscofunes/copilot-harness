# Harness Readiness Contract

Copilot Harness exposes a deterministic readiness contract through `scripts/doctor.ps1`.

The doctor answers one question: **is this installed harness runtime complete enough to be relied on?**

## Command

```powershell
.\scripts\doctor.ps1 -TargetPath .
```

For automation and CI:

```powershell
.\scripts\doctor.ps1 -TargetPath . -Json
```

## Machine-readable schema

The JSON output uses `SchemaVersion = 1` and contains:

- `Target` — resolved repository path.
- `DetectedStacks` — stack signals detected for the repository.
- `Checks` — deterministic readiness checks with `Name`, `Status`, and `Detail`.
- `Counts` — totals for `Pass`, `Warn`, and `Fail`.
- `Ready` — `true` only when no check is in `FAIL`.

## Status semantics

| Status | Meaning | Blocks readiness |
| --- | --- | --- |
| `PASS` | Required contract is satisfied. | No |
| `WARN` | Optional capability or recommendation is unavailable. | No |
| `FAIL` | Required runtime, manifest contract, tool, or configuration is missing or invalid. | Yes |

Warnings must never be silently converted into failures, and failures must never be treated as readiness.

## Exit codes

- `0` — the harness is ready; warnings may still exist.
- `1` — at least one blocking readiness failure exists.

## Stable runtime checks

The doctor validates the repository-native runtime required by the stable harness, including:

- stack detection;
- policy and verification;
- verification profile generation;
- context and curated skills;
- evidence recording and orchestration;
- lifecycle and maker/checker;
- audit metrics, integrity diagnostics, and audit reports;
- the installed doctor itself;
- required contracts and instructions.

It also validates that `.copilot-harness.json` points at the expected stable entry points. A manifest that references missing or incompatible stable entry points is not ready.

## Environment checks

Required local workflow tools such as Git and GitHub CLI are blocking when unavailable. Stack-specific required tools become blocking only when that stack is detected.

Spec Kit CLI/extensions, `uv`, Azure CLI, JFrog CLI, and other optional integrations may produce warnings when the core harness can still operate safely without them.

## Upgrade behavior

Running the installer in `skip` conflict mode preserves repository-owned harness files while adding stable runtime files that were introduced by later harness versions. After installation or upgrade, the doctor is the authoritative readiness check for runtime completeness.

## CI contract

Harness Smoke must prove both sides of the contract:

1. a representative fresh install reports `Ready = true`;
2. removing a required stable runtime file produces `Ready = false`, a `FAIL` check, and exit code `1`.

Copilot proposes; the harness verifies.
