[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root "installer\install.ps1"
$temp = Join-Path ([IO.Path]::GetTempPath()) ("representative-projects-" + [guid]::NewGuid().ToString("N"))

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $global:LASTEXITCODE = 0
        $output = (& $Command @Arguments 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "$Command $($Arguments -join ' ') failed with exit $LASTEXITCODE. $output"
        }
        return $output
    } finally {
        Pop-Location
    }
}

function Install-Harness {
    param([Parameter(Mandatory)][string]$Target)

    $global:LASTEXITCODE = 0
    & $installer -TargetPath $Target -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph

    if ($LASTEXITCODE -ne 0) {
        throw "Harness installation/doctor failed for '$Target' with exit $LASTEXITCODE."
    }
}

function Assert-RepresentativeRun {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$ChangeType,
        [Parameter(Mandatory)][string[]]$ExpectedStacks,
        [Parameter(Mandatory)][string[]]$ExpectedCheckIds,
        [Parameter(Mandatory)][string]$ProposalId,
        [Parameter(Mandatory)][string[]]$ChangedFiles
    )

    $manifestPath = Join-Path $Target ".copilot-harness.json"
    $profilePath = Join-Path $Target ".copilot-harness.verify.json"
    $doctor = Join-Path $Target "scripts\doctor.ps1"
    $runner = Join-Path $Target "scripts\run-harness.ps1"

    foreach ($required in @($manifestPath, $profilePath, $doctor, $runner)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Representative install missing '$required'."
        }
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

    foreach ($stack in $ExpectedStacks) {
        if (@($manifest.detectedStacks) -notcontains $stack) {
            throw "Installer manifest did not record expected stack '$stack'."
        }
        if (@($profile.detectedStacks) -notcontains $stack) {
            throw "Verification profile did not record expected stack '$stack'."
        }
    }

    foreach ($id in $ExpectedCheckIds) {
        if (@($profile.checks | Where-Object id -eq $id).Count -ne 1) {
            throw "Generated verification profile missing expected check '$id'."
        }
    }

    $global:LASTEXITCODE = 0
    $doctorText = (& $doctor -TargetPath $Target -Json | Out-String)
    $doctorExit = $LASTEXITCODE
    if ($doctorExit -ne 0) {
        throw "Installed Doctor rejected representative '$ChangeType' project with exit $doctorExit."
    }

    $doctorResult = $doctorText | ConvertFrom-Json
    if (-not $doctorResult.Ready -or $doctorResult.Counts.Fail -ne 0) {
        throw "Installed Doctor did not report representative '$ChangeType' project ready."
    }

    $global:LASTEXITCODE = 0
    $runText = (& $runner -TargetPath $Target -ChangeType $ChangeType -Intent "validate representative $ChangeType project end to end" -ProposalId $ProposalId -ProposalSummary "representative $ChangeType validation candidate" -ChangedFiles $ChangedFiles -Json | Out-String)
    $runExit = $LASTEXITCODE

    if ($runExit -ne 0) {
        throw "Representative '$ChangeType' harness run failed with exit $runExit. $runText"
    }

    $run = $runText | ConvertFrom-Json
    if ($run.VerificationExitCode -ne 0) {
        throw "Representative '$ChangeType' run recorded verification exit $($run.VerificationExitCode)."
    }
    if ($run.MakerChecker.checker.decision -ne "ACCEPT") {
        throw "Representative '$ChangeType' checker did not ACCEPT."
    }
    if ($run.Lifecycle.state -ne "COMPLETE") {
        throw "Representative '$ChangeType' lifecycle did not reach COMPLETE."
    }

    foreach ($stack in $ExpectedStacks) {
        if (@($run.Context.DetectedStacks) -notcontains $stack) {
            throw "Runtime context lost expected stack '$stack'."
        }
    }

    $runDirectory = [string]$run.Evidence.RunDirectory
    foreach ($relative in @("context.json", "verification.json", "state.json", "maker-checker.json", "evidence.json", "summary.md")) {
        if (-not (Test-Path -LiteralPath (Join-Path $runDirectory $relative) -PathType Leaf)) {
            throw "Representative '$ChangeType' run missing durable evidence '$relative'."
        }
    }

    $verification = Get-Content -LiteralPath (Join-Path $runDirectory "verification.json") -Raw | ConvertFrom-Json
    if (-not $verification.Ready) {
        throw "Representative '$ChangeType' durable verification is not ready."
    }
    foreach ($id in $ExpectedCheckIds) {
        if (@($verification.Results | Where-Object { $_.Id -eq $id -and $_.State -eq "PASS" }).Count -ne 1) {
            throw "Representative '$ChangeType' verification did not PASS '$id'."
        }
    }

    $global:LASTEXITCODE = 0
    Write-Host "PASS: representative $ChangeType project completed install -> doctor -> verification -> checker -> lifecycle -> evidence."
}

