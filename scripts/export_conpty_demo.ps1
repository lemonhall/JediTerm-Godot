param(
  [string]$GodotExe = "",
  [string]$Preset = "Windows Desktop",
  [string]$OutExe = "",
  [string]$MainScene = "res://scenes/render_v6_conpty_crt_demo.tscn"
)

$ErrorActionPreference = "Stop"

function _ReadAllBytes([string]$path) {
  return [System.IO.File]::ReadAllBytes($path)
}

function _WriteAllBytes([string]$path, [byte[]]$bytes) {
  $parent = Split-Path -Parent $path
  if ($parent -and -not (Test-Path $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  [System.IO.File]::WriteAllBytes($path, $bytes)
}

function _SetProjectMainScene([string]$projectText, [string]$scenePath) {
  $targetLine = ('run/main_scene="{0}"' -f $scenePath)

  $lines = [System.Text.RegularExpressions.Regex]::Split($projectText, "\r?\n")
  $inApp = $false
  $appHeaderIndex = -1
  $nextSectionIndex = $lines.Count
  $nameIndex = -1
  $mainSceneIndex = -1

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^\[application\]\s*$') {
      $inApp = $true
      $appHeaderIndex = $i
      continue
    }
    if ($inApp -and $line -match '^\[.+\]\s*$') {
      $nextSectionIndex = $i
      break
    }
    if ($inApp) {
      if ($line -match '^config/name=') { $nameIndex = $i }
      if ($line -match '^run/main_scene=') { $mainSceneIndex = $i; break }
    }
  }

  if ($mainSceneIndex -ge 0) {
    $lines[$mainSceneIndex] = $targetLine
    return ($lines -join "`r`n")
  }

  if ($appHeaderIndex -lt 0) {
    throw "project.godot missing [application] section (cannot set run/main_scene)"
  }

  $insertAt = $appHeaderIndex + 1
  if ($nameIndex -ge 0 -and $nameIndex -lt $nextSectionIndex) {
    $insertAt = $nameIndex + 1
  }

  $newLines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -eq $insertAt) { [void]$newLines.Add($targetLine) }
    [void]$newLines.Add($lines[$i])
  }
  if ($insertAt -ge $lines.Count) {
    [void]$newLines.Add($targetLine)
  }

  return ($newLines.ToArray() -join "`r`n")
}

$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
  if (-not [string]::IsNullOrWhiteSpace($env:GODOT_WIN_EXE)) {
    $GodotExe = $env:GODOT_WIN_EXE
  } else {
    $GodotExe = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
  }
}

if (-not (Test-Path $GodotExe)) {
  throw "GodotExe not found: $GodotExe (set -GodotExe or env:GODOT_WIN_EXE)"
}

$projectPath = Join-Path $rootDir "project.godot"
if (-not (Test-Path $projectPath)) {
  throw "Missing project.godot: $projectPath"
}

$mainSceneFsPath = Join-Path $rootDir ($MainScene -replace '^res://', '')
if (-not (Test-Path $mainSceneFsPath)) {
  throw "MainScene not found: $MainScene ($mainSceneFsPath)"
}

$conptyExtResPath = "res://addons/jediterm/native/conpty.gdextension"
$conptyExtFsPath = Join-Path $rootDir "addons/jediterm/native/conpty.gdextension"
if (-not (Test-Path $conptyExtFsPath)) {
  throw "ConPTY extension not found: $conptyExtFsPath"
}

if ([string]::IsNullOrWhiteSpace($OutExe)) {
  $outDir = Join-Path $rootDir "_export/windows_conpty_demo"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $OutExe = Join-Path $outDir "JediTerm-ConPTY-Demo.exe"
} else {
  $outDir2 = Split-Path -Parent $OutExe
  if ($outDir2 -and -not (Test-Path $outDir2)) {
    New-Item -ItemType Directory -Force -Path $outDir2 | Out-Null
  }
}

$extListPath = Join-Path $rootDir ".godot/extension_list.cfg"
$hadExtList = Test-Path $extListPath
$extListBytes = $null
$projectBytes = $null

try {
  $projectBytes = _ReadAllBytes $projectPath
  if ($hadExtList) {
    $extListBytes = _ReadAllBytes $extListPath
  }

  Set-Content -Path $extListPath -Encoding UTF8 -Value @($conptyExtResPath)
  Write-Host ("[INFO] Enabled ConPTY only for export: {0}" -f $conptyExtResPath)

  $projectText = [System.Text.Encoding]::UTF8.GetString($projectBytes)
  $projectText2 = _SetProjectMainScene $projectText $MainScene
  Set-Content -Path $projectPath -Encoding UTF8 -Value $projectText2
  Write-Host ("[INFO] Set run/main_scene for export: {0}" -f $MainScene)

  Write-Host ("[INFO] Exporting preset='{0}' -> {1}" -f $Preset, $OutExe)
  & $GodotExe --headless --path $rootDir.Path --export-release $Preset $OutExe
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    throw "Godot export failed (ExitCode=$code)"
  }

  if (-not (Test-Path $OutExe)) {
    throw "Export finished but exe not found: $OutExe"
  }

  Write-Host ("[OK] Exported: {0}" -f $OutExe)
} finally {
  if ($projectBytes) {
    _WriteAllBytes $projectPath $projectBytes
  }

  if ($hadExtList) {
    if ($extListBytes) {
      _WriteAllBytes $extListPath $extListBytes
    }
  } else {
    if (Test-Path $extListPath) {
      Remove-Item -Force -Path $extListPath
    }
  }
}
