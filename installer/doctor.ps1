[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$stack = & $detectScript -Path $targetRoot

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet("PASS", "WARN", "FAIL")] [string]$Status,
        [string]$Detail
    )

    $checks.Add([pscustomobject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    })
}

function Test-CommandCheck {
    param(
        [string]$Command,
        [bool]$Required,
        [string]$Reason
    )

    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -ne $found) {
        Add-Check "tool:$Command" "PASS" $found.Source
    } elseif ($Required) {
        Add-Check "tool:$Command" "FAIL" $Reason
    } else {
        Add-Check "tool:$Command" "WARN" $Reason
    }
}

function Test-FileCheck {
    param(
        [string]$RelativePath,
        [bool]$Required = $true
    )

    $path = Join-Path $targetRoot $RelativePath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-Check "file:$RelativePath" "PASS" "present"
    } elseif ($Required) {
        Add-Check "file:$RelativePath" "FAIL" "missing"
    } else {
        Add-Check "file:$RelativePath" "WARN" "not installed"
    }
}

$isWindows = $env:OS -eq "Windows_NT"
if ($isWindows) {
    Add-Check "platform" "PASS" "Windows"
} else {
    Add-Check "platform" "WARN" "Harness is designed and supported primarily for Windows workstations."
}

Test-CommandCheck "git" $true "Git is required for the repository workflow."
Test-CommandCheck "gh" $true "GitHub CLI is required by the approved workflow."
Test-CommandCheck "specify" $false "Install GitHub Spec Kit specify-cli to initialize or update SDD assets."
Test-CommandCheck "uv" $false "uv is the recommended installer/runtime for specify-cli."

if ($stack.Signals.DotNet) {
    Test-CommandCheck "dotnet" $true ".NET was detected in this repository."
}

if ($stack.Signals.Angular) {
    Test-CommandCheck "node" $true "Angular was detected in this repository."
    Test-CommandCheck "npm" $true "Angular was detected in this repository."
}

if ($stack.Signals.AzureDevOps) {
    Test-CommandCheck "az" $false "Azure DevOps signals were detected; Azure CLI is recommended for approved CLI workflows."
}

if ($stack.Signals.JFrog) {
    Test-CommandCheck "jf" $false "JFrog signals were detected; JFrog CLI is recommended for compliance/artifact workflows."
}

Test-FileCheck ".github\copilot-instructions.md"
Test-FileCheck ".github\instructions\tests.instructions.md"
Test-FileCheck ".github\prompts\feature.prompt.md"
Test-FileCheck "spec-kit\constitution-template.md"

if ($stack.Signals.DotNet) {
    Test-FileCheck ".github\instructions\dotnet.instructions.md"
}

if ($stack.Signals.Angular) {
    Test-FileCheck ".github\instructions\angular.instructions.md"
}

if ($stack.Signals.SqlServer -or $stack.Signals.MongoDb -or $stack.Signals.Snowflake -or $stack.Signals.Parquet) {
    Test-FileCheck ".github\instructions\data.instructions.md"
}

$specKitMarker = Join-Path $targetRoot ".specify"
if (Test-Path -LiteralPath $specKitMarker) {
    Add-Check "spec-kit" "PASS" ".specify directory detected"
} else {
    Add-Check "spec-kit" "WARN" "Spec Kit is not initialized in this repository yet."
}

$manifestPath = Join-Path $targetRoot ".copilot-harness.json"
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Add-Check "manifest" "PASS" ".copilot-harness.json present"
} else {
    Add-Check "manifest" "WARN" "No installer manifest found; repository may have been configured manually."
}

Write-Host ""
Write-Host "Copilot Harness Doctor"
Write-Host "Repository: $targetRoot"
Write-Host "Detected stacks: $(if ($stack.DetectedStacks.Count) { $stack.DetectedStacks -join ', ' } else { 'none' })"
Write-Host ""

foreach ($check in $checks) {
    Write-Host ("[{0,-4}] {1,-45} {2}" -f $check.Status, $check.Name, $check.Detail)
}

$failures = @($checks | Where-Object Status -eq "FAIL")
$warnings = @($checks | Where-Object Status -eq "WARN")

Write-Host ""
Write-Host ("Summary: {0} passed, {1} warnings, {2} failures" -f
    @($checks | Where-Object Status -eq "PASS").Count,
    $warnings.Count,
    $failures.Count)

if ($failures.Count -gt 0) {
    exit 1
}

exit 0
