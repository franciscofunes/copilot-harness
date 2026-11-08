[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineSourcePath,
    [Parameter(Mandatory)][string]$CandidateSourcePath,
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Immutable source pins: never substitute current develop for the candidate being qualified.
$baselineSha = "1996bbaef67cf4815ad6c18554bffc9daa5f6ea5"
$candidateSha = "dfc0436054a7548e0ab78767a0df6fded2eee76f"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("harness-v1-2-upgrade-" + [guid]::NewGuid().ToString("N"))

function Assert-PinnedSource {
    param([string]$Path, [string]$ExpectedSha, [string]$ExpectedVersion)
    $source = (Resolve-Path -LiteralPath $Path).Path
    if (-not (Test-Path -LiteralPath (Join-Path $source "installer\install.ps1") -PathType Leaf)) {
        throw "Pinned source lacks the installer: $source"
    }
    $actualSha = (& git -C $source rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualSha -ne $ExpectedSha) {
        throw "Source pin mismatch: expected $ExpectedSha, observed $actualSha"
    }
    $version = (Get-Content -LiteralPath (Join-Path $source "VERSION") -Raw).Trim()
    if ($version -ne $ExpectedVersion) {
        throw "Source version mismatch: expected $ExpectedVersion, got $version"
    }
    return $source
}

function Invoke-PinnedInstall {
    param([string]$Source, [string]$Target, [string]$Mode = "skip")
    $global:LASTEXITCODE = 0
    & (Join-Path $Source "installer\install.ps1") -TargetPath $Target -ConflictMode $Mode -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Pinned $Mode installation failed: $LASTEXITCODE"
    }
}

function Assert-ManifestVersion {
    param([string]$Target, [string]$ExpectedVersion)
    $manifest = Get-Content -LiteralPath (Join-Path $Target ".copilot-harness.json") -Raw | ConvertFrom-Json
    if ($manifest.harnessVersion -ne $ExpectedVersion) {
        throw "Manifest version mismatch: expected $ExpectedVersion, got $($manifest.harnessVersion)"
    }
}

function Get-FileHashValue {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-Inventory {
    param([string]$Target)
    $inventory = @{}
    $root = (Resolve-Path -LiteralPath $Target).Path
    foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
        $inventory[$relative] = Get-FileHashValue $file.FullName
    }
    return $inventory
}

function Assert-InventoryEqual {
    param([hashtable]$Expected, [hashtable]$Actual, [string]$Context)
    if ($Expected.Count -ne $Actual.Count) {
        throw "$Context file count differs: expected $($Expected.Count), got $($Actual.Count)"
    }
    foreach ($key in $Expected.Keys) {
        if (-not $Actual.ContainsKey($key) -or $Actual[$key] -ne $Expected[$key]) {
            throw "$Context changed or lost $key"
        }
    }
}

function Restore-Snapshot {
    param([string]$Snapshot, [string]$Target, [hashtable]$ExpectedInventory)
    if (-not (Test-Path -LiteralPath (Join-Path $Snapshot ".copilot-harness.json"))) {
        throw "Rollback snapshot is missing its manifest"
    }
    # Delete only a uniquely generated disposable fixture created by this test.
    Remove-Item -LiteralPath $Target -Recurse -Force
    Copy-Item -LiteralPath $Snapshot -Destination $Target -Recurse -Force
    Assert-InventoryEqual $ExpectedInventory (Get-Inventory $Target) "Snapshot rollback"
    Assert-ManifestVersion $Target "1.1.0"
    if (Test-Path -LiteralPath (Join-Path $Target ".github\skills\mongodb-data-review\SKILL.md")) {
        throw "Rollback unexpectedly retained a v1.2-only skill"
    }
}

