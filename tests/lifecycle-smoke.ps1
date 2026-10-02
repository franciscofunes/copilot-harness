[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$script=Join-Path $root "scripts/lifecycle.ps1"
$fixture=Join-Path ([System.IO.Path]::GetTempPath()) ("harness-lifecycle-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
try {
  $runId="test-run"
  $state=(& $script -TargetPath $fixture -Action start -RunId $runId -Intent "implement feature" -Json | Out-String)|ConvertFrom-Json
  if($state.state -ne "CONTEXT"){throw "Expected CONTEXT."}
  foreach($next in @("PROPOSED","AUTHORIZED","VERIFYING","RETRY","PROPOSED","AUTHORIZED","VERIFYING","COMPLETE")){
    $state=(& $script -TargetPath $fixture -Action transition -RunId $runId -To $next -Reason "smoke" -Json | Out-String)|ConvertFrom-Json
  }
  if($state.state -ne "COMPLETE"){throw "Expected COMPLETE."}
  $failed=$false
  try { & $script -TargetPath $fixture -Action transition -RunId $runId -To "AUTHORIZED" -Json | Out-Null } catch { $failed=$true }
  if(-not $failed){throw "Terminal COMPLETE state accepted an invalid transition."}
  if(@($state.history).Count -ne 9){throw "Lifecycle history was not preserved."}
  Write-Host "PASS: lifecycle state is persistent, resumable, and transition-validated."
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
