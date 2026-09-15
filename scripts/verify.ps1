[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [ValidateSet("auto", "docs", "powershell", "dotnet", "angular", "api", "data", "platform", "security", "release")]
    [string]$ChangeType = "auto",

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$stack = & $detectScript -Path $targetRoot

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Id,
        [ValidateSet("PASS", "FAIL", "BLOCKED", "SKIPPED", "NOT RUN")]
        [string]$State,
        [string]$Check,
        [string]$Evidence
    )

    [void]$results.Add([pscustomobject]@{
        Id = $Id
        State = $State
        Check = $Check
        Evidence = $Evidence
    })
}

function Invoke-VerificationCommand {
    param(
        [string]$Id,
        [string]$Check,
        [string]$Command,
        [string[]]$Arguments
    )

    $tool = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -eq $tool) {
        Add-Result $Id "BLOCKED" $Check "Required tool '$Command' is unavailable."
        return
    }

    Push-Location $targetRoot
    try {
        $output = (& $Command @Arguments 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            $summaryText = if ([string]::IsNullOrWhiteSpace($output)) { "Command completed successfully." } else { ($output -split "`r?`n" | Select-Object -Last 8) -join " | " }
            Add-Result $Id "PASS" $Check $summaryText
        } else {
            $summaryText = if ([string]::IsNullOrWhiteSpace($output)) { "Command failed with exit code $exitCode." } else { ($output -split "`r?`n" | Select-Object -Last 8) -join " | " }
            Add-Result $Id "FAIL" $Check "Exit ${exitCode}: $summaryText"
        }
    } catch {
        Add-Result $Id "FAIL" $Check $_.Exception.Message
    } finally {
        Pop-Location
    }
}

function Test-PowerShellFiles {
    $psFiles = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "[\\/]node_modules[\\/]" })

    if ($psFiles.Count -eq 0) {
        Add-Result "V1-PS" "SKIPPED" "PowerShell parse" "No PowerShell files found."
        return
    }

    foreach ($file in $psFiles) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            Add-Result "V1-PS" "FAIL" "PowerShell parse" "$($file.FullName): $($errors[0].Message)"
            return
        }
    }

    Add-Result "V1-PS" "PASS" "PowerShell parse" "$($psFiles.Count) PowerShell file(s) parsed successfully."
}

function Test-GitDiff {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $git) {
        Add-Result "V0-DIFF" "BLOCKED" "Git diff integrity" "git is unavailable."
        return
    }

    Push-Location $targetRoot
    try {
        & git rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            Add-Result "V0-DIFF" "SKIPPED" "Git diff integrity" "Target is not a Git work tree."
            return
        }

        $output = (& git diff --check 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            Add-Result "V0-DIFF" "PASS" "Git diff integrity" "git diff --check found no whitespace errors."
        } else {
            Add-Result "V0-DIFF" "FAIL" "Git diff integrity" $output
        }
    } finally {
        Pop-Location
    }
}

function Resolve-EffectiveChangeType {
    if ($ChangeType -ne "auto") { return $ChangeType }
    if ($stack.Signals.DotNet) { return "dotnet" }
    if ($stack.Signals.Angular) { return "angular" }
    return "docs"
}

$effectiveType = Resolve-EffectiveChangeType

Test-GitDiff
Test-PowerShellFiles

