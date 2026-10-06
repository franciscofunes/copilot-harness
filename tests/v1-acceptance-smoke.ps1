[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot;$installer=Join-Path $root "installer\install.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ("v1-acceptance-"+[guid]::NewGuid().ToString("N"))
try{
 New-Item -ItemType Directory -Path $temp -Force|Out-Null
 $global:LASTEXITCODE=0;& $installer -TargetPath $temp -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor|Out-Null
 if($LASTEXITCODE-ne 0){throw "Install failed: $LASTEXITCODE"}
 $doctor=Join-Path $temp "scripts\doctor.ps1";$global:LASTEXITCODE=0;$doctorJson=(& $doctor -TargetPath $temp -Json|Out-String);if($LASTEXITCODE-ne 0){throw "Doctor failed: $LASTEXITCODE"};$health=$doctorJson|ConvertFrom-Json;if(-not $health.Ready){throw "Fresh install is not ready."}
 $runner=Join-Path $temp "scripts\run-harness.ps1";$global:LASTEXITCODE=0;$runJson=(& $runner -TargetPath $temp -ChangeType docs -Intent "verify documentation complete" -ProposalId "v1-acceptance" -ProposalSummary "v1 stable acceptance candidate" -ChangedFiles @("README.md") -Json|Out-String);$runExit=$LASTEXITCODE
 if($runExit-ne 0){throw "Harness acceptance run failed: $runExit"};$run=$runJson|ConvertFrom-Json
 if($run.MakerChecker.checker.decision-ne "ACCEPT" -or $run.Lifecycle.state-ne "COMPLETE"){throw "Acceptance run did not complete with checker ACCEPT."}
 foreach($p in @("state.json","maker-checker.json","verification.json","evidence.json")){if(-not(Test-Path (Join-Path $run.Evidence.RunDirectory $p))){throw "Acceptance evidence missing $p"}}
 $report=Join-Path $temp "scripts\new-audit-report.ps1";$global:LASTEXITCODE=0;$reportJson=(& $report -TargetPath $temp|Out-String);if($LASTEXITCODE-ne 0){throw "Audit report failed: $LASTEXITCODE"};$audit=$reportJson|ConvertFrom-Json
 if(-not $audit.Healthy){throw "Acceptance audit is unhealthy."}
 foreach($p in @($audit.Metrics,$audit.Integrity,$audit.Summary)){if(-not(Test-Path $p)){throw "Acceptance audit artifact missing: $p"}}
 Write-Host "PASS: v1 acceptance path install -> doctor -> orchestration -> evidence -> integrity/audit is healthy."
 $global:LASTEXITCODE=0
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
