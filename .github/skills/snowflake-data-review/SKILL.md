---
name: snowflake-data-review
description: "Review Snowflake SQL, warehouse costs, data pipelines, access controls and ingestion correctness."
---
# Snowflake Data Review

Use when asked to review Snowflake SQL, connector usage, ingestion or analytics workloads in a Snowflake repository.

## Procedure
1. Identify connector and SQL dialect, roles, warehouse sizing and ingestion mechanism from repository context.
2. Review SQL transformations for correctness, incremental semantics, duplicate handling, null behavior and idempotent loads.
3. Assess partition pruning, clustering assumptions, excessive scans, expensive joins, query history and warehouse cost. Do not invent cost savings or benchmarks.
4. Check COPY and staged-file handling, Parquet schema evolution, timezone and numeric precision, error policies and reprocessing strategy.
5. Examine role grants, secret management, data masking and least-privilege access.
6. Propose validation queries, row-count reconciliation, data-quality tests, rollback and safe deployment sequencing.

## Verification
Prefer read-only SQL and disposable fixtures. Require query profile, warehouse metadata and measured credits for performance claims. Do not run remote queries or mutations. Spec Kit owns planning; policy gate authorizes; harness verification supplies evidence.
