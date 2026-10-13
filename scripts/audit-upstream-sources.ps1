[CmdletBinding()]
param([string]$RegistryPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "skills\upstream-sources.json"), [switch]$Json)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$errors = [System.Collections.Generic.List[string]]::new()
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { [void]$errors.Add($Message) } }
try { $registry = Get-Content -LiteralPath $RegistryPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
catch { throw "Unable to parse upstream registry: $($_.Exception.Message)" }
Require ($registry.schemaVersion -eq 1) "schemaVersion must equal 1"
Require ($registry.policy.defaultIntegration -eq "reference-only") "Default integration must be reference-only"
Require ($registry.policy.allowRemoteExecution -ceq $false) "Remote execution must be disabled"
Require ($registry.policy.requirePinnedRevisionForPromotion -ceq $true) "Promotion must require a pinned revision"
Require ($registry.policy.requireVerifiedLicenseForPromotion -ceq $true) "Promotion must require a verified license"
$ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$repos = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$statuses = @("candidate", "reviewed", "rejected")
$categories = @("copilot-library", "technology-skills", "harness-patterns", "skill-authoring", "documentation-skills")
foreach ($source in @($registry.sources)) {
  $id = [string]$source.id
  $repo = [string]$source.repository
  Require (-not [string]::IsNullOrWhiteSpace($id) -and $id -cmatch '^[a-z0-9-]+$') "Invalid source id: '$id'"
  Require ($ids.Add($id)) "Duplicate id: '$id'"
  Require ($repo -cmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') "Invalid repository: '$repo'"
  Require ($repos.Add($repo)) "Duplicate repository: '$repo'"
  Require ([string]$source.url -ceq "https://github.com/$repo") "Source URL must be canonical GitHub HTTPS: '$repo'"
  Require ($categories -ccontains [string]$source.category) "Invalid category: '$id'"
  Require ($statuses -ccontains [string]$source.reviewStatus) "Invalid review status: '$id'"
  Require ([string]$source.integration -ceq "reference-only") "Only reference-only integration is permitted: '$id'"
  Require ($source.requiresMcp -ceq $false) "Baseline cannot require MCP: '$id'"
  $rev = [string]$source.revision
  $license = [string]$source.license
  if ([string]$source.reviewStatus -ceq "reviewed") {
    Require ($rev -cmatch '^[a-fA-F0-9]{40}$') "Reviewed source requires immutable 40-character commit SHA: '$id'"
    Require (-not [string]::IsNullOrWhiteSpace($license) -and $license -cne "unverified") "Reviewed source requires verified license: '$id'"
  } else {
    Require ([string]::IsNullOrWhiteSpace($rev) -or $rev -cmatch '^[a-fA-F0-9]{40}$') "Revision must be a commit SHA or null: '$id'"
  }
  Require (-not [string]::IsNullOrWhiteSpace([string]$source.notes)) "Missing reviewer notes: '$id'"
}
Require (@($registry.sources).Count -gt 0) "Upstream registry cannot be empty"
$result = [pscustomobject]@{ Passed=($errors.Count -eq 0); SourceCount=@($registry.sources).Count; Errors=@($errors) }
if ($Json) { $result | ConvertTo-Json -Depth 5 } elseif ($result.Passed) { Write-Host "PASS: $($result.SourceCount) upstream sources satisfy reference-only review contracts." } else { $errors | ForEach-Object { Write-Error $_ } }
if (-not $result.Passed) { exit 1 }
