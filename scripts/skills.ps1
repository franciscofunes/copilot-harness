[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$TargetPath=".",
  [string]$Intent="",
  [string]$ChangeType="auto",
  [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$catalogPath=Join-Path $root "skills\catalog.json"
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) { throw "Skill catalog not found: $catalogPath" }
$catalog=Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
if ($catalog.schemaVersion -ne 1) { throw "Unsupported skill catalog schemaVersion '$($catalog.schemaVersion)'." }
$target=(Resolve-Path -LiteralPath $TargetPath).Path
$stack=& (Join-Path $root "scripts\detect-stack.ps1") -Path $target
$haystack=("$Intent $ChangeType").ToLowerInvariant()
$selected=@()
foreach($skill in @($catalog.skills)) {
  if ($skill.requiresMcp) { continue }
  $stackMatch=($skill.compatibleStacks -contains "all") -or (@($skill.compatibleStacks | Where-Object { $stack.DetectedStacks -contains $_ }).Count -gt 0)
  if (-not $stackMatch) { continue }
  $triggerMatch=@($skill.triggers | Where-Object { $haystack -match [regex]::Escape($_.ToLowerInvariant()) }).Count -gt 0
  if ($triggerMatch) {
    $selected += [pscustomobject]@{ Id=$skill.id; Title=$skill.title; Source=$skill.source; Authority=$skill.authority; Summary=$skill.summary }
  }
}
$result=[pscustomobject]@{
  SchemaVersion=1
  Target=$target
  Intent=$Intent
  ChangeType=$ChangeType
  DetectedStacks=@($stack.DetectedStacks)
  SelectedSkills=@($selected)
  Rules=[pscustomobject]@{
    SpecKitOwnsPlanning=$true
    PolicyGateOwnsAuthorization=$true
    VerifyOwnsEvidence=$true
    McpRequiredSkillsAllowed=$false
  }
}
if($Json){$result|ConvertTo-Json -Depth 7}else{
  Write-Host "Curated skills: $($selected.Count)"
  foreach($skill in $selected){Write-Host "- $($skill.Id): $($skill.Summary)"}
}
