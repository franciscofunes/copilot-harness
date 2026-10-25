[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "evals/code-review-evidence.json"
$data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
if ($data.schemaVersion -ne 1) { throw "Unsupported evidence schema" }
$ids = @{}
foreach ($case in @($data.cases)) {
  if ([string]::IsNullOrWhiteSpace($case.id) -or $ids.ContainsKey([string]$case.id)) { throw "Duplicate or empty case ID" }
  $ids[[string]$case.id] = $true
  if ([string]::IsNullOrWhiteSpace($case.stack)) { throw "Missing stack" }
  if ($null -eq $case.PSObject.Properties["expectedFindings"] -or $null -eq $case.PSObject.Properties["mustNotClaim"]) { throw "Missing expectation arrays" }
  foreach ($finding in @($case.expectedFindings)) {
    if ($finding.severity -notin @("P0","P1","P2","P3") -or [string]::IsNullOrWhiteSpace($finding.signal)) { throw "Invalid expected finding" }
  }
  if (@($case.mustNotClaim).Count -lt 1) { throw "Missing false-positive / unsupported-claim guards" }
}
foreach ($required in @("dotnet-cross-tenant","angular-untrusted-html","sql-nonatomic-write","mongodb-retry-duplicates","snowflake-full-scan","clean-patch")) {
  if (-not $ids.ContainsKey($required)) { throw "Missing evidence case $required" }
}
$clean = @($data.cases | Where-Object { $_.id -eq "clean-patch" })[0]
if (@($clean.expectedFindings).Count -ne 0) { throw "Clean patch must not have expected findings" }
$quality = Get-Content -LiteralPath (Join-Path $root "evals/interaction-response-quality.json") -Raw | ConvertFrom-Json
if (@($quality.cases | Where-Object { $_.skill -eq "code-review" }).Count -lt 6) { throw "Missing review quality rubric cases" }
Write-Host "PASS: Cross-stack code-review evidence contract validated (not an LLM performance measurement)."
exit 0
