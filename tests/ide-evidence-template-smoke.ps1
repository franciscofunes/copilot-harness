[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $root "scripts/new-ide-adoption-review.ps1"
$evaluator = Join-Path $root "scripts/eval-ide-adoption.ps1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ide-review-template-" + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $target = Join-Path $tempRoot "pending-review.json"
    & $generator -OutputPath $target | Out-Null
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Generator did not create template" }

    $template = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
    $suite = Get-Content -LiteralPath (Join-Path $root "evals/ide-adoption.json") -Raw | ConvertFrom-Json
    if (@($template.reviews).Count -ne @($suite.cases).Count) { throw "Generated template does not cover all IDE cases" }
    foreach ($review in @($template.reviews)) {
        if ($review.pending -ne $true -or -not [string]::IsNullOrEmpty($review.reviewer) -or
            -not [string]::IsNullOrEmpty($review.evidence)) { throw "Generated review is not safely pending" }
        foreach ($check in @("installed", "discoverable", "invoked", "evidence-captured")) {
            if ($review.observed.$check -ne $false) { throw "Generated template pre-approves $check" }
        }
    }

    $report = (& $evaluator -ResultsPath $target -Json | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 1 -or $report.Passed -or $report.Reviewed -ne 0 -or
        $report.Unreviewed -ne @($suite.cases).Count) {
        throw "Pending template must be evaluated as unreviewed and nonpassing"
    }

    $before = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    $blocked = $false
    try {
        & $generator -OutputPath $target | Out-Null
    } catch {
        if ($_.Exception.Message -match "Refusing to overwrite") { $blocked = $true } else { throw }
    }
    if (-not $blocked -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $before) {
        throw "Generator overwrote existing reviewer data"
    }

    $template.reviews[0].pending = $false
    $template.reviews[0].reviewer = "synthetic-test-reviewer"
    $template.reviews[0].evidence = "fixture-not-real"
    $template.reviews[0].ideVersion = "fixture"
    $template.reviews[0].copilotVersion = "fixture"
    foreach ($check in @("installed", "discoverable", "invoked", "evidence-captured")) {
        $template.reviews[0].observed.PSObject.Properties[$check].Value = $true
    }
    $template | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $target -Encoding UTF8
    $partial = (& $evaluator -ResultsPath $target -Json | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 1 -or $partial.Passed -or $partial.Reviewed -ne 1 -or
        $partial.Unreviewed -ne (@($suite.cases).Count - 1)) {
        throw "Partially completed fixture incorrectly passed all cases"
    }

    $template.reviews[1].observed.installed = $true
    $template | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $target -Encoding UTF8
    $unsafeRejected = $false
    try {
        & $evaluator -ResultsPath $target -Json | Out-Null
    } catch {
        if ($_.Exception.Message -match "Pending case") { $unsafeRejected = $true } else { throw }
    }
    if (-not $unsafeRejected) { throw "Pending case with a positive claim must fail closed" }

    Write-Host "PASS: all Q-07 cases generated PENDING; template scoring, partial review, overwrite refusal and unsafe pending data verified."
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

# The negative scorer fixtures intentionally exit 1; do not leak that into the CI job.
$global:LASTEXITCODE = 0
exit 0
