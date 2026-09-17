[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [ValidateSet("skip", "overwrite")]
    [string]$ConflictMode = "skip",

    [ValidateSet("commands", "skills")]
    [string]$SpecKitLayout = "commands",

    [string[]]$SpecKitExtensions = @("git", "bug", "assess"),

    [string]$CodeGraphVersion,

    [switch]$SkipSpecKit,
    [switch]$SkipSpecKitExtensions,
    [switch]$SkipCodeGraph,
    [switch]$SkipCodeGraphInit,
    [switch]$KeepCodeGraphTelemetry,
    [switch]$SkipDoctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$detectScript = Join-Path $harnessRoot "scripts\detect-stack.ps1"
$doctorScript = Join-Path $PSScriptRoot "doctor.ps1"
$codeGraphScript = Join-Path $harnessRoot "scripts\setup-codegraph.ps1"
$specKitRepository = "https://github.com/github/spec-kit"
$codeGraphRepository = "https://github.com/colbymchenry/codegraph"

function Write-Step([string]$Message) { Write-Host "==> $Message" }

function Copy-HarnessFile {
    param([Parameter(Mandatory)][string]$SourceRelativePath,[Parameter(Mandatory)][string]$DestinationRelativePath)
    $source = Join-Path $harnessRoot $SourceRelativePath
    $destination = Join-Path $targetRoot $DestinationRelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Harness source file not found: $source" }
    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        if ($PSCmdlet.ShouldProcess($destinationDirectory, "Create directory")) { New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null }
    }
    if ((Test-Path -LiteralPath $destination -PathType Leaf) -and $ConflictMode -eq "skip") { Write-Warning "Skipping existing file: $DestinationRelativePath"; return "skipped" }
    if ($PSCmdlet.ShouldProcess($destination, "Install harness file")) { Copy-Item -LiteralPath $source -Destination $destination -Force }
    return "installed"
}

