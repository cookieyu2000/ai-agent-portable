# Pinned optional packages, with dry-run as the default. Python 3.10+ required.
[CmdletBinding()]
param(
    [ValidateSet('hallmark','codync','all')][string]$Package = 'all',
    [ValidateSet('codex','claude','both')][string]$Target = 'codex',
    [switch]$Apply,
    [switch]$DryRun,
    [string]$SourceRoot,
    [string]$RuntimeRoot,
    [string]$CodexHome,
    [string]$ClaudeHome,
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonCommand = $null
$pythonArguments = @()
# Prefer the Windows launcher, and verify actual interpreters rather than trusting
# executable names (python/python3 may be Windows Store aliases or older versions).
foreach ($candidate in @(Get-Command py, python, python3 -CommandType Application -All -ErrorAction SilentlyContinue)) {
    $prefix = @()
    if ($candidate.Name -eq 'py.exe' -or $candidate.Name -eq 'py') { $prefix += '-3' }
    $probeArguments = $prefix + @('-B', '-c', 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)')
    try {
        $null = & $candidate.Source @probeArguments 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pythonCommand = $candidate
            $pythonArguments = $prefix
            break
        }
    } catch {
        # Try the next installed interpreter.
    }
}
if (!$pythonCommand) { throw 'A working Python 3.10+ interpreter is required.' }
$pythonArguments += @('-B', (Join-Path $scriptRoot 'scripts\install_optional.py'), '--package', $Package.ToLowerInvariant(), '--target', $Target.ToLowerInvariant())
if ($Apply) { $pythonArguments += '--apply' }
if ($DryRun) { $pythonArguments += '--dry-run' }
foreach ($setting in @(
    @('--source-root', $SourceRoot), @('--runtime-root', $RuntimeRoot),
    @('--codex-home', $CodexHome), @('--claude-home', $ClaudeHome), @('--manifest', $Manifest)
)) {
    if ($setting[1]) { $pythonArguments += @($setting[0], $setting[1]) }
}
& $pythonCommand.Source @pythonArguments
exit $LASTEXITCODE
