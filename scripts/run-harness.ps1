[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [ValidateSet("auto","docs","powershell","dotnet","angular","api","data","platform","security","release")]
    [string]$ChangeType = "auto",
    [string]$BaseRef,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$harnessRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $TargetPath).Path
$contextScript = Join-Path $harnessRoot "scripts\context.ps1"
$verifyScript = Join-Path $harnessRoot "scripts\verify.ps1"
$recordScript = Join-Path $harnessRoot "scripts\record-evidence.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-harness-run-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $contextPath = Join-Path $tempRoot "context.json"
    $verificationPath = Join-Path $tempRoot "verification.json"
    $contextArgs = @{ TargetPath=$targetRoot; ChangeType=$ChangeType; Json=$true }
    if (-not [string]::IsNullOrWhiteSpace($BaseRef)) { $contextArgs.BaseRef = $BaseRef }
    (& $contextScript @contextArgs | Out-String) | Set-Content -LiteralPath $contextPath -Encoding UTF8
    $context = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
    $verifyOutput = (& $verifyScript -TargetPath $targetRoot -ChangeType $context.ChangeType -Json | Out-String)
    $verifyExit = $LASTEXITCODE
    $verifyOutput | Set-Content -LiteralPath $verificationPath -Encoding UTF8
    $evidenceText = (& $recordScript -TargetPath $targetRoot -ContextPath $contextPath -VerificationPath $verificationPath -Json | Out-String)
    $evidence = $evidenceText | ConvertFrom-Json
    $result = [pscustomobject]@{ Context=$context; VerificationExitCode=$verifyExit; Evidence=$evidence }
    if ($Json) { $result | ConvertTo-Json -Depth 8 } else {
        Write-Host "Harness run completed."
        Write-Host "Change type: $($context.ChangeType)"
        Write-Host "Verification exit: $verifyExit"
        Write-Host "Evidence: $($evidence.RunDirectory)"
    }
    exit $verifyExit
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
