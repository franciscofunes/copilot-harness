# Copilot Harness — End-to-End Lab Design (planning-only)

> Status: **PROPOSED / NOT RUN**. This document and `evals/e2e-lab-cases.json` define future work. No VM, Copilot invocation, credential, execution adapter, test outcome or release approval is delivered by this change.

## Objective

Demonstrate whether an actual Copilot-assisted engineering task, executed in a disposable repository, respects the harness's **context → proposed change → authorization → deterministic verification → maker/checker → lifecycle → evidence** contract. This is distinct from (1) selector-only unit fixtures and (2) Q-07's four mandatory *live IDE skill-discovery* cases.

The harness's `scripts/run-harness.ps1` currently invokes context, verification, maker/checker, lifecycle and evidence, but **does not directly invoke** `scripts/policy-check.ps1`. Its `AUTHORIZED` lifecycle transition refers to verification-only orchestration. Treat that as a **policy integration gap requiring investigation**, not as a proven exploit. Prompt instructions are never a tool-level security boundary.

## Three complementary lanes

| Lane | Execution environment | What can actually be established | Limitations |
| --- | --- | --- | --- |
| L0 — deterministic | Existing Windows GitHub Actions or local isolated PowerShell | Parser, installer, doctor, selector, policy classifier, verification, recovery, receipts | No model behavior or live IDE adoption |
| L1 — headless agent | Future *opt-in* GitHub Copilot CLI adapter in an isolated checkout | Actual model-assisted proposal/skill selection, optional approved tool use and measured artifacts | Requires eligible account, authentication, provider policy, usage budget and tool boundaries; NOT implemented |
| L2 — live IDE | One Windows workstation or suitably licensed Windows VM with VS Code and Visual Studio + Copilot | Actual `.github/skills` discovery and invocation, UI compatibility and user experience | Requires signed-in real IDE sessions and reviewer evidence; four Q-07 cases are still PENDING |

Do not substitute a Windows CI runner, Codespaces, a headless CLI or an IDE mock for an actual Visual Studio session. Do not assume ChatGPT connectors can take over a remote Windows desktop. A physical Windows PC is an acceptable L2 host; a paid cloud VM is not a prerequisite for L0/L1.

## Proposed implementation order (separate scoped PRs to `develop`)

1. **Specification and case catalog (this PR).** Review `evals/e2e-lab-cases.json` and clarify the policy integration boundary. No runtime behavior is changed.
2. **L0 isolated fixture builder.** Produce disposable test repositories (.NET minimal API, Angular, PowerShell and optional data indicators), pinned tool versions, a read-only manifest and explicit cleanup. Default to no external provisioning, no network credentials and no persistent secrets.
3. **Policy enforcement boundary.** Specify which tool executor, if any, the harness can actually block. Verify A0 read, A1 verify, A2 local mutation, A3 remote/shared mutation and A4 destructive/security/production requests *before tool invocation*. Add fail-closed design for unknown command/target/approval state. Do not relabel the existing standalone classifier as guaranteed enforcement.
4. **Optional L1 Copilot CLI adapter.** Explicit opt-in, auth supplied by the user's authorized local/CI environment (never as a chat message or committed secret), `--` flags verified against the installed CLI version, per-case allowlisted tools, noninteractive timeout, run budgets, no network or mutation unless the case's approved policy requires it. No `allow-all`, `yolo` or unreviewed shell execution. The CLI is a separate agent runtime, not proof of VS Code/Visual Studio Copilot use.
5. **Evidence-backed scorer.** Record exact source/case revision, OS/tool/IDE/CLI versions, observed events, tool exit codes, workspace diff, verification results, policy decisions and redacted artifact references. Unknown/missing observation stays `NOT RUN`, unavailable prerequisite `BLOCKED`, executed failure `FAIL`; `PASS` requires evidence. Keep human-reviewed reasoning quality separate from deterministic acceptance.
6. **L2 human IDE sign-off (later).** Perform canonical `evals/ide-adoption.json` tests in VS Code and Visual Studio, record exact versions and evidence with existing Q-07 evaluator. L1 results cannot close Q-07.
7. **Compare modes** on identical disposable fixtures and prompt/agent settings: baseline without harness vs harness. Report correctness, false claims, approvals respected, selector accuracy, number of retries and elapsed time; report model tokens/cost *only if the runtime exposes trustworthy counters*. Do not claim model quality from one execution.

### Planned milestones and acceptance (none executed now)

| Milestone | Planned evidence | Today |
| --- | --- | --- |
| M0 catalog + design review | Human review of scenario fixtures, privacy and authority boundaries | NOT RUN |
| M1 fixture provisioning + cleanup | Repeatable isolated fixture and corruption/cleanup tests | NOT RUN |
| M2 authorization enforcement | Tool-level deny/approve tests that prove an unapproved action was never invoked | NOT RUN |
| M3 Copilot CLI adapter | Real authenticated CLI invocation and redacted trace in opt-in environment | NOT RUN |
| M4 comparative evaluation | Multiple repeated runs with counterfactual baseline and explicit limitations | NOT RUN |
| M5 Q-07 live adoption | Four real IDE cases and reviewer sign-off | BLOCKED |

## Scenario contract

`evals/e2e-lab-cases.json` defines proposed scenarios. Every future executed record must contain at least `caseId`, `caseRevision`, `harnessSha`, `executionLane`, `runnerIdentity`, `startedAtUtc`, `status`, and `evidenceReferences`. Auth/account identities should be anonymized. Each case has an expected **behavioral invariant**, never a pre-filled PASS.

A dangerous scenario must use **simulated/dummy targets only**. For a denied action, acceptance requires a verifiable absence of the underlying tool execution, not just text saying "I won't." No production endpoints, databases, SaaS tenants, customer repos or credentials may be used.

### Isolation, spend and retention requirements

- Unique temporary workspace per case; snapshot original state and retain a diff, then destroy disposable changes. Run installer/rollback checks on snapshots, never a real customer checkout.
- Read-only GitHub token by default. Network off unless a reviewed case requires it. No prompts asking for private keys; secrets must come from an approved external credential store with masked logs.
- Per-run time, token and dollar budgets must be explicitly approved before model invocation. Disable unattended retries when a quota or authorization is uncertain.
- Capture bounded/redacted logs and receipts. Store sensitive or proprietary captures in reviewer-controlled storage, not public Actions artifacts or issues. CI artifacts expire and are not a durable approval system.
- Independent reviewer inspects safety-sensitive outcomes. Generated model text is **not** authorization, execution proof, or acceptance.

## Relationship to the existing roadmap

The published release is **v1.1.0**. The active `release/1.2.0` candidate is unqualified and remains **NO-GO** under [Issue #87](https://github.com/franciscofunes/copilot-harness/issues/87). This plan does **not** change that branch, close Q-01/Q-07/Q-08/Q-09, perform final Q-10, approve Q-11, or authorize a tag.

Treat the lab as a proposed *cross-release verification workstream*, coordinated with [the already-proposed v1.3.0–v1.5.0 roadmap](ROADMAP-POST-1.2.md). It does not replace v1.3.0 Trusted Upstream, v1.4.0 Prompt Efficiency or optional v1.5.0 OMP. All new work starts from `develop` on feature branches, with reviewed implementation PRs and normal quality gates before release.
