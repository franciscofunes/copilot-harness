[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$lifecycle=Join-Path $root "scripts/lifecycle.ps1"
$checker=Join-Path $root "scripts/maker-checker.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("lifecycle-negative-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture -Force|Out-Null
try{
 $run="retry-run"
 & $lifecycle -TargetPath $fixture -Action start -RunId $run -Intent "candidate"|Out-Null
 & $lifecycle -TargetPath $fixture -Action transition -RunId $run -To PROPOSED|Out-Null
 & $checker -TargetPath $fixture -Action propose -RunId $run -ProposalId "p1"|Out-Null
 & $lifecycle -TargetPath $fixture -Action transition -RunId $run -To AUTHORIZED|Out-Null
 & $lifecycle -TargetPath $fixture -Action transition -RunId $run -To VERIFYING|Out-Null
 $v=Join-Path $fixture "verification.json"
 [pscustomobject]@{Ready=$false;Results=@([pscustomobject]@{State="BLOCKED"});Counts=[pscustomobject]@{Pass=0;Fail=0;Blocked=1;NotRun=0}}|ConvertTo-Json -Depth 5|Set-Content $v
 $check=(& $checker -TargetPath $fixture -Action check -RunId $run -VerificationPath $v -Json|Out-String)|ConvertFrom-Json
 if($check.checker.decision -ne "REJECT"){throw "BLOCKED verification was accepted."}
 & $lifecycle -TargetPath $fixture -Action transition -RunId $run -To RETRY -Reason "checker REJECT"|Out-Null
 $resumed=(& $lifecycle -TargetPath $fixture -Action resume -RunId $run -Json|Out-String)|ConvertFrom-Json
 if($resumed.state -ne "RETRY"){throw "Resume did not preserve RETRY state."}
 & $lifecycle -TargetPath $fixture -Action transition -RunId $run -To HUMAN_HANDOFF -Reason "manual investigation required"|Out-Null
 $handoff=(& $lifecycle -TargetPath $fixture -Action resume -RunId $run -Json|Out-String)|ConvertFrom-Json
 if($handoff.state -ne "HUMAN_HANDOFF"){throw "Human handoff was not durable."}
 if(@($handoff.history|Where-Object to -eq "HUMAN_HANDOFF").Count -ne 1){throw "Handoff history missing."}
 Write-Host "PASS: rejected verification, retry, resume, and human handoff are durable."
}finally{Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
