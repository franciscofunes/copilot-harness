# Executable Validation Quickstart

This milestone adds deterministic runtime helpers around the Policy Gate and Verification Contract.

## 1. Classify the action

```powershell
.\scripts\policy-check.ps1 -ActionKind read
```

For shared-state mutation:

```powershell
.\scripts\policy-check.ps1 `
  -ActionKind remote-mutate `
  -Environment shared `
  -Target "GitHub pull request" `
  -ExplicitIntent
```

For production/destructive/security-sensitive operations:

```powershell
.\scripts\policy-check.ps1 `
  -ActionKind destructive `
  -Environment production `
  -Target "production database operation" `
  -ImmediateApproval
```

The evaluator returns a non-zero exit code when intent or approval is still required.

## 2. Execute the approved action

Use only approved repository and CLI tooling. Policy approval does not prove the action succeeded; capture the real tool result.

## 3. Run deterministic verification

```powershell
.\scripts\verify.ps1 -TargetPath . -ChangeType auto
```

Or specify the change boundary explicitly:

```powershell
.\scripts\verify.ps1 -TargetPath . -ChangeType powershell
.\scripts\verify.ps1 -TargetPath . -ChangeType dotnet
.\scripts\verify.ps1 -TargetPath . -ChangeType angular
.\scripts\verify.ps1 -TargetPath . -ChangeType release
```

Use `-Json` for machine-readable evidence.

## 4. Interpret evidence

- `PASS`: executed successfully.
- `FAIL`: executed and failed.
- `BLOCKED`: required execution cannot currently proceed.
- `SKIPPED`: intentionally not applicable with reason.
- `NOT RUN`: expected evidence does not exist yet.

Only `PASS` is passing evidence.

## 5. Optional Spec Kit integration

Spec Kit extensions may contribute workflow/context. The `bug` extension can provide assess/fix/test structure, and an approved future `after_implement` hook may call `scripts/verify.ps1`.

The harness remains functional without that hook. Authorization always comes from the Policy Gate, and acceptance always comes from the Verification Contract plus actual evidence.