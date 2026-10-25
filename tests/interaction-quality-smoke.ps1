[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $root "scripts\eval-interaction-quality.ps1"
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -gt 0){throw "Quality runner parse error: $($errors[0].Message)"}
$report=(& $runner -Json|Out-String)|ConvertFrom-Json
if($LASTEXITCODE -ne 0 -or $report.Cases -lt 4 -or $report.Reviewed -ne 0){throw "Expected unreviewed rubric to validate"}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("quality-review-"+[guid]::NewGuid().ToString("N")+".json")
try{
 $suite=Get-Content -LiteralPath (Join-Path $root "evals\interaction-response-quality.json") -Raw|ConvertFrom-Json
 $reviewCases=@($suite.cases|Where-Object{$_.skill -eq "code-review"})
 if($reviewCases.Count -lt 6){throw "Expected at least six cross-stack code-review cases"}
 foreach($required in @("review-dotnet-auth","review-angular-xss","review-sql-server-transaction","review-mongodb-idempotency","review-snowflake-cost","review-clean-patch")){
  if(@($reviewCases|Where-Object{$_.id -eq $required}).Count -ne 1){throw "Missing code-review scenario $required"}
 }
 $reviews=@()
 foreach($case in $suite.cases){
  $grades=@($case.criteria|ForEach-Object{@{criterionId=$_.id;score=2}})
  $reviews+=@{caseId=$case.id;reviewer="smoke-fixture";evidence="fixture-only";grades=$grades}
 }
 @{schemaVersion=1;reviews=$reviews}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
 $scored=(& $runner -ResultsPath $temp -Json|Out-String)|ConvertFrom-Json
 if($LASTEXITCODE -ne 0 -or -not $scored.Passed -or $scored.Unreviewed -ne 0){throw "Full review fixture must pass"}
 $reviews[0].grades[0].score=0
 @{schemaVersion=1;reviews=$reviews}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
 $bad=(& $runner -ResultsPath $temp -Json|Out-String)|ConvertFrom-Json
 if($bad.Passed -or $LASTEXITCODE -ne 1){throw "Low-quality fixture must fail"}
 Write-Host "PASS: Offline interaction quality rubric and scoring smoke checks."
}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
$global:LASTEXITCODE=0
exit 0
