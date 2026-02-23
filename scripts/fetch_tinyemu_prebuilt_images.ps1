param(
  # Windows path. Defaults to repo-local output directory (ignored by git).
  [string]$OutDir = "addons\\jediterm\\native\\tinyemu\\images\\out",
  # Optional HTTP proxy, e.g. http://127.0.0.1:7897
  [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"

function Require-Tool([string]$name, [string]$hint) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Missing tool: $name. $hint" }
}

Require-Tool "curl.exe" "Windows 11 should include curl.exe."
Require-Tool "tar.exe" "Windows 11 should include tar.exe."

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDirFull = (Resolve-Path (Join-Path $repoRoot $OutDir) -ErrorAction SilentlyContinue)
if ($null -eq $outDirFull) {
  $outDirFull = (Join-Path $repoRoot $OutDir)
  New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null
  $outDirFull = (Resolve-Path $outDirFull).Path
} else {
  $outDirFull = $outDirFull.Path
}

$diskUrl = "https://www.bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz"
$tgz = Join-Path $outDirFull "diskimage-linux-riscv-2018-09-23.tar.gz"

$curlArgs = @("-L", "--fail", "--retry", "10", "--retry-delay", "2", "-C", "-", "-o", $tgz, $diskUrl)
if ($Proxy -ne "") {
  $curlArgs = @("-x", $Proxy) + $curlArgs
}

Write-Host "[INFO] Downloading TinyEMU prebuilt disk image..."
& curl.exe @curlArgs | Out-Host
if ($LASTEXITCODE -ne 0) { throw "curl failed (exit=$LASTEXITCODE)" }

Write-Host "[INFO] Extracting bbl64/kernel/rootfs..."
& tar.exe -xzf $tgz -C $outDirFull `
  "diskimage-linux-riscv-2018-09-23/bbl64.bin" `
  "diskimage-linux-riscv-2018-09-23/kernel-riscv64.bin" `
  "diskimage-linux-riscv-2018-09-23/root-riscv64.bin" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "tar failed (exit=$LASTEXITCODE)" }

Copy-Item -Force (Join-Path $outDirFull "diskimage-linux-riscv-2018-09-23\\bbl64.bin") (Join-Path $outDirFull "bbl64.bin")
Copy-Item -Force (Join-Path $outDirFull "diskimage-linux-riscv-2018-09-23\\kernel-riscv64.bin") (Join-Path $outDirFull "kernel-riscv64.bin")
Copy-Item -Force (Join-Path $outDirFull "diskimage-linux-riscv-2018-09-23\\root-riscv64.bin") (Join-Path $outDirFull "root-riscv64.bin")

Write-Host "[OK] Images ready in: $outDirFull"
Get-ChildItem $outDirFull | Sort-Object Name | Select-Object Name, Length | Format-Table -AutoSize