switch ($effectiveType) {
    "docs" {
        Add-Result "V2-DOCS" "SKIPPED" "Automated behavior" "Documentation/instruction change has no mandatory runtime behavior check."
    }
    "powershell" {
        $smokePath = Join-Path $targetRoot "tests\smoke.ps1"
        if (Test-Path -LiteralPath $smokePath -PathType Leaf) {
            Invoke-VerificationCommand "V2-SMOKE" "Harness smoke tests" "powershell" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $smokePath)
        } else {
            Add-Result "V2-SMOKE" "NOT RUN" "Harness smoke tests" "tests/smoke.ps1 was not found."
        }
    }
    "dotnet" {
        $solution = @(Get-ChildItem -LiteralPath $targetRoot -Filter "*.sln" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($solution.Count -eq 0) {
            Add-Result "V1-DOTNET" "BLOCKED" ".NET build" "No solution file found at repository root."
        } else {
            Invoke-VerificationCommand "V1-DOTNET" ".NET build without restore" "dotnet" @("build", $solution[0].FullName, "--no-restore")
            Invoke-VerificationCommand "V2-DOTNET" ".NET tests without restore" "dotnet" @("test", $solution[0].FullName, "--no-build", "--no-restore")
        }
    }
    "angular" {
        $packageJson = Join-Path $targetRoot "package.json"
        if (-not (Test-Path -LiteralPath $packageJson -PathType Leaf)) {
            Add-Result "V1-NPM" "BLOCKED" "Angular package scripts" "package.json was not found."
        } else {
            $package = Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json
            if ($null -ne $package.scripts -and $package.scripts.PSObject.Properties.Name -contains "lint") {
                Invoke-VerificationCommand "V1-ANGULAR" "Angular lint" "npm" @("run", "lint", "--", "--no-fix")
            } else {
                Add-Result "V1-ANGULAR" "SKIPPED" "Angular lint" "No lint script is defined."
            }

            if ($null -ne $package.scripts -and $package.scripts.PSObject.Properties.Name -contains "test") {
                Add-Result "V2-ANGULAR" "NOT RUN" "Angular tests" "Test script detected; invoke the repository-specific non-watch CI test command to avoid assuming framework flags."
            } else {
                Add-Result "V2-ANGULAR" "SKIPPED" "Angular tests" "No test script is defined."
            }
        }
    }
    { $_ -in @("api", "data", "platform", "security", "release") } {
        Add-Result "V3-SPECIAL" "NOT RUN" "$effectiveType verification" "Requires repository/environment-specific integration, security, data, platform or release checks. Configure and execute the applicable approved commands."
    }
}

$resultArray = $results.ToArray()
$blocking = @($resultArray | Where-Object { $_.State -in @("FAIL", "BLOCKED", "NOT RUN") })
$summary = [pscustomobject]@{
    Target = $targetRoot
    ChangeType = $effectiveType
    DetectedStacks = @($stack.DetectedStacks)
    Results = $resultArray
    Counts = [pscustomobject]@{
        Pass = @($resultArray | Where-Object State -eq "PASS").Count
        Fail = @($resultArray | Where-Object State -eq "FAIL").Count
        Blocked = @($resultArray | Where-Object State -eq "BLOCKED").Count
        Skipped = @($resultArray | Where-Object State -eq "SKIPPED").Count
        NotRun = @($resultArray | Where-Object State -eq "NOT RUN").Count
    }
    Ready = ($blocking.Count -eq 0)
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 7
} else {
    Write-Host ""
    Write-Host "Copilot Harness Verification"
    Write-Host "Target: $targetRoot"
    Write-Host "Change type: $effectiveType"
    Write-Host ""
    foreach ($result in $resultArray) {
        Write-Host ("[{0,-7}] {1,-12} {2} -- {3}" -f $result.State, $result.Id, $result.Check, $result.Evidence)
    }
    Write-Host ""
    Write-Host ("Summary: {0} PASS, {1} FAIL, {2} BLOCKED, {3} SKIPPED, {4} NOT RUN" -f $summary.Counts.Pass, $summary.Counts.Fail, $summary.Counts.Blocked, $summary.Counts.Skipped, $summary.Counts.NotRun)
}

if (@($resultArray | Where-Object State -eq "FAIL").Count -gt 0) { exit 1 }
if (@($resultArray | Where-Object State -eq "BLOCKED").Count -gt 0) { exit 2 }
if (@($resultArray | Where-Object State -eq "NOT RUN").Count -gt 0) { exit 3 }
exit 0
