# Changelog

All notable changes to Copilot Harness will be documented in this file.

The project follows Semantic Versioning.

## [0.5.0] - 2026-09-17

### Added

- First-class CodeGraph bootstrap integration using the official `colbymchenry/codegraph` repository.
- Windows CodeGraph setup through `scripts/setup-codegraph.ps1` with optional release pinning via `-CodeGraphVersion`.
- Local CodeGraph project initialization through `codegraph init`.
- CodeGraph telemetry disabled by default unless explicitly retained.
- CodeGraph source, requested version, initialization intent, telemetry mode, and CLI-only integration mode recorded in `.copilot-harness.json`.
- CodeGraph documentation and dedicated smoke tests.

### Changed

- Harness installer can provision CodeGraph as part of repository bootstrap, with explicit opt-out switches.
- CI now validates both the existing harness smoke suite and CodeGraph integration contracts.
- CodeGraph integration remains CLI-only so the harness baseline does not require MCP or marketplace plugins.

### Verification

- PR #12 merged into `develop` after the Windows `Harness Smoke` workflow completed successfully on commit `222f76c127a52544f9ffee9eacca1cabded55179`.
- Release branch: `release/0.5.0`.

### Notes

This release adds semantic code-graph tooling to the harness while preserving the existing policy boundary: repository analysis may use CodeGraph CLI context, but model output remains separate from deterministic execution evidence.

## [0.4.0] - 2026-09-15

### Added

- Repository-configurable verification profiles through `.copilot-harness.verify.json`.
- Explicit verification profile selection with `-ProfilePath`.
- Direct executable + argument-array invocation for repository checks without shell evaluation or `Invoke-Expression`.
- Verification-profile CLI allowlist for supported development and verification tooling.
- Profile change-type filtering and preservation of explicit harness evidence states.
- Example verification profile and repository profile documentation.
- Repository-neutral PR branch-position diagram convention alongside the technical Mermaid change diagram.

### Changed

- `scripts/verify.ps1` can use repository-specific deterministic checks while retaining generic stack-aware verification when no profile exists.
- Automatic profile execution is restricted to A0/A1 verification; A2-A4 actions cannot gain authorization from repository configuration.
- Installed target-repository guidance supports only `feature/*` and `release/*` working branch families and does not assume a `develop` branch.
- PR templates no longer project this harness repository's internal integration topology onto target solutions.

### Security

- Repository verification profiles are treated as reviewed executable configuration.
- Profile commands use direct process invocation rather than arbitrary shell expressions.
- Remote, destructive, production, and security-sensitive operations remain governed by the Policy Gate and cannot be authorized by a verification profile.

### Notes

This release makes the verification layer repository-aware without expanding global Copilot context or weakening the v0.3.0 policy boundary.

## [0.3.0] - 2026-09-15

### Added

- Policy Gate contract with A0-A4 action classifications for read-only work, local verification, repository mutation, shared-state mutation, and destructive/production/security-sensitive actions.
- Executable `scripts/policy-check.ps1` evaluator with deterministic allow, intent-required, and approval-required decisions.
- Verification Contract with V0-V4 evidence levels covering scope, static correctness, automated behavior, integration/data/security, and acceptance/release evidence.
- Executable `scripts/verify.ps1` verification runner with explicit `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, and `NOT RUN` states.
- Cross-repository Copilot instructions that route execution and completion decisions through the policy and verification contracts.
- Spec Kit extension validation strategy covering the official `bug`, `git`, `assess`, and optional `agent-context` extensions without making extensions the authorization or verification source of truth.
- Installer, manifest, doctor, and smoke-test integration for the policy and verification runtime.
- Windows CI smoke coverage for policy A0/A3/A4 behavior and verification-runner behavior.

### Changed

- Harness verification now distinguishes generated reasoning from deterministic execution evidence.
- High-risk actions fail closed when production target or authorization is ambiguous.
- Release and engineering completion claims are bound to explicit verification evidence rather than model assertions.

### Notes

This release establishes the harness reliability layer: Copilot can propose work, but policy determines execution boundaries and deterministic verification determines whether evidence supports acceptance. Spec Kit extensions remain optional accelerators around this model rather than hidden runtime dependencies.

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
