# Native Skill Adoption Acceptance

The harness now exercises native Copilot skill installation and discovery against **temporary representative repositories** in CI, rather than only checking that source files exist.

The test creates a minimal .NET repository (`sample.sln`) and Angular repository (`angular.json` and `package.json`), installs the harness with optional external bootstraps disabled, and verifies:

- The six non-data native skills exercised by this fixture (code-review, ASP.NET Core, Angular, Grill Me, Grill with Docs, session handoff) and the catalog are present after a fresh installation. The SQL Server, MongoDB and Snowflake skills have a separate native-data smoke suite.
- Explicit ASP.NET Core review and Angular feature review intents select the correct skill in the matching stack.
- Angular-specific skill selection does not occur in a .NET-only repository.
- Reinstalling in default `skip` mode preserves a repository-owned native skill file.
- An upgrade adds a missing native skill while retaining the repository-owned customization.

Run locally from the harness root with PowerShell:

```powershell
pwsh ./tests/native-skill-adoption-smoke.ps1
```

## Limits

These are deterministic **installer and selector acceptance tests**. They do not verify Copilot IDE UI discovery or the quality of generated answers. The separate human-reviewed response-quality rubric covers the latter; real VS Code/Visual Studio adoption remains an **open v1.2.0 qualification gate**, with evidence requirements in [IDE Adoption Acceptance](IDE-ADOPTION-ACCEPTANCE.md). Synthetic CI results cannot satisfy that manual gate.

No live MCP, LLM API, network calls or external bootstrap is required for this suite. Installer default skip mode protects existing files, while overwrite mode is an explicit user decision.
