[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$path=Join-Path $root "docs\releases\1.2.0-testing.md"
if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing v1.2.0 qualification plan"}
$text=Get-Content -LiteralPath $path -Raw
foreach($required in @("NOT RELEASED","SqlServer","MongoDB","Snowflake","main...develop","NOT RUN","BLOCKED","rollback","release/1.2.0","v1.2.0")){
 if(-not $text.Contains($required)){throw "Release plan missing $required"}
}
if($text -match '(?im)^\|[^\r\n]*\|\s*PASS\s*\|'){throw "Release qualification must not pre-approve gates"}
$version=(Get-Content -LiteralPath (Join-Path $root "VERSION") -Raw).Trim()
if($version -notin @("1.1.0","1.2.0")){throw "Unexpected version $version"}
if($version -eq "1.2.0"){
 $changelog=Get-Content -LiteralPath (Join-Path $root "CHANGELOG.md") -Raw
 if($changelog -notmatch '(?m)^## \[1\.2\.0\]'){throw "Release candidate must document v1.2.0 in CHANGELOG.md"}
}
Write-Host "PASS: v1.2.0 qualification remains evidence-gated; version=$version"
