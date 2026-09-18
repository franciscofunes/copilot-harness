# CodeGraph integration

## Source of truth

The harness supports only the upstream CodeGraph repository:

- Repository: `https://github.com/colbymchenry/codegraph`
- Windows installer: `https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1`

Do not silently substitute forks, similarly named packages, or other CodeGraph implementations.

## Why it is in the harness

CodeGraph builds a local semantic graph of a repository and can answer structural questions such as symbol relationships, callers/callees, impact radius, affected tests, and cross-file flows. This complements Spec Kit: Spec Kit structures intent and implementation work; CodeGraph improves repository understanding before and during that work.

The upstream project supports C#, TypeScript/JavaScript and many other languages, and stores the project graph locally under `.codegraph/`.

## Harness mode: CLI only

The harness deliberately installs and initializes the CodeGraph CLI without configuring MCP, marketplace extensions, or agent plugins. Copilot may use approved terminal commands such as:

```powershell
codegraph status
codegraph explore "how does authentication reach the database"
codegraph query "UserService"
codegraph callers "SomeMethod"
codegraph callees "SomeMethod"
codegraph impact "SomeMethod"
git diff --name-only | codegraph affected --stdin
```

CodeGraph output is context, not execution proof. Builds, tests, policy checks and the harness verification contract remain authoritative evidence.

## Bootstrap

The harness installer calls `scripts/setup-codegraph.ps1` unless `-SkipCodeGraph` is supplied. The script:

1. Requires Windows.
2. Uses only `colbymchenry/codegraph` as the source repository.
3. Downloads the upstream Windows installer rather than piping remote content directly to `Invoke-Expression`.
4. Can pin a release through `-CodeGraphVersion` / `CODEGRAPH_VERSION`.
5. Verifies that the downloaded installer identifies the expected upstream repository before execution.
6. Disables CodeGraph telemetry by default; `-KeepCodeGraphTelemetry` is an explicit opt-in.
7. Runs `codegraph init` for the target repository unless `-SkipCodeGraphInit` is supplied.
8. Does not run `codegraph install`, because that command configures agent integrations/MCP.

Direct use:

```powershell
./scripts/setup-codegraph.ps1 -TargetPath C:\src\my-app
```

Pinned release:

```powershell
./scripts/setup-codegraph.ps1 -TargetPath C:\src\my-app -Version <release-tag>
```

## Privacy and repository hygiene

CodeGraph documents anonymous usage telemetry. The harness turns it off by default. The semantic index is local. Teams should review whether `.codegraph/` is already ignored and avoid committing generated graph databases unless they have intentionally chosen to version them.

## Updating

Use an explicit reviewed update rather than silently changing the harness contract:

```powershell
codegraph upgrade --check
```

When changing the harness-supported CodeGraph behavior, re-check the upstream repository documentation and release notes first.
