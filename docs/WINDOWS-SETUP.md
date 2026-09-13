# Windows Setup Baseline

The Copilot Harness targets Windows developer workstations first.

## Required baseline

- Windows 10/11 supported by the team's development stack
- Git
- GitHub Copilot enabled in Visual Studio and/or VS Code
- PowerShell
- Python 3.11+
- `uv` for installing and managing `specify-cli`

Stack-specific tools are detected rather than globally required:

- .NET SDK
- Node.js / npm / Angular CLI
- GitHub CLI (`gh`)
- Azure CLI (`az`)
- JFrog CLI (`jf`)
- approved SQL Server, MongoDB and Snowflake tooling

## Spec Kit

Install GitHub Spec Kit's CLI:

```powershell
uv tool install specify-cli
specify --version
```

Initialize an existing repository with GitHub Copilot integration:

```powershell
specify init . --here --integration copilot --force
```

Enable Spec Kit's Git workflow support when needed:

```powershell
specify extension add git
```

The harness installer will eventually perform compatibility checks and wrap these commands with repeatable defaults.

## Visual Studio

The baseline experience relies on repository custom instructions, path-specific instructions, prompt files and Spec Kit artifacts. Developers can run `specify` from a PowerShell terminal and use generated specs/plans/tasks as Copilot Chat context.

## VS Code

The same shared baseline applies. In addition, the current GitHub Spec Kit Copilot integration can install its skills-first layout under `.github/skills/` for the native Spec Kit command experience.

## No WSL requirement

GitHub Spec Kit supports PowerShell scripts on Windows. The harness must not require WSL unless a target repository independently requires it.
