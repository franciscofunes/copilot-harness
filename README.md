# Copilot Harness

Repository-native engineering harness for GitHub Copilot, Spec Kit, QA, and CLI-driven workflows across .NET, Angular, data, and DevOps stacks.

## Branching

This repository follows Git Flow:

- `main`: production/released state
- `develop`: integration branch
- `feature/*`: new capabilities
- `release/*`: release stabilization
- `hotfix/*`: urgent fixes from `main`

## Release model

Releases are cut from `release/*`, merged into `main`, tagged using Semantic Versioning, then merged back into `develop`.

## Pull requests

Every pull request must include a Mermaid diagram describing the change or flow impact.
