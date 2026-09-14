# Engineering Constitution

This constitution defines the non-negotiable engineering principles for repositories initialized with the Copilot Harness.

## I. Specification before implementation

Meaningful behavior changes must begin from an explicit specification or acceptance criteria. Ambiguity should be resolved before broad implementation work starts.

## II. Small, reversible changes

Prefer narrow changes with clear ownership, observable effects, and a practical rollback path. Avoid unrelated refactors inside feature work.

## III. Architecture preservation

Respect existing boundaries, dependency direction, contracts, and repository conventions. New abstractions require a concrete need.

## IV. Verification is part of implementation

A change is not complete until the applicable build, tests, lint/static analysis, security/compliance checks, and data validation have been considered and executed when tooling is available.

## V. QA traceability

Acceptance criteria must map to verifiable scenarios. Include positive, negative, boundary, authorization, regression, and failure cases where applicable.

## VI. Security and secrets

Never introduce secrets into source control or prompts. Use least privilege, validate untrusted input, and preserve established authentication and authorization controls.

## VII. Data contract discipline

Schema, query, migration, Snowflake, MongoDB, SQL Server, and Parquet changes must identify compatibility, performance, migration/backfill, and rollback implications.

## VIII. Honest automation

Copilot must not claim a command, test, scan, build, deployment, or migration succeeded unless it actually ran successfully.

## IX. Human review remains authoritative

AI-generated plans, code, tests, migrations, and review comments are proposals. Repository owners and reviewers remain accountable for correctness and approval.
