[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$setupPath = Join-Path $repoRoot "scripts\setup-codegraph.ps1"
$installerPath = Join-Path $repoRoot "installer\install.ps1"
$docsPath = Join-Path $repoRoot "docs\CODEGRAPH.md"

foreach ($path in @($setupPath, $installerPath)) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) { throw "PowerShell parse failure in $path`: $($errors[0].Message)" }
}

$setup = Get-Content -LiteralPath $setupPath -Raw
$installer = Get-Content -LiteralPath $installerPath -Raw
$docs = Get-Content -LiteralPath $docsPath -Raw

$requiredSource = "https://github.com/colbymchenry/codegraph"
if ($setup -notmatch [regex]::Escape($requiredSource)) { throw "CodeGraph bootstrap must pin the upstream repository." }
if ($installer -notmatch [regex]::Escape($requiredSource)) { throw "Harness manifest/install flow must record the upstream CodeGraph repository." }
if ($docs -notmatch [regex]::Escape($requiredSource)) { throw "CodeGraph documentation must name the upstream repository." }

if ($setup -match "Invoke-Expression|\biex\b") { throw "CodeGraph bootstrap must not pipe the remote installer into Invoke-Expression." }
if ($setup -match "codegraph\s+install") { throw "CodeGraph bootstrap must not configure MCP/agent integrations." }
if ($setup -notmatch "telemetry off") { throw "CodeGraph telemetry must be disabled by default." }
if ($setup -notmatch "codegraphCommand init") { throw "CodeGraph project initialization must be part of the bootstrap." }
if ($installer -notmatch "SkipCodeGraph") { throw "Harness installer must provide an explicit CodeGraph opt-out." }
if ($installer -notmatch "CodeGraphVersion") { throw "Harness installer must support a reviewed/pinned CodeGraph release." }

Write-Host "PASS: CodeGraph scripts parse successfully."
Write-Host "PASS: CodeGraph source is constrained to colbymchenry/codegraph."
Write-Host "PASS: CodeGraph bootstrap remains CLI-only and avoids remote Invoke-Expression."
Write-Host "PASS: Telemetry-off default, project init, opt-out, and version pin contracts are present."
exit 0
