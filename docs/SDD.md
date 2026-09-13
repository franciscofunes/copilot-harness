# Spec-Driven Development Workflow

The harness standardizes Spec Kit as the default workflow for meaningful changes.

## Lifecycle

1. **Constitution** — inherit organizational engineering rules.
2. **Specify** — describe user-visible and system behavior in testable terms.
3. **Clarify** — resolve ambiguity and missing constraints.
4. **Plan** — choose architecture, affected components, data changes, rollout, and verification strategy.
5. **Tasks** — decompose the plan into small, reviewable units.
6. **Implement** — make the smallest changes needed to satisfy the active spec.
7. **Verify** — run applicable build, tests, static analysis, SAST/compliance, and repository scripts.
8. **QA handoff** — map acceptance criteria to QA scenarios and identify regression impact.
9. **Converge** — compare implementation to the specification and close gaps before PR completion.

## Repository expectation

Each initialized repository should keep specification artifacts versioned with the implementation so developers and QA can review the same source of truth.

## Copilot behavior

Copilot should reference the active specification when planning, implementing, reviewing, and generating tests. When no specification exists for a meaningful change, it should recommend creating one before broad implementation.
