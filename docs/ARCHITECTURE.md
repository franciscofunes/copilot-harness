# Architecture

The Copilot Harness is a Windows-first, repository-native engineering harness. It standardizes how GitHub Copilot is instructed, how GitHub Spec Kit drives Spec-Driven Development, and how developers and QA verify changes with approved local tooling.

## Architectural principles

1. **GitHub Spec Kit is the SDD engine** — configure and extend it; do not fork its lifecycle.
2. **Cross-IDE baseline first** — Visual Studio and VS Code must both remain productive.
3. **Progressive disclosure** — load only the instructions and artifacts required for the current task.
4. **Deterministic verification** — use real repository scripts and approved CLIs instead of trusting generated claims.
5. **No mandatory MCP or marketplace dependency** — the harness must work within the organization's current restrictions.
6. **Windows/PowerShell first** — installer, doctor, update and repair tooling will be PowerShell-first.

## Copilot surfaces

### Shared by Visual Studio and VS Code

- `.github/copilot-instructions.md`
- `.github/instructions/*.instructions.md`
- `.github/prompts/*.prompt.md`
- versioned GitHub Spec Kit artifacts
- repository scripts and CLI verification

### VS Code enhanced surface

GitHub Spec Kit's current Copilot integration is skills-first and places generated skills under `.github/skills/`. These are an enhancement for VS Code rather than the only way to use the harness.

### Visual Studio surface

Visual Studio receives the shared repository instructions, path-specific instructions and prompt files. Spec Kit CLI commands are executed through the Windows terminal/PowerShell while Copilot Chat consumes the resulting specs, plans and tasks.

## Core layers

1. **Lean Copilot core guidance** — universal rules only.
2. **Path-scoped stack guidance** — .NET, Angular, SQL Server, MongoDB, Snowflake, Parquet and DevOps guidance loaded only when relevant.
3. **Reusable task prompts** — feature, bug, review, test, QA, security, data and release workflows.
4. **GitHub Spec Kit** — constitution, specs, plans, tasks, analysis, implementation and convergence.
5. **Verification** — `dotnet`, Node/Angular tooling, `gh`, `az`, `jf`, database tooling and repository scripts.
6. **Governance** — Git Flow, PR Mermaid diagrams, QA traceability, semantic versioning and GitHub Releases.

## Supported stack targets

- .NET / ASP.NET Core
- Angular / TypeScript
- SQL Server
- MongoDB
- Snowflake
- Parquet-based data workloads
- Azure DevOps
- JFrog
- GitHub

## Context budget strategy

The architecture intentionally avoids a giant global instruction file. Universal behavior belongs in `.github/copilot-instructions.md`; language/framework/database-specific behavior belongs in path-scoped files; task procedures belong in prompt files or Spec Kit skills; detailed feature context belongs in the active Spec Kit artifacts.

This structure reduces repeated tokens and makes Copilot more likely to receive relevant rather than generic context.
