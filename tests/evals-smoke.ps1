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
if($result.Total -lt 3){throw "Expected at least three evals"}
Write-Host "Harness eval smoke: PASS"
