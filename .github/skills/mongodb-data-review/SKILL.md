---
name: mongodb-data-review
description: "Review MongoDB document models, queries, indexes, aggregation pipelines and safe data evolution."
---
# MongoDB Data Review

Use for explicit MongoDB review when repository dependencies or configuration show MongoDB usage.

## Procedure
1. Find collections, schema validators, driver versions, query code and data-access boundaries.
2. Evaluate embed-versus-reference choices against actual read/write patterns, document growth, atomicity and cardinality.
3. Review filters, projections, sort and pagination, compound index prefix order, index selectivity and unique constraints.
4. Inspect aggregation stage ordering, memory-intensive grouping, lookup fanout, large arrays and explain-plan requirements.
5. Check retryable writes, idempotency, transaction requirements, read/write concerns and concurrency assumptions.
6. Plan additive migrations, backward compatibility, batched backfills, verification and rollback.

## Verification
Ground findings in file paths and propose explain() and targeted integration checks, but never claim measured performance without evidence. No live database access or automatic mutations. Spec Kit plans; policy gate authorizes; deterministic harness verifies.
