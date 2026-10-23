[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$installer=Join-Path $root "installer\install.ps1"
$skillSelector=Join-Path $root "scripts\skills.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ("native-skill-adoption-"+[guid]::NewGuid().ToString("N"))
$skillPaths=@(".github\skills\code-review\SKILL.md",".github\skills\aspnet-core-review\SKILL.md",".github\skills\angular-feature-review\SKILL.md",".github\skills\grill-me\SKILL.md",".github\skills\grill-with-docs\SKILL.md",".github\skills\session-handoff\SKILL.md")
function Install([string]$path,[string]$mode="skip"){
 $global:LASTEXITCODE=0
 & $installer -TargetPath $path -ConflictMode $mode -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor|Out-Null
 if($LASTEXITCODE -ne 0){throw "Installer failed for $path"}
}
function Assert-Selected([string]$path,[string]$intent,[string]$id){
 $result=(& $skillSelector -TargetPath $path -Intent $intent -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($result.SelectedSkills|Where-Object{$_.Id -eq $id}).Count -ne 1){throw "Expected $id for $intent; selected $(@($result.SelectedSkills.Id) -join ',')"}
}
try{
 $dotnet=Join-Path $temp "dotnet";$angular=Join-Path $temp "angular"
 foreach($p in @($dotnet,$angular)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 Set-Content -LiteralPath (Join-Path $dotnet "sample.sln") -Value "" -Encoding utf8
 Set-Content -LiteralPath (Join-Path $angular "angular.json") -Value "{}" -Encoding utf8
 Set-Content -LiteralPath (Join-Path $angular "package.json") -Value "{}" -Encoding utf8
 foreach($p in @($dotnet,$angular)){
  Install $p
  foreach($rel in $skillPaths){if(-not(Test-Path -LiteralPath (Join-Path $p $rel) -PathType Leaf)){throw "Fresh install missing $rel"}}
  if(-not(Test-Path -LiteralPath (Join-Path $p "skills\catalog.json"))){throw "Fresh install missing skill catalog"}
 }
 Assert-Selected $dotnet "review asp.net api" "aspnet-core-review"
 Assert-Selected $angular "review angular feature" "angular-feature-review"
 $dotnetResult=(& $skillSelector -TargetPath $dotnet -Intent "review angular feature" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($dotnetResult.SelectedSkills|Where-Object{$_.Id -eq "angular-feature-review"}).Count -ne 0){throw "Angular review incorrectly activated in .NET-only repository"}
 $ownedPath=Join-Path $dotnet ".github\skills\aspnet-core-review\SKILL.md"
 $owned="# repo-owned customization";Set-Content -LiteralPath $ownedPath -Value $owned -Encoding utf8
 Install $dotnet "skip"
 if((Get-Content -LiteralPath $ownedPath -Raw).Trim() -ne $owned){throw "Skip-mode upgrade overwrote repo-owned skill"}
 $missingPath=Join-Path $dotnet ".github\skills\session-handoff\SKILL.md"
 Remove-Item -LiteralPath $missingPath -Force
 Install $dotnet "skip"
 if(-not(Test-Path -LiteralPath $missingPath -PathType Leaf)){throw "Upgrade failed to add missing native skill"}
 if((Get-Content -LiteralPath $ownedPath -Raw).Trim() -ne $owned){throw "Upgrade altered repo-owned skill"}
 Write-Host "PASS: Native skills install, detect stack, select correctly and preserve repository-owned overrides on upgrade."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
exit 0
