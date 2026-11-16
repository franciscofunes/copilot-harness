[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineSourcePath,
    [Parameter(Mandatory)][string]$CandidateSourcePath,
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$baselineSha = "1996bbaef67cf4815ad6c18554bffc9daa5f6ea5"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("harness-managed-upgrade-" + [guid]::NewGuid().ToString("N"))

function Assert-Source {
    param([string]$Root, [string]$Version, [string]$ExpectedSha)
    $actualVersion = (Get-Content -LiteralPath (Join-Path $Root "VERSION") -Raw).Trim()
    if ($actualVersion -ne $Version) { throw "Expected source $Version, got $actualVersion" }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha)) {
        $sha = (& git -C $Root rev-parse HEAD | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $sha -ne $ExpectedSha) {
            throw "Baseline must be the published immutable Git commit $ExpectedSha, got $sha"
        }
    }
}

function Install-Version {
    param([string]$Source, [string]$Target, [string]$Mode)
    & (Join-Path $Source "installer/install.ps1") -TargetPath $Target -ConflictMode $Mode -SkipSpecKit -SkipSpecKitExtensions -SkipCodeGraph -SkipVerificationProfile -SkipDoctor | Out-Null
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', got '$Actual'." }
}

function Get-Inventory {
    param([string]$Target)
    $result = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $Target -File -Recurse -Force)) {
        $relative = [IO.Path]::GetRelativePath($Target, $file.FullName).Replace([char]92, [char]47)
        if ($relative.StartsWith(".copilot-harness/backups/", [StringComparison]::OrdinalIgnoreCase)) { continue }
        $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $result
}

function Assert-InventoryEqual {
    param([hashtable]$Expected, [hashtable]$Actual, [string]$Context)
    Assert-Equal $Expected.Count $Actual.Count "$Context file count"
    foreach ($key in $Expected.Keys) {
        if (-not $Actual.ContainsKey($key)) { throw "$Context lost $key" }
        Assert-Equal $Expected[$key] $Actual[$key] "$Context changed $key"
    }
}

function New-Fixture {
    param([string]$Name)
    $target = Join-Path $workRoot $Name
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $target "package.json") -Value '{"dependencies":{"mongodb":"^6.0.0"}}' -Encoding UTF8
    Install-Version $BaselineSourcePath $target "skip"
    $manifest = Get-Content -LiteralPath (Join-Path $target ".copilot-harness.json") -Raw | ConvertFrom-Json
    Assert-Equal "1.1.0" $manifest.harnessVersion "Published v1.1.0 fixture"
    return $target
}

