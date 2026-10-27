# NVIDIA Skills installer for native Windows PowerShell 5.1+ (no Node.js/npx).
# Safe default: preview only. Use -Apply to install the pinned catalog.
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
$sourceRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($sourceRoot)
$checkout = Join-Path $sourceRoot $fields[3]
$commit = $fields[2]
$licenseNames = @('LICENSE-APACHE', 'LICENSE-CC-BY-4.0')
$names = @(Get-Content -LiteralPath $manifestPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and !$_.StartsWith('#') })
if ($names.Count -eq 0 -or @($names | Select-Object -Unique).Count -ne $names.Count) {
    throw 'NVIDIA skill list is empty or contains duplicates.'
}
foreach ($name in $names) {
    if ($name -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "Invalid NVIDIA skill name: $name" }
}

function Invoke-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($GitArgs -join ' ')" }
}

function Assert-ContainedPath([string]$candidate, [string]$parent) {
    $absolute = [IO.Path]::GetFullPath($candidate)
    $prefix = [IO.Path]::GetFullPath($parent).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (!$absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the intended source directory: $absolute"
    }
    return $absolute
}

function Assert-SourceCatalog([string]$catalogRoot) {
    foreach ($name in $names) {
        $source = Join-Path (Join-Path $catalogRoot 'skills') $name
        if (!(Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
            throw "Skill missing at pinned commit: $name"
        }
    }
    foreach ($license in $licenseNames) {
        if (!(Test-Path -LiteralPath (Join-Path $catalogRoot $license) -PathType Leaf)) {
            throw "NVIDIA license missing from source: $license"
        }
    }
}

function Assert-DirectoryAncestors([string]$destination) {
    $ancestor = Split-Path -Parent $destination
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and !$item.PSIsContainer) {
            throw "Destination ancestor is not a directory: $ancestor"
        }
        $parent = Split-Path -Parent $ancestor
        if ($parent -eq $ancestor) { break }
        $ancestor = $parent
    }
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
        $tempPath = Assert-ContainedPath "$checkout.tmp.$PID" $sourceRoot
        $checkout = Assert-ContainedPath $checkout $sourceRoot
        if (Test-Path -LiteralPath $tempPath) { throw "Temp path exists: $tempPath" }
        try {
            Invoke-Git -GitArgs @('clone', $fields[1], $tempPath)
            Invoke-Git -GitArgs @('-C', $tempPath, 'checkout', '--detach', $commit)
            Assert-SourceCatalog $tempPath
            Move-Item -LiteralPath $tempPath -Destination $checkout
        } finally {
            if (Test-Path -LiteralPath $tempPath) {
                $tempPath = Assert-ContainedPath $tempPath $sourceRoot
                Remove-Item -LiteralPath $tempPath -Recurse -Force
            }
        }
    }
}
$sourceAvailable = Test-Path -LiteralPath $checkout
if ($sourceAvailable) {
    if (!(Test-Path -LiteralPath (Join-Path $checkout '.git'))) { throw "Not a Git repository: $checkout" }
    $actual = (& git -C $checkout rev-parse HEAD)
    if ($LASTEXITCODE -ne 0 -or !$actual -or $actual.Trim() -ne $commit) {
        throw "Unexpected NVIDIA commit: $actual; expected $commit. Refusing to change existing source."
    }
    & git -C $checkout diff --quiet HEAD -- skills LICENSE-APACHE LICENSE-CC-BY-4.0
    if ($LASTEXITCODE -ne 0) {
        throw "NVIDIA source differs from the pinned commit; refusing to install modified content: $checkout"
    }
    Assert-SourceCatalog $checkout
}

function Test-IdenticalDirectory([string]$source, [string]$destination) {
    $sourceFiles = @(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
    $destFiles = @(Get-ChildItem -LiteralPath $destination -Recurse -File -Force)
    if ($sourceFiles.Count -ne $destFiles.Count) { return $false }
    $sourcePrefix = $source.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $destPrefix = $destination.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    foreach ($f in $sourceFiles) {
        $relativePath = $f.FullName.Substring($sourcePrefix.Length)
        $match = Join-Path $destPrefix $relativePath
        if (!(Test-Path -LiteralPath $match -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $match -Algorithm SHA256).Hash) { return $false }
    }
    return $true
}

$targets = if ($Target -eq 'Both') { @('Codex','Claude') } else { @($Target) }
# Preflight every target before creating any installed skill or license file.
$installs = @()
foreach ($agent in $targets) {
    $configHome = if ($agent -eq 'Codex') {
        if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    } else {
        if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    }
    $configHome = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($configHome)
    $destinationRoot = Join-Path $configHome 'skills'
    foreach ($name in $names) {
        $source = Join-Path (Join-Path $checkout 'skills') $name
        $destination = Join-Path $destinationRoot $name
        Assert-DirectoryAncestors $destination
        $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        if ($null -ne $existing) {
            if (!$sourceAvailable -or !$existing.PSIsContainer -or
                ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                !(Test-IdenticalDirectory $source $destination)) {
                throw "Skill exists with different or unverifiable content, refusing to overwrite: $destination"
            }
        }
        $installs += [PSCustomObject]@{Source=$source; Destination=$destination}
    }
    $licenseRoot = Join-Path (Join-Path (Join-Path $configHome 'licenses') 'nvidia-skills') $commit
    foreach ($license in $licenseNames) {
        $source = Join-Path $checkout $license
        $destination = Join-Path $licenseRoot $license
        Assert-DirectoryAncestors $destination
        $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        if ($null -ne $existing) {
            if (!$sourceAvailable -or $existing.PSIsContainer -or
                ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
                throw "License exists with different or unverifiable content, refusing to overwrite: $destination"
            }
        }
        $installs += [PSCustomObject]@{Source=$source; Destination=$destination}
    }
}

foreach ($item in $installs) {
    if (!$Apply) {
        Write-Host "[dry-run] copy $($item.Source) -> $($item.Destination)"
    } elseif (Test-Path -LiteralPath $item.Destination) {
        Write-Host "ok: already installed $($item.Destination)"
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $item.Destination) -Force | Out-Null
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Recurse
        Write-Host "installed: $($item.Destination)"
    }
}
Write-Host "complete: NVIDIA $($names.Count)-skill catalog for $Target ($(if ($Apply) {'apply'} else {'dry-run'}))"
