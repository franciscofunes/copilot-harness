[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root "installer\install.ps1"
$temp = Join-Path ([IO.Path]::GetTempPath()) ("doctor-readiness-" + [guid]::NewGuid().ToString("N"))

function Invoke-DoctorJson {
    param([string]$Target)

    $doctor = Join-Path $Target "scripts\doctor.ps1"
    if (-not (Test-Path -LiteralPath $doctor -PathType Leaf)) {
        throw "Installed doctor runtime not found: $doctor"
    }

    $global:LASTEXITCODE = 0
    $text = (& $doctor -TargetPath $Target -Json | Out-String)
    $exitCode = $LASTEXITCODE
    $data = $text | ConvertFrom-Json

    return [pscustomobject]@{
        Exit = $exitCode
        Data = $data
    }
}

try {
    $target = Join-Path $temp "fresh"
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    $global:LASTEXITCODE = 0
    & $installer -TargetPath $target -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor
    if ($LASTEXITCODE -ne 0) {
        throw "Fresh install failed with exit code $LASTEXITCODE."
    }

    foreach ($path in @(
        "scripts\detect-stack.ps1",
        "scripts\new-verification-profile.ps1",
        "scripts\doctor.ps1",
        "scripts\run-harness.ps1",
        "scripts\lifecycle.ps1",
        "scripts\maker-checker.ps1",
        "scripts\audit-runs.ps1",
        "scripts\audit-integrity.ps1",
        "scripts\new-audit-report.ps1"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $target $path) -PathType Leaf)) {
            throw "Stable fresh install is missing $path."
        }
    }

    $manifest = Get-Content -LiteralPath (Join-Path $target ".copilot-harness.json") -Raw | ConvertFrom-Json
    if ($manifest.readiness.contract -ne "docs/HARNESS-READINESS.md" -or $manifest.readiness.doctor -ne "scripts/doctor.ps1" -or $manifest.readiness.schemaVersion -ne 1) {
        throw "Manifest readiness contract is missing or invalid."
    }

    $ready = Invoke-DoctorJson $target
    if ($ready.Exit -ne 0) {
        $failedChecks = @($ready.Data.Checks | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object { "$($_.Name): $($_.Detail)" }) -join "; "
        throw "Doctor should return exit 0 for a complete fresh install, got $($ready.Exit). Failed checks: $failedChecks"
    }
    if (-not $ready.Data.Ready -or $ready.Data.SchemaVersion -ne 1 -or $ready.Data.Counts.Fail -ne 0) {
        throw "Doctor JSON did not report a ready schemaVersion 1 runtime."
    }

    $requiredDoctorChecks = @(
        "file:scripts/detect-stack.ps1",
        "file:scripts/new-verification-profile.ps1",
        "file:scripts/doctor.ps1",
        "manifest:readiness-contract",
        "manifest:doctor",
        "manifest:doctor-schema"
    )
    foreach ($name in $requiredDoctorChecks) {
        if (@($ready.Data.Checks | Where-Object { $_.Name -eq $name -and $_.Status -eq "PASS" }).Count -ne 1) {
            throw "Doctor readiness output is missing PASS check '$name'."
        }
    }

    Remove-Item -LiteralPath (Join-Path $target "scripts\lifecycle.ps1") -Force
    $broken = Invoke-DoctorJson $target
    if ($broken.Exit -ne 1) {
        throw "Doctor should fail closed when required runtime is missing, got exit $($broken.Exit)."
    }
    if ($broken.Data.Ready -or $broken.Data.Counts.Fail -lt 1) {
        throw "Doctor reported ready after a required runtime file was removed."
    }
    if (@($broken.Data.Checks | Where-Object { $_.Name -eq "file:scripts/lifecycle.ps1" -and $_.Status -eq "FAIL" }).Count -ne 1) {
        throw "Doctor did not identify the missing lifecycle runtime."
    }

    $global:LASTEXITCODE = 0
    Write-Host "PASS: doctor exposes machine-readable readiness and fails closed on incomplete stable runtime."
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
