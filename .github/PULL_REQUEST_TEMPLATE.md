## Summary

Describe the intent and scope of the change.

## Specification / issue

Link the active Spec Kit specification, issue, or decision record.

## Verification

List the commands actually run and their results. Do not list commands that were not executed.

## Risk and rollout

Describe compatibility, data, security, operational, and rollback considerations.

## Mermaid change diagram

Every PR must include a Mermaid diagram that explains the changed flow, architecture, or lifecycle.

```mermaid
flowchart LR
  A[Current state] --> B[Change]
  B --> C[Result]
```

## Branch position

Keep this second diagram and adapt it to the repository's actual branch topology. The harness does **not** assume a `develop` branch or Git Flow internals in target repositories. Supported working branch prefixes are `feature/*` and `release/*`; show the actual PR base branch as `Base branch` rather than inventing a branch name.

```mermaid
flowchart LR
  BASE[Base branch] -->|branch from| FEATURE[feature/example]
  FEATURE -->|pull request into| BASE
```

For a release PR, replace `feature/example` with `release/x.y.z`. Do not introduce `develop`, `hotfix/*`, or any other branch family into generated target-repository guidance.

## QA handoff

- Acceptance criteria covered:
- Positive scenarios:
- Negative/boundary scenarios:
- Regression areas:
- Manual verification needed:

## Release impact

- [ ] No release note needed
- [ ] Patch
- [ ] Minor
- [ ] Major