function Invoke-Specify {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & specify @Arguments
    if ($LASTEXITCODE -ne 0) { throw "specify $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
}

Write-Step "Detecting repository stack"
$stack = & $detectScript -Path $targetRoot
$detectedStacks = @($stack.DetectedStacks)
if ($detectedStacks.Count -eq 0) { Write-Host "No known application stack detected; installing base harness only." } else { Write-Host ("Detected: " + ($detectedStacks -join ", ")) }

$specKitInitialized = $false
$extensionsInstalled = @()
if (-not $SkipSpecKit) {
    $specify = Get-Command specify -ErrorAction SilentlyContinue
    $specKitMarker = Join-Path $targetRoot ".specify"
    if ($null -eq $specify) {
        Write-Warning "'specify' was not found. GitHub Spec Kit bootstrap cannot run. Install specify-cli from $specKitRepository and rerun this installer."
    } else {
        Push-Location $targetRoot
        try {
            if (Test-Path -LiteralPath $specKitMarker) { Write-Host "GitHub Spec Kit already appears initialized; leaving generated core workflow files unchanged." }
            else {
                Write-Step "Initializing official github/spec-kit with Copilot integration ($SpecKitLayout layout)"
                if ($PSCmdlet.ShouldProcess($targetRoot, "Run official github/spec-kit specify init")) {
                    if ($SpecKitLayout -eq "commands") { Invoke-Specify @("init", ".", "--here", "--integration", "copilot", "--integration-options=--commands", "--force") }
                    else { Invoke-Specify @("init", ".", "--here", "--integration", "copilot", "--force") }
                    $specKitInitialized = $true
                }
            }
            if (-not $SkipSpecKitExtensions) {
                foreach ($extension in $SpecKitExtensions) {
                    if ([string]::IsNullOrWhiteSpace($extension)) { continue }
                    Write-Step "Ensuring Spec Kit extension '$extension' is installed"
                    if ($PSCmdlet.ShouldProcess($targetRoot, "Install Spec Kit extension $extension")) { Invoke-Specify @("extension", "add", $extension); $extensionsInstalled += $extension }
                }
            }
        } finally { Pop-Location }
    }
}

$codeGraphConfigured = $false
if (-not $SkipCodeGraph) {
    Write-Step "Installing and initializing official CodeGraph"
    $codeGraphArgs = @{ TargetPath = $targetRoot }
    if (-not [string]::IsNullOrWhiteSpace($CodeGraphVersion)) { $codeGraphArgs.Version = $CodeGraphVersion }
    if ($SkipCodeGraphInit) { $codeGraphArgs.SkipInit = $true }
    if ($KeepCodeGraphTelemetry) { $codeGraphArgs.KeepTelemetry = $true }
    & $codeGraphScript @codeGraphArgs
    if ($LASTEXITCODE -ne 0) { throw "CodeGraph bootstrap failed with exit code $LASTEXITCODE." }
    $codeGraphConfigured = $true
}

Write-Step "Installing repository-native Copilot harness"
$results = [ordered]@{}
$files = @(
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
    "scripts\policy-check.ps1",
    "scripts\verify.ps1",
    "scripts\setup-codegraph.ps1",
    "scripts\context.ps1",
    "scripts\record-evidence.ps1",
    "scripts\run-harness.ps1"
)
foreach ($file in $files) {
    $display = $file -replace "\","/"
    $results[$display] = Copy-HarnessFile $file $file
}
if ($stack.Signals.DotNet) { $results[".github/instructions/dotnet.instructions.md"] = Copy-HarnessFile ".github\instructions\dotnet.instructions.md" ".github\instructions\dotnet.instructions.md" }
if ($stack.Signals.Angular) { $results[".github/instructions/angular.instructions.md"] = Copy-HarnessFile ".github\instructions\angular.instructions.md" ".github\instructions\angular.instructions.md" }
if ($stack.Signals.SqlServer -or $stack.Signals.MongoDb -or $stack.Signals.Snowflake -or $stack.Signals.Parquet) { $results[".github/instructions/data.instructions.md"] = Copy-HarnessFile ".github\instructions\data.instructions.md" ".github\instructions\data.instructions.md" }

$versionFile = Join-Path $harnessRoot "VERSION"
$harnessVersion = if (Test-Path -LiteralPath $versionFile) { (Get-Content -LiteralPath $versionFile -Raw).Trim() } else { "unknown" }
$manifestPath = Join-Path $targetRoot ".copilot-harness.json"
$manifest = [ordered]@{
    harnessVersion = $harnessVersion
    installedAtUtc = [DateTime]::UtcNow.ToString("o")
    detectedStacks = $detectedStacks
    conflictMode = $ConflictMode
    specKit = [ordered]@{ repository = $specKitRepository; requested = (-not $SkipSpecKit); layout = $SpecKitLayout; initializedThisRun = $specKitInitialized; requestedExtensions = @($SpecKitExtensions); installedThisRun = @($extensionsInstalled) }
    codeGraph = [ordered]@{ repository = $codeGraphRepository; requested = (-not $SkipCodeGraph); configuredThisRun = $codeGraphConfigured; requestedVersion = $CodeGraphVersion; projectInitRequested = (-not $SkipCodeGraphInit); telemetryEnabledByHarness = [bool]$KeepCodeGraphTelemetry; mode = "cli-only" }
    policy = [ordered]@{ gate = "docs/POLICY-GATE.md"; evaluator = "scripts/policy-check.ps1" }
    verification = [ordered]@{ contract = "docs/VERIFICATION-CONTRACT.md"; runner = "scripts/verify.ps1" }
    context = [ordered]@{ builder = "scripts/context.ps1"; orchestrator = "scripts/run-harness.ps1"; evidenceRecorder = "scripts/record-evidence.ps1"; contract = "docs/CONTEXT-EVIDENCE-ENGINE.md" }
    releaseTesting = [ordered]@{ contract = "docs/RELEASE-TESTING.md"; template = "docs/releases/TESTING-TEMPLATE.md" }
}
if ($PSCmdlet.ShouldProcess($manifestPath, "Write harness manifest")) { $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 }

Write-Step "Installation summary"
foreach ($entry in $results.GetEnumerator()) { Write-Host ("{0,-55} {1}" -f $entry.Key, $entry.Value) }
Write-Host "Spec Kit source of truth: $specKitRepository"
Write-Host "Spec Kit Copilot layout: $SpecKitLayout"
if (-not $SkipSpecKitExtensions) { Write-Host ("Spec Kit extensions requested: " + ($SpecKitExtensions -join ", ")) }
Write-Host "CodeGraph source of truth: $codeGraphRepository"
Write-Host "CodeGraph integration mode: CLI only (no MCP/marketplace integration)"
Write-Host "Context builder: scripts/context.ps1"
Write-Host "Harness orchestrator: scripts/run-harness.ps1"
Write-Host "Evidence recorder: scripts/record-evidence.ps1"
Write-Host "Policy gate: docs/POLICY-GATE.md"
Write-Host "Verification runner: scripts/verify.ps1"
Write-Host "Release testing contract: docs/RELEASE-TESTING.md"

if (-not $SkipDoctor -and (Test-Path -LiteralPath $doctorScript)) {
    Write-Step "Running harness doctor"
    & $doctorScript -TargetPath $targetRoot -ExpectedSpecKitLayout $SpecKitLayout -ExpectedSpecKitExtensions $SpecKitExtensions
    if ($LASTEXITCODE -ne 0) { throw "Harness installation completed, but doctor reported blocking failures." }
}
Write-Host "Copilot Harness bootstrap complete."
