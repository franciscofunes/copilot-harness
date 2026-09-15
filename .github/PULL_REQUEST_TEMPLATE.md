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

## Git Flow position

Keep this diagram and replace the example feature branch name with the current branch. The diagram should make the PR's branch/base relationship visible; release and hotfix PRs should adapt it to their actual Git Flow path.

```mermaid
gitGraph
  commit id: "develop baseline"
  branch feature/example
  checkout feature/example
  commit id: "this change"
  checkout develop
  merge feature/example
```

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
