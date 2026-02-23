Param(
  [string]$VenvPath = ".venv"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$venv = Join-Path $root $VenvPath
$sitePkgs = Join-Path $venv "Lib\\site-packages"

if (!(Test-Path $sitePkgs)) {
  throw "site-packages not found at: $sitePkgs (create venv first: uv venv -p 3.13 -c)"
}

$pth = Join-Path $sitePkgs "zzz_disable_wmi.pth"

# Work around a Windows WMI hang which can cause `platform.win32_ver()` (and callers like `platform.system()`)
# to block indefinitely on some machines. Some tools (including uv/pytest plugins) call these APIs while probing
# interpreter metadata, making installs appear 'stuck'.
"import platform; platform._wmi=None" | Set-Content -Path $pth -Encoding ASCII

Write-Host ("Wrote {0}" -f $pth)

