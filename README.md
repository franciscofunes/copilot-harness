# Copilot Harness

A **repository-native engineering harness for GitHub Copilot** that turns AI-assisted development into a controlled, repeatable, and evidence-driven workflow.

Instead of relying on prompts alone, Copilot Harness gives the repository executable rules for **context, planning, authorization, verification, evidence, and quality feedback**.

> **Copilot proposes; the harness verifies.**

## What it does

Copilot Harness sits around the AI-assisted development workflow. It helps Copilot understand the repository, selects relevant engineering guidance, constrains what may execute automatically, runs deterministic verification, and records evidence that can be reviewed by developers and QA.

```mermaid
flowchart LR
    U[Developer intent] --> H[Copilot Harness]
    H --> C[Context Engine]
    C --> S[Spec Kit planning]
    C --> K[Curated Skills]
    S --> P[Proposed change]
    K --> P
    P --> G[Policy Gate A0-A4]
    G --> V[Verification Engine]
    V --> E[Evidence]
    E --> D{Ready?}
    D -->|No| U
    D -->|Yes| R[PR / Release]
```

The model is intentionally asymmetric: AI can reason and propose broadly, but **authorization and acceptance are controlled by deterministic harness components**.

## Core capabilities

| Capability | What it provides |
| --- | --- |
| **Context Engine** | Detects stack, changed files, instructions, verification configuration, CodeGraph availability, task intent, and selected skills. |
| **GitHub Spec Kit** | Provides the supported Spec-Driven Development planning workflow. |
| **Curated Skills** | Selects focused engineering guidance for debugging, TDD, verification, and codebase exploration without installing another agent framework. |
| **Policy Gate** | Classifies actions from A0-A4 and requires explicit intent or immediate approval as risk increases. |
| **Verification Engine** | Runs deterministic repository checks and reports PASS, FAIL, BLOCKED, SKIPPED, or NOT RUN. |
| **Stack-aware profiles** | Generates safe verification profiles for detected .NET and Angular projects and recommendations for platform/data stacks. |
| **Evidence Engine** | Persists context, verification output, policy snapshots when supplied, and run summaries under `.copilot-harness/runs/`. |
| **Harness Evals** | Regression-tests stack detection, skill selection, policy decisions, and evidence behavior. |
| **CodeGraph integration** | Adds semantic codebase context through the official CLI while keeping it separate from verification evidence. |
| **Installer + Doctor** | Bootstraps the harness on Windows and diagnoses repository/environment readiness. |
| **Windows CI** | Exercises harness contracts through GitHub Actions smoke and regression checks. |

## Safety and verification model

The harness separates **what may be done** from **whether the result is acceptable**.

```mermaid
flowchart TB
    A[Requested action] --> P{Policy Gate}
    P -->|A0 Read| A0[Automatic]
    P -->|A1 Verify| A1[Automatic]
    P -->|A2 Repo mutation| A2[Controlled workflow]
    P -->|A3 Shared / remote| A3[Explicit intent required]
    P -->|A4 Destructive / production / security-sensitive| A4[Immediate approval required]

    A0 --> V[Verification]
    A1 --> V
    A2 --> V
    A3 --> V
    A4 --> V

    V --> X[PASS / FAIL / BLOCKED / SKIPPED / NOT RUN]
    X --> E[Durable evidence]
```

A verification profile cannot grant itself additional authorization. Curated skills cannot override the Policy Gate. CodeGraph output is context, not proof. Missing verification is never interpreted as success.

## End-to-end runtime

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant Copilot
    participant Context
    participant Policy
    participant Verify
    participant Evidence

    Dev->>Copilot: Task intent
    Copilot->>Context: Build repository context
    Context-->>Copilot: Stack + instructions + skills
    Copilot->>Policy: Proposed action
    Policy-->>Copilot: Allow / require intent / require approval
    Copilot->>Verify: Request deterministic checks
    Verify-->>Evidence: Verification results
    Context-->>Evidence: Context snapshot
    Evidence-->>Dev: Reviewable run evidence
