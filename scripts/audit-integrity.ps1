[CmdletBinding()]
param([Parameter(Position=0)][string]$TargetPath=".",[int]$Limit=100,[switch]$Json)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$target=(Resolve-Path -LiteralPath $TargetPath).Path
$runsRoot=Join-Path $target ".copilot-harness\runs"
$findings=@()
function Add-Finding([string]$runId,[string]$code,[string]$severity,[string]$message){
 $script:findings += [pscustomobject]@{RunId=$runId;Code=$code;Severity=$severity;Message=$message}
}
if(Test-Path $runsRoot){
 foreach($dir in @(Get-ChildItem $runsRoot -Directory|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First $Limit)){
  $id=$dir.Name;$state=$null;$checker=$null;$verification=$null
  $sp=Join-Path $dir.FullName "state.json";$cp=Join-Path $dir.FullName "maker-checker.json";$vp=Join-Path $dir.FullName "verification.json";$ep=Join-Path $dir.FullName "evidence.json"
  if(Test-Path $sp){try{$state=Get-Content $sp -Raw|ConvertFrom-Json}catch{Add-Finding $id "INVALID_STATE" "ERROR" "state.json is not valid JSON."}}
  else{Add-Finding $id "MISSING_STATE" "ERROR" "state.json is missing."}
  if(Test-Path $cp){try{$checker=Get-Content $cp -Raw|ConvertFrom-Json}catch{Add-Finding $id "INVALID_CHECKER" "ERROR" "maker-checker.json is not valid JSON."}}
  if(Test-Path $vp){try{$verification=Get-Content $vp -Raw|ConvertFrom-Json}catch{Add-Finding $id "INVALID_VERIFICATION" "ERROR" "verification.json is not valid JSON."}}
  if(-not(Test-Path $ep)){Add-Finding $id "MISSING_EVIDENCE_MANIFEST" "ERROR" "evidence.json is missing."}
  if($state -and $state.state -eq "COMPLETE"){
   if(-not $checker -or -not $checker.checker -or $checker.checker.decision -ne "ACCEPT"){Add-Finding $id "COMPLETE_WITHOUT_ACCEPT" "ERROR" "COMPLETE requires checker ACCEPT."}
   if(-not $verification){Add-Finding $id "COMPLETE_WITHOUT_VERIFICATION" "ERROR" "COMPLETE requires verification evidence."}
   elseif(-not [bool]$verification.Ready){Add-Finding $id "COMPLETE_NOT_READY" "ERROR" "COMPLETE has verification Ready=false."}
  }
  if($checker -and $checker.checker -and $checker.checker.decision -eq "ACCEPT" -and (-not $verification -or -not [bool]$verification.Ready)){Add-Finding $id "ACCEPT_WITHOUT_READY" "ERROR" "Checker ACCEPT requires ready verification."}
  if($state -and @($state.history).Count -gt 0 -and $state.history[-1].to -ne $state.state){Add-Finding $id "STATE_HISTORY_MISMATCH" "ERROR" "Current state does not match final history transition."}
 }
}
$result=[ordered]@{schemaVersion=1;generatedAtUtc=[DateTime]::UtcNow.ToString("o");healthy=(@($findings|Where-Object Severity -eq "ERROR").Count -eq 0);errorCount=@($findings|Where-Object Severity -eq "ERROR").Count;findings=$findings}
if($Json){$result|ConvertTo-Json -Depth 7}else{Write-Host "Harness integrity: $(if($result.healthy){'HEALTHY'}else{'UNHEALTHY'}) ($($result.errorCount) errors)";$findings|Format-Table}
if(-not $result.healthy){exit 1}
