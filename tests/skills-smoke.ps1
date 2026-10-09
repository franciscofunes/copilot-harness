[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$selector=Join-Path $root "scripts\skills.ps1"
$catalog=Join-Path $root "skills\catalog.json"
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($selector,[ref]$tokens,[ref]$errors)|Out-Null
if($errors.Count -gt 0){throw "skills.ps1 parse failure: $($errors[0].Message)"}
$data=Get-Content -LiteralPath $catalog -Raw|ConvertFrom-Json
if($data.schemaVersion -ne 2){throw "Catalog schema must be 2."}
foreach($skill in $data.skills){
 if($null -eq $skill.PSObject.Properties["antiTriggers"] -or $null -eq $skill.PSObject.Properties["provenance"] -or $null -eq $skill.PSObject.Properties["verification"]){throw "Missing v2 capability metadata: $($skill.id)"}
}
$ids=@($data.skills.id)
foreach($required in @("systematic-debugging","test-driven-development","verification-before-completion","acquire-codebase-knowledge")){
 if($ids -notcontains $required){throw "Missing curated skill: $required"}
}
if(@($data.skills|Where-Object{$_.requiresMcp}).Count -gt 0){throw "Baseline catalog must not require MCP."}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("skills-smoke-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force|Out-Null
try{
 Set-Content (Join-Path $temp "sample.sln") ""
 $debug=(& $selector -TargetPath $temp -Intent "debug unexpected failure" -ChangeType bug -Json|Out-String)|ConvertFrom-Json
 if(@($debug.SelectedSkills|Where-Object{$_.Id -eq "systematic-debugging"}).Count -ne 1){throw "Debug intent must select systematic-debugging."}
 $done=(& $selector -TargetPath $temp -Intent "feature complete create pr" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($done.SelectedSkills|Where-Object{$_.Id -eq "verification-before-completion"}).Count -ne 1){throw "Completion intent must select verification-before-completion."}
 $excluded=(& $selector -TargetPath $temp -Intent "feature documentation-only" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($excluded.SelectedSkills|Where-Object{$_.Id -eq "test-driven-development"}).Count -ne 0){throw "Anti-trigger must exclude TDD for documentation-only work."}
 if(-not $done.Rules.VerifyOwnsEvidence){throw "Harness verification must remain authoritative."}
 $api=(& $selector -TargetPath $temp -Intent "review api endpoint" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($api.SelectedSkills|Where-Object{$_.Id -eq "aspnet-core-api-review"}).Count -ne 1){throw "DotNet API intent must select API capability."}
 if(@($api.SelectedSkills|Where-Object{$_.Id -eq "angular-application-review"}).Count -ne 0){throw "Angular capability must not activate for DotNet-only repository."}
 Set-Content (Join-Path $temp "angular.json") "{}"
 $angular=(& $selector -TargetPath $temp -Intent "review angular component" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($angular.SelectedSkills|Where-Object{$_.Id -eq "angular-application-review"}).Count -ne 1){throw "Angular component intent must select Angular capability."}
 $excludedApi=(& $selector -TargetPath $temp -Intent "api frontend only" -ChangeType feature -Json|Out-String)|ConvertFrom-Json
 if(@($excludedApi.SelectedSkills|Where-Object{$_.Id -eq "aspnet-core-api-review"}).Count -ne 0){throw "API anti-trigger must exclude frontend-only work."}
 Write-Host "PASS: Curated skill catalog and deterministic selection contracts passed."
 exit 0
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
