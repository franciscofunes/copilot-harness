[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$installer=Join-Path $root "installer\install.ps1";$doctor=Join-Path $root "installer\doctor.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ("doctor-readiness-"+[guid]::NewGuid().ToString("N"))
try{
 New-Item -ItemType Directory -Path $temp -Force|Out-Null
 & $installer -TargetPath $temp -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor|Out-Null
 Remove-Item (Join-Path $temp "scripts\lifecycle.ps1") -Force
 $global:LASTEXITCODE=0;& $doctor -TargetPath $temp *> $null
 if($LASTEXITCODE-ne 1){throw "Doctor did not fail for missing lifecycle runtime."}
 Copy-Item (Join-Path $root "scripts\lifecycle.ps1") (Join-Path $temp "scripts\lifecycle.ps1")
 $manifestPath=Join-Path $temp ".copilot-harness.json";$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
 $manifest.PSObject.Properties.Remove("observability");$manifest|ConvertTo-Json -Depth 8|Set-Content $manifestPath
 $global:LASTEXITCODE=0;& $doctor -TargetPath $temp *> $null
 if($LASTEXITCODE-ne 1){throw "Doctor did not fail for incomplete observability manifest."}
 Write-Host "PASS: Doctor fails closed for partial stable runtime and manifest."
 $global:LASTEXITCODE=0
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
