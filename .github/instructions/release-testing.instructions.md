---
applyTo: "docs/releases/**,installer/**,scripts/**,.github/workflows/**,VERSION,CHANGELOG.md"
---

# Release testing instructions

When working on release preparation, installer/runtime changes, validation scripts, workflows, version metadata, or release documentation:

- Read `docs/RELEASE-TESTING.md` before judging release readiness.
- Read the active `docs/releases/<version>-testing.md` plan and keep it synchronized with release scope.
- Never mark a test `PASS` unless it was actually executed and succeeded.
- Preserve the states `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, and `NOT RUN` exactly; do not reinterpret missing evidence as success.
- Add or update test scenarios when release scope changes.
- Prefer deterministic repository scripts and reproducible fixtures over ad-hoc manual steps.
- Record command/method and concise evidence for executed checks.
- Surface unresolved `FAIL`, `BLOCKED`, and `NOT RUN` items before recommending release readiness.
- For installer changes, include clean install, idempotent rerun, conflict preservation, explicit overwrite, missing-tool, manifest, and doctor scenarios.
- For GitHub Spec Kit changes, validate behavior against the official `github/spec-kit` CLI available in the environment; verify layout and extensions rather than assuming them.
- Treat release documentation as part of the product: commands must be copy/paste safe for Windows PowerShell and must match implemented behavior.
- Do not weaken or delete a release test merely to make the release appear ready.
