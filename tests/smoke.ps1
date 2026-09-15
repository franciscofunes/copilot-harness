[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsToParse = @(
    "scripts\detect-stack.ps1",
    "scripts\policy-check.ps1",
    "scripts\verify.ps1",
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

function Assert-PolicyExit {
    param(
        [string]$ExpectedClass,
        [string]$ExpectedDecision,
        [int]$ExpectedExit,
        [hashtable]$Arguments
    )

    $policyScript = Join-Path $repoRoot "scripts\policy-check.ps1"
    $jsonText = (& $policyScript @Arguments -Json | Out-String)
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExpectedExit) {
        throw "Policy exit mismatch. Expected $ExpectedExit, got $actualExit."
    }

    $result = $jsonText | ConvertFrom-Json
    if ($result.Classification -ne $ExpectedClass -or $result.Decision -ne $ExpectedDecision) {
        throw "Policy result mismatch. Expected $ExpectedClass/$ExpectedDecision, got $($result.Classification)/$($result.Decision)."
    }
}

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

    Assert-PolicyExit "A0" "ALLOW" 0 @{ ActionKind = "read" }
    Assert-PolicyExit "A3" "REQUIRE_INTENT" 20 @{ ActionKind = "remote-mutate"; Environment = "shared" }
    Assert-PolicyExit "A3" "ALLOW" 0 @{ ActionKind = "remote-mutate"; Environment = "shared"; ExplicitIntent = $true }
    Assert-PolicyExit "A4" "REQUIRE_APPROVAL" 30 @{ ActionKind = "destructive"; Environment = "production" }
    Assert-PolicyExit "A4" "ALLOW" 0 @{ ActionKind = "destructive"; Environment = "production"; ImmediateApproval = $true }

    $verifyFixture = Join-Path $temp "verify-fixture"
    New-Item -ItemType Directory -Path $verifyFixture -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $verifyFixture "README.md") -Value "fixture"

    Push-Location $verifyFixture
    try {
        & git init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize verification fixture as a Git repository."
        }
    } finally {
        Pop-Location
    }

    $verifyJson = (& (Join-Path $repoRoot "scripts\verify.ps1") -TargetPath $verifyFixture -ChangeType docs -Json | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Documentation verification fixture should complete without blocking evidence."
    }
    $verify = $verifyJson | ConvertFrom-Json
    if (-not $verify.Ready) {
        throw "Documentation verification fixture should be ready."
    }

    Write-Host "PASS: PowerShell scripts parse successfully."
    Write-Host "PASS: Stack detector identified .NET, Angular, and MongoDB fixture signals."
    Write-Host "PASS: Policy evaluator enforces A0, A3, and A4 decisions."
    Write-Host "PASS: Verification runner emits a ready result for a documentation-only fixture."
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
