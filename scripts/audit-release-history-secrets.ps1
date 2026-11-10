[CmdletBinding()]
param(
    [string]$RepositoryPath,
    [string]$ReceiptPath,
    [switch]$IncludeAllRefs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
    $RepositoryPath = Split-Path -Parent $PSScriptRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryPath)
if (-not (Test-Path -LiteralPath $repository -PathType Container)) {
    throw "Repository path does not exist: $repository"
}
$shallow = @(& git -C $repository rev-parse --is-shallow-repository)
if ($LASTEXITCODE -ne 0 -or @($shallow).Count -ne 1 -or $shallow[0].Trim() -ne "false") {
    throw "A complete local Git history is required. Fetch with depth 0 before running Q-08 history checks."
}
$shaOutput = @(& git -C $repository rev-parse --verify "HEAD^{commit}")
if ($LASTEXITCODE -ne 0 -or @($shaOutput).Count -ne 1 -or $shaOutput[0] -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot resolve exact candidate commit"
}
$candidateSha = [string]$shaOutput[0]

# This bounded heuristic inspects lines ADDED in text patches across reachable history.
# It never writes the matched line, token or surrounding source to the receipt or logs.
$rules = [ordered]@{
    github_token = '(?<![A-Za-z0-9])(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'
    aws_access_key = '(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}'
    private_key_header = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
}
$gitArguments = @("-C", $repository, "-c", "core.quotepath=false", "log",
    "--format=COMMIT:%H", "--patch", "--no-ext-diff", "--no-textconv",
    "--no-renames", "--unified=0")
if ($IncludeAllRefs) { $gitArguments += "--all" } else { $gitArguments += "HEAD" }
$patchLines = @(& git @gitArguments)
if ($LASTEXITCODE -ne 0) { throw "Cannot read Git patch history" }

$commit = ""
$path = ""
$examinedAddedLines = 0
$examinedCommits = 0
$totalFindings = 0
$findings = @(
    foreach ($line in $patchLines) {
        if ($line -match '^COMMIT:([0-9a-f]{40})$') {
            $commit = $Matches[1]
            $examinedCommits++
            $path = ""
            continue
        }
        if ($line -match '^diff --git a/(.+) b/(.+)$') {
            $path = [string]$Matches[2]
            continue
        }
        if (-not $line.StartsWith("+") -or $line.StartsWith("+++") -or
            [string]::IsNullOrWhiteSpace($commit) -or [string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $examinedAddedLines++
        $addedLine = $line.Substring(1)
        foreach ($rule in $rules.GetEnumerator()) {
            if ([regex]::IsMatch($addedLine, $rule.Value)) {
                $totalFindings++
                if ($totalFindings -le 100) {
                    [ordered]@{
                        rule = [string]$rule.Key
                        commitSha = $commit
                        path = $path
                    }
                }
            }
        }
    }
)
if ($examinedCommits -lt 1) { throw "History scan found no commits; evidence would be misleading." }
$receipt = [ordered]@{
    schemaVersion = 1
    candidateSha = $candidateSha
    scope = $(if ($IncludeAllRefs) { "all locally reachable refs" } else { "candidate HEAD ancestry" })
    commitsExamined = $examinedCommits
    addedLinesExamined = $examinedAddedLines
    highConfidenceFindings = $totalFindings
    findingsTruncated = ($totalFindings -gt 100)
    findings = $findings
    outcome = $(if ($totalFindings -gt 0) { "REVIEW_REQUIRED" } else { "NO_HIGH_CONFIDENCE_MATCHES" })
    limitations = "Heuristic on Git text-patch additions only; does not cover binary blobs, credential validity, inaccessible refs, external systems or full secret discovery."
    q08 = "NOT RUN - requires independent human security and provenance sign-off"
    releaseGate = "NO-GO"
}
if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
    $destination = [IO.Path]::GetFullPath($ReceiptPath)
    $directory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $destination -Encoding utf8
}
if ($totalFindings -gt 0) {
    Write-Warning "Potential credential history matches: $totalFindings; values deliberately withheld. Review the redacted receipt privately."
    exit 1
}
Write-Host "PASS: $examinedCommits commits and $examinedAddedLines added text lines scanned for bounded credential patterns at $candidateSha."
Write-Warning "This is not a comprehensive secret scan or Q-08 security approval. Release remains NO-GO."
exit 0
