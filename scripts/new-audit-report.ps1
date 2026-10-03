[CmdletBinding()]
param([Parameter(Position=0)][string]$TargetPath=".",[string]$OutputPath="",[int]$Limit=100)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path $TargetPath ".copilot-harness\audit"}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$metricsPath=Join-Path $OutputPath "metrics.json";$integrityPath=Join-Path $OutputPath "integrity.json";$summaryPath=Join-Path $OutputPath "summary.md"
$global:LASTEXITCODE=0
$metrics=(& (Join-Path $root "audit-runs.ps1") -TargetPath $TargetPath -Limit $Limit -Json|Out-String);if($LASTEXITCODE-ne 0){throw "Run metrics generation failed."}
Set-Content -LiteralPath $metricsPath -Value $metrics
$global:LASTEXITCODE=0
$integrity=(& (Join-Path $root "audit-integrity.ps1") -TargetPath $TargetPath -Limit $Limit -Json|Out-String);$integrityExit=$LASTEXITCODE
Set-Content -LiteralPath $integrityPath -Value $integrity
$m=$metrics|ConvertFrom-Json;$i=$integrity|ConvertFrom-Json
$lines=@("# Harness Audit Report","","Generated: $([DateTime]::UtcNow.ToString('o'))","","## Run metrics","","- Total runs: $($m.totalRuns)","- Complete: $($m.complete)","- Retry: $($m.retry)","- Human handoff: $($m.humanHandoff)","- Checker ACCEPT: $($m.accepted)","- Checker REJECT: $($m.rejected)","","## Integrity","","- Healthy: $($i.healthy)","- Errors: $($i.errorCount)")
if($i.errorCount -gt 0){$lines+=@("","### Findings","");foreach($f in $i.findings){$lines+="- [$($f.Severity)] $($f.RunId) / $($f.Code): $($f.Message)"}}
Set-Content -LiteralPath $summaryPath -Value ($lines -join [Environment]::NewLine)
$result=[pscustomobject]@{Metrics=$metricsPath;Integrity=$integrityPath;Summary=$summaryPath;Healthy=[bool]$i.healthy;IntegrityExitCode=$integrityExit}
$result|ConvertTo-Json -Depth 4
if($integrityExit-ne 0){exit $integrityExit}
