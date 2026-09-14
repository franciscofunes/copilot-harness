# <version> Release Testing Plan

Status values: `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, `NOT RUN`.

This plan follows `docs/RELEASE-TESTING.md`.

## Scope under test

Describe the release capabilities and changed surfaces that require verification.

## Test matrix

| ID | Scenario | Command / Method | Expected Result | Status | Evidence / Notes |
| --- | --- | --- | --- | --- | --- |
| REL-001 | Repository integrity | Review release diff and metadata | Only intended release scope is present | NOT RUN | |
| REL-002 | Static/syntax validation | `<repository command>` | No blocking syntax/static-analysis failures | NOT RUN | |
| REL-003 | Unit/smoke validation | `<repository command>` | Applicable deterministic tests pass | NOT RUN | |
| REL-004 | Negative scenario | `<method>` | Failure is detected and reported correctly | NOT RUN | |
| REL-005 | Manual user flow | Follow documented release workflow | Documented behavior matches actual behavior | NOT RUN | |
| REL-006 | Security/policy review | Review dependencies, secrets and destructive actions | No unapproved dependency, secret, or silent destructive action | NOT RUN | |

Add stack-, installer-, Spec Kit-, upgrade-, data-, security-, and integration-specific scenarios required by the actual release scope.

## Release blockers

List the checks that must be `PASS` before this release can be marked ready.

## Evidence log

Record concise execution evidence here and update the status table above. Do not convert unexecuted checks into PASS.
