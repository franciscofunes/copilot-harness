[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $repoRoot "scripts\verify.ps1"
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
    if ($errors.Count -gt 0) { throw "PowerShell parse failure in $relative`: $($errors[0].Message)" }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-harness-smoke-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

function Assert-PolicyExit {
    param([string]$ExpectedClass,[string]$ExpectedDecision,[int]$ExpectedExit,[hashtable]$Arguments)
    $jsonText = (& (Join-Path $repoRoot "scripts\policy-check.ps1") @Arguments -Json | Out-String)
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExpectedExit) { throw "Policy exit mismatch. Expected $ExpectedExit, got $actualExit." }
    $result = $jsonText | ConvertFrom-Json
    if ($result.Classification -ne $ExpectedClass -or $result.Decision -ne $ExpectedDecision) { throw "Policy result mismatch." }
}

function New-VerifyFixture {
    param([string]$Name)
    $path = Join-Path $temp $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $path "README.md") -Value "fixture"
    Push-Location $path
    try { & git init --quiet; if ($LASTEXITCODE -ne 0) { throw "Failed to initialize Git fixture." } } finally { Pop-Location }
    return $path
}

function Invoke-VerifyJson {
    param([string]$Target,[string]$ChangeType="docs",[string]$ProfilePath)
    if ($ProfilePath) { $text = (& $verifyScript -TargetPath $Target -ChangeType $ChangeType -ProfilePath $ProfilePath -Json | Out-String) }
    else { $text = (& $verifyScript -TargetPath $Target -ChangeType $ChangeType -Json | Out-String) }
    $verifyExit = $LASTEXITCODE
    return [pscustomobject]@{ Exit=$verifyExit; Data=($text | ConvertFrom-Json) }
}

