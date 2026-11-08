[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$SuitePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SuitePath)) {
    $SuitePath = Join-Path $root "evals/ide-adoption.json"
}
$suite = Get-Content -LiteralPath $SuitePath -Raw | ConvertFrom-Json
if ($suite.schemaVersion -ne 1 -or @($suite.cases).Count -lt 4) {
    throw "Cannot generate a review: unexpected IDE adoption suite schema or case count."
}

$destination = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $destination) {
    throw "Refusing to overwrite an existing IDE evidence file: $destination"
}
$directory = Split-Path -Parent $destination
if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    throw "Output directory does not exist: $directory. Create it explicitly before generating review evidence."
}

$seen = @{}
$reviews = @(
    foreach ($case in @($suite.cases)) {
        $id = [string]$case.id
        if ([string]::IsNullOrWhiteSpace($id) -or $seen.ContainsKey($id)) {
            throw "Invalid or duplicate IDE case: $id"
        }
        $seen[$id] = $true
        $observed = [ordered]@{}
        foreach ($check in @("installed", "discoverable", "invoked", "evidence-captured")) {
            if (@($case.checks) -notcontains $check) {
                throw "Case $id is missing required check $check"
            }
            $observed[$check] = $false
        }
        [ordered]@{
            caseId = $id
            pending = $true
            ide = [string]$case.ide
            skill = [string]$case.skill
            fixture = [string]$case.fixture
            intent = [string]$case.intent
            reviewer = ""
            evidence = ""
            ideVersion = ""
            copilotVersion = ""
            observed = $observed
        }
    }
)

$document = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    notice = "PENDING TEMPLATE ONLY. Not real IDE evidence. Confirm all checks in a real IDE, record exact versions and redacted evidence, then set pending=false."
    reviews = @($reviews)
}
if ($PSCmdlet.ShouldProcess($destination, "Write pending IDE adoption review template")) {
    $document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destination -Encoding UTF8
    Write-Host "Created $($reviews.Count) PENDING reviews at $destination. No acceptance cases have passed."
}
