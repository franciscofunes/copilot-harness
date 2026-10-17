[CmdletBinding()]
param([string]$SuitePath,[string]$ResultsPath,[switch]$Json)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
if([string]::IsNullOrWhiteSpace($SuitePath)){$SuitePath=Join-Path $root "evals\ide-adoption.json"}
$suite=Get-Content -LiteralPath $SuitePath -Raw|ConvertFrom-Json
if($suite.schemaVersion -ne 1){throw "Unsupported IDE adoption schema"}
$cases=@{};$checks=@("installed","discoverable","invoked","evidence-captured")
foreach($case in @($suite.cases)){
 if([string]::IsNullOrWhiteSpace($case.id) -or $cases.ContainsKey([string]$case.id)){throw "Missing/duplicate case ID"}
 if($case.ide -notin @("vscode","visualstudio")){throw "Unknown IDE"}
 if(@($case.checks).Count -ne $checks.Count -or @($case.checks|Where-Object{$_ -notin $checks}).Count -gt 0){throw "Invalid checks"}
 $cases[[string]$case.id]=$case
}
if($cases.Count -lt 4){throw "Expected at least four IDE adoption cases"}
$report=[ordered]@{SchemaVersion=1;Cases=$cases.Count;Reviewed=0;Unreviewed=$cases.Count;Passed=$false;Results=@()}
if(-not [string]::IsNullOrWhiteSpace($ResultsPath)){
 $results=Get-Content -LiteralPath $ResultsPath -Raw|ConvertFrom-Json
 if($results.schemaVersion -ne 1){throw "Unsupported results schema"}
 $seen=@{}
 foreach($review in @($results.reviews)){
  $id=[string]$review.caseId
  if(-not $cases.ContainsKey($id) -or $seen.ContainsKey($id)){throw "Unknown/duplicate case ID in review"}
  $seen[$id]=$true
  if([string]::IsNullOrWhiteSpace($review.reviewer) -or [string]::IsNullOrWhiteSpace($review.evidence) -or [string]::IsNullOrWhiteSpace($review.ideVersion) -or [string]::IsNullOrWhiteSpace($review.copilotVersion)){throw "Reviewer, evidence and IDE/Copilot versions are required"}
  $observed=$review.observed
  $allPassed=$true
  foreach($check in $checks){
   if($null -eq $observed -or $null -eq $observed.PSObject.Properties[$check] -or $observed.$check -isnot [bool]){throw "Missing or non-boolean check $check in $id"}
   if(-not $observed.$check){$allPassed=$false}
  }
  $report.Results+=@{CaseId=$id;Passed=$allPassed}
 }
 $report.Reviewed=$seen.Count;$report.Unreviewed=$cases.Count-$seen.Count
 $report.Passed=($report.Unreviewed -eq 0 -and @($report.Results|Where-Object{-not $_.Passed}).Count -eq 0)
}
if($Json){$report|ConvertTo-Json -Depth 7}else{Write-Host "IDE adoption: $($report.Reviewed)/$($report.Cases) reviewed; passed=$($report.Passed)"}
if(-not [string]::IsNullOrWhiteSpace($ResultsPath) -and -not $report.Passed){exit 1}
exit 0
