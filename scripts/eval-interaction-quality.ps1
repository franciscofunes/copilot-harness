[CmdletBinding()]
param(
 [string]$SuitePath,
 [string]$ResultsPath,
 [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
if([string]::IsNullOrWhiteSpace($SuitePath)){$SuitePath=Join-Path $root "evals\interaction-response-quality.json"}
$suite=Get-Content -LiteralPath $SuitePath -Raw|ConvertFrom-Json
if($suite.schemaVersion -ne 1){throw "Unsupported quality eval schema"}
$ids=@{}
foreach($case in @($suite.cases)){
 if([string]::IsNullOrWhiteSpace($case.id) -or $ids.ContainsKey($case.id)){throw "Missing or duplicate case ID"}
 $ids[$case.id]=$true
 if([string]::IsNullOrWhiteSpace($case.prompt) -or @($case.criteria).Count -eq 0){throw "Missing prompt or criteria for $($case.id)"}
 $criterionIds=@{}
 foreach($criterion in @($case.criteria)){
  if([string]::IsNullOrWhiteSpace($criterion.id) -or $criterionIds.ContainsKey($criterion.id)){throw "Duplicate/empty criterion in $($case.id)"}
  $criterionIds[$criterion.id]=$true
  if($criterion.weight -lt 1 -or $criterion.weight -gt 5){throw "Criterion weight must be 1..5"}
 }
}
if($ids.Count -lt 4){throw "Expected at least four quality cases"}
$report=[ordered]@{SchemaVersion=1;Cases=$ids.Count;Reviewed=0;Unreviewed=$ids.Count;Passed=$false;Scores=@()}
if(-not [string]::IsNullOrWhiteSpace($ResultsPath)){
 $results=Get-Content -LiteralPath $ResultsPath -Raw|ConvertFrom-Json
 if($results.schemaVersion -ne 1){throw "Unsupported review results schema"}
 $seen=@{}
 foreach($item in @($results.reviews)){
  if(-not $ids.ContainsKey([string]$item.caseId) -or $seen.ContainsKey([string]$item.caseId)){throw "Unknown or duplicate reviewed case"}
  $seen[[string]$item.caseId]=$true
  if([string]::IsNullOrWhiteSpace($item.reviewer) -or [string]::IsNullOrWhiteSpace($item.evidence)){throw "Reviewer and evidence reference required"}
  $case=@($suite.cases|Where-Object{$_.id -eq $item.caseId})[0]
  $grades=@{}
  foreach($grade in @($item.grades)){
   if($grades.ContainsKey([string]$grade.criterionId)){throw "Duplicate grade"}
   if($grade.score -notin @(0,1,2)){throw "Score must be 0, 1 or 2"}
   $grades[[string]$grade.criterionId]=[int]$grade.score
  }
  $earned=0;$possible=0
  foreach($criterion in @($case.criteria)){
   if(-not $grades.ContainsKey([string]$criterion.id)){throw "Missing criterion grade: $($criterion.id)"}
   $earned+=$grades[[string]$criterion.id]*[int]$criterion.weight
   $possible+=2*[int]$criterion.weight
  }
  if($grades.Count -ne @($case.criteria).Count){throw "Unexpected criterion grade"}
  $report.Scores+=@{CaseId=$item.caseId;Earned=$earned;Possible=$possible;Percent=[math]::Round(100*$earned/$possible,2)}
 }
 $report.Reviewed=$seen.Count
 $report.Unreviewed=$ids.Count-$seen.Count
 $report.Passed=($report.Unreviewed -eq 0 -and @($report.Scores|Where-Object{$_.Percent -lt 80}).Count -eq 0)
}
if($Json){$report|ConvertTo-Json -Depth 7}else{Write-Host "Response quality rubric: $($report.Cases) cases, $($report.Reviewed) reviewed, $($report.Unreviewed) unreviewed"}
if(-not [string]::IsNullOrWhiteSpace($ResultsPath) -and -not $report.Passed){exit 1}
exit 0
