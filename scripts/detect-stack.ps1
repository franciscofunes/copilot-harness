[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $Path).Path

function Test-AnyFile {
    param([string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        if (Get-ChildItem -Path $root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1) {
            return $true
        }
    }

    return $false
}

function Test-FileContent {
    param(
        [string[]]$Patterns,
        [string[]]$Needles
    )

    foreach ($pattern in $Patterns) {
        $files = Get-ChildItem -Path $root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $text) { continue }

            foreach ($needle in $Needles) {
                if ($text -match $needle) { return $true }
            }
        }
    }

    return $false
}

$signals = [ordered]@{
    DotNet = (Test-AnyFile @("*.sln", "*.slnx", "*.csproj", "global.json"))
    Angular = (Test-AnyFile @("angular.json"))
    SqlServer = (
        (Test-AnyFile @("*.sqlproj")) -or
        (Test-FileContent @("*.csproj", "*.props", "*.json") @("Microsoft\.Data\.SqlClient", "System\.Data\.SqlClient", "SqlServer"))
    )
    MongoDb = (Test-FileContent @("*.csproj", "package.json", "*.json") @("MongoDB\.Driver", "mongodb", "mongoose"))
    Snowflake = (Test-FileContent @("*.csproj", "package.json", "*.py", "*.yml", "*.yaml", "*.toml") @("Snowflake", "snowflake-connector", "snowflake-sdk"))
    Parquet = (
        (Test-AnyFile @("*.parquet")) -or
        (Test-FileContent @("*.csproj", "package.json", "*.py") @("Parquet\.Net", "ParquetSharp", "parquetjs", "pyarrow", "fastparquet"))
    )
    AzureDevOps = (
        (Test-AnyFile @("azure-pipelines.yml", "azure-pipelines.yaml")) -or
        (Test-AnyFile @("*.pipeline.yml", "*.pipeline.yaml"))
    )
    GitHubActions = (Test-Path -LiteralPath (Join-Path $root ".github\workflows"))
    JFrog = (
        (Test-AnyFile @("jfrog-cli.conf", ".jfrog", "*.jfrog.yml", "*.jfrog.yaml")) -or
        (Test-FileContent @("*.yml", "*.yaml", "*.ps1", "*.sh") @("jfrog", "\bjf\s"))
    )
}

$detected = @($signals.GetEnumerator() | Where-Object Value | ForEach-Object Key)

$result = [pscustomobject]@{
    RepositoryRoot = $root
    DetectedStacks = $detected
    Signals = [pscustomobject]$signals
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}
