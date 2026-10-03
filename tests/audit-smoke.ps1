[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$audit=Join-Path $root "scripts/audit-runs.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("audit-"+[guid]::NewGuid().ToString("N"))
try{
 $runs=Join-Path $fixture ".copilot-harness\runs"; New-Item -ItemType Directory -Path $runs -Force|Out-Null
 foreach($case in @(@("a","COMPLETE","ACCEPT"),@("b","RETRY","REJECT"),@("c","HUMAN_HANDOFF","REJECT"))){
   $d=Join-Path $runs $case[0];New-Item -ItemType Directory -Path $d -Force|Out-Null
   [pscustomobject]@{state=$case[1];updatedAtUtc=[DateTime]::UtcNow.ToString("o");history=@([pscustomobject]@{to=$case[1]})}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $d "state.json")
   [pscustomobject]@{checker=[pscustomobject]@{decision=$case[2]}}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $d "maker-checker.json")
   [pscustomobject]@{Ready=($case[1] -eq "COMPLETE")}|ConvertTo-Json|Set-Content (Join-Path $d "verification.json")
 }
 $r=(& $audit -TargetPath $fixture -Json|Out-String)|ConvertFrom-Json
 if($r.totalRuns-ne 3 -or $r.complete-ne 1 -or $r.retry-ne 1 -or $r.humanHandoff-ne 1){throw "Lifecycle audit counts incorrect."}
 if($r.accepted-ne 1 -or $r.rejected-ne 2 -or $r.verificationReady-ne 1){throw "Checker/verification audit counts incorrect."}
 Write-Host "PASS: harness audit metrics summarize durable run evidence."
}finally{Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
