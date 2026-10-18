[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$suite=Get-Content -LiteralPath (Join-Path $root "evals\data-skill-selection.json") -Raw|ConvertFrom-Json
if($suite.schemaVersion -ne 1){throw "Unsupported benchmark schema"}
$catalog=Get-Content -LiteralPath (Join-Path $root "skills\catalog.json") -Raw|ConvertFrom-Json
$selector=Join-Path $root "scripts\skills.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ("data-skill-benchmark-"+[guid]::NewGuid().ToString("N"))
$seen=@{};$count=0;$totalSelectedChars=0;$totalCatalogChars=0
try{
 foreach($case in @($suite.cases)){
  $id=[string]$case.id
  if([string]::IsNullOrWhiteSpace($id) -or $seen.ContainsKey($id)){throw "Missing/duplicate case ID"}
  $seen[$id]=$true
  $path=Join-Path $temp $id
  New-Item -ItemType Directory -Path $path -Force|Out-Null
  $stacks=@(([string]$case.stack).Split(','))
  foreach($stack in $stacks){
   switch($stack){
    "SqlServer" {Set-Content -LiteralPath (Join-Path $path "schema.sqlproj") -Value "<Project />"}
    "MongoDb" {Set-Content -LiteralPath (Join-Path $path "package.json") -Value '{"dependencies":{"mongodb":"^6.0.0"}}'}
    "Snowflake" {Set-Content -LiteralPath (Join-Path $path "requirements.toml") -Value 'snowflake-connector-python = "1"'}
    default {throw "Unknown fixture stack $stack"}
   }
  }
  $result=(& $selector -TargetPath $path -Intent ([string]$case.intent) -ChangeType feature -Json|Out-String)|ConvertFrom-Json
  # PowerShell script invocation does not necessarily set $LASTEXITCODE. Under StrictMode,
  # referencing an unset automatic variable fails even when the selector succeeded.
  # Selector errors propagate through $ErrorActionPreference = "Stop"; validate the result contract.
  if($null -eq $result -or $null -eq $result.SelectedSkills){throw "Selector returned invalid JSON for $id"}
  $selected=@($result.SelectedSkills|ForEach-Object{$_.Id})
  foreach($expected in @($case.expected)){if($selected -notcontains $expected){throw "$id missing expected $expected (selected $($selected -join ','))"}}
  foreach($excluded in @($case.excluded)){if($selected -contains $excluded){throw "$id unexpectedly selected $excluded"}}
  $allData=@("sql-server-data-review","mongodb-data-review","snowflake-data-review")
  foreach($candidate in $allData){
   if($selected -contains $candidate -and @($case.expected) -notcontains $candidate){throw "$id selected unexpected data skill $candidate"}
  }
  $catalogChars=0;$selectedChars=0
  foreach($skill in @($catalog.skills|Where-Object{$_.id -in $allData})){
   $skillPath=Join-Path $root ".github\skills\$($skill.id)\SKILL.md"
   $chars=(Get-Content -LiteralPath $skillPath -Raw).Length
   $catalogChars+=$chars
   if($selected -contains $skill.id){$selectedChars+=$chars}
  }
  $totalSelectedChars+=$selectedChars;$totalCatalogChars+=$catalogChars
  $count++
  Write-Host "PASS $id : $($selected -join ',') | selected skill chars=$selectedChars of $catalogChars"
 }
 if($count -lt 8){throw "Insufficient benchmark coverage"}
 $saved=$totalCatalogChars-$totalSelectedChars
 Write-Host "PASS: $count selection scenarios. Potential context character reduction vs always loading all three skills: $saved / $totalCatalogChars."
 Write-Host "IMPORTANT: This is a static selected-skill character proxy, NOT observed Copilot context usage or tokenizer-based token savings."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
exit 0
