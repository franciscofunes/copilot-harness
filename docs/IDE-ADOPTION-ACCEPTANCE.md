# IDE Adoption Acceptance — VS Code and Visual Studio

This is a **manual, evidence-backed** acceptance kit. CI cannot establish whether a particular version of VS Code or Visual Studio actually exposes native Copilot skills.

## Runbook

1. Prepare a temporary .NET project (solution file `sample.sln`) and an Angular project (`angular.json`). Use disposable copies; never include credentials or proprietary source in shared evidence.
2. Install the harness from the **exact `release/1.2.0` candidate checkout**: `pwsh ./installer/install.ps1 -TargetPath <project-path> -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph`. Record that candidate SHA.
3. Generate a **PENDING** template covering every required case, in a secure local directory **outside the repository**. The generator refuses to overwrite existing results:

   ```powershell
   pwsh ./scripts/new-ide-adoption-review.ps1 -OutputPath "C:\\temp\\ide-review.json"
   ```

4. In the IDE named by each case in `evals/ide-adoption.json`, open the target, record the exact IDE/Copilot versions, and verify whether Copilot **actually discovers and invokes** the native `.github/skills/<skill>/SKILL.md` skill.
5. For each **observed** case, enter the named reviewer, exact versions, redacted evidence reference and four actual booleans, then change `pending` to `false`. Leave unperformed cases with `pending: true` and every `observed` value `false`. Do not claim a check succeeded because CI, a parser, or a generated template passed.
6. Score the local file:

   ```powershell
   pwsh ./scripts/eval-ide-adoption.ps1 -ResultsPath "C:\\temp\\ide-review.json" -Json
   ```

   The scorer exits nonzero until all cases have been reviewed and passed. Submit the **redacted evidence references and reviewer decision** to the release owner using an approved private channel. Do not commit raw screenshots or proprietary project details.

Example **completed single case** inside a larger review (the suite still fails until every other case is observed):

```json
{
  "schemaVersion": 1,
  "reviews": [{
    "caseId": "vscode-dotnet",
    "pending": false,
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

CI only tests **schema validation, synthetic scoring and safe template handling**, not live Copilot UI behavior. A generated template starts at zero reviewed cases and is never acceptance evidence. Do not report adoption as passed until real IDE evidence exists. The companion response-quality rubric in `docs/INTERACTION-RESPONSE-QUALITY.md` assesses answer quality separately.

Spec Kit owns planning; policy gates authorize; deterministic harness verification provides code evidence. IDE discovery does not override those boundaries.
