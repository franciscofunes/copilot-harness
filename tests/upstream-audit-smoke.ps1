[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root=Split-Path -Parent $PSScriptRoot
$validator=Join-Path $root "scripts\audit-upstream-sources.ps1"
$registry=Join-Path $root "skills\upstream-sources.json"
$tokens=$null;$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile($validator,[ref]$tokens,[ref]$parseErrors)|Out-Null
if(@($parseErrors).Count -gt 0){throw "Upstream audit script parse failure: $($parseErrors[0].Message)"}
$good=(& $validator -RegistryPath $registry -Json | Out-String)|ConvertFrom-Json
if(-not $good.Passed -or $good.SourceCount -lt 6){throw "Expected validated upstream source registry."}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("upstream-audit-"+[guid]::NewGuid().ToString("N")+".json")
try{
  $raw=Get-Content -LiteralPath $registry -Raw|ConvertFrom-Json
  $raw.sources[0].reviewStatus="reviewed"
  $raw|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
  $bad=(& $validator -RegistryPath $temp -Json | Out-String)|ConvertFrom-Json
  if($bad.Passed -or -not (@($bad.Errors) -match "immutable 40-character commit SHA")){throw "Unpinned reviewed source must be rejected."}
  $raw.sources[0].reviewStatus="candidate"
  $raw.sources[0].url="https://example.com/untrusted"
  $raw|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
  $bad=(& $validator -RegistryPath $temp -Json | Out-String)|ConvertFrom-Json
  if($bad.Passed -or -not (@($bad.Errors) -match "canonical GitHub HTTPS")){throw "Noncanonical source URL must be rejected."}
  $raw.sources[0].url="https://github.com/"+$raw.sources[0].repository
  $raw.sources[0].integration="execute"
  $raw|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $temp
  $bad=(& $validator -RegistryPath $temp -Json | Out-String)|ConvertFrom-Json
  if($bad.Passed -or -not (@($bad.Errors) -match "reference-only")){throw "Remote integration must be rejected."}
  Write-Host "PASS: Upstream registry validation and negative-path tests passed."
}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
