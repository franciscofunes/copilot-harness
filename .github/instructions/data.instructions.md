---
applyTo: "**/*.sql,**/*.parquet,**/*snowflake*,**/*mongo*,**/migrations/**"
---
# Data: SQL Server / MongoDB / Snowflake / Parquet

- Treat schemas, collections, tables, views, files, queries, and serialized records as contracts.
- Identify compatibility, migration/backfill, rollback, retention, and downstream-consumer impact before changing a contract.
- Prefer parameterized queries and existing data-access abstractions. Never construct unsafe queries from untrusted input.
- For SQL Server, consider indexes, execution/query shape, transaction scope, locking/concurrency, null semantics, and migration safety.
- For MongoDB, consider document-version compatibility, indexes, atomicity boundaries, query selectivity, and old/new document coexistence.
- For Snowflake, consider warehouse/query cost, pruning, incremental processing, idempotency, roles/least privilege, and downstream model impact.
- For Parquet, consider schema evolution, nullability, partitioning, compression, column types, producer/consumer compatibility, and large-file behavior.
- Do not infer production data shape from a tiny fixture. State assumptions and validate against repository evidence or approved tooling.
- For destructive or irreversible operations, require an explicit rollback/recovery plan before execution.
- Never claim a migration/query/data validation succeeded unless it actually ran.