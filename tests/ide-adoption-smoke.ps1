[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $root "scripts\eval-ide-adoption.ps1"
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$errors)|Out-Null
if(@($errors).Count -gt 0){throw "IDE adoption scorer parse failure: $($errors[0].Message)"}
$empty=(& $runner -Json|Out-String)|ConvertFrom-Json
if($LASTEXITCODE -ne 0 -or $empty.Cases -lt 4 -or $empty.Reviewed -ne 0){throw "Expected valid unreviewed suite"}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("ide-adoption-"+[guid]::NewGuid().ToString("N")+".json")
try{
 $suite=Get-Content -LiteralPath (Join-Path $root "evals\ide-adoption.json") -Raw|ConvertFrom-Json
 $reviews=@($suite.cases|ForEach-Object{@{caseId=$_.id;reviewer="synthetic-smoke";evidence="fixture-not-real";ideVersion="fixture";copilotVersion="fixture";observed=@{installed=$true;discoverable=$true;invoked=$true;"evidence-captured"=$true}}})
 @{schemaVersion=1;reviews=$reviews}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
 $ok=(& $runner -ResultsPath $temp -Json|Out-String)|ConvertFrom-Json
 if($LASTEXITCODE -ne 0 -or -not $ok.Passed){throw "Passing fixture rejected"}
 $reviews[0].observed["discoverable"]=$false
 @{schemaVersion=1;reviews=$reviews}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
 $bad=(& $runner -ResultsPath $temp -Json|Out-String)|ConvertFrom-Json
 if($LASTEXITCODE -ne 1 -or $bad.Passed){throw "Failing fixture accepted"}
 Write-Host "PASS: IDE adoption scoring and negative fixture."
}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
$global:LASTEXITCODE=0
exit 0
