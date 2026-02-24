param(
  [string]$BuildrootVersion = "2025.02.1",
  [string]$WorkDir = ""
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

$stageScriptWin = Join-Path $PSScriptRoot "_wsl\\stage_2_build.sh"
$stageScriptWsl = Convert-ToWslPath $stageScriptWin

$workDir = $WorkDir.Trim()

$cmd = @"
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
bash '$stageScriptWsl' --version '$BuildrootVersion' --workdir '$workDir'
"@

Write-Host "[INFO] Stage 2 (build) via WSL..."
& wsl.exe -e bash -lc $cmd
if ($LASTEXITCODE -ne 0) { throw "Stage 2 failed (exit=$LASTEXITCODE)" }

