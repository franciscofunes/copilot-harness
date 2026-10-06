[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [ValidateSet("commands", "skills")]
    [string]$ExpectedSpecKitLayout = "commands",

    [string[]]$ExpectedSpecKitExtensions = @("git", "bug", "assess"),

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$specKitRepository = "https://github.com/github/spec-kit"
$schemaVersion = 1

if (-not (Test-Path -LiteralPath $detectScript -PathType Leaf)) {
    throw "Harness doctor cannot run because scripts/detect-stack.ps1 is missing from the harness runtime."
}

$stack = & $detectScript -Path $targetRoot
$checks = New-Object System.Collections.Generic.List[object]

function Get-ObjectPropertyValue {
    param([object]$InputObject,[string]$Name)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

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
    $display = $RelativePath -replace "\\", "/"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-Check "file:$display" "PASS" "present"
    } elseif ($Required) {
        Add-Check "file:$display" "FAIL" "missing"
    } else {
        Add-Check "file:$display" "WARN" "not installed"
    }
}

function Test-ManifestValue {
    param(
        [object]$Parent,
        [string]$Property,
        [object]$Expected,
        [string]$Name,
        [string]$SuccessDetail
    )

    $actual = Get-ObjectPropertyValue $Parent $Property
    if ($actual -eq $Expected) {
        Add-Check $Name "PASS" $SuccessDetail
    } else {
        Add-Check $Name "FAIL" "Expected '$Property' to be '$Expected', found '$actual'."
    }
}

