# Architecture

The Copilot Harness is repository-native. It standardizes how GitHub Copilot is instructed, how Spec-Driven Development is applied, and how developers and QA verify changes using approved local tooling.

## Core layers

1. **Copilot guidance** — repository-wide and path-scoped instructions.
2. **Reusable workflows** — prompt files for feature work, bug fixing, review, testing, QA handoff, and security review.
3. **SDD** — GitHub Spec Kit artifacts and organization-specific conventions.
4. **Verification** — deterministic CLI commands and repository scripts.
5. **Governance** — Git Flow, PR templates, semantic versioning, release notes, and QA traceability.

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

## Constraints

The harness must remain useful without MCP servers or marketplace plugins. Approved CLIs may be used where available.
