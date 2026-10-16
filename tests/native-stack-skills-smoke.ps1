[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$catalog=Get-Content -LiteralPath (Join-Path $root "skills\catalog.json") -Raw|ConvertFrom-Json
$installer=Get-Content -LiteralPath (Join-Path $root "installer\install.ps1") -Raw
foreach($id in @("aspnet-core-review","angular-feature-review")){
 $path=Join-Path $root ".github\skills\$id\SKILL.md"
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing $id"}
 $body=Get-Content -LiteralPath $path -Raw
 if(-not $body.Contains("name: $id") -or -not $body.Contains("Spec Kit") -or -not $body.Contains("verification")){throw "Missing native skill contract: $id"}
 $entry=@($catalog.skills|Where-Object{$_.id -eq $id})
 if($entry.Count -ne 1 -or $entry[0].requiresMcp -or $entry[0].authority -ne "advisory"){throw "Invalid catalog: $id"}
 if(-not $installer.Contains(".github\skills\$id\SKILL.md")){throw "Installer missing $id"}
}
Write-Host "PASS: Native .NET and Angular skill contracts."
exit 0
