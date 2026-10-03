[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot;$report=Join-Path $root "scripts/new-audit-report.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("audit-report-"+[guid]::NewGuid().ToString("N"))
try{
 $run=Join-Path $fixture ".copilot-harness\runs\good";New-Item -ItemType Directory -Path $run -Force|Out-Null
 [pscustomobject]@{state="COMPLETE";updatedAtUtc=[DateTime]::UtcNow.ToString("o");history=@([pscustomobject]@{to="COMPLETE"})}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $run "state.json")
 [pscustomobject]@{checker=[pscustomobject]@{decision="ACCEPT"}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $run "maker-checker.json")
 [pscustomobject]@{Ready=$true}|ConvertTo-Json|Set-Content (Join-Path $run "verification.json");"{}"|Set-Content (Join-Path $run "evidence.json")
 $global:LASTEXITCODE=0;$r=(& $report -TargetPath $fixture|Out-String)|ConvertFrom-Json
 if($LASTEXITCODE-ne 0 -or -not $r.Healthy){throw "Healthy audit report failed."}
 foreach($p in @($r.Metrics,$r.Integrity,$r.Summary)){if(-not(Test-Path $p)){throw "Missing audit artifact: $p"}}
 $summary=Get-Content $r.Summary -Raw;if($summary -notmatch "Total runs: 1" -or $summary -notmatch "Healthy: True"){throw "Audit summary missing expected metrics."}
 Write-Host "PASS: machine-readable audit artifacts and Markdown summary generated."
}finally{Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
