---
applyTo: "**"
---

# Policy and verification

Before executing tools or declaring engineering work complete:

1. Read `docs/POLICY-GATE.md` for the action/approval boundary.
2. Read `docs/VERIFICATION-CONTRACT.md` for required evidence.
3. Use the active Spec Kit artifacts to determine intended scope and acceptance criteria.
4. Before a material runtime or remote action, use `scripts/policy-check.ps1` when the action can be represented by its declared action kind/environment. Do not infer approval from natural language when the evaluator requires explicit intent or approval.
5. Use `scripts/verify.ps1` for the baseline deterministic verification supported by the repository, then add environment-specific checks required by the contract.
6. Prefer the narrowest deterministic verification command that can disprove the change first.
7. Distinguish `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, and `NOT RUN` exactly; only `PASS` is passing evidence.
8. Never infer that a command, test, scan, deployment, migration, remote mutation or release succeeded without its actual result.
9. Treat production, destructive, security-sensitive and irreversible actions as approval-gated even when implementation work was broadly requested.
10. Never bypass security, compliance or legitimate tests to produce a successful status.
11. Keep evidence concise: command/check, state, scope, outcome and durable reference when available.
12. Feed failed verification back into implementation and rerun affected checks after correction.
13. Spec Kit extensions (`bug`, `git`, `assess`, `agent-context`) may contribute context or workflow evidence, but they do not replace the Policy Gate or Verification Contract.

Copilot proposes changes; deterministic verification and authorized human decisions determine acceptance.