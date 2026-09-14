# QA Workflow

QA participates in the same specification-driven lifecycle as development.

## Inputs

- Active specification and acceptance criteria
- Implementation plan and affected components
- Changed APIs, UI flows, data contracts, permissions, and integrations

## Required coverage review

For each acceptance criterion, identify:

- Positive scenarios
- Negative scenarios
- Boundary/value-limit scenarios
- Authorization and role scenarios
- Failure and retry behavior
- Regression areas
- Data integrity/compatibility checks
- Automation candidates

## Handoff output

A PR should make it possible for QA to understand:

1. what behavior changed;
2. what did not change;
3. how the developer verified it;
4. what risks remain;
5. which environments/data are required for manual verification;
6. which acceptance criteria map to which tests.

QA feedback that changes expected behavior should update the specification, not remain only in an ephemeral chat thread.