function Write-Profile {
    param([string]$Path,[object]$Profile)
    $Profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

try {
    Set-Content -LiteralPath (Join-Path $temp "sample.sln") -Value ""
    Set-Content -LiteralPath (Join-Path $temp "angular.json") -Value "{}"
    Set-Content -LiteralPath (Join-Path $temp "package.json") -Value '{"dependencies":{"mongodb":"latest"}}'
    $result = & (Join-Path $repoRoot "scripts\detect-stack.ps1") -Path $temp
    foreach ($expected in @("DotNet", "Angular", "MongoDb")) { if ($result.DetectedStacks -notcontains $expected) { throw "Expected stack '$expected' was not detected." } }

    Assert-PolicyExit "A0" "ALLOW" 0 @{ ActionKind = "read" }
    Assert-PolicyExit "A3" "REQUIRE_INTENT" 20 @{ ActionKind = "remote-mutate"; Environment = "shared" }
    Assert-PolicyExit "A3" "ALLOW" 0 @{ ActionKind = "remote-mutate"; Environment = "shared"; ExplicitIntent = $true }
    Assert-PolicyExit "A4" "REQUIRE_APPROVAL" 30 @{ ActionKind = "destructive"; Environment = "production" }
    Assert-PolicyExit "A4" "ALLOW" 0 @{ ActionKind = "destructive"; Environment = "production"; ImmediateApproval = $true }

    $docsFixture = New-VerifyFixture "docs"
    $docs = Invoke-VerifyJson $docsFixture
    if ($docs.Exit -ne 0 -or -not $docs.Data.Ready) { throw "Documentation fallback fixture should be ready." }

    $profileFixture = New-VerifyFixture "profile-pass"
    $profilePath = Join-Path $profileFixture ".copilot-harness.verify.json"
    Write-Profile $profilePath ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="V1-PROFILE-PASS"; name="Profile pass"; changeTypes=@("docs"); verificationLevel="V1"; policyClass="A1"; command="powershell"; args=@("-NoProfile","-Command","exit 0"); required=$true }) })
    $pass = Invoke-VerifyJson $profileFixture
    if ($pass.Exit -ne 0 -or -not $pass.Data.Ready -or @($pass.Data.Results | Where-Object { $_.Id -eq "V1-PROFILE-PASS" -and $_.State -eq "PASS" }).Count -ne 1) { throw "Allowed A1 profile should execute and PASS." }

    $explicitFixture = New-VerifyFixture "profile-explicit"
    $explicitPath = Join-Path $temp "explicit-profile.json"
    Write-Profile $explicitPath ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="V1-EXPLICIT"; name="Explicit profile"; changeTypes=@("dotnet"); verificationLevel="V1"; policyClass="A1"; command="powershell"; args=@("-NoProfile","-Command","exit 0") }) })
    $explicit = Invoke-VerifyJson $explicitFixture "docs" $explicitPath
    if ($explicit.Exit -ne 0 -or @($explicit.Data.Results | Where-Object { $_.Id -eq "V1-EXPLICIT" -and $_.State -eq "SKIPPED" }).Count -ne 1) { throw "Explicit profile should load and nonmatching change type should SKIP." }

    $failFixture = New-VerifyFixture "profile-fail"
    Write-Profile (Join-Path $failFixture ".copilot-harness.verify.json") ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="V2-EXPECTED-FAIL"; name="Expected child failure"; changeTypes=@("all"); verificationLevel="V2"; policyClass="A1"; command="powershell"; args=@("-NoProfile","-Command","exit 7") }) })
    $failed = Invoke-VerifyJson $failFixture
    if ($failed.Exit -ne 1 -or @($failed.Data.Results | Where-Object { $_.Id -eq "V2-EXPECTED-FAIL" -and $_.State -eq "FAIL" }).Count -ne 1) { throw "Failed child command must produce FAIL/exit 1." }

    foreach ($policyClass in @("A2","A3","A4")) {
        $blockedFixture = New-VerifyFixture ("profile-" + $policyClass.ToLowerInvariant())
        Write-Profile (Join-Path $blockedFixture ".copilot-harness.verify.json") ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="POLICY-$policyClass"; name="Blocked $policyClass"; changeTypes=@("all"); verificationLevel="V1"; policyClass=$policyClass; command="powershell"; args=@("-NoProfile","-Command","exit 0") }) })
        $blocked = Invoke-VerifyJson $blockedFixture
        if ($blocked.Exit -ne 2 -or @($blocked.Data.Results | Where-Object { $_.Id -eq "POLICY-$policyClass" -and $_.State -eq "BLOCKED" }).Count -ne 1) { throw "$policyClass profile action must be BLOCKED/exit 2." }
    }

    $allowFixture = New-VerifyFixture "profile-allowlist"
    Write-Profile (Join-Path $allowFixture ".copilot-harness.verify.json") ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="ALLOWLIST"; name="Disallowed executable"; changeTypes=@("all"); verificationLevel="V1"; policyClass="A1"; command="cmd"; args=@("/c","exit 0") }) })
    $allow = Invoke-VerifyJson $allowFixture
    if ($allow.Exit -ne 2 -or @($allow.Data.Results | Where-Object { $_.Id -eq "ALLOWLIST" -and $_.State -eq "BLOCKED" }).Count -ne 1) { throw "Non-allowlisted executable must be BLOCKED." }

    $badJsonFixture = New-VerifyFixture "profile-bad-json"
    Set-Content -LiteralPath (Join-Path $badJsonFixture ".copilot-harness.verify.json") -Value '{bad json'
    $badJson = Invoke-VerifyJson $badJsonFixture
    if ($badJson.Exit -ne 1 -or @($badJson.Data.Results | Where-Object { $_.Id -eq "PROFILE" -and $_.State -eq "FAIL" }).Count -lt 1) { throw "Malformed profile must FAIL closed." }

    $badSchemaFixture = New-VerifyFixture "profile-bad-schema"
    Write-Profile (Join-Path $badSchemaFixture ".copilot-harness.verify.json") ([ordered]@{ schemaVersion=999; checks=@() })
    $badSchema = Invoke-VerifyJson $badSchemaFixture
    if ($badSchema.Exit -ne 1) { throw "Unsupported schema must FAIL closed." }

    $missingFixture = New-VerifyFixture "profile-missing-fields"
    Write-Profile (Join-Path $missingFixture ".copilot-harness.verify.json") ([ordered]@{ schemaVersion=1; checks=@([ordered]@{ id="MISSING"; name="Missing command"; verificationLevel="V1"; policyClass="A1" }) })
    $missing = Invoke-VerifyJson $missingFixture
    if ($missing.Exit -ne 1) { throw "Missing required profile fields must FAIL closed." }

    Write-Host "PASS: PowerShell scripts parse successfully."
    Write-Host "PASS: Stack detector regression fixture passed."
    Write-Host "PASS: Policy evaluator enforces A0, A3, and A4 decisions."
    Write-Host "PASS: Generic documentation verification fallback is ready."
    Write-Host "PASS: Verification profile discovery and explicit path selection work."
    Write-Host "PASS: A1 profile execution, command failure, and change-type filtering are deterministic."
    Write-Host "PASS: A2/A3/A4 profile actions and non-allowlisted executables fail closed."
    Write-Host "PASS: Malformed, unsupported, and incomplete profiles fail closed."

    # Expected negative fixtures intentionally leave LASTEXITCODE non-zero.
    # A successful smoke suite must explicitly return success to the CI runner.
    $global:LASTEXITCODE = 0
    exit 0
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
