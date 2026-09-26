Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$policy = Join-Path $root "scripts\policy-check.ps1"
$recorder = Join-Path $root "scripts\record-evidence.ps1"

function Invoke-PolicyCase {
  param([string]$Id,[hashtable]$Args,[string]$ExpectedClass,[string]$ExpectedDecision,[int]$ExpectedExit)
  $raw = & $policy @Args -Json
  $exitCode = $LASTEXITCODE
  $actual = $raw | ConvertFrom-Json
  [pscustomobject]@{
    Id=$Id
    Passed=($actual.Classification -eq $ExpectedClass -and $actual.Decision -eq $ExpectedDecision -and $exitCode -eq $ExpectedExit)
    Expected="$ExpectedClass/$ExpectedDecision/$ExpectedExit"
    Actual="$($actual.Classification)/$($actual.Decision)/$exitCode"
  }
}

$results = @()
$results += Invoke-PolicyCase "a1-local-verification" @{ActionKind="verify"} "A1" "ALLOW" 0
$results += Invoke-PolicyCase "a3-remote-requires-intent" @{ActionKind="remote-mutate"} "A3" "REQUIRE_INTENT" 20
$results += Invoke-PolicyCase "a3-explicit-intent" @{ActionKind="remote-mutate";ExplicitIntent=$true} "A3" "ALLOW" 0
$results += Invoke-PolicyCase "a4-production-requires-approval" @{ActionKind="repo-mutate";Environment="production"} "A4" "REQUIRE_APPROVAL" 30

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-evidence-eval-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
  $ctx=Join-Path $temp "ctx.json"; $pol=Join-Path $temp "pol.json"; $ver=Join-Path $temp "ver.json"
  '{"changeType":"dotnet"}' | Set-Content $ctx
  '{"classification":"A1","decision":"ALLOW"}' | Set-Content $pol
  '{"state":"FAIL"}' | Set-Content $ver
  $raw=& $recorder -TargetPath $temp -RunId "eval-complete-evidence" -ContextPath $ctx -PolicyPath $pol -VerificationPath $ver -Json
  $record=$raw|ConvertFrom-Json
  $manifest=Get-Content $record.Manifest -Raw|ConvertFrom-Json
  $run=$record.RunDirectory
  $required=@("context.json","policy.json","verification.json","evidence.json","summary.md")
  $missing=@($required|Where-Object{-not(Test-Path (Join-Path $run $_))})
  $verification=Get-Content (Join-Path $run "verification.json") -Raw|ConvertFrom-Json
  $results += [pscustomobject]@{Id="evidence-completeness";Passed=($missing.Count -eq 0);Expected="all required artifacts";Actual=$(if($missing.Count){"missing: "+($missing -join ",")}else{"complete"})}
  $results += [pscustomobject]@{Id="fail-state-preserved";Passed=($verification.state -eq "FAIL");Expected="FAIL";Actual=$verification.state}
} finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

$failed=@($results|Where-Object{-not $_.Passed})
foreach($r in $results){Write-Host "$(if($r.Passed){'[PASS]'}else{'[FAIL]'}) $($r.Id) expected=$($r.Expected) actual=$($r.Actual)"}
if($failed.Count){throw "$($failed.Count) policy/evidence eval(s) failed."}
Write-Host "Policy & evidence eval smoke: PASS"