```

## Supported engineering environment

The harness is Windows-first and designed for teams using **GitHub Copilot Chat in Visual Studio or VS Code**. It currently understands signals for .NET / ASP.NET Core, Angular / TypeScript, SQL Server, MongoDB, Snowflake, Parquet, Azure DevOps, GitHub Actions, and JFrog.

The baseline is deliberately CLI-driven. Optional integrations such as CodeGraph enrich context without turning MCP or marketplace plugins into runtime requirements.

## Repository architecture

```text
scripts/
  context.ps1                  Build deterministic task/repository context
  skills.ps1                   Select curated engineering skills
  policy-check.ps1             Evaluate A0-A4 authorization policy
  verify.ps1                   Run deterministic verification
  record-evidence.ps1          Persist evidence artifacts
  run-harness.ps1              Orchestrate context -> verify -> evidence
  new-verification-profile.ps1 Generate stack-aware verification profiles
  setup-codegraph.ps1          Bootstrap CodeGraph CLI integration

skills/catalog.json             Curated capability catalog
tests/                          Smoke tests and harness evals
installer/                      Windows installation/bootstrap
docs/                           Contracts and implementation guidance
.github/                        Copilot instructions, PR workflow, CI
```

## Release roadmap

```mermaid
flowchart LR
    A["v1.0.0<br/>Stable Harness"] --> B["v1.1.0<br/>Native Skills and Adoption Toolkit"]
    B --> C["v1.2.0 candidate<br/>Data Skills, Selection Evals, Doctor"]
    C --> D["Qualification<br/>CI, IDE evidence, upgrade and rollback"]
    D --> E["Publish v1.2.0<br/>After approval"]
```

**v1.0.0** established the stable runtime. **v1.1.0** added native interaction, ASP.NET Core and Angular review skills and adoption tooling. **v1.2.0** introduces native SQL Server, MongoDB and Snowflake review skills, deterministic selection benchmarks and stack-aware Doctor diagnostics.

The v1.2.0 release candidate has been merged into `main`, but a GitHub release/tag and outstanding qualification evidence must be verified separately before calling it published. The benchmark reports a static character-count proxy, **not observed token savings**.

### Native data skill selection

```mermaid
flowchart TD
    U[Developer request] --> D[Stack and intent detection]
    D --> S{Relevant native data skill?}
    S -->|SQL Server| Q[SQL Server review]
    S -->|MongoDB| M[MongoDB review]
    S -->|Snowflake| W[Snowflake review]
    S -->|No match| N[No data skill activated]
    Q --> P[Advisory recommendations]
    M --> P
    W --> P
    P --> G[Policy authorization]
    G --> V[Deterministic verification]
    V --> E[Evidence and review]
```

Skills do not authorize database writes, override policy, or count as verification evidence. See [curated skills](docs/CURATED-SKILLS.md), [architecture](docs/ARCHITECTURE.md), and [selection benchmarks](docs/DATA-SKILL-SELECTION-BENCHMARK.md).

## Getting started

Start with the bootstrap and architecture documentation in `docs/`. The installer detects the target repository, installs the supported harness assets, integrates the official GitHub Spec Kit workflow, and records installation metadata.

After installation, use the doctor and verification tooling to validate the environment before relying on harness completion evidence.

## Branching and releases

This repository uses Git Flow:

- `main` — production/released state
- `develop` — integration
- `feature/*` — new capabilities
- `release/*` — release stabilization
- `hotfix/*` — urgent fixes from `main`

Releases are cut from `release/*`, promoted to `main`, tagged with Semantic Versioning, and synchronized back into `develop`.

Every pull request includes two Mermaid views: a **technical/change diagram** and a **Git Flow branch-position diagram**.

## Design principles

1. **Repository state beats chat history.** Important state and contracts belong in the repository.
2. **Progressive disclosure beats giant prompts.** Load task-relevant context rather than everything.
3. **Generated reasoning is not verification evidence.** Acceptance requires deterministic checks.
4. **Authorization and verification are separate concerns.** Passing a test does not authorize an action.
5. **Fail closed.** Ambiguous high-risk operations and missing evidence do not become implicit success.
6. **Keep the baseline portable.** Optional tooling can enrich the harness without becoming a hidden dependency.
