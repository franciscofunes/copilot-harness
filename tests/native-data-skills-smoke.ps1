[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$catalog=(Get-Content -LiteralPath (Join-Path $root "skills\catalog.json") -Raw|ConvertFrom-Json)
$installer=Get-Content -LiteralPath (Join-Path $root "installer\install.ps1") -Raw
$skills=@("sql-server-data-review","mongodb-data-review","snowflake-data-review")
foreach($id in $skills){
 $path=Join-Path $root ".github\skills\$id\SKILL.md"
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing native skill $id"}
 $body=Get-Content -LiteralPath $path -Raw
 if(-not $body.Contains("name: $id") -or -not $body.Contains("Spec Kit") -or -not $body.Contains("Verification")){throw "Invalid skill contract $id"}
 $entries=@($catalog.skills|Where-Object{$_.id -eq $id})
 if($entries.Count -ne 1 -or $entries[0].requiresMcp -or $entries[0].authority -ne "advisory"){throw "Invalid catalog $id"}
 if(-not $installer.Contains(".github\skills\$id\SKILL.md")){throw "Installer missing $id"}
}
Write-Host "PASS: Three native data engineering skills have advisory contracts, catalog entries and installer coverage."
exit 0
