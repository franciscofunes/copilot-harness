---
applyTo: "**"
---

# Policy and verification

Before executing tools or declaring engineering work complete:

1. Read `docs/POLICY-GATE.md` for the action/approval boundary.
2. Read `docs/VERIFICATION-CONTRACT.md` for required evidence.
3. Read `docs/SPECKIT-EXTENSIONS-VALIDATION.md` when Spec Kit extensions could improve discovery, bug validation, branch validation, context management, or lifecycle hooks.
4. Use the active Spec Kit artifacts to determine intended scope and acceptance criteria.
5. Prefer the narrowest deterministic verification command that can disprove the change first.
6. Distinguish `PASS`, `FAIL`, `BLOCKED`, `SKIPPED`, and `NOT RUN` exactly; only `PASS` is passing evidence.
7. Never infer that a command, test, scan, deployment, migration, remote mutation or release succeeded without its actual result.
8. Treat production, destructive, security-sensitive and irreversible actions as approval-gated even when implementation work was broadly requested.
9. Never bypass security, compliance or legitimate tests to produce a successful status.
10. Keep evidence concise: command/check, state, scope, outcome and durable reference when available.
11. Feed failed verification back into implementation and rerun affected checks after correction.
12. Treat Spec Kit extensions as optional accelerators, not as replacements for the Policy Gate, Verification Contract, repository tests, CI, SAST, JFrog or other deterministic controls.

Copilot proposes changes; deterministic verification and authorized human decisions determine acceptance.