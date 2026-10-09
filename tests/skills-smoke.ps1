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
 $dataRepo=Join-Path $temp "data-fixture";New-Item -ItemType Directory -Path $dataRepo -Force|Out-Null
 Set-Content (Join-Path $dataRepo "data.csproj") '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Microsoft.Data.SqlClient" Version="5.0.0" /><PackageReference Include="MongoDB.Driver" Version="2.0.0" /><PackageReference Include="Snowflake.Data" Version="4.0.0" /></ItemGroup></Project>'
 $sql=(& $selector -TargetPath $dataRepo -Intent "review sql server query" -ChangeType data -Json|Out-String)|ConvertFrom-Json
 if(@($sql.SelectedSkills|Where-Object{$_.Id -eq "sql-server-data-review"}).Count -ne 1){throw "SQL Server capability not selected."}
 $mongo=(& $selector -TargetPath $dataRepo -Intent "review mongodb aggregation" -ChangeType data -Json|Out-String)|ConvertFrom-Json
 if(@($mongo.SelectedSkills|Where-Object{$_.Id -eq "mongodb-data-review"}).Count -ne 1){throw "MongoDB capability not selected."}
 $snow=(& $selector -TargetPath $dataRepo -Intent "review snowflake warehouse" -ChangeType data -Json|Out-String)|ConvertFrom-Json
 if(@($snow.SelectedSkills|Where-Object{$_.Id -eq "snowflake-data-review"}).Count -ne 1){throw "Snowflake capability not selected."}
 $blocked=(& $selector -TargetPath $dataRepo -Intent "mongodb only index" -ChangeType data -Json|Out-String)|ConvertFrom-Json
 if(@($blocked.SelectedSkills|Where-Object{$_.Id -eq "sql-server-data-review"}).Count -ne 0){throw "SQL Server anti-trigger ignored."}
 $plain=(& $selector -TargetPath $temp -Intent "review snowflake warehouse" -ChangeType data -Json|Out-String)|ConvertFrom-Json
 if(@($plain.SelectedSkills|Where-Object{$_.Id -eq "snowflake-data-review"}).Count -ne 0){throw "Snowflake capability selected without stack signal."}
 $infra=Join-Path $temp "infra-fixture"
 New-Item -ItemType Directory -Path $infra -Force | Out-Null
 Set-Content (Join-Path $infra "main.tf") 'provider "aws" {}'
 Set-Content (Join-Path $infra "package.json") '{"dependencies":{"tailwindcss":"4.0.0"}}'
 Set-Content (Join-Path $infra "deployment.yaml") "apiVersion: apps/v1`nkind: Deployment"
 foreach($case in @(
  @{Intent="review aws iam";Id="aws-cloud-review"},
  @{Intent="review terraform module";Id="terraform-infrastructure-review"},
  @{Intent="review kubernetes yaml";Id="kubernetes-manifest-review"},
  @{Intent="review tailwind responsive";Id="tailwind-ui-review"}
 )){
  $selected=(& $selector -TargetPath $infra -Intent $case.Intent -ChangeType platform -Json | Out-String) | ConvertFrom-Json
  if(@($selected.SelectedSkills | Where-Object {$_.Id -eq $case.Id}).Count -ne 1){throw "Expected capability: $($case.Id)"}
 }
 $generic=Join-Path $temp "generic-yaml"
 New-Item -ItemType Directory -Path $generic -Force | Out-Null
 Set-Content (Join-Path $generic "notes.yaml") "description: generic configuration"
 $result=(& $selector -TargetPath $generic -Intent "review yaml" -ChangeType platform -Json | Out-String) | ConvertFrom-Json
 if(@($result.SelectedSkills | Where-Object {$_.Id -eq "kubernetes-manifest-review"}).Count -ne 0){throw "Generic YAML must not select Kubernetes capability."}
 Write-Host "PASS: Curated skill catalog and deterministic selection contracts passed."
 exit 0
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
