[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [string]$OutputPath,

    [switch]$Force,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$stack = & $detectScript -Path $targetRoot

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $targetRoot ".copilot-harness.verify.json"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $targetRoot $OutputPath
}

if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    throw "Verification profile already exists at '$OutputPath'. Use -Force only when replacement is intentional."
}

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check {
    param([string]$Id,[string]$Name,[string[]]$ChangeTypes,[string]$Level,[string]$Command,[string[]]$Arguments)
    [void]$checks.Add([ordered]@{
        id = $Id
        name = $Name
        changeTypes = $ChangeTypes
        verificationLevel = $Level
        policyClass = "A1"
        command = $Command
        args = $Arguments
        required = $true
    })
}

if ($stack.Signals.DotNet) {
    Add-Check "V1-DOTNET-BUILD" ".NET build" @("dotnet","api") "V1" "dotnet" @("build","--no-restore")
    Add-Check "V2-DOTNET-TEST" ".NET tests" @("dotnet","api") "V2" "dotnet" @("test","--no-build","--no-restore")
}

if ($stack.Signals.Angular) {
    $packagePath = Join-Path $targetRoot "package.json"
    if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
        try {
            $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
            $scriptNames = if ($null -ne $package.scripts) { @($package.scripts.PSObject.Properties.Name) } else { @() }
            if ($scriptNames -contains "lint") { Add-Check "V1-ANGULAR-LINT" "Angular lint" @("angular") "V1" "npm" @("run","lint","--","--no-fix") }
            if ($scriptNames -contains "test:ci") { Add-Check "V2-ANGULAR-TEST" "Angular CI tests" @("angular") "V2" "npm" @("run","test:ci") }
        } catch {
            throw "package.json could not be parsed while generating the verification profile: $($_.Exception.Message)"
        }
    }
}

# Data/platform signals are recorded as recommendations rather than executable checks.
# The generator must never guess credentials, targets, databases, warehouses, environments,
# remote mutations, or production-safe command lines.
$recommendations = New-Object System.Collections.Generic.List[string]
if ($stack.Signals.SqlServer) { [void]$recommendations.Add("SQL Server detected: add reviewed local/read-only verification only after the repository's safe target and command are known.") }
if ($stack.Signals.MongoDb) { [void]$recommendations.Add("MongoDB detected: add reviewed local/read-only verification only after the repository's safe target and command are known.") }
if ($stack.Signals.Snowflake) { [void]$recommendations.Add("Snowflake detected: keep remote/shared verification outside automatic A1 execution unless a deterministic read-only adapter is defined.") }
if ($stack.Signals.Parquet) { [void]$recommendations.Add("Parquet detected: add a repository-specific local schema/content validation command when available.") }
if ($stack.Signals.AzureDevOps) { [void]$recommendations.Add("Azure DevOps detected: pipeline/deployment actions remain outside the generated A1 profile.") }
if ($stack.Signals.GitHubActions) { [void]$recommendations.Add("GitHub Actions detected: remote workflow mutations/runs are not generated as A1 checks.") }
if ($stack.Signals.JFrog) { [void]$recommendations.Add("JFrog detected: remote artifact/compliance operations require their separately authorized workflow.") }

$profile = [ordered]@{
    schemaVersion = 1
    generatedBy = "copilot-harness"
    detectedStacks = @($stack.DetectedStacks)
    checks = @($checks.ToArray())
    recommendations = @($recommendations.ToArray())
}

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$result = [pscustomobject]@{
    Target = $targetRoot
    OutputPath = $OutputPath
    DetectedStacks = @($stack.DetectedStacks)
    GeneratedChecks = $checks.Count
    Recommendations = $recommendations.Count
}

if ($Json) { $result | ConvertTo-Json -Depth 5 } else {
    Write-Host "Generated verification profile: $OutputPath"
    Write-Host "Detected stacks: $(@($stack.DetectedStacks) -join ', ')"
    Write-Host "Executable A1 checks: $($checks.Count)"
    Write-Host "Review recommendations: $($recommendations.Count)"
}
