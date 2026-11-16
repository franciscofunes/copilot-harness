[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TargetPath,
    [Parameter(Mandatory)][string]$BackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$backupRoot = (Resolve-Path -LiteralPath $BackupPath).Path
$approvedRoot = Join-Path $targetRoot ".copilot-harness/backups"
$prefix = $approvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $backupRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to restore an upgrade backup outside $approvedRoot"
}
. (Join-Path $PSScriptRoot "managed-upgrade.ps1")
Restore-HarnessManagedUpgradeBackup -TargetRoot $targetRoot -BackupRoot $backupRoot
Write-Host "Restored managed files and the original manifest from $backupRoot."
Write-Host "Backup evidence was preserved for audit. Review any unrelated repository changes separately."
