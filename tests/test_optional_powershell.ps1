# Offline integration checks for the PowerShell optional-package entry point.
# Requires Python 3.10+ and Git. No agent homes or environment variables are changed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw "Assertion failed: $Message" }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot 'install-optional.ps1'
$shellExecutable = (Get-Process -Id $PID).Path
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('ai agent optional tests-' + [Guid]::NewGuid().ToString('N'))))
$nativeWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

function Get-FixturePaths([string]$CaseName) {
    $caseRoot = Join-Path $testRoot $CaseName
    return @{
        SourceRoot = Join-Path $caseRoot 'source root'
        RuntimeRoot = Join-Path $caseRoot 'runtime root'
        CodexHome = Join-Path $caseRoot 'codex home'
        ClaudeHome = Join-Path $caseRoot 'claude home'
    }
}

function Invoke-Installer([hashtable]$Paths, [string[]]$ExtraArguments) {
    # A separate PowerShell process checks the wrapper's actual process exit code.
    # Expected stderr from Python failures must not terminate this test process.
    $ErrorActionPreference = 'Continue'
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $installer,
        '-SourceRoot', $Paths.SourceRoot, '-RuntimeRoot', $Paths.RuntimeRoot,
        '-CodexHome', $Paths.CodexHome, '-ClaudeHome', $Paths.ClaudeHome
    ) + $ExtraArguments
    $output = (& $shellExecutable @arguments 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $exitCode = $LASTEXITCODE
    return @{ ExitCode = $exitCode; Output = $output }
}

function Assert-NoTargets([hashtable]$Paths, [string]$Message, [switch]$AllowSource) {
    $keys = @('RuntimeRoot', 'CodexHome', 'ClaudeHome')
    if (!$AllowSource) { $keys += 'SourceRoot' }
    foreach ($key in $keys) {
        Assert-True (!(Test-Path -LiteralPath $Paths[$key])) "$Message ($key)"
    }
}

