[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$TargetPath=".",
  [Parameter(Mandatory=$true)][ValidateSet("propose","check","show")][string]$Action,
  [Parameter(Mandatory=$true)][string]$RunId,
  [string]$ProposalId,
  [string]$Summary="",
  [string[]]$ChangedFiles=@(),
  [string]$VerificationPath,
  [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$target=(Resolve-Path -LiteralPath $TargetPath).Path
$runRoot=Join-Path $target ".copilot-harness\runs\$RunId"
$path=Join-Path $runRoot "maker-checker.json"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
function Save($value){$value|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding UTF8}
if($Action -eq "propose"){
  if([string]::IsNullOrWhiteSpace($ProposalId)){throw "ProposalId is required."}
  if(Test-Path $path){throw "Maker proposal already exists for run '$RunId'."}
  $doc=[ordered]@{schemaVersion=1;runId=$RunId;maker=[ordered]@{proposalId=$ProposalId;summary=$Summary;changedFiles=@($ChangedFiles);recordedAtUtc=[DateTime]::UtcNow.ToString("o")};checker=$null}
  Save $doc
} elseif($Action -eq "check"){
  if(-not(Test-Path $path)){throw "Maker proposal not found for run '$RunId'."}
  if([string]::IsNullOrWhiteSpace($VerificationPath)){throw "VerificationPath is required."}
  $resolved=Resolve-Path -LiteralPath $VerificationPath -ErrorAction Stop
  $verification=Get-Content -LiteralPath $resolved.Path -Raw|ConvertFrom-Json
  $doc=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
  if($null -ne $doc.checker){throw "Checker result already exists for run '$RunId'."}
  $blocking=@($verification.Results|Where-Object{$_.State -in @("FAIL","BLOCKED","NOT RUN")})
  $decision=if($blocking.Count -eq 0 -and $verification.Ready){"ACCEPT"}else{"REJECT"}
  $doc.checker=[pscustomobject]@{source="verify.ps1";decision=$decision;ready=[bool]$verification.Ready;counts=$verification.Counts;recordedAtUtc=[DateTime]::UtcNow.ToString("o")}
  Save $doc
} elseif(-not(Test-Path $path)){throw "Maker/checker record not found for run '$RunId'."}
$result=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
if($Json){$result|ConvertTo-Json -Depth 8}else{$result}
