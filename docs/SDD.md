# Spec-Driven Development with GitHub Spec Kit

GitHub Spec Kit (`github/spec-kit`) is the authoritative SDD engine for this harness. The harness must extend and configure Spec Kit; it must not reimplement a competing specification workflow.

## Windows-first bootstrap

All supported workstations are Windows PCs. PowerShell is the canonical shell for harness automation. Spec Kit supports Windows directly; WSL is not required.

Recommended bootstrap:

```powershell
uv tool install specify-cli
specify init . --here --integration copilot --force
specify extension add git
```

The future installer will wrap these steps, pin/test compatible versions, and keep them repeatable across repositories.

## Authoritative lifecycle

Use Spec Kit's native workflow and artifacts:

1. `/speckit.constitution`
2. `/speckit.specify`
3. `/speckit.clarify`
4. `/speckit.plan`
5. `/speckit.tasks`
6. `/speckit.analyze`
7. `/speckit.implement`
8. `/speckit.converge`

QA participates from specification and clarification onward; acceptance criteria and testability are part of the spec, not an afterthought.

## VS Code and Visual Studio compatibility

### VS Code

Spec Kit's current GitHub Copilot integration is skills-first. It scaffolds `speckit-<command>/SKILL.md` assets under `.github/skills/` by default. This is the preferred Spec Kit-native experience for VS Code.

### Visual Studio

Visual Studio is a first-class target for this harness, but its Copilot customization surface is not identical to VS Code. The cross-IDE baseline therefore uses:

- `.github/copilot-instructions.md`
- `.github/instructions/*.instructions.md`
- `.github/prompts/*.prompt.md`
- the same versioned Spec Kit specifications, plans, and tasks

The installer must not assume that Spec Kit skills are callable from Visual Studio exactly as they are from VS Code. Visual Studio users can still run the `specify` CLI from PowerShell/terminal and use the shared prompt files and generated artifacts in Copilot Chat.

## Context and token optimization

Spec Kit artifacts can become large. The harness must keep Copilot context intentionally small:

1. Keep repository-wide instructions limited to universal invariants.
2. Put stack rules in path-specific instruction files so they are loaded only when relevant.
3. Invoke prompt files only for the current task.
4. Load only the active feature's Spec Kit artifacts.
5. Implement large features by phase or task instead of asking Copilot to process the entire plan repeatedly.
6. Mark completed tasks in `tasks.md` so subsequent implementation sessions can resume from the remaining work.
7. Start a new Copilot chat when moving to a different feature or problem.
8. Avoid duplicate rules across the constitution, repo instructions, prompt files, and stack instructions.

For large features, prefer requests such as:

```text
/speckit.implement execute only the Core phase, then stop
```

or explicitly select a small group of tasks from `tasks.md`.

## Extensions

Use official Spec Kit extensions when they solve a requirement instead of duplicating the behavior in this repository. Git workflow support should use the Spec Kit `git` extension.

Organization-specific capabilities may later be packaged as our own Spec Kit extension or preset after the base workflow is stable.
