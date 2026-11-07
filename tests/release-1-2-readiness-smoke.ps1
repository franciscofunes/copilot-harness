[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "docs\releases\1.2.0-testing.md"
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing v1.2.0 qualification plan"
}
$text = Get-Content -LiteralPath $path -Raw
foreach ($required in @("SQL Server", "MongoDB", "Snowflake", "main...develop", "NOT RUN", "BLOCKED", "rollback", "release/1.2.0", "v1.2.0")) {
    if (-not $text.Contains($required)) { throw "Release plan missing $required" }
}
if (-not $text.Contains("NO-GO") -or -not $text.Contains("NOT RELEASED")) {
    throw "Release plan must explicitly distinguish the unqualified candidate from a published release"
}

# A completed gate is permitted only with a concrete, auditable evidence reference.
# The previous blanket ban on PASS prevented recording legitimate exact-SHA CI results.
$gates = @{}
$validStates = @("PASS", "FAIL", "BLOCKED", "SKIPPED", "NOT RUN")
$ciGates = @("Q-02", "Q-03", "Q-04", "Q-05", "Q-06", "Q-10")
$reviewerGates = @("Q-01", "Q-07", "Q-08", "Q-09", "Q-11")
foreach ($line in ($text -split "\r?\n")) {
    if ($line -notmatch '^\|\s*Q-\d{2}\s*\|') { continue }
    $cells = @($line.Trim().TrimStart([char]'|').TrimEnd([char]'|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 5) { throw "Expected five release gate columns in: $line" }
    $id, $gate, $requiredEvidence, $state, $evidence = $cells
    if ($gates.ContainsKey($id)) { throw "Duplicate qualification gate $id" }
    if ([string]::IsNullOrWhiteSpace($gate) -or [string]::IsNullOrWhiteSpace($requiredEvidence)) {
        throw "Release gate $id lacks its name or evidence contract"
    }
    if ($validStates -notcontains $state) { throw "Unsupported evidence state '$state' at $id" }
    if ($state -eq "PASS") {
        if ([string]::IsNullOrWhiteSpace($evidence) -or $evidence -match '^(?:—|-|TBD|Pending|none)$') {
            throw "PASS gate $id has no recorded evidence"
        }
        if ($evidence -notmatch '(https://|docs/|evals/|artifacts/)') {
            throw "PASS gate $id needs a traceable evidence link or repository artifact"
        }
        if ($ciGates -contains $id -and ($evidence -notmatch 'actions/runs/\d+' -or $evidence -notmatch '[0-9a-f]{40}')) {
            throw "Automated PASS gate $id needs an Actions run and exact commit SHA"
        }
        if ($reviewerGates -contains $id -and $evidence -notmatch '(?i)reviewer:') {
            throw "Manual PASS gate $id needs a named reviewer"
        }
    }
    if ($state -eq "SKIPPED" -and $evidence -notmatch '(?i)reason:') {
        throw "SKIPPED gate $id needs an explicit reason"
    }
    $gates[$id] = $state
}

foreach ($requiredGate in @("Q-01", "Q-02", "Q-03", "Q-04", "Q-05", "Q-06", "Q-07", "Q-08", "Q-09", "Q-10", "Q-11")) {
    if (-not $gates.ContainsKey($requiredGate)) { throw "Missing qualification gate $requiredGate" }
}

$version = (Get-Content -LiteralPath (Join-Path $root "VERSION") -Raw).Trim()
if ($version -notin @("1.1.0", "1.2.0")) { throw "Unexpected version $version" }
if ($version -eq "1.2.0") {
    $changelog = Get-Content -LiteralPath (Join-Path $root "CHANGELOG.md") -Raw
    if ($changelog -notmatch '(?m)^## \[1\.2\.0\]') { throw "Release candidate must document v1.2.0 in CHANGELOG.md" }
}

$passed = @($gates.Values | Where-Object { $_ -eq "PASS" }).Count
$unresolved = @($gates.Values | Where-Object { $_ -in @("FAIL", "BLOCKED", "NOT RUN") }).Count
Write-Host "PASS: v1.2.0 qualification gate evidence contract valid; version=$version; recorded_pass=$passed; unresolved=$unresolved"
