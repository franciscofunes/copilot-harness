[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $root "scripts/run-harness.ps1"
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-orchestration-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $fixture "README.md") -Value "documentation fixture"
    $output = (& $runner -TargetPath $fixture -ChangeType docs -Intent "verify documentation complete" -ProposalId "proposal-smoke" -ProposalSummary "documentation candidate" -ChangedFiles @("README.md") -Json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Expected successful orchestration, exit $LASTEXITCODE." }
    $run = $output | ConvertFrom-Json
    if (@($run.Context.SelectedSkills | Where-Object Id -eq "verification-before-completion").Count -ne 1) {
        throw "Orchestration failed to propagate intent into curated skills."
    }
    if (-not $run.Context.SkillRules.PolicyGateOwnsAuthorization -or -not $run.Context.SkillRules.VerifyOwnsEvidence) {
        throw "Orchestration lost authority boundaries."
    }
    if ($run.MakerChecker.checker.decision -ne "ACCEPT") { throw "Deterministic checker did not accept passing verification." }
    if ($run.Lifecycle.state -ne "COMPLETE") { throw "Successful closed-loop run did not reach COMPLETE." }
    if (-not (Test-Path -LiteralPath $run.Evidence.Manifest -PathType Leaf)) { throw "Evidence manifest missing." }
    if (-not (Test-Path -LiteralPath (Join-Path $run.Evidence.RunDirectory "state.json") -PathType Leaf)) { throw "Lifecycle state missing from durable run directory." }
    if (-not (Test-Path -LiteralPath (Join-Path $run.Evidence.RunDirectory "maker-checker.json") -PathType Leaf)) { throw "Maker/checker evidence missing from durable run directory." }
    $stored = Get-Content -LiteralPath (Join-Path $run.Evidence.RunDirectory "context.json") -Raw | ConvertFrom-Json
    if (@($stored.SelectedSkills | Where-Object Id -eq "verification-before-completion").Count -ne 1) {
        throw "Selected skills missing from durable context evidence."
    }
    Write-Host "PASS: closed-loop intent, proposal, checker, lifecycle, and durable evidence."
    $global:LASTEXITCODE = 0
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
