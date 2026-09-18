[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [string]$RunId,
    [string]$ContextPath,
    [string]$PolicyPath,
    [string]$VerificationPath,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
if ([string]::IsNullOrWhiteSpace($RunId)) { $RunId = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ") }
$runsRoot = Join-Path $targetRoot ".copilot-harness\runs"
$runRoot = Join-Path $runsRoot $RunId
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

function Copy-IfPresent {
    param([string]$Source,[string]$DestinationName)
    if ([string]::IsNullOrWhiteSpace($Source)) { return $null }
    $resolved = Resolve-Path -LiteralPath $Source -ErrorAction SilentlyContinue
    if ($null -eq $resolved) { return $null }
    $destination = Join-Path $runRoot $DestinationName
    Copy-Item -LiteralPath $resolved.Path -Destination $destination -Force
    return $DestinationName
}

$contextFile = Copy-IfPresent $ContextPath "context.json"
$policyFile = Copy-IfPresent $PolicyPath "policy.json"
$verificationFile = Copy-IfPresent $VerificationPath "verification.json"
$manifest = [ordered]@{
    schemaVersion = 1
    runId = $RunId
    recordedAtUtc = [DateTime]::UtcNow.ToString("o")
    files = [ordered]@{ context=$contextFile; policy=$policyFile; verification=$verificationFile }
}
$manifestPath = Join-Path $runRoot "evidence.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$summaryPath = Join-Path $runRoot "summary.md"
@(
    "# Copilot Harness Evidence Run",
    "",
    "- Run ID: $RunId",
    "- Recorded at: $($manifest.recordedAtUtc)",
    "- Context: $(if ($contextFile) { $contextFile } else { 'not supplied' })",
    "- Policy: $(if ($policyFile) { $policyFile } else { 'not supplied' })",
    "- Verification: $(if ($verificationFile) { $verificationFile } else { 'not supplied' })",
    "",
    "This directory stores execution metadata/evidence only. It must not contain secrets, private prompts, credentials, or raw model chain-of-thought."
) | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$result = [pscustomobject]@{ RunId=$RunId; RunDirectory=$runRoot; Manifest=$manifestPath; Summary=$summaryPath }
if ($Json) { $result | ConvertTo-Json -Depth 4 } else { Write-Host "Evidence recorded: $runRoot" }
