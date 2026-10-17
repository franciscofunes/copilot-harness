---
name: sql-server-data-review
description: "Review SQL Server schema, queries, migrations, indexing and transactional correctness with repository evidence."
---
# SQL Server Data Review

Use when a developer explicitly asks for SQL Server query, schema, indexing, transaction or migration review and the repository indicates SQL Server usage.

## Procedure
1. Identify schema and query entry points, database compatibility level and migration tooling from repository evidence.
2. Check parameterization, least-privilege permissions, dynamic SQL injection risks and sensitive data exposure.
3. Analyze predicates, SARGability, join cardinality, pagination, N+1 patterns and likely index access paths. Request actual execution plans and statistics before claiming performance gains.
4. Review transactions, isolation, locking, deadlock retry and idempotency. Never suggest NOLOCK as a blanket fix for blocking or consistency.
5. Assess migration reversibility, deployment sequencing, backfill batching and compatibility with old application versions.
6. Provide path-specific findings, severity, rationale, validation SQL (read-only by default), and rollback considerations.

## Verification
Prefer repository tests, local disposable database fixtures, query plans and migration dry runs. Clearly label unexecuted proposals. Do not connect to remote databases or run writes. Spec Kit owns planning, policy gate authorizes, and the harness verifies.