try {
    Assert-Source $BaselineSourcePath "1.1.0" $baselineSha
    Assert-Source $CandidateSourcePath "1.2.0" ""
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

    # A modified managed skill blocks the whole upgrade without changing a single target byte.
    $customized = New-Fixture "customized"
    $customPath = Join-Path $customized ".github/skills/aspnet-core-review/SKILL.md"
    $customText = "# repository custom rule, do not replace"
    Set-Content -LiteralPath $customPath -Value $customText -Encoding UTF8
    $customBefore = Get-Inventory $customized
    $blocked = $false
    try {
        Install-Version $CandidateSourcePath $customized "managed-upgrade"
    } catch {
        if ($_.Exception.Message -match "Managed upgrade blocked before mutation" -and
            $_.Exception.Message -match "aspnet-core-review") {
            $blocked = $true
        } else {
            throw
        }
    }
    if (-not $blocked) { throw "Customized managed skill should block upgrade before mutation" }
    Assert-InventoryEqual $customBefore (Get-Inventory $customized) "Customized fixture"
    if (Test-Path -LiteralPath (Join-Path $customized ".copilot-harness/backups")) {
        throw "A failed preflight must not create a backup or alter the target."
    }

    # A pristine pinned 1.1.0 install can become 1.2.0 without overwriting user-owned configuration.
    $pristine = New-Fixture "pristine"
    $profile = Join-Path $pristine ".copilot-harness.verify.json"
    $profileText = '{"schemaVersion":1,"checks":[]}'
    Set-Content -LiteralPath $profile -Value $profileText -Encoding UTF8
    $before = Get-Inventory $pristine
    Install-Version $CandidateSourcePath $pristine "managed-upgrade"
    $manifest = Get-Content -LiteralPath (Join-Path $pristine ".copilot-harness.json") -Raw | ConvertFrom-Json
    Assert-Equal "1.2.0" $manifest.harnessVersion "Managed-upgrade manifest"
    Assert-Equal "COMPLETE" $manifest.upgrade.status "Managed-upgrade gate"
    Assert-Equal "1.1.0" $manifest.upgrade.previousVersion "Managed-upgrade provenance"
    if ([string]::IsNullOrWhiteSpace($manifest.upgrade.backupPath)) { throw "A complete managed upgrade requires a backup receipt" }
    $backup = Join-Path $pristine $manifest.upgrade.backupPath
    if (-not (Test-Path -LiteralPath (Join-Path $backup "receipt.json") -PathType Leaf)) { throw "Missing backup receipt" }
    Assert-Equal $profileText (Get-Content -LiteralPath $profile -Raw).Trim() "Custom verification profile"
    foreach ($relative in @("scripts/doctor.ps1", ".github/skills/mongodb-data-review/SKILL.md", "skills/catalog.json")) {
        $expected = (Get-FileHash -LiteralPath (Join-Path $CandidateSourcePath $relative) -Algorithm SHA256).Hash
        $actual = (Get-FileHash -LiteralPath (Join-Path $pristine $relative) -Algorithm SHA256).Hash
        Assert-Equal $expected $actual "Candidate runtime content for $relative"
    }
    if ((Get-FileHash -LiteralPath (Join-Path $BaselineSourcePath "scripts/doctor.ps1") -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath (Join-Path $pristine "scripts/doctor.ps1") -Algorithm SHA256).Hash) {
        throw "Managed-upgrade left the old Doctor in place"
    }

    & (Join-Path $CandidateSourcePath "installer/restore-managed-upgrade.ps1") -TargetPath $pristine -BackupPath $backup | Out-Null
    Assert-InventoryEqual $before (Get-Inventory $pristine) "Explicit managed-upgrade rollback"
    $restored = Get-Content -LiteralPath (Join-Path $pristine ".copilot-harness.json") -Raw | ConvertFrom-Json
    Assert-Equal "1.1.0" $restored.harnessVersion "Restored manifest"

    # Default skip is still preservation-first, but must no longer claim an upgraded runtime.
    $skip = New-Fixture "default-skip"
    $oldDoctor = (Get-FileHash -LiteralPath (Join-Path $skip "scripts/doctor.ps1") -Algorithm SHA256).Hash
    Install-Version $CandidateSourcePath $skip "skip"
    $skipManifest = Get-Content -LiteralPath (Join-Path $skip ".copilot-harness.json") -Raw | ConvertFrom-Json
    Assert-Equal "1.1.0" $skipManifest.harnessVersion "Skip-mode effective runtime version"
    Assert-Equal "1.2.0" $skipManifest.upgrade.requestedVersion "Skip-mode requested version"
    Assert-Equal "PARTIAL" $skipManifest.upgrade.status "Skip-mode release gate"
    if (@($skipManifest.upgrade.skippedDifferingFiles).Count -lt 1) { throw "Partial skip manifest lacks differing-file evidence" }
    Assert-Equal $oldDoctor (Get-FileHash -LiteralPath (Join-Path $skip "scripts/doctor.ps1") -Algorithm SHA256).Hash "Skip-mode Doctor preservation"

    if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
        $candidateCommit = (& git -C $CandidateSourcePath rev-parse HEAD | Out-String).Trim()
        $receipt = [ordered]@{
            schemaVersion = 1
            publishedBaseline = [ordered]@{ version = "1.1.0"; sha = $baselineSha }
            testedImplementation = [ordered]@{ version = "1.2.0"; sha = $candidateCommit; note = "PR integration head, not the nominated pinned main candidate" }
            gates = [ordered]@{
                customizedFilesRejectedBeforeMutation = $true
                pristineRuntimeUpgraded = $true
                skipModeManifestReportsPartial = $true
                backupVerifiedAndRestoredByteForByte = $true
            }
            releaseGate = "BLOCKED"
            reason = "The final v1.2.0 candidate has not been updated, frozen, and requalified; live IDE adoption and owner sign-off remain outstanding."
        }
        $folder = Split-Path -Parent $ReceiptPath
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        $receipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
    }
    Write-Host "PASS: pinned pristine upgrade, custom-content preflight, effective-version reporting, backup integrity and exact rollback."
} finally {
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
