param(
  [string]$Proxy = "http://192.168.50.250:7897",
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

$stageScriptWin = Join-Path $PSScriptRoot "_wsl\\stage_1_prep.sh"
$stageScriptWsl = Convert-ToWslPath $stageScriptWin

$proxy = $Proxy.Trim()
$workDir = $WorkDir.Trim()

$cmd = @"
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
if [ -n '$proxy' ]; then
  export http_proxy='$proxy' https_proxy='$proxy' HTTP_PROXY='$proxy' HTTPS_PROXY='$proxy'
fi
bash '$stageScriptWsl' --version '$BuildrootVersion' --workdir '$workDir'
"@

Write-Host "[INFO] Stage 1 (prep) via WSL..."
& wsl.exe -e bash -lc $cmd
if ($LASTEXITCODE -ne 0) { throw "Stage 1 failed (exit=$LASTEXITCODE)" }

