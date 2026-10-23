---
name: code-review
description: "Optional evidence-grounded cross-stack code review before PR merge."
---
# Code Review

Use when asked to review a change, pull request, patch or implementation against requirements and repository conventions. This is independently authored harness guidance inspired by the AI Hero review workflow, **not** a copy of upstream content.

## Workflow

1. Read the requested scope, requirements/specification, changed files, repository instructions and tests. Ask for missing evidence rather than inventing it.
2. Separate **specification compliance** (required behavior, edge cases, acceptance criteria) from **engineering quality** (security, reliability, maintainability, performance and tests).
3. Apply only relevant stack-specific native review guidance: ASP.NET Core, Angular, SQL Server, MongoDB or Snowflake. Do not load unrelated skill guidance.
4. For every actionable finding, provide severity **P0–P3**, path and line/section when known, observable evidence, impact, and the smallest safe correction. Clearly label unverified hypotheses.
5. Look for authorization gaps, secrets exposure, unsafe input handling, concurrency and data loss, missing negative tests, and unintended scope changes.
6. End with a concise summary of findings, remaining risks, missing verification evidence and a suggested validation command or test. State **no findings observed** when appropriate; do not manufacture issues.

## Review output

- **Findings:** ordered by severity, with reproducible evidence and targeted remediation.
- **Specification coverage:** verified / missing / unknown, citing the relevant acceptance criteria.
- **Validation:** what was actually executed and its outcome versus what is merely recommended.
- **Decision:** advisory only; human reviewer and existing repository gates determine merge readiness.

## Boundaries

Read-only by default. No automatic commits, PR approvals, merges, shell execution, network access, MCP requirement, or third-party installer. Do not treat generated review text as a passing test. Spec Kit owns specifications; policy-check controls authorization; verify.ps1 provides deterministic evidence. Preserve the repository's two-Mermaid PR convention and Git Flow.