function Invoke-FixtureGit([string]$Directory, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    $output = (& git -C $Directory @Arguments 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $output" }
    return $output.Trim()
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null

    # No checkout, network fetch, target home or runtime directory is needed to preview.
    foreach ($explicitDryRun in @($false, $true)) {
        $caseName = if ($explicitDryRun) { 'explicit dry run' } else { 'default dry run' }
        $paths = Get-FixturePaths $caseName
        $arguments = @('-Package', 'Hallmark', '-Target', 'Both')
        if ($explicitDryRun) { $arguments += '-DryRun' }
        $result = Invoke-Installer $paths $arguments
        Assert-True ($result.ExitCode -eq 0) "$caseName succeeds: $($result.Output)"
        Assert-True ($result.Output -match '\[dry-run\] copy') "$caseName reports planned copies"
        Assert-True ($result.Output -match 'complete: optional hallmark \(dry-run\)') "$caseName reports completion"
        foreach ($agentHome in @($paths.CodexHome, $paths.ClaudeHome)) {
            $destination = Join-Path (Join-Path $agentHome 'skills') 'hallmark'
            Assert-True ($result.Output.Contains($destination)) "$caseName preserves paths with spaces"
        }
        Assert-NoTargets $paths "$caseName creates nothing"
        Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Force).Count -eq 0) "$caseName leaves the fixture root empty"
    }

    $paths = Get-FixturePaths 'conflicting flags'
    $result = Invoke-Installer $paths @('-Package', 'Hallmark', '-Target', 'Both', '-Apply', '-DryRun')
    Assert-True ($result.ExitCode -ne 0) 'Apply and DryRun are mutually exclusive'
    Assert-True ($result.Output -match 'not allowed with argument|mutually exclusive') "conflicting flags explain the error: $($result.Output)"
    Assert-NoTargets $paths 'conflicting flags create nothing'
    Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Force).Count -eq 0) 'invalid arguments leave the fixture root empty'

    if ($nativeWindows) {
        foreach ($package in @('Codync', 'All')) {
            foreach ($mode in @('-DryRun', '-Apply')) {
                $paths = Get-FixturePaths ("unsupported $package $mode")
                $result = Invoke-Installer $paths @('-Package', $package, '-Target', 'Both', $mode)
                Assert-True ($result.ExitCode -ne 0) "$package $mode refuses the missing Windows host asset"
                Assert-True ($result.Output -match 'no pinned host asset for windows-.*WSL') "Windows refusal gives the supported alternative: $($result.Output)"
                Assert-NoTargets $paths "$package $mode refuses before writing anything"
                Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Force).Count -eq 0) 'unsupported packages leave the fixture root empty'
            }
        }
    } else {
        Write-Host 'SKIP: native Windows Codync/All refusal requires Windows.'
    }

    # Supply a real, clean local checkout at the pinned destination. The installer
    # reads this fixture; it never needs to clone the repository named in the manifest.
    Assert-True ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) 'Git is required for the offline fixture'
    $fixture = Join-Path $testRoot 'local git fixture'
    $skillRoot = Join-Path (Join-Path $fixture 'skills') 'hallmark'
    $themeRoot = Join-Path $skillRoot 'themes'
    New-Item -ItemType Directory -Path $themeRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $skillRoot 'SKILL.md'), "---`nname: hallmark`ndescription: Offline fixture`n---`n", $utf8WithoutBom)
    [IO.File]::WriteAllText((Join-Path $themeRoot 'example.md'), "Nested theme fixture`n", $utf8WithoutBom)
    [IO.File]::WriteAllText((Join-Path $fixture 'LICENSE'), "Fixture license`n", $utf8WithoutBom)
    Invoke-FixtureGit $fixture @('init') | Out-Null
    Invoke-FixtureGit $fixture @('-c', 'core.autocrlf=false', 'add', '.') | Out-Null
    Invoke-FixtureGit $fixture @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-m', 'offline fixture') | Out-Null
    $commit = Invoke-FixtureGit $fixture @('rev-parse', 'HEAD')
    Assert-True ($commit -match '^[0-9a-f]{40}$') 'fixture has a full source commit'

    $paths = Get-FixturePaths 'local apply'
    New-Item -ItemType Directory -Path $paths.SourceRoot -Force | Out-Null
    $checkout = Join-Path $paths.SourceRoot ("hallmark-$commit")
    Move-Item -LiteralPath $fixture -Destination $checkout
    $manifestPath = Join-Path $testRoot 'fixture manifest.json'
    $manifest = @{
        schema_version = 1
        packages = @{
            hallmark = @{
                kind = 'skill'
                repository = 'https://github.com/Nutlope/hallmark.git'
                commit = $commit
                skill_path = 'skills/hallmark'
                skill_name = 'hallmark'
                license_files = @('LICENSE')
            }
        }
    }
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8WithoutBom)

    $arguments = @('-Package', 'Hallmark', '-Target', 'Both', '-Manifest', $manifestPath)
    $result = Invoke-Installer $paths $arguments
    Assert-True ($result.ExitCode -eq 0) "local checkout preview succeeds: $($result.Output)"
    Assert-True ($result.Output -match '\[dry-run\] copy') 'verified-source preview still reports copies'
    Assert-NoTargets $paths 'verified-source preview creates no targets' -AllowSource

    $result = Invoke-Installer $paths ($arguments + '-Apply')
    Assert-True ($result.ExitCode -eq 0) "local fixture apply succeeds: $($result.Output)"
    Assert-True ($result.Output -match 'complete: optional hallmark \(apply\)') 'apply reports completion'
    $sentinelPaths = @()
    foreach ($agentHome in @($paths.CodexHome, $paths.ClaudeHome)) {
        $installedRoot = Join-Path (Join-Path $agentHome 'skills') 'hallmark'
        foreach ($relativePath in @('SKILL.md', 'themes/example.md')) {
            $installedFile = Join-Path $installedRoot $relativePath
            $sourceFile = Join-Path (Join-Path (Join-Path $checkout 'skills') 'hallmark') $relativePath
            Assert-True (Test-Path -LiteralPath $installedFile -PathType Leaf) "Both preserves $relativePath"
            Assert-True ((Get-FileHash -LiteralPath $installedFile).Hash -eq (Get-FileHash -LiteralPath $sourceFile).Hash) "Both copies complete content: $relativePath"
            $sentinelPaths += $installedFile
        }
        $licensePath = Join-Path (Join-Path (Join-Path (Join-Path $agentHome 'licenses') 'hallmark') $commit) 'LICENSE'
        Assert-True ((Get-FileHash -LiteralPath $licensePath).Hash -eq (Get-FileHash -LiteralPath (Join-Path $checkout 'LICENSE')).Hash) 'source license is copied under its SHA'
        $sentinelPaths += $licensePath
        Assert-True (!(Test-Path -LiteralPath (Join-Path $agentHome 'settings.json'))) 'skill installation does not create agent settings'
    }
    Assert-True (!(Test-Path -LiteralPath $paths.RuntimeRoot)) 'Hallmark does not create a runtime directory'

    $sentinelTime = [DateTime]::SpecifyKind([DateTime]'2001-02-03T04:05:06', [DateTimeKind]::Utc)
    foreach ($path in $sentinelPaths) { [IO.File]::SetLastWriteTimeUtc($path, $sentinelTime) }
    $result = Invoke-Installer $paths ($arguments + '-Apply')
    Assert-True ($result.ExitCode -eq 0) "repeated apply succeeds: $($result.Output)"
    foreach ($path in $sentinelPaths) {
        Assert-True ([IO.File]::GetLastWriteTimeUtc($path) -eq $sentinelTime) 'repeated apply preserves existing identical files'
    }

    Write-Host 'Optional PowerShell offline integration tests passed (Hallmark, both agents, paths with spaces).'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $tempPrefix = $tempBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolvedRoot -ne $testRoot -or !$resolvedRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedRoot) -notmatch '^ai agent optional tests-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected fixture path: $resolvedRoot"
        }
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
