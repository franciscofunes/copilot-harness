# Context & Evidence Engine

The Context & Evidence Engine closes two gaps in the harness architecture: deterministic context selection before Copilot reasons about a change, and durable local evidence after deterministic verification runs.

## Context builder

Run:

```powershell
.\scripts\context.ps1 -TargetPath . -ChangeType auto
```

The context builder returns detected stacks, changed files, effective change type, relevant Copilot instruction files, verification-profile presence, CodeGraph availability, and the policy/verification entry points.

It does not send repository content anywhere. It builds a compact local context manifest for the repository/terminal workflow.

## Evidence recording

```powershell
.\scripts\record-evidence.ps1 -TargetPath . -ContextPath .\context.json -VerificationPath .\verification.json
```

Evidence is stored under:

```text
.copilot-harness/
  runs/
    <run-id>/
      context.json
      verification.json
      evidence.json
      summary.md
```

Do not store secrets, credentials, private prompts, or hidden model reasoning in the evidence store.

## Orchestrated run

```powershell
.\scripts\run-harness.ps1 -TargetPath . -ChangeType auto
```

```mermaid
flowchart LR
    G[Repository change] --> C[context.ps1]
    C --> L[Copilot / developer workflow]
    L --> P[Policy Gate]
    P --> V[verify.ps1]
    V --> E[record-evidence.ps1]
    E --> R[Local evidence run]
    V -->|FAIL / BLOCKED / NOT RUN| C
```

The feedback arrow is conceptual: failed verification evidence becomes grounded input for the next implementation iteration.

## CodeGraph role

CodeGraph is one input to the context builder. The harness does not treat CodeGraph output as verification evidence and does not configure its MCP integration. When a local `.codegraph` index is present, the context manifest advertises semantic CLI commands that may help investigate impact and affected code.

## Boundaries

- Context selection is not authorization.
- Model output is not execution evidence.
- Policy decisions remain the responsibility of `scripts/policy-check.ps1`.
- Verification evidence remains the responsibility of `scripts/verify.ps1`.
- The evidence store records metadata and deterministic outputs; it is not a transcript archive.

## End-to-end intent propagation

Use `run-harness.ps1 -TargetPath . -ChangeType release -Intent "prepare release pr"` to carry task intent through context and curated-skill selection into the durable evidence context snapshot.

The orchestrator stops when context generation fails, verification returns no JSON, or evidence recording fails. Verification failures and blocked checks retain their verification exit code and are recorded as evidence rather than converted to success.

The orchestration smoke fixture checks selected skills, authority boundaries, and the persisted context snapshot. This is deterministic local coverage; representative real-project validation remains a separate release gate.


## Persistent lifecycle state

`scripts/lifecycle.ps1` stores a small resumable state machine in each harness run. The lifecycle is repository state, not chat history:

```mermaid
stateDiagram-v2
    [*] --> CONTEXT
    CONTEXT --> PROPOSED
    PROPOSED --> AWAITING_AUTHORIZATION
    PROPOSED --> AUTHORIZED
    AWAITING_AUTHORIZATION --> AUTHORIZED
    AUTHORIZED --> VERIFYING
    VERIFYING --> COMPLETE
    VERIFYING --> RETRY
    RETRY --> PROPOSED
    CONTEXT --> HUMAN_HANDOFF
    PROPOSED --> HUMAN_HANDOFF
    AWAITING_AUTHORIZATION --> HUMAN_HANDOFF
    AUTHORIZED --> HUMAN_HANDOFF
    VERIFYING --> HUMAN_HANDOFF
    RETRY --> HUMAN_HANDOFF
    HUMAN_HANDOFF --> PROPOSED
    HUMAN_HANDOFF --> AUTHORIZED
```

Every transition is validated and appended to `state.json` history. Lifecycle state does not authorize an operation and does not replace verification evidence. It records where a run is in the engineering loop so later tooling can resume or hand work to a human without reconstructing state from a conversation.