$runningOnWindows = $env:OS -eq "Windows_NT"
if ($runningOnWindows) {
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

$requiredFiles = @(
    ".github\copilot-instructions.md",
    ".github\instructions\tests.instructions.md",
    ".github\instructions\release-testing.instructions.md",
    ".github\instructions\policy-verification.instructions.md",
    ".github\prompts\feature.prompt.md",
    "spec-kit\constitution-template.md",
    "docs\POLICY-GATE.md",
    "docs\VERIFICATION-CONTRACT.md",
    "docs\SPECKIT-EXTENSIONS-VALIDATION.md",
    "docs\RELEASE-TESTING.md",
    "docs\releases\TESTING-TEMPLATE.md",
    "docs\CODEGRAPH.md",
    "docs\CONTEXT-EVIDENCE-ENGINE.md",
    "docs\CURATED-SKILLS.md",
    "docs\HARNESS-READINESS.md",
    "scripts\detect-stack.ps1",
    "scripts\policy-check.ps1",
    "scripts\verify.ps1",
    "scripts\new-verification-profile.ps1",
    "scripts\setup-codegraph.ps1",
    "scripts\context.ps1",
    "scripts\skills.ps1",
    "skills\catalog.json",
    "scripts\record-evidence.ps1",
    "scripts\run-harness.ps1",
    "scripts\lifecycle.ps1",
    "scripts\maker-checker.ps1",
    "scripts\audit-runs.ps1",
    "scripts\audit-integrity.ps1",
    "scripts\new-audit-report.ps1",
    "scripts\doctor.ps1"
)
foreach ($file in $requiredFiles) {
    Test-FileCheck $file
}

if ($stack.Signals.DotNet) {
    Test-FileCheck ".github\instructions\dotnet.instructions.md"
}

if ($stack.Signals.Angular) {
    Test-FileCheck ".github\instructions\angular.instructions.md"
}

if ($stack.Signals.SqlServer -or $stack.Signals.MongoDb -or $stack.Signals.Snowflake -or $stack.Signals.Parquet) {
    Test-FileCheck ".github\instructions\data.instructions.md"
}

$profilePath = Join-Path $targetRoot ".copilot-harness.verify.json"
if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    try {
        $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        if ($profile.schemaVersion -ne 1) {
            Add-Check "verification:profile" "FAIL" "unsupported schemaVersion"
        } elseif ($null -eq $profile.checks) {
            Add-Check "verification:profile" "FAIL" "checks property missing"
        } else {
            Add-Check "verification:profile" "PASS" "schemaVersion 1 profile is parseable"
            $unsafe = @($profile.checks | Where-Object { $_.policyClass -notin @("A0","A1") })
            if ($unsafe.Count -gt 0) {
                Add-Check "verification:profile-policy" "WARN" "$($unsafe.Count) check(s) require separate authorization and will be blocked by verify.ps1"
            } else {
                Add-Check "verification:profile-policy" "PASS" "automatic checks are A0/A1 only"
            }
        }
    } catch {
        Add-Check "verification:profile" "FAIL" "invalid JSON: $($_.Exception.Message)"
    }
} else {
    Add-Check "verification:profile" "WARN" "No .copilot-harness.verify.json found; run scripts/new-verification-profile.ps1 or configure one explicitly."
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
        $manifestSpecKit = Get-ObjectPropertyValue $manifest "specKit"
        $manifestRelease = Get-ObjectPropertyValue $manifest "releaseTesting"
        $manifestPolicy = Get-ObjectPropertyValue $manifest "policy"
        $manifestVerification = Get-ObjectPropertyValue $manifest "verification"
        $manifestContext = Get-ObjectPropertyValue $manifest "context"
        $manifestObservability = Get-ObjectPropertyValue $manifest "observability"
        $manifestReadiness = Get-ObjectPropertyValue $manifest "readiness"

        Test-ManifestValue $manifestSpecKit "repository" $specKitRepository "manifest:spec-kit-source" $specKitRepository
        Test-ManifestValue $manifestRelease "contract" "docs/RELEASE-TESTING.md" "manifest:release-testing" "release testing contract recorded"
        Test-ManifestValue $manifestPolicy "gate" "docs/POLICY-GATE.md" "manifest:policy-gate" "policy gate recorded"
        Test-ManifestValue $manifestPolicy "evaluator" "scripts/policy-check.ps1" "manifest:policy-evaluator" "policy evaluator recorded"
        Test-ManifestValue $manifestVerification "contract" "docs/VERIFICATION-CONTRACT.md" "manifest:verification-contract" "verification contract recorded"
        Test-ManifestValue $manifestVerification "runner" "scripts/verify.ps1" "manifest:verification-runner" "verification runner recorded"
        Test-ManifestValue $manifestVerification "profileGenerator" "scripts/new-verification-profile.ps1" "manifest:verification-generator" "verification profile generator recorded"
        Test-ManifestValue $manifestContext "builder" "scripts/context.ps1" "manifest:context-builder" "context builder recorded"
        Test-ManifestValue $manifestContext "orchestrator" "scripts/run-harness.ps1" "manifest:orchestrator" "orchestrator recorded"
        Test-ManifestValue $manifestContext "evidenceRecorder" "scripts/record-evidence.ps1" "manifest:evidence-recorder" "evidence recorder recorded"
        Test-ManifestValue $manifestContext "lifecycle" "scripts/lifecycle.ps1" "manifest:lifecycle" "lifecycle runtime recorded"
        Test-ManifestValue $manifestContext "makerChecker" "scripts/maker-checker.ps1" "manifest:maker-checker" "maker/checker runtime recorded"
        Test-ManifestValue $manifestObservability "metrics" "scripts/audit-runs.ps1" "manifest:audit-metrics" "audit metrics runtime recorded"
        Test-ManifestValue $manifestObservability "integrity" "scripts/audit-integrity.ps1" "manifest:audit-integrity" "integrity runtime recorded"
        Test-ManifestValue $manifestObservability "report" "scripts/new-audit-report.ps1" "manifest:audit-report" "audit report runtime recorded"
        Test-ManifestValue $manifestReadiness "contract" "docs/HARNESS-READINESS.md" "manifest:readiness-contract" "readiness contract recorded"
        Test-ManifestValue $manifestReadiness "doctor" "scripts/doctor.ps1" "manifest:doctor" "doctor runtime recorded"
        Test-ManifestValue $manifestReadiness "schemaVersion" $schemaVersion "manifest:doctor-schema" "doctor schemaVersion $schemaVersion recorded"
    } catch {
        Add-Check "manifest:json" "FAIL" "manifest could not be parsed as JSON: $($_.Exception.Message)"
    }
} else {
    Add-Check "manifest" "WARN" "No installer manifest found; repository may have been configured manually."
}

$passCount = @($checks | Where-Object Status -eq "PASS").Count
$warningCount = @($checks | Where-Object Status -eq "WARN").Count
$failureCount = @($checks | Where-Object Status -eq "FAIL").Count
$summary = [pscustomobject]@{
    SchemaVersion = $schemaVersion
    Target = $targetRoot
    DetectedStacks = @($stack.DetectedStacks)
    Checks = @($checks.ToArray())
    Counts = [pscustomobject]@{
        Pass = $passCount
        Warn = $warningCount
        Fail = $failureCount
    }
    Ready = ($failureCount -eq 0)
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 8
} else {
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

    Write-Host ""
    Write-Host ("Summary: {0} passed, {1} warnings, {2} failures" -f $passCount, $warningCount, $failureCount)
    Write-Host ("Ready: {0}" -f $summary.Ready)
}

if (-not $summary.Ready) {
    exit 1
}

exit 0
