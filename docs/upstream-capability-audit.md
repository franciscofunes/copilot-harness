# Upstream Capability Audit

This registry tracks GitHub projects that may inform future Copilot Harness capabilities. It is **not** an installer or an endorsement to execute third-party scripts.

## Review process

1. Record an upstream GitHub repository as `candidate` in `skills/upstream-sources.json`. Existence is checked, but neither safety nor license compatibility is implied.
2. Review a specific commit for origin/authenticity, license, scope, data handling, injected instructions, shell commands, network access and MCP/plugin dependencies.
3. Set `reviewStatus: reviewed` **only** with the immutable 40-character commit SHA and verified license identifier. Update reviewer notes to state what was examined and the decision. `rejected` records remain in the registry for traceability.
4. Integrate by writing **independent, repository-native instructions** through a separate PR and deterministic tests. This registry never downloads or installs code. Pinning in the registry is evidence, not permission to run it.
5. Re-review whenever advancing the pinned commit or changing the integration mechanism.

## Verification

```powershell
.\scripts\audit-upstream-sources.ps1
.\tests\upstream-audit-smoke.ps1
```

Both operate offline, require no plugin marketplace or MCP connection, and never invoke remote commands. The GitHub Actions PowerShell smoke workflow runs the test. The existing `skills/catalog.json` remains the skill selection authority; source records only supply review metadata.

The first six sources are deliberately marked **candidate** until license and revision reviews are performed. Source existence alone does not warrant `reviewed` status. Decisions about actual native Copilot `SKILL.md` packaging and efficacy evaluation belong to subsequent changes.
