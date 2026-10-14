[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$skill=Join-Path $root ".github\skills\grill-me\SKILL.md"
$registry=Join-Path $root "skills\upstream-sources.json"
$catalog=Join-Path $root "skills\catalog.json"
if(-not (Test-Path -LiteralPath $skill -PathType Leaf)){throw "Missing native Grill Me SKILL.md"}
$body=Get-Content -LiteralPath $skill -Raw
foreach($required in @("name: grill-me","one high-impact question at a time","GitHub Spec Kit","Policy A0","no scripts")){
 if(-not $body.Contains($required)){throw "Missing interaction contract: $required"}
}
$upstream=Get-Content -LiteralPath $registry -Raw|ConvertFrom-Json
$source=@($upstream.sources|Where-Object{$_.repository -eq "mattpocock/skills"})
if($source.Count -ne 1 -or $source[0].reviewStatus -ne "candidate" -or $source[0].integration -ne "reference-only"){throw "Matt Pocock source must remain a reference-only candidate"}
$data=Get-Content -LiteralPath $catalog -Raw|ConvertFrom-Json
$entry=@($data.skills|Where-Object{$_.id -eq "grill-me"})
if($entry.Count -ne 1 -or $entry[0].requiresMcp -or $entry[0].authority -ne "advisory"){throw "Grill Me must be an optional advisory capability"}
$selector=Join-Path $root "scripts\skills.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("grill-me-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture -Force|Out-Null
try {
 $explicit=(& $selector -TargetPath $fixture -Intent "grill me about this feature" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($explicit.SelectedSkills|Where-Object{$_.Id -eq "grill-me"}).Count -ne 1){throw "Explicit request must select Grill Me"}
 $bug=(& $selector -TargetPath $fixture -Intent "fix a typo in error message" -ChangeType bug -Json|Out-String)|ConvertFrom-Json
 if(@($bug.SelectedSkills|Where-Object{$_.Id -eq "grill-me"}).Count -ne 0){throw "Routine bug must not trigger Grill Me"}
 Write-Host "PASS: Grill Me is native, optional and does not replace planning or verification."
}finally{Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue}
exit 0
