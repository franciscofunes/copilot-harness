# Copilot Harness Core Instructions

This repository uses GitHub Copilot with GitHub Spec Kit. These instructions contain only universal rules; stack-specific guidance belongs in path-scoped instruction files so context stays lean.

## SDD

- Treat GitHub Spec Kit artifacts as the source of truth for meaningful changes.
- Prefer the native Spec Kit lifecycle: constitution, specify, clarify, plan, tasks, analyze, implement, converge.
- Do not invent a parallel specification format when an active Spec Kit artifact exists.
- For large features, implement a small phase or task group at a time rather than repeatedly loading the entire feature context.

## Change discipline

- Keep changes scoped to requested behavior.
- Do not modify unrelated code.
- Preserve backwards compatibility unless the active specification explicitly allows a breaking change.
- Prefer existing repository patterns over speculative abstractions.
- Surface assumptions, risks, migrations, security implications and operational impact.

## Verification

- Identify and run the applicable repository build, test, lint, static-analysis, security and validation commands when tools are available.
- Never claim a build, test, scan, migration, deployment or CLI command succeeded unless it actually ran successfully.
- Use repository scripts before inventing one-off commands.
- For release work, read `docs/RELEASE-TESTING.md` and the active `docs/releases/<version>-testing.md` plan before judging readiness.
- Never reinterpret `BLOCKED`, `SKIPPED`, or `NOT RUN` release checks as successful execution.

## QA

- Map acceptance criteria to verifiable scenarios.
- Consider positive, negative, boundary, authorization, failure and regression cases when relevant.
- Do not weaken or delete tests merely to make a change pass.

## Security

- Treat external input as untrusted.
- Never expose secrets, tokens, connection strings or sensitive data.
- Preserve established authentication and authorization controls and least privilege.

## Environment

- Windows is the canonical workstation environment.
- Prefer PowerShell for harness automation and documentation examples.
- The organization allows repository-local Copilot customizations and approved CLIs but does not assume MCP servers or marketplace plugins.
- Common approved tools may include `specify`, `dotnet`, Node/npm/Angular CLI, `gh`, `az`, `jf`, and approved database tooling.

## IDE compatibility

- Keep the shared baseline compatible with both Visual Studio and VS Code.
- GitHub Spec Kit Copilot integration layout may vary by explicit configuration; do not assume `.github/skills/` is universal.
- Keep core behavior available through shared instructions, prompt files and Spec Kit artifacts rather than depending on an IDE-only feature.
