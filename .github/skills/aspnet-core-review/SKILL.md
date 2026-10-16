---
name: aspnet-core-review
description: "Optional ASP.NET Core API architecture and reliability review."
---
# ASP.NET Core API Review

Use when explicitly asked to review ASP.NET Core, C# API endpoints, controllers, minimal APIs, dependency injection or middleware. Read repository context before suggesting changes.

## Review checklist
1. Identify API contract and request/response validation, HTTP semantics, authorization and error handling.
2. Inspect DI lifetimes, async/await, cancellation propagation, HttpClientFactory and connection-pool usage.
3. Evaluate EF Core query shape, transaction boundaries, idempotency, concurrency and N+1 risks where relevant.
4. Examine logging, PII redaction, correlation IDs, health checks and operational failure modes.
5. Recommend targeted tests: unit, integration, contract and negative authorization tests.
6. Distinguish observed findings from hypotheses; cite paths and avoid claiming benchmark results without measurements.

## Boundaries
Advisory and repository-local; no MCP, shell or remote dependency. Do not modify code without approval. GitHub Spec Kit owns feature planning, policy gates own authorization and the harness owns deterministic verification.
