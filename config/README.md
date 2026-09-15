# Harness configuration templates

`verification.profile.example.json` is the reviewed starter profile for repository-specific deterministic verification.

Copy it to the target repository root as `.copilot-harness.verify.json`, then adapt the checks to commands that are already part of that repository's approved developer and CI workflow. Do not add remote, destructive, production, or security-sensitive actions to the executable verification profile; those require separately authorized workflows under the Policy Gate.
