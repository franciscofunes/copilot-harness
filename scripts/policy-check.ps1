[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("read", "verify", "repo-mutate", "remote-mutate", "destructive")]
    [string]$ActionKind,

    [ValidateSet("local", "shared", "production")]
    [string]$Environment = "local",

    [string]$Target = "",

    [switch]$SecuritySensitive,

    [switch]$Irreversible,

    [switch]$ExplicitIntent,

    [switch]$ImmediateApproval,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$classification = switch ($ActionKind) {
    "read"          { "A0" }
    "verify"        { "A1" }
    "repo-mutate"   { "A2" }
    "remote-mutate" { "A3" }
    "destructive"   { "A4" }
}

if ($Environment -eq "production" -or $SecuritySensitive -or $Irreversible) {
    $classification = "A4"
} elseif ($Environment -eq "shared" -and $classification -in @("A0", "A1", "A2")) {
    $classification = "A3"
}

$decision = "ALLOW"
$reason = "Action is within the autonomous execution boundary."
$requiresApproval = $false

switch ($classification) {
    "A3" {
        if (-not $ExplicitIntent) {
            $decision = "REQUIRE_INTENT"
            $reason = "Remote/shared-state mutation requires explicit user intent or an established approved workflow."
            $requiresApproval = $true
        }
    }
    "A4" {
        if (-not $ImmediateApproval) {
            $decision = "REQUIRE_APPROVAL"
            $reason = "Production, destructive, irreversible or security-sensitive action requires immediate explicit human approval."
            $requiresApproval = $true
        }
    }
}

$result = [pscustomobject]@{
    Classification = $classification
    Decision = $decision
    ActionKind = $ActionKind
    Environment = $Environment
    Target = $Target
    SecuritySensitive = [bool]$SecuritySensitive
    Irreversible = [bool]$Irreversible
    ExplicitIntent = [bool]$ExplicitIntent
    ImmediateApproval = [bool]$ImmediateApproval
    RequiresApproval = $requiresApproval
    Reason = $reason
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
} else {
    Write-Host "Copilot Harness Policy Gate"
    Write-Host ("Classification : {0}" -f $result.Classification)
    Write-Host ("Decision       : {0}" -f $result.Decision)
    Write-Host ("Action         : {0}" -f $result.ActionKind)
    Write-Host ("Environment    : {0}" -f $result.Environment)
    if (-not [string]::IsNullOrWhiteSpace($result.Target)) {
        Write-Host ("Target         : {0}" -f $result.Target)
    }
    Write-Host ("Reason         : {0}" -f $result.Reason)
}

switch ($decision) {
    "ALLOW" { exit 0 }
    "REQUIRE_INTENT" { exit 20 }
    "REQUIRE_APPROVAL" { exit 30 }
    default { exit 40 }
}
