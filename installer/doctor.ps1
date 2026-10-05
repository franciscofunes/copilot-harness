[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [ValidateSet("commands", "skills")]
    [string]$ExpectedSpecKitLayout = "commands",

    [string[]]$ExpectedSpecKitExtensions = @("git", "bug", "assess"),

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$harnessRoot = Split-Path -Parent $PSScriptRoot
$doctorScript = Join-Path $harnessRoot "scripts\doctor.ps1"

if (-not (Test-Path -LiteralPath $doctorScript -PathType Leaf)) {
    throw "Harness doctor runtime not found: $doctorScript"
}

& $doctorScript @PSBoundParameters
