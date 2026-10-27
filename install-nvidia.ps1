# NVIDIA Skills installer for native Windows PowerShell 5.1+ (no Node.js/npx).
# Safe default: preview only. Use -Apply to clone and copy selected skills.
[CmdletBinding()]
param(
    [ValidateSet('Codex','Claude','Both')]
    [string]$Target = 'Codex',
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $root 'manifests\nvidia-skills.txt'
$sourcesPath = Join-Path $root 'manifests\sources.tsv'
if (!(Test-Path -LiteralPath $manifestPath) -or !(Test-Path -LiteralPath $sourcesPath)) {
    throw 'NVIDIA manifest or source manifest missing.'
}
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required. Node.js/npx is NOT required.'
}
$record = @(Get-Content -LiteralPath $sourcesPath | Where-Object { $_.StartsWith("nvidia-skills`t") })
if ($record.Count -ne 1) { throw 'Expected exactly one nvidia-skills source record.' }
$fields = $record[0].Split("`t")
if ($fields.Count -ne 4 -or $fields[1] -ne 'https://github.com/NVIDIA/skills.git' -or
    $fields[2] -notmatch '^[0-9a-f]{40}$' -or $fields[3] -ne 'nvidia-skills') {
    throw 'Invalid NVIDIA pinned source manifest entry.'
}
$sourceRoot = if ($env:AI_AGENT_SOURCE_ROOT) { $env:AI_AGENT_SOURCE_ROOT } else { Join-Path $HOME 'src\ai-agent-sources' }
$checkout = Join-Path $sourceRoot $fields[3]
$commit = $fields[2]
$names = @(Get-Content -LiteralPath $manifestPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and !$_.StartsWith('#') })
if ($names.Count -eq 0 -or ($names | Select-Object -Unique).Count -ne $names.Count) {
    throw 'NVIDIA skill list is empty or contains duplicates.'
}
foreach ($name in $names) {
    if ($name -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "Invalid NVIDIA skill name: $name" }
}

function Invoke-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($GitArgs -join ' ')" }
}

if (!$Apply) {
    if (!(Test-Path -LiteralPath $checkout)) {
        Write-Host "[dry-run] git clone $($fields[1]) $checkout"
        Write-Host "[dry-run] git -C $checkout checkout --detach $commit"
    } else {
        Write-Host "[dry-run] verify pinned checkout $checkout ($commit)"
    }
} else {
    if (!(Test-Path -LiteralPath $checkout)) {
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
        $tempPath = "$checkout.tmp.$PID"
        if (Test-Path -LiteralPath $tempPath) { throw "Temp path exists: $tempPath" }
        try {
            Invoke-Git -GitArgs @('clone', $fields[1], $tempPath)
            Invoke-Git -GitArgs @('-C', $tempPath, 'checkout', '--detach', $commit)
            Move-Item -LiteralPath $tempPath -Destination $checkout
        } finally {
            if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Recurse -Force }
        }
    }
    if (!(Test-Path -LiteralPath (Join-Path $checkout '.git'))) { throw "Not a Git repository: $checkout" }
    $actual = (& git -C $checkout rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $commit) {
        throw "Unexpected NVIDIA commit: $actual; expected $commit. Refusing to change existing source."
    }
    foreach ($name in $names) {
        $source = Join-Path (Join-Path $checkout 'skills') $name
        if (!(Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw "Skill missing at pinned commit: $name" }
    }
}

function Test-IdenticalDirectory([string]$source, [string]$destination) {
    $sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File)
    $destFiles = @(Get-ChildItem -LiteralPath $destination -Recurse -File)
    if ($sourceFiles.Count -ne $destFiles.Count) { return $false }
    $sourceRoot = $source.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $destRoot = $destination.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    foreach ($f in $sourceFiles) {
        $relativePath = $f.FullName.Substring($sourceRoot.Length)
        $match = Join-Path $destRoot $relativePath
        if (!(Test-Path -LiteralPath $match -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $match -Algorithm SHA256).Hash) { return $false }
    }
    return $true
}

$targets = if ($Target -eq 'Both') { @('Codex','Claude') } else { @($Target) }
foreach ($agent in $targets) {
    $configHome = if ($agent -eq 'Codex') {
        if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    } else {
        if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    }
    $destinationRoot = Join-Path $configHome 'skills'
    foreach ($name in $names) {
        $source = Join-Path (Join-Path $checkout 'skills') $name
        $destination = Join-Path $destinationRoot $name
        if (!$Apply) { Write-Host "[dry-run] copy $source -> $destination"; continue }
        if (Test-Path -LiteralPath $destination) {
            if ((Get-Item -LiteralPath $destination).PSIsContainer -and (Test-IdenticalDirectory $source $destination)) {
                Write-Host "ok: already installed $agent/$name"
                continue
            }
            throw "Skill exists with different content, refusing to overwrite: $destination"
        }
        New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse
        Write-Host "installed: $agent/$name"
    }
}
Write-Host "complete: NVIDIA $($names.Count)-skill selection for $Target ($(if ($Apply) {'apply'} else {'dry-run'}))"
