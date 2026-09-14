# Windows Bootstrap and Doctor

This document describes the first executable adoption flow for Copilot Harness.

## Goal

A developer should be able to clone the harness repository, point the installer at an existing Windows repository, and receive a stack-aware Copilot + GitHub Spec Kit baseline without requiring MCP servers or marketplace plugins.

## Bootstrap

Run from a PowerShell terminal in the cloned `copilot-harness` repository:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application
```

The installer:

1. detects repository technologies;
2. initializes GitHub Spec Kit when `specify` is available and `.specify` is not already present;
3. installs the lean repository-wide Copilot instructions;
4. installs only the path-scoped stack instructions that apply to the target repository;
5. installs the shared feature prompt and constitution template;
6. writes `.copilot-harness.json` as an installation manifest;
7. runs the harness doctor.

### Safe defaults

Existing target files are **not overwritten by default**. The installer reports a warning and leaves them unchanged.

To intentionally replace managed harness files:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application -ConflictMode overwrite
```

Use overwrite mode only after reviewing local customizations. A later release should provide semantic merge/update support rather than treating overwrite as the normal upgrade path.

### Spec Kit

The bootstrap expects the GitHub Spec Kit `specify` command when SDD initialization is desired. When it is unavailable, the installer continues with the repository-native Copilot assets and reports a warning.

To deliberately skip Spec Kit initialization:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application -SkipSpecKit
```

The installer does not attempt to install developer tooling automatically. Tool installation remains an explicit workstation-management decision.

## Stack detection

The detector can be run independently:

```powershell
.\scripts\detect-stack.ps1 -Path C:\src\my-application
```

Or emit machine-readable output:

```powershell
.\scripts\detect-stack.ps1 -Path C:\src\my-application -AsJson
```

Current signals cover:

- .NET / ASP.NET repositories
- Angular
- SQL Server
- MongoDB
- Snowflake
- Parquet
- Azure DevOps pipelines
- GitHub Actions
- JFrog usage

Detection is intentionally evidence-based and conservative. It does not claim that a technology is present only because it exists in the organization-wide stack.

## Harness doctor

Run diagnostics without changing the target repository:

```powershell
.\installer\doctor.ps1 -TargetPath C:\src\my-application
```

Doctor results use three states:

- `PASS` — required evidence is present;
- `WARN` — optional/recommended capability is missing or configuration needs attention;
- `FAIL` — a blocking requirement for the detected target stack is missing.

The command exits with code `1` only when blocking failures exist.

## Smoke validation

The harness repository includes a dependency-free PowerShell smoke check:

```powershell
.\tests\smoke.ps1
```

It validates PowerShell syntax and exercises stack detection against a temporary fixture. This is a repository-level smoke test; it does not replace testing the bootstrap against representative real .NET and Angular repositories.

## Current limitations

This first bootstrap iteration intentionally does not yet provide:

- semantic merging of existing Copilot instruction files;
- automatic dependency or CLI installation;
- centralized policy-gate enforcement;
- CI validation of harness health;
- upgrade migrations between harness versions;
- a reference application fixture covering the complete company stack.

Those are follow-on `v0.2.0` capabilities, with deterministic policy and verification behavior taking priority over adding more prompt content.
