param(
  # Optional explicit source dir that contains godot-cpp/SConstruct.
  [string]$Source = "",
  # Force recreate the junction if target already exists but looks wrong.
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$targetRoot = Join-Path $repoRoot "addons\\jediterm\\native\\thirdparty"
$target = Join-Path $targetRoot "godot-cpp"

function Test-GodotCpp([string]$p) {
  if (-not $p) { return $false }
  return (Test-Path (Join-Path $p "SConstruct"))
}

if (Test-GodotCpp $target) {
  Write-Host "[OK] godot-cpp already present: $target"
  exit 0
}

if ((Test-Path $target) -and -not $Force) {
  throw "Target exists but is not usable: $target`nDelete it manually or re-run with -Force."
}

if ($Source -eq "") {
  if (Test-GodotCpp $env:GODOT_CPP_DIR) { $Source = $env:GODOT_CPP_DIR }
  elseif (Test-GodotCpp "E:\\development\\echo-guard\\deps\\godot-cpp") { $Source = "E:\\development\\echo-guard\\deps\\godot-cpp" }
}

if (-not (Test-GodotCpp $Source)) {
  throw @"
No usable godot-cpp found.

Options:
  1) (Recommended) Use git submodule:
     git submodule add https://github.com/godotengine/godot-cpp.git addons/jediterm/native/thirdparty/godot-cpp
     git submodule update --init --recursive

  2) (This machine) Reuse existing checkout via junction:
     pwsh -File scripts\\setup_godot_cpp.ps1 -Source <path-to-godot-cpp>

Expected: <path> contains SConstruct.
"@
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

if (Test-Path $target) {
  if ($Force) {
    throw "Refusing to remove existing path automatically: $target`nPlease delete it manually, then rerun."
  }
  throw "Target already exists: $target"
}

Write-Host "[INFO] Creating junction:"
Write-Host "  target: $target"
Write-Host "  source: $Source"

New-Item -ItemType Junction -Path $target -Target $Source | Out-Null

if (-not (Test-GodotCpp $target)) {
  throw "Junction created but SConstruct not found at target: $target"
}

Write-Host "[OK] godot-cpp linked: $target"

