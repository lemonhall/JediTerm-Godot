param(
  [ValidateSet("2019", "2022")]
  [string]$PreferVs = "2019"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "win\\vs.ps1")

Write-Host "Probing MSVC toolchain via VsDevCmd..."
$code = Invoke-InVsDevCmd -Prefer $PreferVs -Command "where cl && where link && where msbuild && cl /? >nul 2>nul"
if ($code -ne 0) {
  throw "MSVC probe failed (exit=$code). Make sure Visual Studio Build Tools with C++ workload is installed."
}

Write-Host "[OK] MSVC toolchain is usable."

