[CmdletBinding()]
param([string]$ReceiptPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $root "VERSION") -Raw).Trim()
if ($version -ne "1.2.0") { throw "Expected unpublished v1.2.0 candidate, got '$version'." }

$changelog = Get-Content -LiteralPath (Join-Path $root "CHANGELOG.md") -Raw
if ($changelog -notmatch '(?m)^## \[1\.2\.0\] - Unreleased\s*$') {
    throw "v1.2.0 must remain Unreleased until qualification is approved."
}
if ($changelog -notmatch '(?m)^## \[1\.1\.0\] - 2026-10-17\s*$') {
    throw "Published baseline v1.1.0 metadata is missing or stale."
}

$gateDoc = Get-Content -LiteralPath (Join-Path $root "docs/releases/1.2.0-testing.md") -Raw
if ($gateDoc -notmatch '(?i)NO-GO' -or $gateDoc -notmatch 'NOT RELEASED' -or
    $gateDoc -notmatch '(?m)^\| Q-11 \|[^\r\n]*\| BLOCKED \|') {
    throw "Release owner sign-off gate must remain explicitly BLOCKED."
}

$baseline = Get-Content -LiteralPath (Join-Path $root "installer/managed-baselines/1.1.0.json") -Raw | ConvertFrom-Json -AsHashtable
$publishedSha = "1996bbaef67cf4815ad6c18554bffc9daa5f6ea5"
if ($baseline.sourceVersion -ne "1.1.0" -or $baseline.sourceCommit -ne $publishedSha -or
    $baseline.hashAlgorithm -ne "git-blob-sha1" -or $baseline.files.Count -lt 35) {
    throw "Pinned published baseline inventory is missing or incomplete."
}
foreach ($key in $baseline.files.Keys) {
    if ($key -match '(^|/)\.\.(/|$)' -or $baseline.files[$key] -notmatch '^[0-9a-f]{40}$') {
        throw "Invalid pinned file fingerprint: $key"
    }
}

$workflow = Get-Content -LiteralPath (Join-Path $root ".github/workflows/harness-smoke.yml") -Raw
if ($workflow -notmatch '(?m)^permissions:\s*\r?\n\s+contents:\s*read\s*$' -or
    $workflow -match '(?i)pull_request_target:|workflow_run:|write-all|id-token:\s*write') {
    throw "Release workflow has unexpected or elevated GitHub Actions permissions/triggers."
}

# Bounded, high-confidence source heuristic only; not a substitute for secret scanning.
$secretRules = [ordered]@{
    github_pat = '(?<![A-Za-z0-9])(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'
    aws_access_key = '(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}'
    private_key_header = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
}
$checkedFiles = 0
foreach ($folder in @("scripts", "installer", "config", ".github/workflows", "skills")) {
    $path = Join-Path $root $folder
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
    foreach ($file in (Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Extension -in @(".ps1", ".json", ".yaml", ".yml") })) {
        $checkedFiles++
        $content = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($rule in $secretRules.GetEnumerator()) {
            if ($content -match $rule.Value) {
                throw "Potential $($rule.Key) pattern in $($file.FullName). Manual security review required."
            }
        }
    }
}
if ($checkedFiles -lt 15) { throw "Security heuristic scanned unexpectedly few source files: $checkedFiles" }

$sha = (& git -C $root rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot capture exact qualification checkout HEAD SHA."
}

$receipt = [ordered]@{
    schemaVersion = 1
    candidateVersion = $version
    checkoutSha = $sha
    sourceFilesHeuristicallyScanned = $checkedFiles
    checks = [ordered]@{
        versionAndChangelogConsistent = $true
        publishedBaselineFingerprintMetadataValid = $true
        releaseNoGoExplicit = $true
        actionsPermissionsRestricted = $true
        highConfidenceSecretPatternsAbsentInSelectedSources = $true
    }
    coverage = "Local metadata and bounded source heuristics only; not a signed security review."
    unresolved = @("Q-01 owner scope sign-off", "Q-07 live IDE adoption", "Q-08 full security/provenance reviewer sign-off", "Q-09 upgrade policy owner approval", "Q-10 post-freeze final-head CI", "Q-11 publication decision")
    releaseGate = "NO-GO"
}

if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
    $directory = Split-Path -Parent $ReceiptPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
}
Write-Host "PASS: v1.2.0 source provenance metadata and bounded high-confidence checks validated for $sha; scanned $checkedFiles files."
Write-Warning "RELEASE NO-GO: Live IDE, broader security, scope and owner approval evidence remain outstanding."
