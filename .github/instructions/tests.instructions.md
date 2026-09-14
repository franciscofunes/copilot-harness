---
applyTo: "**/*Tests*/**,**/*.spec.ts,**/*.test.ts,**/*.tests.cs,**/e2e/**,**/tests/**"
---
# Tests and QA

- Derive tests from the active GitHub Spec Kit acceptance criteria and the behavior actually changed.
- Follow the repository's existing test framework, fixture, mocking, naming, and assertion conventions.
- Cover the smallest useful level first; add integration or end-to-end coverage when component boundaries or risk require it.
- Consider positive, negative, boundary, authorization, failure/retry, concurrency, data-integrity, and regression scenarios when relevant.
- Prefer deterministic tests. Avoid arbitrary sleeps, external dependencies, shared mutable state, and time/randomness without control.
- Do not weaken assertions, delete coverage, or rewrite expected behavior merely to make implementation pass.
- Keep test data minimal and intention-revealing; do not expose secrets or production personal data.
- Map important acceptance criteria to tests or explicit manual QA scenarios.
- Report what was executed separately from what is only recommended.
- Never claim a test suite passed unless it actually ran successfully.