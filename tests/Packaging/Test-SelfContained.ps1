param(
    [Parameter(Mandatory)][string]$PlayerDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$player = (Resolve-Path -LiteralPath $PlayerDirectory).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a new output directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$emptyRuntime = New-Item -ItemType Directory -Path (Join-Path $output 'empty-dotnet')
$config = New-Item -ItemType Directory -Path (Join-Path $output 'config')
$extraction = Join-Path $output 'bundle'
$tracePath = Join-Path $output 'host-trace.txt'

$start = [Diagnostics.ProcessStartInfo]::new((Join-Path $player 'mpvnet.exe'))
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.WorkingDirectory = $player
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Arguments = '--no-config --load-scripts=no --vo=null --ao=null --version'
$start.Environment['DOTNET_ROOT'] = $emptyRuntime.FullName
$start.Environment['DOTNET_ROOT_X64'] = $emptyRuntime.FullName
$start.Environment['DOTNET_MULTILEVEL_LOOKUP'] = '0'
$start.Environment['DOTNET_DISABLE_GUI_ERRORS'] = '1'
$start.Environment['DOTNET_HOST_TRACE'] = '1'
$start.Environment['DOTNET_HOST_TRACEFILE'] = $tracePath
$start.Environment['DOTNET_BUNDLE_EXTRACT_BASE_DIR'] = $extraction
$start.Environment['MPVNET_HOME'] = $config.FullName
$start.Environment['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot"

$process = [Diagnostics.Process]::Start($start)
try {
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw 'The packaged player did not exit within 30 seconds.'
    }
    $text = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $output 'player-output.txt'), $text)
    if ($process.ExitCode -ne 0) {
        throw "Player failed without an installed runtime: exit $($process.ExitCode). See $output."
    }
    if ($text -notmatch 'mpv[.]net') { throw 'The player did not print its version.' }
    $trace = Get-Content -LiteralPath $tracePath -Raw
    # .NET 10's self-contained single-file host links CoreCLR into the EXE.
    if (-not $trace.Contains('Executing as a self-contained app') -or
        -not $trace.Contains('Using internal fxr') -or
        -not $trace.Contains('Using internal hostpolicy') -or
        -not $trace.Contains("CoreCLR path = '', CoreCLR dir = ''")) {
        throw 'The host trace did not confirm use of the runtime built into this package.'
    }
    Write-Output 'PASS packaged mpv.net starts and exits using its bundled runtime with installed-runtime lookup isolated.'
    Write-Output 'Runtime: built into the EXE (confirmed by the .NET host trace).'
}
finally {
    $process.Dispose()
}
