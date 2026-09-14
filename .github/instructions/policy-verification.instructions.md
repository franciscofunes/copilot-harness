---
applyTo: "**"
---

# Policy and verification

Before executing tools or declaring engineering work complete:

1. Read `docs/POLICY-GATE.md` for the action/approval boundary.
2. Read `docs/VERIFICATION-CONTRACT.md` for required evidence.
3. Use the active Spec Kit artifacts to determine intended scope and acceptance criteria.
4. Prefer the narrowest deterministic verification command that can disprove the change first.
5. Distinguish `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, and `NOT RUN` exactly; only `PASS` is passing evidence.
6. Never infer that a command, test, scan, deployment, migration, remote mutation or release succeeded without its actual result.
7. Treat production, destructive, security-sensitive and irreversible actions as approval-gated even when implementation work was broadly requested.
8. Never bypass security, compliance or legitimate tests to produce a successful status.
9. Keep evidence concise: command/check, state, scope, outcome and durable reference when available.
10. Feed failed verification back into implementation and rerun affected checks after correction.

Copilot proposes changes; deterministic verification and authorized human decisions determine acceptance.