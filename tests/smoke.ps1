[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsToParse = @(
    "scripts\detect-stack.ps1",
    "installer\install.ps1",
    "installer\doctor.ps1"
)

foreach ($relative in $scriptsToParse) {
    $path = Join-Path $repoRoot $relative
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell parse failure in $relative`: $($errors[0].Message)"
    }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-harness-smoke-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    Set-Content -LiteralPath (Join-Path $temp "sample.sln") -Value ""
    Set-Content -LiteralPath (Join-Path $temp "angular.json") -Value "{}"
    Set-Content -LiteralPath (Join-Path $temp "package.json") -Value '{"dependencies":{"mongodb":"latest"}}'

    $result = & (Join-Path $repoRoot "scripts\detect-stack.ps1") -Path $temp

    foreach ($expected in @("DotNet", "Angular", "MongoDb")) {
        if ($result.DetectedStacks -notcontains $expected) {
            throw "Expected stack '$expected' was not detected. Actual: $($result.DetectedStacks -join ', ')"
        }
    }

    Write-Host "PASS: PowerShell scripts parse successfully."
    Write-Host "PASS: Stack detector identified .NET, Angular, and MongoDB fixture signals."
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
