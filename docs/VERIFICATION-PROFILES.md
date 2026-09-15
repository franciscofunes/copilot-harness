# Repository Verification Profiles

A target repository can define `.copilot-harness.verify.json` to replace generic stack assumptions with exact deterministic verification commands.

Start from `config/verification.profile.example.json` and copy it to the target repository root as `.copilot-harness.verify.json`.

## Contract

Each check declares:

- `id`: stable evidence identifier;
- `name`: human-readable check name;
- `changeTypes`: applicable harness change types or `all`;
- `verificationLevel`: `V0` through `V4`;
- `policyClass`: currently executable profiles accept only `A0` or `A1`;
- `command`: direct executable name;
- `args`: argument array;
- `required`: reserved for richer profile policy in a later schema version.

## Safety boundary

Profiles are repository code and require review. The verifier never evaluates a shell command string and never uses `Invoke-Expression`. It invokes the executable directly with an argument array.

The baseline allowlist is intentionally narrow: `dotnet`, `npm`, `node`, `powershell`, `pwsh`, `git`, `az`, `gh`, `jf`, `sqlcmd`, `mongosh`, and `snowsql`.

Profile execution is restricted to A0/A1 checks. A2 repository mutations belong to the requested implementation workflow. A3 remote/shared-state and A4 destructive/production/security-sensitive actions must use separately authorized workflows and cannot gain authorization merely by being placed in a profile.

## Usage

```powershell
.\scripts\verify.ps1 -TargetPath . -ChangeType auto
```

The verifier automatically discovers `.copilot-harness.verify.json` at the target root. A different profile can be selected explicitly:

```powershell
.\scripts\verify.ps1 -TargetPath . -ChangeType data -ProfilePath .\config\my-profile.json
```

Use `-Json` for machine-readable evidence.

## Design goal

The profile is the bridge from the generic harness to a repository's real build/test/lint/data/security commands. It allows teams to encode deterministic checks without expanding global Copilot instructions or teaching the model every repository-specific command on every conversation.
