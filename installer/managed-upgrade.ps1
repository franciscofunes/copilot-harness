# Pristine-file detection and recoverable, fail-closed upgrades from the pinned v1.1.0 release.
# This helper is dot-sourced by install.ps1 and restore-managed-upgrade.ps1.
Set-StrictMode -Version Latest

function Get-HarnessGitBlobHash {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)" + [char]0)
    $inputBytes = [byte[]]::new($header.Length + $bytes.Length)
    [Buffer]::BlockCopy($header, 0, $inputBytes, 0, $header.Length)
    [Buffer]::BlockCopy($bytes, 0, $inputBytes, $header.Length, $bytes.Length)
    $digest = [Security.Cryptography.SHA1]::HashData($inputBytes)
    return [Convert]::ToHexString($digest).ToLowerInvariant()
}

function Assert-HarnessManagedRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or
        $RelativePath -match '(^|[\\/])\.([\\/]|$)' -or
        $RelativePath -match '^[\\/]' -or
        [string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Unsafe managed path in upgrade inventory: $RelativePath"
    }
}

function Get-HarnessManagedUpgradePlan {
    param(
        [Parameter(Mandatory)][string]$HarnessRoot,
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string[]]$RelativePaths
    )
    $manifestPath = Join-Path $TargetRoot ".copilot-harness.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Managed upgrade requires an existing .copilot-harness.json from the pinned v1.1.0 installer. Use the regular installer for new repositories."
    }
    $oldManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($oldManifest.harnessVersion -ne "1.1.0") {
        throw "Managed upgrade only supports a v1.1.0 manifest; found '$($oldManifest.harnessVersion)'. Stop and review the upgrade path."
    }
    $baselinePath = Join-Path $HarnessRoot "installer/managed-baselines/1.1.0.json"
    $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json -AsHashtable
    if ($baseline.sourceCommit -ne "1996bbaef67cf4815ad6c18554bffc9daa5f6ea5" -or
        $baseline.hashAlgorithm -ne "git-blob-sha1") {
        throw "The pinned v1.1.0 managed-file baseline is invalid."
    }

    $conflicts = [System.Collections.Generic.List[string]]::new()
    $pristine = [System.Collections.Generic.List[string]]::new()
    $newFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @($RelativePaths | Sort-Object -Unique)) {
        Assert-HarnessManagedRelativePath $relative
        $normalized = $relative.Replace([char]92, [char]47)
        $source = Join-Path $HarnessRoot $normalized
        $target = Join-Path $TargetRoot $normalized
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Upgrade source is missing: $normalized"
        }
        if (-not (Test-Path -LiteralPath $target)) {
            $newFiles.Add($normalized)
            continue
        }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $conflicts.Add("$normalized (destination is not a file)")
            continue
        }
        $currentHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if ($currentHash -eq $sourceHash) {
            $pristine.Add($normalized)
            continue
        }
        if (-not $baseline.files.ContainsKey($normalized) -or
            (Get-HarnessGitBlobHash $target) -ne $baseline.files[$normalized]) {
            $conflicts.Add("$normalized (customized or unrecognized content)")
            continue
        }
        $pristine.Add($normalized)
    }
    if ($conflicts.Count -gt 0) {
        throw ("Managed upgrade blocked before mutation; preserve and review these files: " + ($conflicts -join "; "))
    }
    return [pscustomobject]@{
        PreviousVersion = "1.1.0"
        Paths = @($RelativePaths | ForEach-Object { $_.Replace([char]92, [char]47) } | Sort-Object -Unique)
        ExistingPristine = @($pristine)
        NewFiles = @($newFiles)
    }
}

function Start-HarnessManagedUpgradeBackup {
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)]$Plan
    )
    $backupRelative = ".copilot-harness/backups/" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" + [guid]::NewGuid().ToString("N")
    $backupRoot = Join-Path $TargetRoot $backupRelative
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $originals = [System.Collections.Generic.List[object]]::new()
    $additions = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @($Plan.Paths) + @(".copilot-harness.json")) {
        Assert-HarnessManagedRelativePath $relative
        $target = Join-Path $TargetRoot $relative
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $copy = Join-Path $backupRoot ("files/" + $relative)
            New-Item -ItemType Directory -Path (Split-Path -Parent $copy) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $copy -Force
            $originals.Add([ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash })
        } elseif (Test-Path -LiteralPath $target) {
            throw "Cannot back up a non-file target: $relative"
        } else {
            $additions.Add($relative)
        }
    }

    $receipt = [ordered]@{
        schemaVersion = 1
        fromVersion = $Plan.PreviousVersion
        createdAtUtc = [DateTime]::UtcNow.ToString("o")
        originalFiles = @($originals)
        addedFiles = @($additions)
    }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backupRoot "receipt.json") -Encoding UTF8
    return [pscustomobject]@{ Root = $backupRoot; Relative = $backupRelative }
}

function Restore-HarnessManagedUpgradeBackup {
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string]$BackupRoot
    )
    $receiptPath = Join-Path $BackupRoot "receipt.json"
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        throw "Managed-upgrade backup receipt does not exist: $receiptPath"
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($receipt.schemaVersion -ne 1 -or $receipt.fromVersion -ne "1.1.0") {
        throw "Unexpected managed-upgrade receipt version."
    }
    # Verify the entire backup before changing any target files.
    foreach ($file in @($receipt.originalFiles)) {
        Assert-HarnessManagedRelativePath $file.path
        $copy = Join-Path $BackupRoot ("files/" + $file.path)
        if (-not (Test-Path -LiteralPath $copy -PathType Leaf) -or
            (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ne $file.sha256) {
            throw "Backup integrity check failed: $($file.path)"
        }
    }
    foreach ($relative in @($receipt.addedFiles)) {
        Assert-HarnessManagedRelativePath $relative
        $target = Join-Path $TargetRoot $relative
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        } elseif (Test-Path -LiteralPath $target) {
            throw "Cannot remove a non-file introduced by upgrade: $relative"
        }
    }
    foreach ($file in @($receipt.originalFiles)) {
        $target = Join-Path $TargetRoot $file.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $BackupRoot ("files/" + $file.path)) -Destination $target -Force
    }
}
