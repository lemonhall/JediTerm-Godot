Param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$Suite = "all",
  [string]$One = "",
  [int]$TimeoutSec = $(if ($env:GODOT_TEST_TIMEOUT_SEC) { [int]$env:GODOT_TEST_TIMEOUT_SEC } else { 120 }),
  [string[]]$ExtraArgs = @(),
  # By default, headless tests should be deterministic and not depend on local editor state under .godot/.
  # If you want to run native extension integration tests (e.g. ConPTY), enable this explicitly.
  [switch]$EnableGdExtensions
)

$ErrorActionPreference = "Stop"

function Quote-Arg([string]$a) {
  if ($null -eq $a) { return '""' }
  if ($a -match '[\s"]') {
    $escaped = $a -replace '"', '\\"'
    return '"' + $escaped + '"'
  }
  return $a
}

function Run-ProcessCapture {
  Param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Args,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][int]$TimeoutSec,
    [Parameter(Mandatory = $true)][hashtable]$Env
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $psi.Arguments = (($Args | ForEach-Object { Quote-Arg $_ }) -join ' ')
  foreach ($k in $Env.Keys) { $psi.Environment[$k] = [string]$Env[$k] }

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi

  [void]$p.Start()
  $outTask = $p.StandardOutput.ReadToEndAsync()
  $errTask = $p.StandardError.ReadToEndAsync()

  $timedOut = -not $p.WaitForExit($TimeoutSec * 1000)
  if ($timedOut) {
    try { $p.Kill($true) } catch { try { Stop-Process -Id $p.Id -Force } catch {} }
  }

  $p.WaitForExit()

  $stdoutText = ""
  $stderrText = ""
  try { $stdoutText = $outTask.GetAwaiter().GetResult() } catch { $stdoutText = "" }
  try { $stderrText = $errTask.GetAwaiter().GetResult() } catch { $stderrText = "" }

  return @{
    timed_out = $timedOut
    exit_code = [int]$p.ExitCode
    stdout = $stdoutText
    stderr = $stderrText
  }
}

function Usage {
  Write-Host @"
Run Godot headless test scripts from Windows (PowerShell).

Usage:
  scripts/run_godot_tests.ps1 [-GodotExe <path>] [-Suite <name>] [-One <test_script.gd>] [-TimeoutSec <seconds>] [-ExtraArgs <args...>]

Examples:
  scripts/run_godot_tests.ps1
  scripts/run_godot_tests.ps1 -GodotExe "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  scripts/run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd
  scripts/run_godot_tests.ps1 -Suite jediterm

Suites:
  all (default), addons, jediterm, render

Notes:
  - Prefer the *console* exe for reliable headless output.
  - Set GODOT_WIN_EXE to avoid passing -GodotExe every time.
  - To avoid hung tests, set GODOT_TEST_TIMEOUT_SEC or pass -TimeoutSec.
"@
}

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
  $DefaultExe = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  if (Test-Path $DefaultExe) { $GodotExe = $DefaultExe }
}

if ([string]::IsNullOrWhiteSpace($GodotExe) -or !(Test-Path $GodotExe)) {
  Write-Host "Godot exe not found. Set GODOT_WIN_EXE or pass -GodotExe."
  Usage
  exit 2
}

function Ensure-Dir([string]$p) { if (!(Test-Path $p)) { [void](New-Item -ItemType Directory -Force -Path $p) } }

$GodotUserRoot = Join-Path $RootDir ".godot-user"
$AppDataRoaming = Join-Path $GodotUserRoot "AppData\\Roaming"
$AppDataLocal = Join-Path $GodotUserRoot "AppData\\Local"
$UserProfile = Join-Path $GodotUserRoot "User"
Ensure-Dir $AppDataRoaming
Ensure-Dir $AppDataLocal
Ensure-Dir $UserProfile

$Env = @{
  "APPDATA" = $AppDataRoaming
  "LOCALAPPDATA" = $AppDataLocal
  "USERPROFILE" = $UserProfile
}

$tests = @()
if (![string]::IsNullOrWhiteSpace($One)) {
  $tests = @($One)
} else {
  $suiteDir = Join-Path $RootDir "tests"
  switch ($Suite) {
    "all" { $suiteDir = Join-Path $RootDir "tests" }
    "addons" { $suiteDir = Join-Path $RootDir "tests\\addons" }
    "jediterm" { $suiteDir = Join-Path $RootDir "tests\\addons\\jediterm" }
    "render" { $suiteDir = Join-Path $RootDir "tests\\addons\\jediterm_render" }
    default {
      Write-Host ("Unknown suite: {0}" -f $Suite)
      Usage
      exit 2
    }
  }

  $tests = Get-ChildItem -Path $suiteDir -Recurse -Filter "test_*.gd" -File |
    Sort-Object FullName |
    ForEach-Object { $_.FullName }

  if ($tests.Count -eq 0) {
    Write-Host ("No tests found under {0}\\**\\test_*.gd" -f $suiteDir)
    exit 2
  }
}

$status = 0
$disabledExtensionListPath = ""
try {
  $extListPath = Join-Path $RootDir ".godot\\extension_list.cfg"
  if (-not $EnableGdExtensions -and (Test-Path $extListPath)) {
    $disabledExtensionListPath = Join-Path $RootDir (".godot\\extension_list.cfg.disabled_tests_{0}" -f ([guid]::NewGuid().ToString("N")))
    Move-Item -Force -Path $extListPath -Destination $disabledExtensionListPath
    Write-Host ("[INFO] Disabled local GDExtensions list for tests: {0}" -f $extListPath)
  }

  foreach ($t in $tests) {
    $scriptPath = $t
    if (!(Test-Path $scriptPath)) { $scriptPath = Join-Path $RootDir $t }
    if (!(Test-Path $scriptPath)) {
      Write-Host "Missing test script: $t"
      $status = 1
      continue
    }

    Write-Host "--- RUN $t"
    $args = @()
    if ($ExtraArgs.Count -gt 0) { $args += $ExtraArgs }
    $args += @("--headless", "--rendering-driver", "dummy", "--path", $RootDir.Path, "--script", $scriptPath)

    $res = Run-ProcessCapture -FilePath $GodotExe -Args $args -WorkingDirectory $RootDir.Path -TimeoutSec $TimeoutSec -Env $Env
    if ($res.timed_out) {
      if (-not [string]::IsNullOrWhiteSpace($res.stdout)) { $res.stdout | Write-Host }
      if (-not [string]::IsNullOrWhiteSpace($res.stderr)) { $res.stderr | Write-Host }
      Write-Host ("TIMEOUT after {0}s: {1}" -f $TimeoutSec, $t)
      $status = 1
      continue
    }

    if (-not [string]::IsNullOrWhiteSpace($res.stdout)) { $res.stdout | Write-Host }
    if (-not [string]::IsNullOrWhiteSpace($res.stderr)) { $res.stderr | Write-Host }

    if ($res.exit_code -ne 0) { $status = 1 }
  }
} finally {
  if ($disabledExtensionListPath -and (Test-Path $disabledExtensionListPath)) {
    $extListPath = Join-Path $RootDir ".godot\\extension_list.cfg"
    if (Test-Path $extListPath) {
      Remove-Item -Force -Path $disabledExtensionListPath
    } else {
      Move-Item -Force -Path $disabledExtensionListPath -Destination $extListPath
    }
  }
}

exit $status

