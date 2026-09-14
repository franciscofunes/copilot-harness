# Windows Bootstrap and Doctor

This document describes the first executable adoption flow for Copilot Harness.

## Goal

A developer should be able to clone the harness repository, point the installer at an existing Windows repository, and receive a stack-aware Copilot + GitHub Spec Kit baseline without requiring MCP servers or marketplace plugins.

The only supported SDD engine for this harness is the official GitHub repository:

- `https://github.com/github/spec-kit`

The harness must not reimplement or fork Spec Kit's generated SDD workflow.

## Bootstrap

Run from a PowerShell terminal in the cloned `copilot-harness` repository:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application
```

The installer:

1. detects repository technologies;
2. initializes the official `github/spec-kit` integration when `specify` is available and `.specify` is not already present;
3. defaults Copilot integration to the **commands layout** because current team usage is generating Spec Kit content under `.github/agents` / `.github/prompts`, not `.github/skills`;
4. installs recommended Spec Kit extensions (`git`, `bug`, and `assess`) unless explicitly skipped;
5. installs the lean repository-wide Copilot instructions;
6. installs only the path-scoped stack instructions that apply to the target repository;
7. installs the shared feature prompt and constitution template;
8. writes `.copilot-harness.json` as an installation manifest;
9. runs the harness doctor.

### Safe defaults

Existing target files are **not overwritten by default**. The installer reports a warning and leaves them unchanged.

To intentionally replace managed harness files:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application -ConflictMode overwrite
```

Use overwrite mode only after reviewing local customizations. A later release should provide semantic merge/update support rather than treating overwrite as the normal upgrade path.

## Spec Kit source of truth

The harness is intentionally coupled to the official GitHub project:

```text
https://github.com/github/spec-kit
```

`specify` is expected to come from that project. The harness records the repository URL in `.copilot-harness.json` and the doctor checks that the manifest points to the same source of truth.

The generated Spec Kit workflow remains owned by Spec Kit. Copilot Harness only adds organization-specific policy, stack instructions, verification, and bootstrap behavior around it.

## Copilot layout: commands vs skills

Spec Kit supports multiple Copilot integration layouts. In our environment, the installer defaults to `commands`:

```powershell
.\installer\install.ps1 `
  -TargetPath C:\src\my-application `
  -SpecKitLayout commands
```

This invokes Spec Kit with the commands integration option and is expected to generate Copilot assets under `.github/agents` and `.github/prompts`.

This default directly reflects team feedback that current Spec Kit initialization is creating content in `agents` rather than defaulting to `.github/skills`.

If a repository explicitly wants the skills layout, it remains available:

```powershell
.\installer\install.ps1 `
  -TargetPath C:\src\my-application `
  -SpecKitLayout skills
```

The harness therefore must not claim that `.github/skills` is always the default seen by every Copilot setup. The actual integration mode is explicit and recorded in the manifest.

## Recommended Spec Kit extensions

The initial team baseline installs these official bundled extensions:

```powershell
specify extension add git
specify extension add bug
specify extension add assess
```

Why:

- `git` adds Spec Kit's Git branching workflow support.
- `bug` adds the bug assessment/fix/test workflow.
- `assess` adds idea assessment before committing to the full SDD lifecycle.

The installer can be customized:

```powershell
.\installer\install.ps1 `
  -TargetPath C:\src\my-application `
  -SpecKitExtensions git,bug,assess
```

Or extension installation can be deliberately skipped:

```powershell
.\installer\install.ps1 `
  -TargetPath C:\src\my-application `
  -SkipSpecKitExtensions
```

Extensions are opt-in capabilities from Spec Kit. Adding more extensions later should be an explicit, reviewed harness decision rather than an uncontrolled marketplace-style dependency.

### Bug workflow

With the `bug` extension enabled, the intended flow is:

```text
assess -> fix -> test
```

This is particularly useful for turning bug reports into bounded artifacts and verified remediation instead of jumping directly from a chat request into code changes.

### Assess workflow

With the `assess` extension enabled, teams can evaluate an idea before starting a full feature specification. This provides a useful discovery/triage gate for requests that may be unclear, low-value, or not ready for implementation.

## Skipping Spec Kit

Spec Kit can still be deliberately skipped for diagnostics or exceptional repositories:

```powershell
.\installer\install.ps1 -TargetPath C:\src\my-application -SkipSpecKit
```

This is not the normal team path. The default harness architecture expects official GitHub Spec Kit to own SDD.

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

The doctor now also checks:

- that `.specify` exists;
- that the expected Copilot integration layout is visible;
- that the manifest records `https://github.com/github/spec-kit` as the Spec Kit source;
- that recommended Spec Kit extensions are visible via `specify extension list` when the CLI is available.

The command exits with code `1` only when blocking failures exist.

## Smoke validation

The harness repository includes a dependency-free PowerShell smoke check:

```powershell
.\tests\smoke.ps1
```

It validates PowerShell syntax and exercises stack detection against a temporary fixture. This is a repository-level smoke test; it does not replace testing the bootstrap against representative real .NET and Angular repositories.

## Current limitations

This bootstrap iteration intentionally does not yet provide:

- semantic merging of existing Copilot instruction files;
- automatic dependency or CLI installation;
- centralized policy-gate enforcement;
- upgrade migrations between harness versions;
- a reference application fixture covering the complete company stack.

Those are follow-on `v0.2.0` capabilities, with deterministic policy and verification behavior taking priority over adding more prompt content.
