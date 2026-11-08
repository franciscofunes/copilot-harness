[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$scriptRoots = @("scripts", "installer", "tests")
$jsonRoots = @("config", "evals", "installer", "skills")

$scripts = @(
    foreach ($folder in $scriptRoots) {
        Get-ChildItem -LiteralPath (Join-Path $root $folder) -Recurse -File -Filter "*.ps1"
    }
)
$jsonFiles = @(
    foreach ($folder in $jsonRoots) {
        Get-ChildItem -LiteralPath (Join-Path $root $folder) -Recurse -File -Filter "*.json"
    }
)

if ($scripts.Count -lt 25 -or $jsonFiles.Count -lt 5) {
    throw "Unexpectedly small syntax-audit inventory: PowerShell=$($scripts.Count), JSON=$($jsonFiles.Count)"
}

foreach ($file in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell parse failure in $($file.FullName): $($parseErrors[0].Message)"
    }
}

foreach ($file in $jsonFiles) {
    try {
        $null = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    } catch {
        throw "Invalid JSON in $($file.FullName): $($_.Exception.Message)"
    }
}

Write-Host "PASS: Parsed $($scripts.Count) PowerShell scripts and $($jsonFiles.Count) JSON files."
