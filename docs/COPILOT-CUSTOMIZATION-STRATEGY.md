# Copilot Customization Strategy

This document records which GitHub Copilot customization patterns the harness should adopt and which ones it should avoid under the team's current restrictions.

## Constraint

The team may use GitHub Copilot Chat inside Visual Studio and VS Code plus approved CLIs. MCP servers and marketplace plugins are not assumed to be available.

That means the harness should **adapt useful assets from popular Copilot collections into repository-local files**, not require developers to install external plugin packages.

## Upstream sources to track

### GitHub Spec Kit

Use `github/spec-kit` as the SDD engine. Its Copilot integration currently defaults to skills under `.github/skills/` and supports a commands layout as an alternative. The harness should not duplicate its generated workflow.

### Awesome Copilot

`github/awesome-copilot` is the primary upstream catalog to study for reusable Copilot instructions, prompts, skills and plugin bundles.

For our stack, the highest-value patterns are:

1. **C# / .NET development**
   - .NET best-practice review
   - C# async guidance
   - ASP.NET API/OpenAPI guidance
   - xUnit / NUnit / MSTest patterns
   - .NET upgrade analysis
2. **Frontend web development**
   - Angular / TypeScript conventions
   - frontend testing patterns
   - accessibility and UI review patterns
3. **Testing / QA**
   - unit-test generation
   - edge-case and negative-test discovery
   - acceptance-criteria traceability
4. **Security / review**
   - secure coding review
   - dependency/compliance checks
   - PR readiness
5. **Database / data engineering**
   - SQL and schema review
   - data-contract compatibility
   - Snowflake/data-pipeline guidance
   - Parquet schema/evolution review

## What we should vendor

Prefer small repository-local assets that are transparent and reviewable:

- `.github/instructions/*.instructions.md`
- `.github/prompts/*.prompt.md`
- organization-owned Spec Kit presets/extensions where they add genuine company-specific behavior
- PowerShell scripts that invoke approved CLIs

When adapting an upstream asset, preserve attribution/license requirements and simplify it for our actual stack rather than copying large generic bundles blindly.

## What we should not depend on

Do not make the baseline harness depend on:

- MCP servers
- Docker-based MCP helpers
- marketplace plugin installation
- Copilot CLI-only features when Visual Studio developers also need the workflow
- large always-on instruction files

A plugin or skill can still be used as a **reference implementation** during harness development.

## Progressive disclosure

The harness should resolve context in this order:

1. universal repo rules;
2. path-specific stack rules;
3. explicit task prompt;
4. active Spec Kit feature artifacts;
5. only the source files required for the task.

This keeps the normal Copilot request small and avoids sending .NET, Angular, database, DevOps and QA guidance simultaneously when only one domain is relevant.

## Evaluation rule

Before adopting a new upstream skill/plugin pattern, ask:

- Does it solve a repeated team problem?
- Can it work without MCP/marketplace dependencies?
- Does it work in both IDEs, or is there a documented fallback?
- Can it be path-scoped or invoked on demand?
- Can its behavior be verified deterministically with an approved CLI?
- Is the extra context worth the tokens it adds?

If the answer to the last question is unclear, do not put it in global instructions.
