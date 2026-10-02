# Changelog

All notable changes to Copilot Harness will be documented in this file.

The project follows Semantic Versioning.

## [0.9.0] - 2026-10-02

### Added

- End-to-end task-intent propagation through `scripts/run-harness.ps1` into deterministic context and curated skill selection.
- Durable selected-skill and authority-boundary context in evidence runs.
- End-to-end orchestration smoke coverage in Windows Harness Smoke CI.

### Changed

- Orchestration fails closed when context generation fails, verification returns no JSON, or evidence recording fails.
- Verification FAIL, BLOCKED, and NOT RUN outcomes retain their verification exit state instead of being converted into orchestration success.
- Curated skills are integrated into runtime context while Policy Gate remains authoritative for authorization and `verify.ps1` remains authoritative for deterministic evidence.

### Verification

- PR #26 integrated curated skills into runtime context and completed Harness Smoke successfully.
- PR #27 merged into `develop` as `1041eacad10b57453358c28d5927de330f1bf824`.
- PR #27 final feature head `50fb676bfc8e951f82141a15ce64149cef43ae61` completed Harness Smoke run #36995593859 successfully.
- Release-head CI is required before promotion to `main`.

### Notes

This release turns the existing context, curated-skills, verification, and evidence components into a more explicit end-to-end orchestration path. It preserves the core boundary: Copilot proposes; the harness verifies. Authorization is not inferred from task intent or skill selection.

## [0.8.1] - 2026-09-28

### Added

- Stack-aware repository verification profile generation through `scripts/new-verification-profile.ps1`.
- Deterministic local A1 verification checks for detected .NET and Angular projects.
- Review recommendations for detected data/platform stacks instead of guessed remote executable checks.
- Installer and doctor integration for generated repository verification profiles.

### Changed

- Existing `.copilot-harness.verify.json` files are preserved by default unless replacement is explicitly requested.
- Harness Smoke now validates generated profiles, profile preservation, and safe data/platform recommendations.
- GitHub Actions Harness Smoke coverage now includes release branches and pull requests targeting `main`, enabling release-head CI before promotion.

### Verification

- PR #11 merged into `develop` as `9caf1ae36fd184864315478546e790fbb3311945`.
- Final PR #11 feature head `12a47cf0df2a0d1944a1e706aba3d06f723e8383` completed Harness Smoke successfully.
- Release-head CI is required before promotion to `main`.

### Notes

This patch restores the previously unmerged stack-aware verification capability on top of the current harness architecture and hardens the release verification path. Generated executable checks remain limited to known local A1 verification; remote or higher-risk actions are not inferred from stack detection.

## [0.8.0] - 2026-09-27

### Added

- Deterministic harness eval runner and scenario catalog for regression testing.
- Baseline .NET debugging, Angular feature/TDD, and release-verification eval scenarios.
- Machine-readable pass/fail/pass-rate metrics for expected stack and curated-skill selection.
- Policy Gate evals for A1, A3 explicit-intent boundaries, and A4 production approval requirements.
- Evidence Engine evals for artifact completeness and preservation of FAIL verification state.
- Dedicated Windows CI coverage for harness eval regressions and policy/evidence boundaries.

### Changed

- Harness reliability can now be regression-tested across stack detection, skill selection, policy decisions, and evidence recording.
- Eval acceptance relies on deterministic assertions rather than an LLM judge.

### Verification

- PR #21 merged into `develop`; Harness Smoke #63 passed on its feature head.
- PR #22 merged into `develop` as `54b2e1920b9dba7742e97591c25b93e99a1863a3`.
- Harness Smoke #67 completed successfully on PR #22 feature head `52a779c5a2ef9704d75e821558be717c8fe3bd81`.
- Release branch: `release/0.8.0`.
- Release-head CI is required before promotion to `main`.

### Notes

This release establishes an objective regression layer for key harness contracts. Metrics describe harness behavior and evidence completeness; they are not developer productivity scores or model-generated proof.

## [0.7.0] - 2026-09-20

### Added

- Curated skills catalog with recorded upstream provenance.
- Deterministic skill selection through `scripts/skills.ps1`.
- Initial capabilities for systematic debugging, test-driven development, verification before completion, and codebase knowledge acquisition.
- Dedicated curated-skills smoke coverage in the Windows Harness Smoke workflow.

### Changed

- The harness can select task-relevant capability guidance from intent and detected stack without installing an overlapping agent framework.
- Skills requiring MCP are excluded from the baseline.
- Curated skills remain advisory: Spec Kit owns planning, Policy Gate owns authorization, `verify.ps1` owns deterministic evidence, and CodeGraph remains a context provider.

### Verification

- PR #18 merged into `develop` as `7545d7ac6a58cee6380edbc9b2d2b1b8fa2a8e38`.
- Harness Smoke run #59 completed successfully on feature head `719bc350f915988134ab2feb7b717669dd1fbaa3`.
- Release branch: `release/0.7.0`.
- Release-head CI is required before promotion to `main`.

### Notes

This release adds a narrow capability layer instead of installing external frameworks wholesale, preserving the harness's existing authority boundaries.

## [0.6.0] - 2026-09-18

### Added

- Deterministic context builder through `scripts/context.ps1`.
- Local evidence recorder through `scripts/record-evidence.ps1`.
- Orchestrated context → verification → evidence workflow through `scripts/run-harness.ps1`.
- Context manifests covering stack detection, changed files, relevant Copilot instructions, verification profile presence, CodeGraph availability, and policy/verification entry points.
- Local evidence runs under `.copilot-harness/runs/<run-id>/`.
- Context & Evidence Engine documentation and smoke coverage.

### Changed

- Harness installer now deploys and records the Context & Evidence Engine assets.
- Verification failures can be fed back as grounded context for the next implementation iteration.
- CodeGraph is explicitly treated as a context provider rather than verification evidence.

### Verification

- PR #14 merged into `develop` as merge commit `7d708942c5c287d8bd53c296e65a9386a985cfcc`.
- Release branch: `release/0.6.0`.
- Release-head CI must complete before promotion to `main`.

### Notes

This release extends the reliability layer from policy and deterministic verification into deterministic context selection and durable local evidence. Evidence storage is metadata/output oriented and is not a transcript or hidden-reasoning archive.

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
