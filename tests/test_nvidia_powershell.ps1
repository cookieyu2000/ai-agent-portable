# Offline regression checks for the native Windows PowerShell 5.1+ installer.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw "Assertion failed: $Message" }
}

function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    $caught = $null
    try { & $Action } catch { $caught = $_ }
    Assert-True ($null -ne $caught) "$Message (expected an error)"
    Assert-True ($caught.Exception.Message -match $Pattern) "$Message (unexpected error: $($caught.Exception.Message))"
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot 'install-nvidia.ps1'
$names = @(Get-Content -LiteralPath (Join-Path $repositoryRoot 'manifests/nvidia-skills.txt') |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -and !$_.StartsWith('#') })
Assert-True ($names.Count -eq 417) 'the pinned catalog contains all 417 skills'
$sourceRecords = @(Get-Content -LiteralPath (Join-Path $repositoryRoot 'manifests/sources.tsv') |
    Where-Object { $_.StartsWith("nvidia-skills`t") })
Assert-True ($sourceRecords.Count -eq 1) 'exactly one NVIDIA source is pinned'
$sourceFields = $sourceRecords[0].Split("`t")
$pinnedCommit = $sourceFields[2]
Assert-True ($pinnedCommit -match '^[0-9a-f]{40}$') 'the source commit is a full SHA'
$licenseNames = @('LICENSE-APACHE', 'LICENSE-CC-BY-4.0')
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('ai-agent-nvidia-tests-' + [Guid]::NewGuid().ToString('N'))))
$savedEnvironment = @{}
foreach ($variableName in @('AI_AGENT_SOURCE_ROOT', 'CODEX_HOME', 'CLAUDE_CONFIG_DIR', 'AI_AGENT_TEST_NVIDIA_COMMIT', 'AI_AGENT_TEST_NVIDIA_DIRTY_SOURCE')) {
    $savedEnvironment[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process')
}
$existingGitFunction = Get-Item -LiteralPath Function:\git -ErrorAction SilentlyContinue
$savedGitFunction = if ($null -ne $existingGitFunction) { $existingGitFunction.ScriptBlock } else { $null }
$existingLastExitCode = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
$hadLastExitCode = $null -ne $existingLastExitCode
$savedLastExitCode = if ($hadLastExitCode) { $existingLastExitCode.Value } else { $null }

function Set-FixtureTargets([string]$CaseName) {
    $caseRoot = Join-Path $testRoot $CaseName
    $env:CODEX_HOME = Join-Path $caseRoot 'codex'
    $env:CLAUDE_CONFIG_DIR = Join-Path $caseRoot 'claude'
}

function Assert-NoTargets([string]$Message) {
    Assert-True (!(Test-Path -LiteralPath $env:CODEX_HOME)) "$Message (Codex)"
    Assert-True (!(Test-Path -LiteralPath $env:CLAUDE_CONFIG_DIR)) "$Message (Claude)"
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $env:AI_AGENT_TEST_NVIDIA_COMMIT = $pinnedCommit
    $env:AI_AGENT_TEST_NVIDIA_DIRTY_SOURCE = $null
    function global:git {
        $global:LASTEXITCODE = 0
        if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
            $env:AI_AGENT_TEST_NVIDIA_COMMIT
            return
        }
        if ($args -contains 'diff' -and $args -contains '--quiet') {
            if ($env:AI_AGENT_TEST_NVIDIA_DIRTY_SOURCE -eq '1') { $global:LASTEXITCODE = 1 }
            return
        }
        $global:LASTEXITCODE = 91
        throw "Unexpected Git operation in offline fixture: $($args -join ' ')"
    }

    # An absent checkout may be previewed without cloning or creating config homes.
    $env:AI_AGENT_SOURCE_ROOT = Join-Path $testRoot 'absent-sources'
    Set-FixtureTargets 'dry-run-absent'
    & $installer -Target Both *> $null
    Assert-True (!(Test-Path -LiteralPath $env:AI_AGENT_SOURCE_ROOT)) 'default dry-run never creates a source directory'
    Assert-NoTargets 'default dry-run never creates agent config homes'

    $env:AI_AGENT_SOURCE_ROOT = Join-Path $testRoot 'sources'
    $checkout = Join-Path $env:AI_AGENT_SOURCE_ROOT $sourceFields[3]
    New-Item -ItemType Directory -Path (Join-Path $checkout '.git') -Force | Out-Null
    foreach ($name in $names) {
        $skillRoot = Join-Path (Join-Path $checkout 'skills') $name
        New-Item -ItemType Directory -Path (Join-Path $skillRoot 'references') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillRoot 'SKILL.md') -Value "fixture skill: $name" -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $skillRoot 'references/fixture.txt') -Value "fixture reference: $name" -Encoding UTF8
    }
    foreach ($licenseName in $licenseNames) {
        Set-Content -LiteralPath (Join-Path $checkout $licenseName) -Value "fixture license: $licenseName" -Encoding UTF8
    }

    Set-FixtureTargets 'dirty-source'
    $env:AI_AGENT_TEST_NVIDIA_DIRTY_SOURCE = '1'
    try {
        Assert-Throws { & $installer -Target Both -Apply *> $null } 'dirty|modif|changed|local changes|git failed|diff|refusing' 'tracked source changes cannot masquerade as the pinned commit'
        Assert-NoTargets 'a modified source creates no agent config homes'
    } finally { $env:AI_AGENT_TEST_NVIDIA_DIRTY_SOURCE = $null }

    # Relative overrides resolve from PowerShell's location after Set-Location.
    # The process working directory may still be the directory that launched PS.
    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $testRoot
        $env:AI_AGENT_SOURCE_ROOT = 'sources'
        $env:CODEX_HOME = Join-Path 'relative-targets' 'codex'
        $env:CLAUDE_CONFIG_DIR = Join-Path 'relative-targets' 'claude'
        $relativePreview = (& $installer -Target Both 6>&1 | ForEach-Object { $_.ToString() }) -join "`n"
        $expectedSource = Join-Path (Join-Path $checkout 'skills') $names[0]
        Assert-True ($relativePreview.Contains($expectedSource)) 'relative source override follows PowerShell current location'
        foreach ($relativeConfigHome in @($env:CODEX_HOME, $env:CLAUDE_CONFIG_DIR)) {
            $expectedDestination = Join-Path (Join-Path (Join-Path $testRoot $relativeConfigHome) 'skills') $names[0]
            Assert-True ($relativePreview.Contains($expectedDestination)) 'relative config override follows PowerShell current location'
        }
        Assert-NoTargets 'relative default dry-run creates no agent config homes'
    } finally {
        Set-Location -LiteralPath $previousLocation.Path
        $env:AI_AGENT_SOURCE_ROOT = Split-Path -Parent $checkout
    }

    Set-FixtureTargets 'installed'
    & $installer -Target Both *> $null
    Assert-NoTargets 'dry-run with a verified checkout never creates agent config homes'
    & $installer -Target Both -Apply *> $null
    foreach ($configHome in @($env:CODEX_HOME, $env:CLAUDE_CONFIG_DIR)) {
        $skillsRoot = Join-Path $configHome 'skills'
        $installedSkills = @(Get-ChildItem -LiteralPath $skillsRoot -Directory)
        Assert-True ($installedSkills.Count -eq 417) "Both installs the complete catalog in $configHome"
        foreach ($name in $names) {
            $source = Join-Path (Join-Path $checkout 'skills') $name
            $destination = Join-Path $skillsRoot $name
            foreach ($relativePath in @('SKILL.md', 'references/fixture.txt')) {
                $installedFile = Join-Path $destination $relativePath
                Assert-True (Test-Path -LiteralPath $installedFile -PathType Leaf) "nested asset survives: $name/$relativePath"
                Assert-True ((Get-Content -LiteralPath $installedFile -Raw) -ceq
                    (Get-Content -LiteralPath (Join-Path $source $relativePath) -Raw)) "copied content matches: $name/$relativePath"
            }
        }
        $licenseRoot = Join-Path (Join-Path $configHome 'licenses/nvidia-skills') $pinnedCommit
        foreach ($licenseName in $licenseNames) {
            $licenseFile = Join-Path $licenseRoot $licenseName
            Assert-True (Test-Path -LiteralPath $licenseFile -PathType Leaf) "license is retained under its source SHA: $licenseName"
            Assert-True ((Get-Content -LiteralPath $licenseFile -Raw) -ceq
                (Get-Content -LiteralPath (Join-Path $checkout $licenseName) -Raw)) "license content matches: $licenseName"
        }
    }

    # Identical existing installs must stay untouched, including file timestamps.
    $sentinelPaths = @()
    foreach ($configHome in @($env:CODEX_HOME, $env:CLAUDE_CONFIG_DIR)) {
        $sentinelPaths += Join-Path (Join-Path (Join-Path $configHome 'skills') $names[-1]) 'references/fixture.txt'
        $sentinelPaths += Join-Path (Join-Path (Join-Path $configHome 'licenses/nvidia-skills') $pinnedCommit) $licenseNames[0]
    }
    $sentinelTime = [DateTime]::SpecifyKind([DateTime]'2001-02-03T04:05:06', [DateTimeKind]::Utc)
    foreach ($sentinelPath in $sentinelPaths) { [IO.File]::SetLastWriteTimeUtc($sentinelPath, $sentinelTime) }
    & $installer -Target Both -Apply *> $null
    foreach ($sentinelPath in $sentinelPaths) {
        Assert-True ([IO.File]::GetLastWriteTimeUtc($sentinelPath) -eq $sentinelTime) 'rerunning Apply preserves existing identical files'
    }

    # A conflict at the very end of Claude's catalog must block writes to Codex too.
    Set-FixtureTargets 'late-conflict'
    $conflictRoot = Join-Path (Join-Path $env:CLAUDE_CONFIG_DIR 'skills') $names[-1]
    New-Item -ItemType Directory -Path $conflictRoot -Force | Out-Null
    $conflictFile = Join-Path $conflictRoot 'SKILL.md'
    Set-Content -LiteralPath $conflictFile -Value 'keep existing user content' -Encoding UTF8
    $conflictContent = Get-Content -LiteralPath $conflictFile -Raw
    Assert-Throws { & $installer -Target Both -Apply *> $null } 'different content|refusing to overwrite' 'a late conflict rejects the whole batch'
    Assert-True (!(Test-Path -LiteralPath $env:CODEX_HOME)) 'a late Claude conflict creates no Codex files'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $env:CLAUDE_CONFIG_DIR 'skills')).Count -eq 1) 'a late conflict creates no other Claude skills'
    Assert-True ((Get-Content -LiteralPath $conflictFile -Raw) -ceq $conflictContent) 'existing conflicting content is preserved'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $env:CLAUDE_CONFIG_DIR 'licenses'))) 'a late conflict creates no licenses'

    # A same-name regular file is also a protected collision, not a copy target.
    Set-FixtureTargets 'file-conflict'
    $fileConflict = Join-Path (Join-Path $env:CODEX_HOME 'skills') $names[0]
    New-Item -ItemType Directory -Path (Split-Path -Parent $fileConflict) -Force | Out-Null
    Set-Content -LiteralPath $fileConflict -Value 'keep existing file' -Encoding UTF8
    $fileConflictContent = Get-Content -LiteralPath $fileConflict -Raw
    Assert-Throws { & $installer -Target Both -Apply *> $null } 'different content|refusing to overwrite' 'same-name files cannot be overwritten'
    Assert-True ((Get-Content -LiteralPath $fileConflict -Raw) -ceq $fileConflictContent) 'a same-name file keeps its content'
    Assert-True (!(Test-Path -LiteralPath $env:CLAUDE_CONFIG_DIR)) 'a file collision blocks the other target'

    # Existing files at required parent directories must also block both targets.
    foreach ($blockedParent in @('skills', 'licenses')) {
        Set-FixtureTargets ("parent-conflict-$blockedParent")
        New-Item -ItemType Directory -Path $env:CLAUDE_CONFIG_DIR -Force | Out-Null
        $blockedPath = Join-Path $env:CLAUDE_CONFIG_DIR $blockedParent
        Set-Content -LiteralPath $blockedPath -Value 'keep existing parent file' -Encoding UTF8
        $blockedContent = Get-Content -LiteralPath $blockedPath -Raw
        Assert-Throws { & $installer -Target Both -Apply *> $null } 'directory|parent|container|conflict|refusing' "a file at $blockedParent is rejected during preflight"
        Assert-True (!(Test-Path -LiteralPath $env:CODEX_HOME)) "a blocked Claude $blockedParent parent creates no Codex files"
        Assert-True ((Get-Content -LiteralPath $blockedPath -Raw) -ceq $blockedContent) "the existing $blockedParent parent file stays intact"
        Assert-True (@(Get-ChildItem -LiteralPath $env:CLAUDE_CONFIG_DIR -Force).Count -eq 1) "a blocked $blockedParent parent creates no other Claude files"
    }

    # Validate every source before copying even the first skill or license.
    Set-FixtureTargets 'missing-skill'
    $missingSkill = Join-Path (Join-Path (Join-Path $checkout 'skills') $names[-1]) 'SKILL.md'
    Remove-Item -LiteralPath $missingSkill -Force
    Assert-Throws { & $installer -Target Both -Apply *> $null } 'Skill missing|SKILL.md' 'an incomplete source is rejected before copying'
    Assert-NoTargets 'missing final source skill creates no agent config homes'
    Set-Content -LiteralPath $missingSkill -Value "fixture skill: $($names[-1])" -Encoding UTF8

    Set-FixtureTargets 'missing-license'
    Remove-Item -LiteralPath (Join-Path $checkout $licenseNames[-1]) -Force
    Assert-Throws { & $installer -Target Both -Apply *> $null } 'license|LICENSE' 'missing source licenses are rejected before copying'
    Assert-NoTargets 'missing source license creates no agent config homes'

    Write-Host 'NVIDIA PowerShell offline regression tests passed (417 skills, both agents).'
} finally {
    foreach ($variableName in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($variableName, $savedEnvironment[$variableName], 'Process')
    }
    if ($null -ne $savedGitFunction) {
        Set-Item -Path Function:\global:git -Value $savedGitFunction
    } else {
        Remove-Item -LiteralPath Function:\git -Force -ErrorAction SilentlyContinue
    }
    if ($hadLastExitCode) {
        $global:LASTEXITCODE = $savedLastExitCode
    } else {
        Remove-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $tempPrefix = $tempBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolvedRoot -ne $testRoot -or !$resolvedRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedRoot) -notmatch '^ai-agent-nvidia-tests-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected fixture path: $resolvedRoot"
        }
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
