# Policy Gate

The Policy Gate defines the execution boundary between Copilot reasoning and repository/runtime actions.

A model suggestion is not authorization. Before an action is executed, classify the action and apply the strongest applicable rule.

## Action classes

### A0 — Read-only / reasoning

May proceed without additional approval when already within the user's requested task.

Examples:
- inspect repository files, diffs, logs, schemas, configuration and documentation;
- search code and dependency metadata;
- run stack detection and harness diagnostics that do not mutate state;
- produce plans, specifications, test cases and review findings.

### A1 — Local reversible verification

May proceed when it is a normal consequence of the requested engineering task and uses approved tooling.

Examples:
- `dotnet build` / `dotnet test`;
- npm/Angular lint, test and build commands already defined by the repository;
- static analysis and repository validation scripts;
- read-only database/schema inspection against an explicitly selected non-production target;
- local generation into disposable/temp output.

Requirements:
- prefer the narrowest relevant command first;
- do not invent success when execution is unavailable;
- record command and outcome as verification evidence.

### A2 — Repository mutation

Allowed when the user has requested implementation or modification and the change is within the active Spec Kit scope.

Examples:
- edit source, tests, docs and configuration;
- create repository-local harness artifacts;
- create feature branches and commits when the workflow explicitly calls for them.

Requirements:
- preserve unrelated changes;
- do not silently overwrite user-owned customization;
- keep the diff bounded by the active specification/task;
- add/update tests and documentation when required by the verification contract.

### A3 — Remote / shared-state mutation

Requires explicit user intent or an already-approved workflow whose purpose necessarily includes the action.

Examples:
- push branches;
- open, update or merge pull requests;
- publish packages/artifacts;
- modify shared Azure, GitHub, JFrog or database resources;
- apply database migrations to shared environments;
- create releases/tags.

Requirements:
- identify the target before execution;
- prefer preview/dry-run where supported;
- preserve rollback/recovery information;
- report the actual remote result.

### A4 — Destructive, production or security-sensitive

Requires explicit human approval immediately before execution. The harness must not infer approval from a general request to "fix", "deploy" or "make it work".

Examples:
- production data deletion or irreversible mutation;
- destructive schema migration;
- force push / history rewrite on shared branches;
- deleting repositories, environments, artifacts or shared resources;
- changing access control, credentials, secrets or security enforcement;
- bypassing SAST, compliance, required tests or branch protections.

Where a safe preview is possible, produce the preview and request approval for the destructive step.

## Always prohibited

The harness must not:
- expose, print, commit or persist secrets unnecessarily;
- disable or evade security/compliance controls to obtain a green result;
- falsify test, scan, deployment or verification evidence;
- treat model output as proof that an external action succeeded;
- introduce an MCP or marketplace-plugin runtime dependency into the baseline harness;
- silently switch away from the supported official `github/spec-kit` SDD engine;
- execute against production when the target environment is ambiguous.

## Decision algorithm

1. Determine the requested outcome and active Spec Kit scope.
2. Identify the exact action, tool and target environment.
3. Classify it A0–A4.
4. Apply any stricter stack/security/data rule.
5. For A0–A2, execute only when within scope and safe.
6. For A3, require explicit intent or an established approved workflow.
7. For A4, require immediate explicit approval.
8. Capture execution evidence.
9. Feed failures back into reasoning; never hide them.

## Enforcement boundary

Copilot instructions are behavioral guidance, not a security boundary. Enforce important controls in deterministic mechanisms where available: repository scripts, CI, GitHub rulesets/branch protections, Azure permissions, database permissions, JFrog policy, SAST/compliance gates and human review.

The harness should fail closed when a high-risk target or authorization state is ambiguous.