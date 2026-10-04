[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$installer=Get-Content (Join-Path $root "installer\install.ps1") -Raw
$required=@(
 "scripts\\context.ps1","scripts\\skills.ps1","scripts\\policy-check.ps1","scripts\\verify.ps1",
 "scripts\\record-evidence.ps1","scripts\\run-harness.ps1","scripts\\lifecycle.ps1","scripts\\maker-checker.ps1",
 "scripts\\audit-runs.ps1","scripts\\audit-integrity.ps1","scripts\\new-audit-report.ps1"
)
foreach($path in $required){
 if($installer -notmatch [regex]::Escape('"' + $path + '"')){throw "Installer contract missing $path"}
 $source=Join-Path $root $path;if(-not(Test-Path $source -PathType Leaf)){throw "Runtime source missing $path"}
}
foreach($manifestField in @("lifecycle","makerChecker","observability")){if($installer -notmatch $manifestField){throw "Install manifest missing $manifestField contract."}}
Write-Host "PASS: installer contains the complete v1 runtime and observability contract."
