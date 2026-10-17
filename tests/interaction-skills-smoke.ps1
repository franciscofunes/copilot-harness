[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$selector=Join-Path $root "scripts\skills.ps1"
$catalog=Get-Content -LiteralPath (Join-Path $root "skills\catalog.json") -Raw|ConvertFrom-Json
foreach($id in @("grill-with-docs","session-handoff")){
 $file=Join-Path $root ".github\skills\$id\SKILL.md"
 if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "Missing native skill: $id"}
 $body=Get-Content -LiteralPath $file -Raw
 if(-not $body.Contains("name: $id")){throw "Missing frontmatter name: $id"}
 if(-not $body.Contains("Spec Kit") -or -not $body.Contains("verification")){throw "Missing authority boundaries: $id"}
 $entry=@($catalog.skills|Where-Object{$_.id -eq $id})
 if($entry.Count -ne 1 -or $entry[0].requiresMcp -or $entry[0].authority -ne "advisory"){throw "Invalid advisory catalog entry: $id"}
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("interaction-skills-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
try{
 foreach($case in @(
  @{Intent="document our decisions";Id="grill-with-docs"},
  @{Intent="session handoff";Id="session-handoff"}
  )){
  $result=(& $selector -TargetPath $temp -Intent $case.Intent -ChangeType feature -Json|Out-String)|ConvertFrom-Json
  if(@($result.SelectedSkills|Where-Object{$_.Id -eq $case.Id}).Count -ne 1){throw "Expected opt-in skill: $($case.Id)"}
 }
 $normal=(& $selector -TargetPath $temp -Intent "fix an error message typo" -ChangeType bug -Json|Out-String)|ConvertFrom-Json
 if(@($normal.SelectedSkills|Where-Object{$_.Id -in @("grill-with-docs","session-handoff")}).Count -ne 0){throw "Interaction skills must not activate for routine bugs"}
 Write-Host "PASS: Decision and handoff native skill contracts passed."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
exit 0
