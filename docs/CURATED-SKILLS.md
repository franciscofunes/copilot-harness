# Curated Skills

The harness uses a curated capability layer rather than installing entire external agent frameworks.

## Sources

Initial patterns are reviewed from:

- GitHub `github/awesome-copilot`
- Superpowers `obra/superpowers`

The catalog records upstream provenance. External projects remain their own source of truth; the harness does not silently copy or auto-update third-party instructions.

## Authority boundaries

Skills are capability guidance, not a parallel control plane.

- Spec Kit owns specification/planning workflow.
- `scripts/policy-check.ps1` owns execution authorization.
- `scripts/verify.ps1` owns deterministic verification evidence.
- CodeGraph provides semantic context.
- Curated skills may guide how Copilot approaches a task, but cannot authorize commands or declare verification success.

## Initial catalog

| Skill | Upstream pattern | Harness role |
| --- | --- | --- |
| systematic-debugging | obra/superpowers | root-cause-first debugging |
| test-driven-development | obra/superpowers | red-green-refactor guidance |
| verification-before-completion | obra/superpowers | mapped to harness verification contract |
| acquire-codebase-knowledge | github/awesome-copilot | repository exploration using existing instructions + CodeGraph |

## Selection

```powershell
.\scripts\skills.ps1 -TargetPath . -Intent "debug failing API test" -ChangeType bug
```

Selection is deterministic from the local catalog, detected stack, and task intent. Skills requiring MCP are excluded from the baseline.

## Why not install everything?

Whole-framework installation would create overlapping authorities for planning, execution, verification, and agent behavior. The harness instead adopts narrowly useful patterns while preserving one policy gate and one verification contract.


## Runtime integration

`scripts/context.ps1` invokes the selector with the effective change type and optional task intent. The context manifest exposes `SelectedSkills` and `SkillRules`, so the normal Context & Evidence Engine can consume capability guidance without a separate manual selection step.

The installer deploys `scripts/skills.ps1`, `skills/catalog.json`, and this contract, and records those assets in the installation manifest.

A selected skill cannot raise the automatic execution ceiling or turn generated guidance into deterministic verification evidence.

**Copilot proposes; the harness verifies.**
