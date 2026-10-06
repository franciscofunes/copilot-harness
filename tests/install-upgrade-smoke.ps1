[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$installer=Join-Path $root "installer\install.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ("install-upgrade-"+[guid]::NewGuid().ToString("N"))
function Invoke-Install([string]$target,[string]$mode="skip"){
 $global:LASTEXITCODE=0
 & $installer -TargetPath $target -ConflictMode $mode -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor
 if($LASTEXITCODE-ne 0){throw "Installer failed for $target with exit $LASTEXITCODE"}
}
try{
 $fresh=Join-Path $temp "fresh";New-Item -ItemType Directory -Path $fresh -Force|Out-Null
 Invoke-Install $fresh
 foreach($p in @("scripts\run-harness.ps1","scripts\lifecycle.ps1","scripts\maker-checker.ps1","scripts\audit-runs.ps1","scripts\audit-integrity.ps1","scripts\new-audit-report.ps1",".copilot-harness.json")){
  if(-not(Test-Path (Join-Path $fresh $p) -PathType Leaf)){throw "Fresh install missing $p"}
 }
 $manifest=Get-Content (Join-Path $fresh ".copilot-harness.json") -Raw|ConvertFrom-Json
 if(-not $manifest.context.lifecycle -or -not $manifest.context.makerChecker -or -not $manifest.observability.report){throw "Fresh manifest missing stable runtime contract."}
 $upgrade=Join-Path $temp "upgrade";New-Item -ItemType Directory -Path (Join-Path $upgrade "scripts") -Force|Out-Null
 $owned="# repository-owned verify";Set-Content (Join-Path $upgrade "scripts\verify.ps1") $owned
 $profile='{ "schemaVersion": 1, "checks": [] }';Set-Content (Join-Path $upgrade ".copilot-harness.verify.json") $profile
 Invoke-Install $upgrade "skip"
 if((Get-Content (Join-Path $upgrade "scripts\verify.ps1") -Raw).Trim() -ne $owned){throw "Upgrade replaced repository-owned file in skip mode."}
 if((Get-Content (Join-Path $upgrade ".copilot-harness.verify.json") -Raw).Trim() -ne $profile){throw "Upgrade changed repository verification profile."}
 foreach($p in @("scripts\lifecycle.ps1","scripts\maker-checker.ps1","scripts\new-audit-report.ps1")){if(-not(Test-Path (Join-Path $upgrade $p))){throw "Upgrade did not add $p"}}
 Write-Host "PASS: fresh install is complete and skip-mode upgrade preserves repository-owned configuration while adding stable runtime."
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
