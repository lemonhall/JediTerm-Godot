param(
  [string]$BuildrootVersion = "2025.02.1",
  [string]$WorkDir = "",
  # Windows path (repo-local target recommended): addons\jediterm\native\tinyemu\images\python
  [string]$OutDir = "addons\\jediterm\\native\\tinyemu\\images\\python"
)

$ErrorActionPreference = "Stop"

function Require-Tool([string]$name, [string]$hint) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Missing tool: $name. $hint" }
}

function Convert-ToWslPath([string]$winPath) {
  $full = (Resolve-Path $winPath).Path -replace '/', '\'
  $bash = 'wslpath -a -u "$1"'
  $out = & wsl.exe -e bash -lc $bash -- $full
  if ($LASTEXITCODE -ne 0) { throw "wslpath failed (exit=$LASTEXITCODE): $full" }
  return ($out | Out-String).Trim()
}

Require-Tool "wsl.exe" "Install WSL2 and set up an Ubuntu distro."

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$outDirFull = (Resolve-Path (Join-Path $repoRoot $OutDir) -ErrorAction SilentlyContinue)
if ($null -eq $outDirFull) {
  $outDirFull = (Join-Path $repoRoot $OutDir)
  New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null
  $outDirFull = (Resolve-Path $outDirFull).Path
} else {
  $outDirFull = $outDirFull.Path
}

$stageScriptWin = Join-Path $PSScriptRoot "_wsl\\stage_3_package.sh"
$stageScriptWsl = Convert-ToWslPath $stageScriptWin
$outDirWsl = Convert-ToWslPath $outDirFull

$workDir = $WorkDir.Trim()

$cmd = @"
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
OUT_DIR='$outDirWsl' bash '$stageScriptWsl' --version '$BuildrootVersion' --workdir '$workDir'
"@

Write-Host "[INFO] Stage 3 (package) via WSL..."
& wsl.exe -e bash -lc $cmd
if ($LASTEXITCODE -ne 0) { throw "Stage 3 failed (exit=$LASTEXITCODE)" }

Write-Host "[OK] Output: $outDirFull"

