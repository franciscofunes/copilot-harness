[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$script=Join-Path $root "scripts/maker-checker.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("maker-checker-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture -Force|Out-Null
try{
 $run="test"; & $script -TargetPath $fixture -Action propose -RunId $run -ProposalId "proposal-1" -Summary "candidate change" -ChangedFiles @("README.md")|Out-Null
 $v=Join-Path $fixture "verification.json"
 [pscustomobject]@{Ready=$true;Results=@([pscustomobject]@{State="PASS"});Counts=[pscustomobject]@{Pass=1;Fail=0;Blocked=0;NotRun=0}}|ConvertTo-Json -Depth 5|Set-Content $v
 $r=(& $script -TargetPath $fixture -Action check -RunId $run -VerificationPath $v -Json|Out-String)|ConvertFrom-Json
 if($r.maker.proposalId -ne "proposal-1"){throw "Maker identity lost."}
 if($r.checker.source -ne "verify.ps1" -or $r.checker.decision -ne "ACCEPT"){throw "Checker did not use deterministic verification."}
 $run2="reject"; & $script -TargetPath $fixture -Action propose -RunId $run2 -ProposalId "proposal-2"|Out-Null
 [pscustomobject]@{Ready=$false;Results=@([pscustomobject]@{State="NOT RUN"});Counts=[pscustomobject]@{Pass=0;Fail=0;Blocked=0;NotRun=1}}|ConvertTo-Json -Depth 5|Set-Content $v
 $r2=(& $script -TargetPath $fixture -Action check -RunId $run2 -VerificationPath $v -Json|Out-String)|ConvertFrom-Json
 if($r2.checker.decision -ne "REJECT"){throw "Checker accepted missing evidence."}
 Write-Host "PASS: maker proposal and deterministic checker evidence remain separate."
}finally{Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
