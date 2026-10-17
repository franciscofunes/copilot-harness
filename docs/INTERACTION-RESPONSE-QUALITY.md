# Copilot Interaction Response Quality — Human Review

This suite evaluates **actual Copilot answers**, not just skill selection. The repository intentionally does not invoke an LLM in CI.

1. Open `evals/interaction-response-quality.json`. For each case, use the named native skill in an isolated Copilot Chat session with the provided prompt. Keep the skill and tool environment consistent; do not include secrets.
2. Save the answer outside the repository or in an approved redacted evidence location. Record a durable evidence reference (PR comment, approved artifact ID, etc.).
3. Have a reviewer grade each criterion: **0 = missing/wrong, 1 = partial, 2 = meets expectation**. Weights are 1–5. Record their identifier and the evidence reference.
4. Save a local results JSON and run `pwsh ./scripts/eval-interaction-quality.ps1 -ResultsPath ./review-results.json -Json`.
5. A complete review passes only if every case is reviewed and **each** weighted case score is at least 80%. Do not confuse fixture scores with actual model-quality evidence.

Example results structure (one case shown; supply every case and every criterion for a complete review):

```json
{
  "schemaVersion": 1,
  "reviews": [
    {
      "caseId": "grill-routine-bug",
      "reviewer": "reviewer-id",
      "evidence": "approved-redacted-artifact-reference",
      "grades": [
        {"criterionId": "avoid-interview", "score": 2},
        {"criterionId": "stay-scoped", "score": 2}
      ]
    }
  ]
}
```

The CI smoke test uses **synthetic fixtures** to verify scoring and failure behavior. It does not claim Copilot has passed these quality benchmarks. Reviewers should capture model/version, IDE, relevant instructions and date with their evidence when possible. Do not commit confidential transcripts or personally identifiable information.

Authority boundaries remain: Spec Kit plans; policy gates authorize; deterministic verification verifies code. These rubrics provide supplementary human assessment, not policy authorization.
