param(
  [string]$GodotDir = "E:\\Godot_v4.6-stable_win64.exe",
  [string]$GodotExe = "",
  [ValidateSet("2019", "2022")]
  [string]$PreferVs = "2019",
  [switch]$DebugOnly,
  [switch]$ReleaseOnly,
  [switch]$All,
  # Forces a (slow) full bindings regen for godot-cpp. Use when upgrading Godot.
  [switch]$RegenBindings
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "win\\vs.ps1")

function Get-GodotConsoleExe() {
  if ($env:GODOT_WIN_EXE -and (Test-Path $env:GODOT_WIN_EXE)) { return $env:GODOT_WIN_EXE }
  if ($GodotExe -ne "") { return $GodotExe }
  $p = Join-Path $GodotDir "Godot_v4.6-stable_win64_console.exe"
  if (Test-Path $p) { return $p }
  $p = Join-Path $GodotDir "Godot_v4.6-stable_win64.exe"
  if (Test-Path $p) { return $p }
  throw "Godot executable not found. Provide -GodotExe or -GodotDir (or set env:GODOT_WIN_EXE). Tried: $p"
}

function Require-Tool([string]$name, [string]$installHint) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Missing tool: $name. $installHint" }
}

Require-Tool "scons" "Install with: python -m pip install --user -U scons"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$nativeDir = Join-Path $repoRoot "addons\\jediterm\\native"

if (-not (Test-Path (Join-Path $nativeDir "SConstruct"))) {
  throw "Missing native extension project: $nativeDir"
}

$godotCppScons = Join-Path $nativeDir "thirdparty\\godot-cpp\\SConstruct"
if (-not (Test-Path $godotCppScons)) {
  throw "Missing godot-cpp: $godotCppScons`nRun: pwsh -File scripts\\setup_godot_cpp.ps1  (or add as git submodule)"
}

$apiDir = Join-Path $nativeDir "build\\godot_api"
$apiFile = Join-Path $apiDir "extension_api.json"

$needApiDump = (-not (Test-Path $apiFile)) -or $RegenBindings
Write-Host ("[INFO] extension_api.json: {0} (exists={1})" -f $apiFile, (Test-Path $apiFile))

if ($needApiDump) {
  New-Item -ItemType Directory -Force -Path $apiDir | Out-Null
  $godot = Get-GodotConsoleExe
  Push-Location $apiDir
  try {
    Write-Host "[INFO] Dumping extension_api.json via Godot..."
    & $godot --dump-extension-api | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Godot --dump-extension-api failed (exit=$LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
} else {
  Write-Host "[SKIP] extension_api.json already exists."
}

if (-not (Test-Path $apiFile)) { throw "Expected extension_api.json not found: $apiFile" }

$generatedHeader = Join-Path $nativeDir "thirdparty\\godot-cpp\\gen\\include\\godot_cpp\\classes\\object.hpp"
$needBindings = (-not (Test-Path $generatedHeader)) -or $RegenBindings
Write-Host ("[INFO] godot-cpp bindings: {0} (exists={1})" -f $generatedHeader, (Test-Path $generatedHeader))

$buildDebug = $true
$buildRelease = $false
if ($All) { $buildDebug = $true; $buildRelease = $true }
elseif ($ReleaseOnly) { $buildDebug = $false; $buildRelease = $true }
elseif ($DebugOnly) { $buildDebug = $true; $buildRelease = $false }

$bindingsArg = ""
if ($needBindings) {
  $bindingsArg = " generate_bindings=yes"
  if ($RegenBindings) {
    Write-Host "[INFO] -RegenBindings enabled: forcing godot-cpp bindings regeneration (slow)."
  } else {
    Write-Host "[INFO] godot-cpp bindings not found; generating bindings (first build, slow)."
  }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
  if ($buildDebug) {
    Write-Host "[INFO] Building GDExtension (template_debug, incremental)..."
    $code = Invoke-InVsDevCmd -Prefer $PreferVs -Command ("cd /d ""{0}"" && scons platform=windows target=template_debug arch=x86_64{2} custom_api_file=""{1}""" -f $nativeDir, $apiFile, $bindingsArg)
    if ($code -ne 0) { throw "Build failed (template_debug), exit=$code" }
  }

  if ($buildRelease) {
    Write-Host "[INFO] Building GDExtension (template_release, incremental)..."
    $code = Invoke-InVsDevCmd -Prefer $PreferVs -Command ("cd /d ""{0}"" && scons platform=windows target=template_release arch=x86_64{2} custom_api_file=""{1}""" -f $nativeDir, $apiFile, $bindingsArg)
    if ($code -ne 0) { throw "Build failed (template_release), exit=$code" }
  }
} finally {
  $sw.Stop()
}

Write-Host ("[OK] Build finished in {0:n1}s" -f $sw.Elapsed.TotalSeconds)