try {
    $baseline = Assert-PinnedSource $BaselineSourcePath $baselineSha "1.1.0"
    $candidate = Assert-PinnedSource $CandidateSourcePath $candidateSha "1.2.0"
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

    $target = Join-Path $workRoot "upgrade"
    $snapshot = Join-Path $workRoot "snapshot-v1-1"
    $overwriteTarget = Join-Path $workRoot "explicit-overwrite"
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $target "package.json") -Value '{"dependencies":{"mongodb":"^6.0.0"}}' -Encoding UTF8

    # Actual published 1.1.0 installation, then repository-owned customization.
    Invoke-PinnedInstall $baseline $target
    Assert-ManifestVersion $target "1.1.0"
    $customSkill = Join-Path $target ".github\skills\aspnet-core-review\SKILL.md"
    $customContent = "# repository-owned skill customization, must survive default skip"
    Set-Content -LiteralPath $customSkill -Value $customContent -Encoding UTF8
    $customProfile = Join-Path $target ".copilot-harness.verify.json"
    Set-Content -LiteralPath $customProfile -Value '{"schemaVersion":1,"checks":[]}' -Encoding UTF8
    $oldDoctorHash = Get-FileHashValue (Join-Path $target "scripts\doctor.ps1")
    $oldCatalogHash = Get-FileHashValue (Join-Path $target "skills\catalog.json")
    Copy-Item -LiteralPath $target -Destination $snapshot -Recurse -Force
    $originalInventory = Get-Inventory $snapshot
    if ($originalInventory.Count -lt 15) { throw "Unexpectedly small v1.1.0 installed fixture" }

    # Default skip must preserve every existing byte except the rewritten manifest.
    Invoke-PinnedInstall $candidate $target "skip"
    Assert-ManifestVersion $target "1.2.0"
    $afterSkip = Get-Inventory $target
    foreach ($key in $originalInventory.Keys) {
        if ($key -eq ".copilot-harness.json") { continue }
        if (-not $afterSkip.ContainsKey($key) -or $afterSkip[$key] -ne $originalInventory[$key]) {
            throw "Default skip did not preserve repository file $key"
        }
    }
    foreach ($skill in @("sql-server-data-review", "mongodb-data-review", "snowflake-data-review")) {
        $rel = ".github\skills\$skill\SKILL.md"
        $installed = Join-Path $target $rel
        if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {
            throw "Additive upgrade failed to install $skill"
        }
        if ((Get-FileHashValue $installed) -ne (Get-FileHashValue (Join-Path $candidate $rel))) {
            throw "Installed $skill bytes do not match pinned v1.2.0"
        }
    }
    if ((Get-FileHashValue (Join-Path $target "scripts\doctor.ps1")) -ne $oldDoctorHash -or
        (Get-FileHashValue (Join-Path $target "skills\catalog.json")) -ne $oldCatalogHash) {
        throw "Default skip unexpectedly replaced existing runtime/catalog files"
    }
    $candidateDoctorDiffers = (Get-FileHashValue (Join-Path $candidate "scripts\doctor.ps1")) -ne $oldDoctorHash
    $candidateCatalogDiffers = (Get-FileHashValue (Join-Path $candidate "skills\catalog.json")) -ne $oldCatalogHash
    if (-not $candidateDoctorDiffers -or -not $candidateCatalogDiffers) {
        throw "Expected cross-version Doctor/catalog changes were not present"
    }

    # Overwrite is intentionally explicit and demonstrated only on a disposable copy.
    # It can replace custom files; do not call it a safe unattended user upgrade.
    Copy-Item -LiteralPath $snapshot -Destination $overwriteTarget -Recurse -Force
    Invoke-PinnedInstall $candidate $overwriteTarget "overwrite"
    Assert-ManifestVersion $overwriteTarget "1.2.0"
    foreach ($rel in @("scripts\doctor.ps1", "skills\catalog.json", ".github\skills\mongodb-data-review\SKILL.md")) {
        if ((Get-FileHashValue (Join-Path $overwriteTarget $rel)) -ne (Get-FileHashValue (Join-Path $candidate $rel))) {
            throw "Explicit overwrite failed to install pinned $rel"
        }
    }
    $overwroteCustomization = (Get-Content -LiteralPath (Join-Path $overwriteTarget ".github\skills\aspnet-core-review\SKILL.md") -Raw).Trim() -ne $customContent
    if (-not $overwroteCustomization) { throw "Expected overwrite risk was not demonstrated" }
    $global:LASTEXITCODE = 0
    $doctor = (& (Join-Path $overwriteTarget "scripts\doctor.ps1") -TargetPath $overwriteTarget -Json | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $doctor.Ready -or $doctor.Counts.Fail -ne 0) {
        throw "Overwritten v1.2.0 Doctor did not report ready"
    }

    # Revert both upgrade modes by restoring the pre-upgrade snapshot, never
    # by pretending a skip-mode reinstall performs an in-place downgrade.
    Restore-Snapshot $snapshot $target $originalInventory
    Restore-Snapshot $snapshot $overwriteTarget $originalInventory

    $receipt = [ordered]@{
        schemaVersion = 1
        baseline = [ordered]@{ version = "1.1.0"; sha = $baselineSha }
        candidate = [ordered]@{ version = "1.2.0"; sha = $candidateSha }
        defaultSkip = [ordered]@{
            existingFilesPreserved = $true
            newDataSkillsInstalled = $true
            oldDoctorAndCatalogRemain = $true
            completeRuntimeUpgrade = $false
        }
        explicitOverwrite = [ordered]@{
            candidateRuntimeInstalled = $true
            doctorReady = $true
            overwritesRepositoryCustomization = $true
        }
        snapshotRollback = [ordered]@{
            defaultSkipRestoredByteForByte = $true
            explicitOverwriteRestoredByteForByte = $true
            restoredManifestVersion = "1.1.0"
        }
        releaseGate = "BLOCKED"
        reason = "Default skip preserves old runtime/catalog while reporting a 1.2.0 manifest; overwrite replaces customized content. A safe full in-place upgrade policy is not yet proven."
    }
    if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
        $receiptDirectory = Split-Path -Parent $ReceiptPath
        if (-not (Test-Path -LiteralPath $receiptDirectory)) {
            New-Item -ItemType Directory -Path $receiptDirectory -Force | Out-Null
        }
        $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
    }
    Write-Host "PASS: Pinned v1.1.0 -> v1.2.0 fixture checks and both snapshot restorations passed."
    Write-Warning "RELEASE BLOCKED: Skip preserves old Doctor/catalog; overwrite destroys customizations. No full safe upgrade claim."
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}
