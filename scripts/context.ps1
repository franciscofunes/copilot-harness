[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [ValidateSet("auto","docs","powershell","dotnet","angular","api","data","platform","security","release")]
    [string]$ChangeType = "auto",
    [string]$BaseRef,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$stack = & $detectScript -Path $targetRoot

function Get-GitChangedFiles {
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) { return @() }
    Push-Location $targetRoot
    try {
        & git rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) { return @() }
        $args = @("diff","--name-only")
        if (-not [string]::IsNullOrWhiteSpace($BaseRef)) { $args += "$BaseRef...HEAD" }
        $output = (& git @args 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($output)) {
            $output = (& git status --short 2>$null | ForEach-Object { $_.Substring(3) } | Out-String).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($output)) { return @() }
        return @($output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    } finally { Pop-Location }
}

function Resolve-EffectiveChangeType {
    if ($ChangeType -ne "auto") { return $ChangeType }
    $changed = Get-GitChangedFiles
    if ($changed.Count -gt 0) {
        if (@($changed | Where-Object { $_ -match '\.(md|txt)$' }).Count -eq $changed.Count) { return "docs" }
        if (@($changed | Where-Object { $_ -match '\.ps1$' }).Count -gt 0) { return "powershell" }
        if (@($changed | Where-Object { $_ -match '\.(cs|csproj|sln|slnx)$' }).Count -gt 0) { return "dotnet" }
        if (@($changed | Where-Object { $_ -match '\.(ts|tsx|js|jsx)$|angular\.json|package\.json' }).Count -gt 0) { return "angular" }
        if (@($changed | Where-Object { $_ -match '\.(sql|sqlproj|parquet)$' }).Count -gt 0) { return "data" }
    }
    if ($stack.Signals.DotNet) { return "dotnet" }
    if ($stack.Signals.Angular) { return "angular" }
    return "docs"
}

function Get-RelevantInstructions {
    param([string]$EffectiveType)
    $files = New-Object System.Collections.Generic.List[string]
    $global = Join-Path $targetRoot ".github\copilot-instructions.md"
    if (Test-Path -LiteralPath $global -PathType Leaf) { [void]$files.Add(".github/copilot-instructions.md") }
    $map = @{ dotnet = ".github/instructions/dotnet.instructions.md"; angular = ".github/instructions/angular.instructions.md"; data = ".github/instructions/data.instructions.md" }
    if ($map.ContainsKey($EffectiveType)) {
        $candidate = Join-Path $targetRoot ($map[$EffectiveType] -replace "/","\")
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { [void]$files.Add($map[$EffectiveType]) }
    }
    foreach ($common in @(".github/instructions/tests.instructions.md",".github/instructions/policy-verification.instructions.md")) {
        $candidate = Join-Path $targetRoot ($common -replace "/","\")
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { [void]$files.Add($common) }
    }
    return @($files.ToArray() | Select-Object -Unique)
}

function Get-CodeGraphContext {
    $codegraph = Get-Command codegraph -ErrorAction SilentlyContinue
    $marker = Join-Path $targetRoot ".codegraph"
    if ($null -eq $codegraph -or -not (Test-Path -LiteralPath $marker)) {
        return [pscustomobject]@{ Available=$false; Summary="CodeGraph CLI/index unavailable"; Commands=@() }
    }
    return [pscustomobject]@{ Available=$true; Summary="Local CodeGraph index available for semantic exploration"; Commands=@("codegraph explore","codegraph impact <symbol>","codegraph affected <symbol>") }
}

$effectiveType = Resolve-EffectiveChangeType
$changedFiles = Get-GitChangedFiles
$instructions = Get-RelevantInstructions $effectiveType
$profilePath = Join-Path $targetRoot ".copilot-harness.verify.json"
$profile = if (Test-Path -LiteralPath $profilePath -PathType Leaf) { ".copilot-harness.verify.json" } else { $null }
$codeGraph = Get-CodeGraphContext
$result = [pscustomobject]@{
    Target = $targetRoot
    ChangeType = $effectiveType
    DetectedStacks = @($stack.DetectedStacks)
    ChangedFiles = @($changedFiles)
    RelevantInstructions = @($instructions)
    VerificationProfile = $profile
    CodeGraph = $codeGraph
    Policy = [pscustomobject]@{ DefaultAutomaticCeiling="A2"; Gate="scripts/policy-check.ps1" }
    Verification = [pscustomobject]@{ Runner="scripts/verify.ps1"; EvidenceStates=@("PASS","FAIL","BLOCKED","SKIPPED","NOT RUN") }
}
if ($Json) { $result | ConvertTo-Json -Depth 7 } else {
    Write-Host "Copilot Harness Context"
    Write-Host "Target: $targetRoot"
    Write-Host "Change type: $effectiveType"
    Write-Host "Stacks: $(if ($result.DetectedStacks.Count) { $result.DetectedStacks -join ', ' } else { 'none' })"
    Write-Host "Changed files: $($result.ChangedFiles.Count)"
    Write-Host "Instructions: $(if ($result.RelevantInstructions.Count) { $result.RelevantInstructions -join ', ' } else { 'none' })"
    Write-Host "Verification profile: $(if ($profile) { $profile } else { 'none' })"
    Write-Host "CodeGraph: $($codeGraph.Summary)"
}
