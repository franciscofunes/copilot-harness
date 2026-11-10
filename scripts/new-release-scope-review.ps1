[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$ReviewPath,
    [ValidateSet("Generate", "Validate")][string]$Mode = "Generate",
    [string]$RepoPath,
    [string]$BaselineRef = "1996bbaef67cf4815ad6c18554bffc9daa5f6ea5",
    [string]$CandidateRef = "HEAD"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Split-Path -Parent $PSScriptRoot
}
$repository = [IO.Path]::GetFullPath($RepoPath)
if (-not (Test-Path -LiteralPath $repository -PathType Container)) {
    throw "Repository directory does not exist: $repository"
}
foreach ($ref in @($BaselineRef, $CandidateRef)) {
    if ($ref -ne "HEAD" -and $ref -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Only HEAD or an immutable 40-character commit SHA is accepted: $ref"
    }
}
$baselineOutput = @(& git -C $repository rev-parse --verify "$BaselineRef^{commit}")
if ($LASTEXITCODE -ne 0 -or $baselineOutput.Count -ne 1 -or $baselineOutput[0] -notmatch '^[0-9a-f]{40}$') {
    throw "Baseline commit is unavailable locally. Fetch the published v1.1.0 baseline into this checkout before review."
}
$candidateOutput = @(& git -C $repository rev-parse --verify "$CandidateRef^{commit}")
if ($LASTEXITCODE -ne 0 -or $candidateOutput.Count -ne 1 -or $candidateOutput[0] -notmatch '^[0-9a-f]{40}$') {
    throw "Candidate commit is unavailable locally. Check out the exact release SHA first."
}
$baselineSha = [string]$baselineOutput[0]
$candidateSha = [string]$candidateOutput[0]
& git -C $repository merge-base --is-ancestor $baselineSha $candidateSha
if ($LASTEXITCODE -ne 0) {
    throw "Published baseline must be an ancestor of the candidate before a scope review can be generated."
}
$lines = @(& git -C $repository -c core.quotepath=false diff --name-status --no-renames $baselineSha $candidateSha --)
if ($LASTEXITCODE -ne 0) { throw "Cannot enumerate the exact baseline-to-candidate file diff" }

$files = @(
    foreach ($line in $lines) {
        if ($line -notmatch '^(A|M|D|T)\t([^\t\r\n]+)$') {
            throw "Unrecognized Git change record; inspect the diff manually: $line"
        }
        $status = [string]$Matches[1]
        $path = [string]$Matches[2]
        if ($path.StartsWith('"') -or $path -match '(^|/)\.\.(/|$)') {
            throw "Path requires manual scope inspection: $path"
        }
        $area = switch -Regex ($path) {
            '^\.github/workflows/' { "CI and permissions"; break }
            '^installer/' { "Installer and upgrade"; break }
            '^skills/' { "Native skills"; break }
            '^scripts/' { "Runtime scripts"; break }
            '^tests/' { "Tests"; break }
            '^evals/' { "Evaluation"; break }
            '^config/' { "Configuration"; break }
            '^docs/' { "Documentation"; break }
            '^(VERSION|CHANGELOG\.md)$' { "Release metadata"; break }
            default { "Other - inspect manually" }
        }
        [ordered]@{
            path = $path
            change = $status
            area = $area
            decision = "PENDING"
            reviewer = ""
            rationale = ""
        }
    }
)
$files = @($files | Sort-Object -Property path)
if ($files.Count -eq 0) { throw "No candidate changes since the published baseline; verify the refs." }
$destination = [IO.Path]::GetFullPath($ReviewPath)

if ($Mode -eq "Generate") {
    if (Test-Path -LiteralPath $destination) {
        throw "Refusing to overwrite an existing scope review: $destination"
    }
    $directory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw "Output directory does not exist: $directory"
    }
    $document = [ordered]@{
        schemaVersion = 1
        gate = "Q-01"
        baselineSha = $baselineSha
        candidateSha = $candidateSha
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        disposition = "PENDING - NOT APPROVED"
        scopeReviewer = ""
        reviewDateUtc = ""
        ownerApprovalReference = ""
        notice = "Inventory only; no file or release scope is approved. Record decisions from a real review and obtain separate owner sign-off."
        files = $files
    }
    if ($PSCmdlet.ShouldProcess($destination, "Write pending release scope review")) {
        $document | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $destination -Encoding utf8
        Write-Host "Generated $($files.Count) PENDING file reviews for $candidateSha. Q-01 remains NOT RUN."
    }
    return
}

if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw "Scope review file does not exist: $destination"
}
$review = Get-Content -LiteralPath $destination -Raw | ConvertFrom-Json
if ($review.schemaVersion -ne 1 -or $review.gate -ne "Q-01" -or
    $review.baselineSha -ne $baselineSha -or $review.candidateSha -ne $candidateSha) {
    throw "Stale or incompatible Q-01 scope review; regenerate for the exact candidate SHA."
}
if (@($review.files).Count -ne $files.Count) {
    throw "Scope review file count does not match the exact candidate diff."
}
$recorded = @{}
foreach ($entry in @($review.files)) {
    $path = [string]$entry.path
    if ($recorded.ContainsKey($path)) { throw "Duplicate reviewed path: $path" }
    $recorded[$path] = $entry
}
foreach ($expected in $files) {
    $entry = $recorded[[string]$expected.path]
    if ($null -eq $entry -or $entry.change -ne $expected.change -or $entry.area -ne $expected.area) {
        throw "Scope inventory drift or unreviewed file: $($expected.path)"
    }
    if ($entry.decision -ne "INCLUDE") {
        throw "Candidate file $($expected.path) is not approved for inclusion; resolve PENDING/EXCLUDE before sign-off."
    }
    if ([string]::IsNullOrWhiteSpace($entry.reviewer) -or [string]::IsNullOrWhiteSpace($entry.rationale)) {
        throw "Missing reviewer and rationale for candidate file $($expected.path)"
    }
}
if ([string]::IsNullOrWhiteSpace($review.scopeReviewer) -or
    [string]::IsNullOrWhiteSpace($review.reviewDateUtc) -or
    [string]::IsNullOrWhiteSpace($review.ownerApprovalReference)) {
    throw "Q-01 requires a named scope reviewer, review date and separate owner-approval reference."
}
Write-Host "PASS: Q-01 file-level review is internally consistent for $candidateSha ($($files.Count) files)."
Write-Warning "This validates review-file completeness only; it does NOT establish Q-01 PASS, authenticate the reviewer or authorize release."