try {
    if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw ".NET SDK is required for representative .NET validation."
    }
    if ($null -eq (Get-Command node -ErrorAction SilentlyContinue) -or $null -eq (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "Node.js and npm are required for representative Angular validation."
    }

    # Representative .NET repository: real SDK restore/build with a local VSTest target
    # so the fixture remains dependency-free and does not fetch a test framework package.
    $dotnet = Join-Path $temp "dotnet"
    New-Item -ItemType Directory -Path $dotnet -Force | Out-Null

    @'
<Project>
  <Import Project="Sdk.props" Sdk="Microsoft.NET.Sdk" />
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <Import Project="Sdk.targets" Sdk="Microsoft.NET.Sdk" />
  <Target Name="VSTest">
    <Message Text="Representative dependency-free VSTest target passed." Importance="high" />
  </Target>
</Project>
'@ | Set-Content -LiteralPath (Join-Path $dotnet "RepresentativeApp.csproj") -Encoding UTF8

    'Console.WriteLine("representative dotnet fixture");' |
        Set-Content -LiteralPath (Join-Path $dotnet "Program.cs") -Encoding UTF8

    Invoke-NativeChecked "dotnet" @("restore", ".\RepresentativeApp.csproj", "--ignore-failed-sources") $dotnet | Out-Null
    Install-Harness $dotnet
    Assert-RepresentativeRun -Target $dotnet -ChangeType "dotnet" -ExpectedStacks @("DotNet") -ExpectedCheckIds @("V1-DOTNET-BUILD", "V2-DOTNET-TEST") -ProposalId "representative-dotnet" -ChangedFiles @("RepresentativeApp.csproj", "Program.cs")

    # Representative Angular repository: Angular signals plus deterministic local
    # lint/test:ci scripts, without npm install or external dependencies.
    $angular = Join-Path $temp "angular"
    New-Item -ItemType Directory -Path (Join-Path $angular "tools") -Force | Out-Null

    @'
{
  "version": 1,
  "projects": {
    "representative-app": {
      "projectType": "application",
      "root": "",
      "sourceRoot": "src"
    }
  }
}
'@ | Set-Content -LiteralPath (Join-Path $angular "angular.json") -Encoding UTF8

    @'
{
  "name": "representative-angular-fixture",
  "private": true,
  "scripts": {
    "lint": "node tools/representative-check.mjs lint",
    "test:ci": "node tools/representative-check.mjs test"
  }
}
'@ | Set-Content -LiteralPath (Join-Path $angular "package.json") -Encoding UTF8

    @'
const mode = process.argv[2];
if (mode !== "lint" && mode !== "test") {
  console.error("unexpected representative check mode");
  process.exit(2);
}
console.log("representative angular " + mode + " passed");
'@ | Set-Content -LiteralPath (Join-Path $angular "tools\representative-check.mjs") -Encoding UTF8

    Install-Harness $angular
    Assert-RepresentativeRun -Target $angular -ChangeType "angular" -ExpectedStacks @("Angular") -ExpectedCheckIds @("V1-ANGULAR-LINT", "V2-ANGULAR-TEST") -ProposalId "representative-angular" -ChangedFiles @("angular.json", "package.json", "tools/representative-check.mjs")

    $global:LASTEXITCODE = 0
    Write-Host "PASS: representative .NET and Angular end-to-end validation completed."
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
