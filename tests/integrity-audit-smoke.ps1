[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot;$audit=Join-Path $root "scripts/audit-integrity.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("integrity-"+[guid]::NewGuid().ToString("N"))
try{
 $runs=Join-Path $fixture ".copilot-harness\runs";$good=Join-Path $runs "good";New-Item -ItemType Directory -Path $good -Force|Out-Null
 [pscustomobject]@{state="COMPLETE";history=@([pscustomobject]@{to="COMPLETE"})}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $good "state.json")
 [pscustomobject]@{checker=[pscustomobject]@{decision="ACCEPT"}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $good "maker-checker.json")
 [pscustomobject]@{Ready=$true}|ConvertTo-Json|Set-Content (Join-Path $good "verification.json")
 "{}"|Set-Content (Join-Path $good "evidence.json")
 $global:LASTEXITCODE=0
 $out=(& $audit -TargetPath $fixture -Json|Out-String);if($LASTEXITCODE-ne 0){throw "Healthy fixture failed integrity audit."};$r=$out|ConvertFrom-Json;if(-not $r.healthy){throw "Healthy fixture marked unhealthy."}
 $bad=Join-Path $runs "bad";New-Item -ItemType Directory -Path $bad -Force|Out-Null
 [pscustomobject]@{state="COMPLETE";history=@([pscustomobject]@{to="RETRY"})}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $bad "state.json")
 [pscustomobject]@{checker=[pscustomobject]@{decision="REJECT"}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $bad "maker-checker.json")
 [pscustomobject]@{Ready=$false}|ConvertTo-Json|Set-Content (Join-Path $bad "verification.json")
 "{}"|Set-Content (Join-Path $bad "evidence.json")
 $global:LASTEXITCODE=0;$out=(& $audit -TargetPath $fixture -Json|Out-String);if($LASTEXITCODE-ne 1){throw "Unhealthy fixture did not fail closed."};$r=$out|ConvertFrom-Json
 foreach($code in @("COMPLETE_WITHOUT_ACCEPT","COMPLETE_NOT_READY","STATE_HISTORY_MISMATCH")){if(@($r.findings|Where-Object Code -eq $code).Count-ne 1){throw "Missing finding $code."}}
 Write-Host "PASS: integrity audit detects contradictory durable evidence and fails closed."
 $global:LASTEXITCODE=0
}finally{Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
