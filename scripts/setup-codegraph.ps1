[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [string]$Version,

    [switch]$SkipInstall,

    [switch]$SkipInit,

    [switch]$KeepTelemetry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repository = "colbymchenry/codegraph"
$repositoryUrl = "https://github.com/$repository"
$installerUrl = "https://raw.githubusercontent.com/$repository/main/install.ps1"
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path

if ($env:OS -ne "Windows_NT") {
    throw "The Copilot Harness CodeGraph bootstrap currently supports Windows only."
}

function Resolve-CodeGraphCommand {
    $command = Get-Command codegraph -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    $bundled = Join-Path $env:LOCALAPPDATA "codegraph\current\bin\codegraph.cmd"
    if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
    return $null
}

$codegraphCommand = Resolve-CodeGraphCommand

if (-not $SkipInstall -and $null -eq $codegraphCommand) {
    $tempInstaller = Join-Path $env:TEMP ("codegraph-install-" + [guid]::NewGuid().ToString("N") + ".ps1")
    try {
        Write-Host "==> Downloading CodeGraph installer from $installerUrl"
        Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstaller
        $installerText = Get-Content -LiteralPath $tempInstaller -Raw
        if ($installerText -notmatch [regex]::Escape("$repo = 'colbymchenry/codegraph'")) {
            throw "Downloaded installer did not identify the required repository $repository. Refusing to execute it."
        }

        $previousVersion = $env:CODEGRAPH_VERSION
        try {
            if (-not [string]::IsNullOrWhiteSpace($Version)) {
                $env:CODEGRAPH_VERSION = $Version
            }
            if ($PSCmdlet.ShouldProcess($targetRoot, "Install CodeGraph from $repositoryUrl")) {
                & $tempInstaller
            }
        } finally {
            $env:CODEGRAPH_VERSION = $previousVersion
        }
    } finally {
        Remove-Item -LiteralPath $tempInstaller -Force -ErrorAction SilentlyContinue
    }

    $codegraphCommand = Resolve-CodeGraphCommand
}

if ($null -eq $codegraphCommand) {
    throw "CodeGraph CLI is not available. Install it from $repositoryUrl and rerun."
}

Write-Host "==> CodeGraph command: $codegraphCommand"
& $codegraphCommand --version
if ($LASTEXITCODE -ne 0) { throw "codegraph --version failed with exit code $LASTEXITCODE." }

if (-not $KeepTelemetry) {
    if ($PSCmdlet.ShouldProcess($targetRoot, "Disable CodeGraph telemetry")) {
        & $codegraphCommand telemetry off
        if ($LASTEXITCODE -ne 0) { throw "codegraph telemetry off failed with exit code $LASTEXITCODE." }
    }
}

if (-not $SkipInit) {
    $marker = Join-Path $targetRoot ".codegraph"
    if (Test-Path -LiteralPath $marker) {
        Write-Host "CodeGraph is already initialized in this repository; leaving the existing index in place."
    } elseif ($PSCmdlet.ShouldProcess($targetRoot, "Initialize local CodeGraph index")) {
        Push-Location $targetRoot
        try {
            & $codegraphCommand init
            if ($LASTEXITCODE -ne 0) { throw "codegraph init failed with exit code $LASTEXITCODE." }
        } finally {
            Pop-Location
        }
    }
}

Write-Host "CodeGraph source of truth: $repositoryUrl"
Write-Host "CodeGraph is installed in CLI-only mode by the harness; no MCP or marketplace integration is configured."
