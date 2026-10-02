[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [ValidateSet("auto","docs","powershell","dotnet","angular","api","data","platform","security","release")]
    [string]$ChangeType = "auto",
    [string]$BaseRef,
    [string]$Intent = "",
    [string]$ProposalId = "",
    [string]$ProposalSummary = "",
    [string[]]$ChangedFiles = @(),
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$contextScript = Join-Path $harnessRoot "scripts\context.ps1"
$verifyScript = Join-Path $harnessRoot "scripts\verify.ps1"
$recordScript = Join-Path $harnessRoot "scripts\record-evidence.ps1"
$lifecycleScript = Join-Path $harnessRoot "scripts\lifecycle.ps1"
$makerCheckerScript = Join-Path $harnessRoot "scripts\maker-checker.ps1"
$runId = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-harness-run-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    & $lifecycleScript -TargetPath $targetRoot -Action start -RunId $runId -Intent $Intent | Out-Null
    $contextPath = Join-Path $tempRoot "context.json"
    $verificationPath = Join-Path $tempRoot "verification.json"
    $contextArgs = @{ TargetPath=$targetRoot; ChangeType=$ChangeType; Json=$true }
    if (-not [string]::IsNullOrWhiteSpace($BaseRef)) { $contextArgs.BaseRef = $BaseRef }
    $contextArgs.Intent = $Intent
    $global:LASTEXITCODE = 0 # Avoid inheriting unrelated native-command status
    $contextOutput = (& $contextScript @contextArgs | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Context generation failed with exit code $LASTEXITCODE." }
    $contextOutput | Set-Content -LiteralPath $contextPath -Encoding UTF8
    $context = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($ProposalId)) {
        & $lifecycleScript -TargetPath $targetRoot -Action transition -RunId $runId -To PROPOSED -Reason "proposal recorded" | Out-Null
        & $makerCheckerScript -TargetPath $targetRoot -Action propose -RunId $runId -ProposalId $ProposalId -Summary $ProposalSummary -ChangedFiles $ChangedFiles | Out-Null
        & $lifecycleScript -TargetPath $targetRoot -Action transition -RunId $runId -To AUTHORIZED -Reason "verification-only orchestration boundary" | Out-Null
        & $lifecycleScript -TargetPath $targetRoot -Action transition -RunId $runId -To VERIFYING -Reason "deterministic verification started" | Out-Null
    }
    $verifyOutput = (& $verifyScript -TargetPath $targetRoot -ChangeType $context.ChangeType -Json | Out-String)
    $verifyExit = $LASTEXITCODE
    if ([string]::IsNullOrWhiteSpace($verifyOutput)) { throw "Verification returned no JSON; refusing to record incomplete evidence." }
    $verifyOutput | Set-Content -LiteralPath $verificationPath -Encoding UTF8
    $makerChecker = $null
    if (-not [string]::IsNullOrWhiteSpace($ProposalId)) {
        $makerCheckerText = (& $makerCheckerScript -TargetPath $targetRoot -Action check -RunId $runId -VerificationPath $verificationPath -Json | Out-String)
        $makerChecker = $makerCheckerText | ConvertFrom-Json
        $nextState = if ($makerChecker.checker.decision -eq "ACCEPT") { "COMPLETE" } else { "RETRY" }
        & $lifecycleScript -TargetPath $targetRoot -Action transition -RunId $runId -To $nextState -Reason ("checker " + $makerChecker.checker.decision) | Out-Null
    }
    $global:LASTEXITCODE = 0 # Evidence recorder is a PowerShell script
    $evidenceText = (& $recordScript -TargetPath $targetRoot -RunId $runId -ContextPath $contextPath -VerificationPath $verificationPath -Json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Evidence recording failed with exit code $LASTEXITCODE." }
    $evidence = $evidenceText | ConvertFrom-Json
    $lifecycle = (& $lifecycleScript -TargetPath $targetRoot -Action show -RunId $runId -Json | Out-String) | ConvertFrom-Json
    $result = [pscustomobject]@{ RunId=$runId; Context=$context; VerificationExitCode=$verifyExit; MakerChecker=$makerChecker; Lifecycle=$lifecycle; Evidence=$evidence }
    if ($Json) { $result | ConvertTo-Json -Depth 8 } else {
        Write-Host "Harness run completed."
        Write-Host "Change type: $($context.ChangeType)"
        Write-Host "Verification exit: $verifyExit"
        Write-Host "Evidence: $($evidence.RunDirectory)"
    }
    exit $verifyExit
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
