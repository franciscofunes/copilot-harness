# Policy & Evidence Evals

This suite extends Harness Evals & Metrics across control-plane boundaries.

Deterministic cases assert that local verification remains A1/ALLOW, remote mutation requires explicit intent, explicit intent can satisfy the A3 gate, and production mutation is elevated to A4 and requires immediate approval.

Evidence cases create an isolated run through `record-evidence.ps1`, require the complete context/policy/verification/evidence/summary artifact set, and confirm a supplied FAIL verification state remains FAIL in recorded evidence.

These checks evaluate harness behavior, not model reasoning. They do not authorize real remote or production actions.
