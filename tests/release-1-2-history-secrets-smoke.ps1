[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$scanner = Join-Path $root "scripts/audit-release-history-secrets.ps1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("release-history-secret-" + [guid]::NewGuid().ToString("N"))
$repo = Join-Path $tempRoot "history-fixture"
$clean = Join-Path $tempRoot "clean-fixture"
$receiptPath = Join-Path $tempRoot "history-receipt.json"
$cleanReceipt = Join-Path $tempRoot "clean-receipt.json"

try {
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    & git -C $repo init -q
    & git -C $repo config user.email "fixture@example.invalid"
    & git -C $repo config user.name "Synthetic Fixture"
    Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "ordinary fixture"
    & git -C $repo add .
    & git -C $repo commit -q -m "baseline"
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare baseline" }

    # Construct a synthetic token at runtime; never commit a token-shaped literal to source.
    $syntheticMarker = "ghp_" + ("A" * 36)
    $secretFile = Join-Path $repo "historical-example.txt"
    Set-Content -LiteralPath $secretFile -Value ("synthetic=" + $syntheticMarker)
    & git -C $repo add .
    & git -C $repo commit -q -m "fixture historical addition"
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare historical addition" }
    Remove-Item -LiteralPath $secretFile -Force
    & git -C $repo add -A
    & git -C $repo commit -q -m "fixture removed from head"
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare historical removal" }

    $output = (& $scanner -RepositoryPath $repo -ReceiptPath $receiptPath 3>&1 | Out-String)
    if ($LASTEXITCODE -ne 1) { throw "Scanner missed a historical token absent from HEAD" }
    $receiptText = Get-Content -LiteralPath $receiptPath -Raw
    $receipt = $receiptText | ConvertFrom-Json
    if ($receipt.outcome -ne "REVIEW_REQUIRED" -or $receipt.highConfidenceFindings -ne 1 -or
        @($receipt.findings).Count -ne 1 -or $receipt.findings[0].rule -ne "github_token" -or
        $receipt.findings[0].path -ne "historical-example.txt") {
        throw "Scanner did not produce the expected bounded and redacted historical finding"
    }
    if ($receiptText.Contains($syntheticMarker) -or $output.Contains($syntheticMarker)) {
        throw "Scanner leaked a synthetic secret value to the receipt or output"
    }
    if ($receipt.q08 -notmatch "NOT RUN" -or $receipt.releaseGate -ne "NO-GO") {
        throw "Heuristic must never automatically approve the release"
    }

    New-Item -ItemType Directory -Path $clean -Force | Out-Null
    & git -C $clean init -q
    & git -C $clean config user.email "fixture@example.invalid"
    & git -C $clean config user.name "Synthetic Fixture"
    Set-Content -LiteralPath (Join-Path $clean "README.md") -Value "clean fixture"
    & git -C $clean add .
    & git -C $clean commit -q -m "clean baseline"
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare clean fixture" }
    & $scanner -RepositoryPath $clean -ReceiptPath $cleanReceipt 3>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Clean history incorrectly rejected" }
    $safe = Get-Content -LiteralPath $cleanReceipt -Raw | ConvertFrom-Json
    if ($safe.highConfidenceFindings -ne 0 -or $safe.outcome -ne "NO_HIGH_CONFIDENCE_MATCHES" -or
        $safe.q08 -notmatch "NOT RUN" -or $safe.releaseGate -ne "NO-GO") {
        throw "Clean heuristic output incorrectly implies Q-08 approval"
    }

    Write-Host "PASS: historical-only credential detected, matched value redacted, clean history accepted, Q-08 stays unsigned."
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
$global:LASTEXITCODE = 0
exit 0
