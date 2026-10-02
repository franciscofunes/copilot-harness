[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$TargetPath=".",
    [Parameter(Mandatory=$true)][ValidateSet("start","transition","show","resume")][string]$Action,
    [string]$RunId,
    [string]$Intent="",
    [ValidateSet("CONTEXT","PROPOSED","AWAITING_AUTHORIZATION","AUTHORIZED","VERIFYING","RETRY","HUMAN_HANDOFF","COMPLETE")][string]$To,
    [string]$Reason="",
    [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$target=(Resolve-Path -LiteralPath $TargetPath).Path
$runsRoot=Join-Path $target ".copilot-harness\runs"
if ([string]::IsNullOrWhiteSpace($RunId)) {
    if ($Action -ne "start") { throw "RunId is required for '$Action'." }
    $RunId=[DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
}
$runRoot=Join-Path $runsRoot $RunId
$statePath=Join-Path $runRoot "state.json"
function Write-State($state) { New-Item -ItemType Directory -Path $runRoot -Force | Out-Null; $state | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $statePath -Encoding UTF8 }
if ($Action -eq "resume") {
    if (-not (Test-Path $statePath)) { throw "Lifecycle state not found for run '$RunId'." }
    $existing=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($existing.state -eq "COMPLETE") { throw "Completed run '$RunId' cannot be resumed." }
} elseif ($Action -eq "start") {
    if (Test-Path $statePath) { throw "Lifecycle state already exists for run '$RunId'." }
    $now=[DateTime]::UtcNow.ToString("o")
    $state=[ordered]@{schemaVersion=1;runId=$RunId;intent=$Intent;state="CONTEXT";createdAtUtc=$now;updatedAtUtc=$now;history=@([ordered]@{from=$null;to="CONTEXT";atUtc=$now;reason="run started"})}
    Write-State $state
} else {
    if (-not (Test-Path $statePath)) { throw "Lifecycle state not found for run '$RunId'." }
    $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($Action -eq "transition") {
        if ([string]::IsNullOrWhiteSpace($To)) { throw "To is required for transition." }
        $allowed=@{
            CONTEXT=@("PROPOSED","HUMAN_HANDOFF"); PROPOSED=@("AWAITING_AUTHORIZATION","AUTHORIZED","HUMAN_HANDOFF");
            AWAITING_AUTHORIZATION=@("AUTHORIZED","HUMAN_HANDOFF"); AUTHORIZED=@("VERIFYING","HUMAN_HANDOFF");
            VERIFYING=@("COMPLETE","RETRY","HUMAN_HANDOFF"); RETRY=@("PROPOSED","HUMAN_HANDOFF");
            HUMAN_HANDOFF=@("PROPOSED","AUTHORIZED"); COMPLETE=@()
        }
        $from=[string]$state.state
        if (@($allowed[$from]) -notcontains $To) { throw "Invalid lifecycle transition: $from -> $To." }
        $now=[DateTime]::UtcNow.ToString("o")
        $history=@($state.history)+@([pscustomobject]@{from=$from;to=$To;atUtc=$now;reason=$Reason})
        $state.state=$To; $state.updatedAtUtc=$now; $state.history=$history
        Write-State $state
    }
}
$result=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if($Json){$result|ConvertTo-Json -Depth 7}else{Write-Host ("Run {0}: {1}" -f $RunId,$result.state)}
