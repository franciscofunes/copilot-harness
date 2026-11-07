# IDE Adoption Acceptance — VS Code and Visual Studio

This is a **manual, evidence-backed** acceptance kit. CI cannot establish whether a particular version of VS Code or Visual Studio actually exposes native Copilot skills.

## Runbook

1. Prepare disposable representative repositories: .NET (`sample.sln`), Angular (`angular.json`), SQL Server (`schema.sqlproj`), MongoDB (`package.json` with an `mongodb` dependency), and Snowflake (`requirements.toml` containing `snowflake-connector-python = "1"`). The same SQL Server fixture is exercised in VS Code and Visual Studio. Do not include credentials, live database connections, or proprietary code in shared evidence.
2. Install the harness using `pwsh ./installer/install.ps1 -TargetPath <project-path> -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph`. Run from the harness checkout; do not disable safety checks for production use.
3. Open each target repository in the IDE specified by `evals/ide-adoption.json`. Record IDE version, Copilot extension/version and date.
4. Verify native `.github/skills/<skill>/SKILL.md` exists, inspect whether Copilot **actually discovers** it, explicitly invoke it using the case intent, and capture redacted response evidence. For v1.2.0, include real SQL Server, MongoDB, and Snowflake review invocations; the deterministic selector benchmark alone is insufficient.
5. Mark all four observed checks as booleans. A case passes only if installed, discoverable, invoked and evidence-captured are all true.
6. Save the reviewed JSON outside the repository or in an approved evidence location and run `pwsh ./scripts/eval-ide-adoption.ps1 -ResultsPath ./ide-review.json -Json`.

Example **partial** review (the complete suite requires all eight cases, including four v1.2.0 data-skill cases):

```json
{
  "schemaVersion": 1,
  "reviews": [{
    "caseId": "vscode-dotnet",
    "reviewer": "reviewer-id",
    "evidence": "approved-redacted-evidence-ref",
    "ideVersion": "record-exact-version",
    "copilotVersion": "record-exact-version",
    "observed": {
      "installed": true,
      "discoverable": true,
      "invoked": true,
      "evidence-captured": true
    }
  }]
}
```

## Interpretation

CI only tests **schema validation and synthetic pass/fail scoring**, not live Copilot UI behavior. Do not report adoption as passed until real IDE evidence exists. The companion response-quality rubric in `docs/INTERACTION-RESPONSE-QUALITY.md` assesses answer quality separately.

Spec Kit owns planning; policy gates authorize; deterministic harness verification provides code evidence. IDE discovery does not override those boundaries.
