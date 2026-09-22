[CmdletBinding()]
param(
  [string]$ScenarioPath,
  [string]$OutputPath,
  [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScenarioPath)) { $ScenarioPath = Join-Path $root "evals\scenarios.json" }
if (-not (Test-Path -LiteralPath $ScenarioPath -PathType Leaf)) { throw "Eval scenarios not found: $ScenarioPath" }
$suite = Get-Content -LiteralPath $ScenarioPath -Raw | ConvertFrom-Json
if ($suite.schemaVersion -ne 1) { throw "Unsupported eval schemaVersion '$($suite.schemaVersion)'." }
$results = @()
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-harness-eval-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
  foreach ($scenario in @($suite.scenarios)) {
    $target = Join-Path $tempRoot $scenario.id
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($marker in @($scenario.stackMarkers)) {
      $path = Join-Path $target $marker
      $parent = Split-Path -Parent $path
      if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
      Set-Content -LiteralPath $path -Value "" -Encoding utf8
    }
    $skillJson = & (Join-Path $root "scripts\skills.ps1") -TargetPath $target -Intent $scenario.intent -ChangeType $scenario.changeType -Json
    $skillResult = $skillJson | ConvertFrom-Json
    $actualSkills = @($skillResult.SelectedSkills | ForEach-Object { $_.Id })
    $actualStacks = @($skillResult.DetectedStacks)
    $missingSkills = @($scenario.expectedSkills | Where-Object { $actualSkills -notcontains $_ })
    $missingStacks = @($scenario.expectedStacks | Where-Object { $actualStacks -notcontains $_ })
    $pass = ($missingSkills.Count -eq 0 -and $missingStacks.Count -eq 0)
    $results += [pscustomobject]@{
      Id = $scenario.id; Passed = $pass
      ExpectedSkills = @($scenario.expectedSkills); ActualSkills = $actualSkills
      ExpectedStacks = @($scenario.expectedStacks); ActualStacks = $actualStacks
      MissingSkills = $missingSkills; MissingStacks = $missingStacks
    }
  }
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
$passed = @($results | Where-Object Passed).Count
$total = $results.Count
$summary = [pscustomobject]@{
  SchemaVersion = 1
  Total = $total
  Passed = $passed
  Failed = $total - $passed
  PassRate = if ($total -eq 0) { 0 } else { [math]::Round(($passed / $total) * 100, 2) }
  Results = $results
}
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $dir = Split-Path -Parent $OutputPath
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
if ($Json) { $summary | ConvertTo-Json -Depth 8 } else {
  Write-Host "Harness evals: $passed/$total PASS ($($summary.PassRate)%)"
  foreach ($r in $results) { Write-Host "$(if($r.Passed){'[PASS]'}else{'[FAIL]'}) $($r.Id)" }
}
if ($summary.Failed -gt 0) { exit 1 }
exit 0
