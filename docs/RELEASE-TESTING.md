# Release Testing Contract

Every Copilot Harness release must have a versioned testing plan that defines what must be verified, what evidence is acceptable, and which checks may be skipped only with an explicit reason.

This document is the stable contract. Release-specific test plans live under `docs/releases/<version>-testing.md`.

## Why this exists

The harness must never treat generated output as proof of correctness. A release is considered ready only when its applicable verification steps have been executed or explicitly marked unavailable with a documented reason and risk.

Copilot should use this contract together with the active release-specific testing plan when helping prepare, review, or validate a release.

## Required evidence states

Each test item must end in exactly one of these states:

- `PASS` — the check was executed and succeeded.
- `FAIL` — the check was executed and failed.
- `BLOCKED` — the check is required but cannot currently be executed.
- `SKIPPED` — the check is not applicable to this release, with a reason.
- `NOT RUN` — the check has not yet been executed. This is never equivalent to PASS.

Copilot must not rewrite `BLOCKED`, `SKIPPED`, or `NOT RUN` as success.

## Release test layers

### 1. Repository integrity

Verify that:

- the release branch contains only intended scope;
- version and changelog metadata are correct;
- documentation matches implemented behavior;
- no generated secrets, credentials, local paths, or machine-specific files are committed;
- required PR and Mermaid conventions are satisfied.

### 2. Static and syntax validation

Run all applicable parsers, linters, formatters, schema checks, and static analysis available in the repository.

For PowerShell harness code, parsing through the PowerShell AST is the minimum syntax gate.

### 3. Unit and smoke validation

Run the smallest deterministic tests that exercise the changed behavior. Tests should prefer temporary isolated fixtures and must not depend on production data.

### 4. Installer and idempotency validation

For installer-related releases, validate at minimum:

- clean install;
- second install with no changes;
- existing-file preservation in default conflict mode;
- explicit overwrite behavior;
- missing optional tooling;
- invalid or partial target repository;
- manifest creation and parseability;
- doctor result after installation.

### 5. Spec Kit integration validation

When Spec Kit integration changes, verify against the official `github/spec-kit` CLI available in the environment:

- `specify` is available and reports a version;
- initialization completes successfully;
- selected Copilot layout is created as expected;
- expected extensions are discoverable/installable;
- existing `.specify` content is not unintentionally destroyed;
- the harness manifest records the configured Spec Kit source, layout, and extensions;
- doctor output reflects the actual installed state.

Never infer Spec Kit behavior solely from documentation when executable verification is available.

### 6. Stack-specific validation

Apply only the checks relevant to the detected stack:

- .NET: restore/build/test and relevant analyzers;
- Angular/TypeScript: install/restore, lint, tests, build;
- SQL Server: migration/query validation, compatibility and rollback review;
- MongoDB: schema/index/compatibility review and targeted tests;
- Snowflake: query validation, role/access assumptions, cost/pruning concerns;
- Parquet: schema compatibility and producer/consumer validation;
- Azure/JFrog/GitHub integrations: CLI presence plus non-destructive/read-only checks unless the release explicitly requires write actions.

### 7. Negative and failure-path validation

Every release test plan must include relevant negative scenarios. Examples:

- required CLI missing;
- permissions denied;
- malformed configuration;
- unsupported stack;
- partially initialized Spec Kit;
- extension installation failure;
- existing customized instructions;
- non-zero child process exit code.

### 8. Upgrade and compatibility validation

If the release changes managed files, manifests, installer behavior, or Spec Kit integration, test upgrades from the latest released harness version where possible.

Document any intentionally unsupported upgrade path.

### 9. Security and policy validation

Confirm that the release:

- introduces no secrets;
- does not weaken authentication/authorization or repository protections;
- does not add unapproved runtime dependencies;
- does not silently execute destructive operations;
- preserves explicit user approval for overwrite or destructive actions;
- does not claim prompt text alone is an enforceable security boundary.

### 10. Manual UX validation

For developer-facing releases, perform the documented flow exactly as a user would and verify:

- commands are copy/paste safe on Windows PowerShell;
- errors are understandable and actionable;
- warnings are distinguishable from failures;
- the final output tells the user what happened and what remains to do.

## Minimum release gate

A release must not be marked ready while any release-specific item remains `FAIL`.

A `BLOCKED` item requires an explicit risk decision in the release notes or PR. `NOT RUN` items must be resolved before release unless they are changed to `SKIPPED` with a justified reason.

## Evidence format

Release-specific plans should use a table with these columns:

| ID | Scenario | Command / Method | Expected Result | Status | Evidence / Notes |
| --- | --- | --- | --- | --- | --- |
| RT-001 | Example | `command` | Expected behavior | NOT RUN | |

Evidence should prefer reproducible artifacts such as command output, CI run links, test reports, screenshots, or concise manually recorded observations.

## Copilot behavior

When asked whether a release is ready, Copilot must:

1. read this contract;
2. read the current release-specific testing plan;
3. inspect the relevant changed files;
4. distinguish executed checks from recommendations;
5. list unresolved `FAIL`, `BLOCKED`, and `NOT RUN` items;
6. never declare the release ready unless the release gate is satisfied.

When a new release is started, Copilot should create `docs/releases/<version>-testing.md` from the current scope and keep it updated as verification is performed.
