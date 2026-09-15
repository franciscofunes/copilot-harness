[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [ValidateSet("commands", "skills")]
    [string]$ExpectedSpecKitLayout = "commands",

    [string[]]$ExpectedSpecKitExtensions = @("git", "bug", "assess")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$stack = & $detectScript -Path $targetRoot
$specKitRepository = "https://github.com/github/spec-kit"

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
Test-CommandCheck "specify" $false "Install the official github/spec-kit specify-cli from $specKitRepository."
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
Test-FileCheck ".github\instructions\release-testing.instructions.md"
Test-FileCheck ".github\instructions\policy-verification.instructions.md"
Test-FileCheck ".github\prompts\feature.prompt.md"
Test-FileCheck "spec-kit\constitution-template.md"
Test-FileCheck "docs\POLICY-GATE.md"
Test-FileCheck "docs\VERIFICATION-CONTRACT.md"
Test-FileCheck "docs\SPECKIT-EXTENSIONS-VALIDATION.md"
Test-FileCheck "docs\RELEASE-TESTING.md"
Test-FileCheck "docs\releases\TESTING-TEMPLATE.md"
Test-FileCheck "scripts\policy-check.ps1"
Test-FileCheck "scripts\verify.ps1"

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
    Add-Check "spec-kit" "PASS" ".specify directory detected; expected source of truth is $specKitRepository"

    if ($ExpectedSpecKitLayout -eq "commands") {
        $agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $targetRoot ".github\agents") -Filter "*.agent.md" -File -ErrorAction SilentlyContinue)
        $promptFiles = @(Get-ChildItem -LiteralPath (Join-Path $targetRoot ".github\prompts") -Filter "*.prompt.md" -File -ErrorAction SilentlyContinue)
        if ($agentFiles.Count -gt 0 -or $promptFiles.Count -gt 1) {
            Add-Check "spec-kit:layout" "PASS" "commands layout evidence detected under .github/agents or .github/prompts"
        } else {
            Add-Check "spec-kit:layout" "WARN" "commands layout expected, but no generated Spec Kit agents/prompts were detected."
        }
    } else {
        $skillsPath = Join-Path $targetRoot ".github\skills"
        if (Test-Path -LiteralPath $skillsPath) {
            Add-Check "spec-kit:layout" "PASS" "skills layout detected under .github/skills"
        } else {
            Add-Check "spec-kit:layout" "WARN" "skills layout expected, but .github/skills was not detected."
        }
    }

    $specify = Get-Command specify -ErrorAction SilentlyContinue
    if ($null -ne $specify) {
        Push-Location $targetRoot
        try {
            $extensionOutput = (& specify extension list 2>&1 | Out-String)
            if ($LASTEXITCODE -eq 0) {
                foreach ($extension in $ExpectedSpecKitExtensions) {
                    if ($extensionOutput -match "(?im)^.*\b$([regex]::Escape($extension))\b.*$") {
                        Add-Check "spec-kit:extension:$extension" "PASS" "installed"
                    } else {
                        Add-Check "spec-kit:extension:$extension" "WARN" "recommended extension is not listed; run: specify extension add $extension"
                    }
                }
            } else {
                Add-Check "spec-kit:extensions" "WARN" "could not query installed extensions; verify with: specify extension list"
            }
        } finally {
            Pop-Location
        }
    } else {
        Add-Check "spec-kit:extensions" "WARN" "specify CLI unavailable; cannot verify recommended extensions."
    }
} else {
    Add-Check "spec-kit" "WARN" "Official github/spec-kit is not initialized in this repository yet."
}

$manifestPath = Join-Path $targetRoot ".copilot-harness.json"
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Add-Check "manifest" "PASS" ".copilot-harness.json present"
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($null -ne $manifest.specKit -and $manifest.specKit.repository -eq $specKitRepository) {
            Add-Check "manifest:spec-kit-source" "PASS" $specKitRepository
        } else {
            Add-Check "manifest:spec-kit-source" "WARN" "manifest does not record the official github/spec-kit repository."
        }

        if ($null -ne $manifest.releaseTesting -and $manifest.releaseTesting.contract -eq "docs/RELEASE-TESTING.md") {
            Add-Check "manifest:release-testing" "PASS" "release testing contract recorded"
        } else {
            Add-Check "manifest:release-testing" "WARN" "manifest does not record the release testing contract."
        }

        if ($null -ne $manifest.policy -and $manifest.policy.gate -eq "docs/POLICY-GATE.md" -and $manifest.policy.evaluator -eq "scripts/policy-check.ps1") {
            Add-Check "manifest:policy" "PASS" "policy gate and evaluator recorded"
        } else {
            Add-Check "manifest:policy" "WARN" "manifest does not record executable policy assets."
        }

        if ($null -ne $manifest.verification -and $manifest.verification.contract -eq "docs/VERIFICATION-CONTRACT.md" -and $manifest.verification.runner -eq "scripts/verify.ps1") {
            Add-Check "manifest:verification" "PASS" "verification contract and runner recorded"
        } else {
            Add-Check "manifest:verification" "WARN" "manifest does not record executable verification assets."
        }
    } catch {
        Add-Check "manifest:json" "WARN" "manifest could not be parsed as JSON."
    }
} else {
    Add-Check "manifest" "WARN" "No installer manifest found; repository may have been configured manually."
}

Write-Host ""
Write-Host "Copilot Harness Doctor"
Write-Host "Repository: $targetRoot"
Write-Host "Detected stacks: $(if ($stack.DetectedStacks.Count) { $stack.DetectedStacks -join ', ' } else { 'none' })"
Write-Host "Expected Spec Kit source: $specKitRepository"
Write-Host "Expected Copilot layout: $ExpectedSpecKitLayout"
Write-Host "Policy gate: docs/POLICY-GATE.md"
Write-Host "Verification contract: docs/VERIFICATION-CONTRACT.md"
Write-Host "Release testing contract: docs/RELEASE-TESTING.md"
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
