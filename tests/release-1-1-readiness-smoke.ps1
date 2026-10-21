[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $root "VERSION") -Raw).Trim()
if ($version -notin @("1.0.0", "1.1.0", "1.2.0")) { throw "Unexpected release version $version" }
if ($version -eq "1.1.0") {
    $changelog = Get-Content -LiteralPath (Join-Path $root "CHANGELOG.md") -Raw
    if ($changelog -notmatch '(?m)^## \[1\.1\.0\] - (Unreleased|\d{4}-\d{2}-\d{2})\s*$') {
        throw "Missing valid v1.1.0 changelog heading"
    }
}
$path = Join-Path $root "docs\releases\1.1.0-testing.md"
$doc = Get-Content -LiteralPath $path -Raw
foreach ($item in @("release/1.1.0", "Harness Smoke", "native-skill-adoption-smoke.ps1", "BLOCKED", "NOT RUN", "v1.0.0", "main", "develop", "rollback")) {
    if (-not $doc.Contains($item)) { throw "Release qualification plan missing $item" }
}
if ($doc -match '(?im)^\s*\|\s*Release-head CI\s*\|[^\r\n]*\|\s*PASS\s*\|') {
    throw "Release-head CI must not be preapproved"
}
Write-Host "PASS: v1.1.0 release qualification plan preserves v1.0.0 baseline and fail-closed gates."
exit 0
