# Changelog

All notable changes to Copilot Harness will be documented in this file.

The project follows Semantic Versioning.

## [0.2.0] - 2026-09-14

### Added

- Windows bootstrap installer with safe, idempotent-by-default behavior.
- Repository stack detection for .NET, Angular, SQL Server, MongoDB, Snowflake, Parquet, Azure DevOps, GitHub Actions, and JFrog signals.
- Harness doctor with PASS / WARN / FAIL diagnostics and blocking exit codes.
- Official `github/spec-kit` integration as the supported SDD engine.
- Explicit Copilot integration layout selection for Spec Kit (`commands` or `skills`), with `commands` as the harness default.
- Default Spec Kit extension baseline for `git`, `bug`, and `assess`.
- Installation manifest (`.copilot-harness.json`) with harness, stack, Spec Kit, and release-testing metadata.
- Release testing contract, reusable release-test template, Copilot instructions for evidence handling, and a concrete `v0.2.0` test plan.
- Dependency-free PowerShell smoke tests and a Windows GitHub Actions smoke workflow.
- Bootstrap and doctor documentation for developers and QA.

### Changed

- Copilot guidance no longer assumes `.github/skills` is universally the default Spec Kit integration layout.
- Release readiness now requires explicit evidence states: `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, or `NOT RUN`; missing execution evidence is never treated as success.

### Notes

This release turns the harness foundation into an executable adoption workflow. It focuses on deterministic bootstrap, environment discovery, Spec Kit configuration, stack-aware Copilot customization, diagnostics, and release evidence. Policy-gate enforcement, change-type verification contracts, branch/ruleset enforcement, semantic upgrade merging, and a representative reference application remain follow-up work.

## [0.1.0] - 2026-09-14

### Added

- Windows-first repository-native Copilot harness foundation.
- Git Flow branching and release conventions.
- GitHub Spec Kit as the authoritative Spec-Driven Development engine.
- Shared Copilot repository instructions for Visual Studio and VS Code.
- Path-scoped instructions for .NET / ASP.NET Core, Angular / TypeScript, data workloads, and tests / QA.
- Token-efficient progressive-disclosure guidance for Copilot context.
- Harness engineering model covering context building, reasoning, policy, tools/runtime, verification, and accepted results.
- QA workflow and acceptance-criteria traceability guidance.
- Windows setup and Copilot customization strategy documentation.
- PR template with mandatory Mermaid diagrams and release-impact classification.

### Notes

This is the first foundation release. It defines the architecture, governance, SDD model, IDE compatibility strategy, and engineering constraints. Automated Windows installation, stack detection, harness doctor checks, and executable policy/verification gates are planned for the next minor release.
