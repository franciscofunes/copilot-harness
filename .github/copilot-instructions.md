# Copilot Harness Core Instructions

You are working in a repository governed by the Copilot Harness.

## Working agreement

- Prefer specification-driven development: understand or create the active specification before implementing meaningful changes.
- Keep changes scoped to the requested behavior. Do not modify unrelated code.
- Preserve backwards compatibility unless the specification explicitly allows a breaking change.
- Before proposing completion, identify the appropriate build, test, lint, security, and validation commands for the repository and run them when tools are available.
- Never claim a build, test, scan, migration, deployment, or CLI command succeeded unless it actually ran successfully.
- Surface assumptions, risks, data migrations, security implications, and operational impact.
- Prefer small, reviewable changes and clear commit boundaries.

## Architecture

- Respect existing architectural boundaries and dependency direction.
- Prefer established repository patterns over introducing new abstractions.
- Avoid hidden coupling, duplicate business rules, and speculative frameworks.
- For API changes, document contract, validation, error behavior, authorization, observability, and backwards compatibility.
- For data changes, document schema or contract impact, migration/backfill needs, rollback strategy, and performance implications.

## Testing and QA

- Behavior changes require tests at the lowest useful level and additional integration/e2e coverage when risk warrants it.
- Include positive, negative, boundary, authorization, regression, and failure scenarios where relevant.
- Translate acceptance criteria into verifiable QA scenarios.
- Do not weaken or delete tests merely to make a change pass.

## Security and compliance

- Treat external input as untrusted.
- Do not expose credentials, tokens, connection strings, personal data, or secrets.
- Use least privilege and existing authentication/authorization mechanisms.
- Consider dependency, SAST, artifact, and compliance checks part of completion when configured in the repository.

## Tooling policy

This organization permits repository-local files and approved CLIs. Do not assume MCP servers or marketplace plugins are available.

Common approved CLIs may include:

- `dotnet`
- `node`, `npm`, `npx`, Angular CLI
- `gh`
- `az`
- `jf`
- database-specific approved tooling

Use repository scripts when they exist instead of inventing one-off commands.
