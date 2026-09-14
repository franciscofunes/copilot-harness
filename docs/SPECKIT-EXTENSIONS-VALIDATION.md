# Spec Kit Extensions in the Validation Flow

This harness keeps the core policy and verification model repository-native and deterministic. Spec Kit extensions are optional capabilities that can strengthen or streamline parts of the workflow; they must not become the only source of verification truth.

## First-party bundled extensions currently relevant

The official `github/spec-kit` bundled catalog currently exposes four first-party extensions: `agent-context`, `assess`, `bug`, and `git`.

### `bug` — strongly recommended for defect validation

Use for defect work where diagnosis and verification must remain separate.

Flow:

```text
speckit.bug.assess -> speckit.bug.fix -> speckit.bug.test
```

Harness mapping:

- assess supports V0 scope/root-cause evidence;
- fix maps to A2 repository mutation;
- test supports V2/V3 execution evidence;
- the test result still enters the harness evidence model as PASS/FAIL/BLOCKED/SKIPPED/NOT RUN.

The bug extension is additive. Its `test` step does not replace repository-defined build/test/security/compliance checks.

### `git` — recommended workflow support

Use for feature-branch creation and branch validation. Its validation command can provide branch-workflow evidence before implementation/release work.

Harness mapping:

- branch creation is classified by the Policy Gate;
- branch validation contributes V0 workflow/scope evidence;
- remote push/merge/release actions remain A3 even when a git extension command initiated the workflow.

The harness Git Flow conventions remain authoritative for this repository.

### `agent-context` — optional context maintenance

Use when a project benefits from keeping coding-agent context/instruction files synchronized with project-specific plan references.

Harness mapping:

- useful for context-building and progressive disclosure;
- may reduce stale context around active plans;
- does not itself count as verification evidence;
- must not overwrite repository-owned Copilot instructions without the repository's normal conflict policy.

### `assess` — optional pre-SDD quality gate

Use before feature SDD when the team wants evidence that an idea is worth building. Its intake -> research -> define -> shape -> decide flow produces a go / needs-clarification / kill decision.

Harness mapping:

- operates before the implementation verification loop;
- a `go` decision can hand off to normal Spec Kit SDD;
- useful for high-cost, ambiguous or architecture-heavy work;
- not a substitute for V0-V4 validation after implementation.

## Hooks

Spec Kit extensions can register lifecycle hooks such as `before_implement` and `after_implement` in `.specify/extensions.yml`. Hooks can be optional or mandatory.

The harness may use hooks to surface verification commands, but with these constraints:

1. A mandatory hook failure must remain visible and must not be silently ignored.
2. Hook execution must still pass through the Policy Gate before performing a risky action.
3. A hook result becomes harness evidence only after actual execution.
4. Hooks must not bypass repository CI, security or compliance gates.
5. `auto_execute_hooks` must not be treated as a security authorization mechanism.

A useful future pattern is an `after_implement` verification hook that invokes a harness-owned deterministic verification runner. This should remain optional until tested against the approved Spec Kit version and IDE behavior.

## Extension discovery and trust

Do not blindly install community extensions.

Use:

```powershell
specify extension search
specify extension search --verified
specify extension list
```

Before adding a non-bundled extension, review:

- source repository and author;
- required Spec Kit version;
- commands/hooks/scripts it contributes;
- external tools and network dependencies;
- whether it writes files or mutates remote state;
- license;
- testing/security claims;
- compatibility with Windows, Copilot and the organization's approved tooling.

Catalog presence is discovery metadata, not proof that third-party extension code has been security-audited or endorsed.

## Harness recommendation tiers

| Tier | Extension | Recommendation | Role |
| --- | --- | --- | --- |
| Baseline | `git` | Recommended | Branch workflow/validation |
| Baseline | `bug` | Recommended | Defect assess -> fix -> test |
| Optional | `assess` | Recommended for ambiguous/high-cost ideas | Pre-SDD decision quality |
| Optional | `agent-context` | Use when context synchronization is valuable | Context management |
| Experimental | Third-party verified/catalog extensions | Case-by-case approval | Specialized capabilities |

## Design rule

The harness must remain functional when optional extensions are absent.

Extensions can provide commands, artifacts, context and lifecycle hooks, but the source of truth for authorization is `docs/POLICY-GATE.md` and the source of truth for acceptance evidence is `docs/VERIFICATION-CONTRACT.md` plus the repository's executable checks.
