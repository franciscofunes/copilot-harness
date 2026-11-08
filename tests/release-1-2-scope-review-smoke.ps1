[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $root "scripts/new-release-scope-review.ps1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("release-scope-review-" + [guid]::NewGuid().ToString("N"))
$repo = Join-Path $tempRoot "fixture-repo"
$reviewPath = Join-Path $tempRoot "review.json"

try {
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize disposable git repo" }
    & git -C $repo config user.email "synthetic-review@example.invalid"
    & git -C $repo config user.name "Synthetic Fixture"
    New-Item -ItemType Directory -Path (Join-Path $repo "skills") | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "VERSION") -Value "1.1.0"
    Set-Content -LiteralPath (Join-Path $repo "skills/example.md") -Value "before"
    & git -C $repo add .
    & git -C $repo commit -q -m "baseline fixture"
    if ($LASTEXITCODE -ne 0) { throw "Could not create fixture baseline" }
    $baseline = (& git -C $repo rev-parse HEAD | Out-String).Trim()

    New-Item -ItemType Directory -Path (Join-Path $repo "installer") | Out-Null
    Set-Content -LiteralPath (Join-Path $repo "VERSION") -Value "1.2.0"
    Set-Content -LiteralPath (Join-Path $repo "skills/example.md") -Value "after"
    Set-Content -LiteralPath (Join-Path $repo "installer/new.ps1") -Value "Write-Host 'fixture'"
    & git -C $repo add .
    & git -C $repo commit -q -m "candidate fixture"
    if ($LASTEXITCODE -ne 0) { throw "Could not create fixture candidate" }
    $candidate = (& git -C $repo rev-parse HEAD | Out-String).Trim()

    & $runner -RepoPath $repo -BaselineRef $baseline -CandidateRef HEAD -ReviewPath $reviewPath | Out-Null
    $document = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
    if ($document.gate -ne "Q-01" -or $document.baselineSha -ne $baseline -or
        $document.candidateSha -ne $candidate -or @($document.files).Count -ne 3) {
        throw "Generated inventory was not tied to exact fixture commit and changed files"
    }
    foreach ($entry in @($document.files)) {
        if ($entry.decision -ne "PENDING" -or -not [string]::IsNullOrWhiteSpace($entry.reviewer) -or
            -not [string]::IsNullOrWhiteSpace($entry.rationale)) {
            throw "Generated review preapproves file changes"
        }
    }
    $expectedPaths = @("VERSION", "installer/new.ps1", "skills/example.md")
    $actualPaths = @($document.files | ForEach-Object { $_.path })
    if (($expectedPaths -join ",") -ne ($actualPaths -join ",")) {
        throw "Scope review inventory omitted a changed file"
    }

    $originalHash = (Get-FileHash -LiteralPath $reviewPath -Algorithm SHA256).Hash
    $overwriteBlocked = $false
    try {
        & $runner -RepoPath $repo -BaselineRef $baseline -ReviewPath $reviewPath | Out-Null
    } catch {
        if ($_.Exception.Message -match "Refusing to overwrite") { $overwriteBlocked = $true } else { throw }
    }
    if (-not $overwriteBlocked -or (Get-FileHash -LiteralPath $reviewPath -Algorithm SHA256).Hash -ne $originalHash) {
        throw "Scope generator overwrote reviewer evidence"
    }
    $pendingBlocked = $false
    try {
        & $runner -Mode Validate -RepoPath $repo -BaselineRef $baseline -ReviewPath $reviewPath | Out-Null
    } catch {
        if ($_.Exception.Message -match "not approved for inclusion") { $pendingBlocked = $true } else { throw }
    }
    if (-not $pendingBlocked) { throw "Pending inventory incorrectly validated" }

    # Synthetic fixture only: this is not real release-owner approval.
    $document.scopeReviewer = "synthetic-reviewer"
    $document.reviewDateUtc = "2026-11-08"
    $document.ownerApprovalReference = "fixture-not-approval"
    foreach ($entry in @($document.files)) {
        $entry.decision = "INCLUDE"
        $entry.reviewer = "synthetic-reviewer"
        $entry.rationale = "fixture-only"
    }
    $document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewPath -Encoding utf8
    & $runner -Mode Validate -RepoPath $repo -BaselineRef $baseline -ReviewPath $reviewPath | Out-Null

    Set-Content -LiteralPath (Join-Path $repo "new-scope-file.md") -Value "unreviewed"
    & git -C $repo add .
    & git -C $repo commit -q -m "scope drift fixture"
    if ($LASTEXITCODE -ne 0) { throw "Could not create fixture drift commit" }
    $staleBlocked = $false
    try {
        & $runner -Mode Validate -RepoPath $repo -BaselineRef $baseline -ReviewPath $reviewPath | Out-Null
    } catch {
        if ($_.Exception.Message -match "Stale or incompatible") { $staleBlocked = $true } else { throw }
    }
    if (-not $staleBlocked) { throw "Previously reviewed file incorrectly validated after candidate SHA drift" }

    Write-Host "PASS: exact-SHA scope inventory, PENDING defaults, overwrite refusal, synthetic completeness and stale-candidate rejection."
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
$global:LASTEXITCODE = 0
exit 0
