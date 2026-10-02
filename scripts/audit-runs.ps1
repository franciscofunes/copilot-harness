[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$TargetPath=".",
  [int]$Limit=100,
  [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$target=(Resolve-Path -LiteralPath $TargetPath).Path
$runsRoot=Join-Path $target ".copilot-harness\runs"
$runs=@()
if(Test-Path $runsRoot){
  foreach($dir in @(Get-ChildItem -LiteralPath $runsRoot -Directory | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $Limit)){
    $statePath=Join-Path $dir.FullName "state.json"
    $checkerPath=Join-Path $dir.FullName "maker-checker.json"
    $verificationPath=Join-Path $dir.FullName "verification.json"
    $state=$null;$checker=$null;$verification=$null
    if(Test-Path $statePath){$state=Get-Content $statePath -Raw|ConvertFrom-Json}
    if(Test-Path $checkerPath){$checker=Get-Content $checkerPath -Raw|ConvertFrom-Json}
    if(Test-Path $verificationPath){$verification=Get-Content $verificationPath -Raw|ConvertFrom-Json}
    $runs+= [pscustomobject]@{
      RunId=$dir.Name
      State=if($state){$state.state}else{"UNKNOWN"}
      CheckerDecision=if($checker -and $checker.checker){$checker.checker.decision}else{$null}
      VerificationReady=if($verification){[bool]$verification.Ready}else{$null}
      RetryCount=if($state){@($state.history|Where-Object to -eq "RETRY").Count}else{0}
      HandoffCount=if($state){@($state.history|Where-Object to -eq "HUMAN_HANDOFF").Count}else{0}
      UpdatedAtUtc=if($state){$state.updatedAtUtc}else{$dir.LastWriteTimeUtc.ToString("o")}
    }
  }
}
$total=@($runs).Count
$summary=[ordered]@{
  schemaVersion=1
  generatedAtUtc=[DateTime]::UtcNow.ToString("o")
  totalRuns=$total
  complete=@($runs|Where-Object State -eq "COMPLETE").Count
  retry=@($runs|Where-Object State -eq "RETRY").Count
  humanHandoff=@($runs|Where-Object State -eq "HUMAN_HANDOFF").Count
  accepted=@($runs|Where-Object CheckerDecision -eq "ACCEPT").Count
  rejected=@($runs|Where-Object CheckerDecision -eq "REJECT").Count
  verificationReady=@($runs|Where-Object VerificationReady -eq $true).Count
  runs=$runs
}
if($Json){$summary|ConvertTo-Json -Depth 7}else{
 Write-Host "Harness audit: $total runs"
 Write-Host "Complete: $($summary.complete) | Retry: $($summary.retry) | Human handoff: $($summary.humanHandoff)"
 Write-Host "Checker ACCEPT: $($summary.accepted) | REJECT: $($summary.rejected)"
}
