Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$eval = Join-Path $root "scripts\eval.ps1"
$scenarios = Join-Path $root "evals\scenarios.json"
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($eval,[ref]$tokens,[ref]$errors)|Out-Null
if($errors.Count){throw "eval.ps1 parser errors: $($errors -join '; ')"}
$suite=Get-Content $scenarios -Raw|ConvertFrom-Json
if($suite.schemaVersion -ne 1){throw "Unexpected eval schema"}
foreach($id in @("dotnet-debug","angular-feature","release-verification")){
 if(-not ($suite.scenarios.id -contains $id)){throw "Missing eval scenario $id"}
}
$json=& $eval -ScenarioPath $scenarios -Json
if($LASTEXITCODE -ne 0){throw "Eval runner returned exit $LASTEXITCODE"}
$result=$json|ConvertFrom-Json
if($result.Failed -ne 0){throw "Expected zero failed evals"}
if($result.Total -lt 11){throw "Expected at least eleven eval scenarios"}
foreach($id in @("grill-explicit","decision-record","session-handoff","routine-bug-no-interview","generic-feature-no-interview")){
 if(@($result.Results|Where-Object{$_.Id -eq $id -and $_.Passed}).Count -ne 1){throw "Missing passing interaction eval: $id"}
}
if(@($result.Results|Where-Object{@($_.UnexpectedSkills).Count -gt 0}).Count -gt 0){throw "Interaction eval detected forbidden skill activation"}
Write-Host "Harness eval smoke: PASS"
