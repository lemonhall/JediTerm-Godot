param(
  # Windows path. Defaults to repo-local output directory (ignored by git).
  [string]$OutDir = "addons\\jediterm\\native\\tinyemu\\images\\out",
  # Buildroot git ref (tag/branch/commit). Script is robust to ref missing; override if needed.
  [string]$BuildrootRef = "2025.02.1",
  [string]$BuildrootRepo = "https://github.com/buildroot/buildroot.git",
  # Where to keep buildroot state inside WSL (cache). Not under the repo to avoid polluting git status.
  [string]$WslWorkDir = "~/.cache/jediterm_tinyemu_buildroot",
  # Optional HTTP proxy for WSL downloads, e.g. http://127.0.0.1:7897
  [string]$Proxy = "",
  # Auto-detect via nproc when 0.
  [int]$Jobs = 0,
  [switch]$InstallDeps,
  [switch]$DryRun
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

Require-Tool "wsl.exe" "Install WSL2 and Ubuntu 24 (or set up a default distro)."

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDirFull = (Resolve-Path (Join-Path $repoRoot $OutDir) -ErrorAction SilentlyContinue)
if ($null -eq $outDirFull) {
  $outDirFull = (Join-Path $repoRoot $OutDir)
  New-Item -ItemType Directory -Force -Path $outDirFull | Out-Null
  $outDirFull = (Resolve-Path $outDirFull).Path
} else {
  $outDirFull = $outDirFull.Path
}

$outDirWsl = Convert-ToWslPath $outDirFull

$bashScript = @'
set -euo pipefail

# Buildroot rejects PATH entries containing spaces (common in WSL when Windows paths are appended).
# Use a minimal Linux-only PATH for deterministic builds.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

OUT_DIR="$1"
WORK_DIR="$2"
BUILDROOT_REPO="$3"
BUILDROOT_REF="$4"
PROXY="$5"
INSTALL_DEPS="$6"
JOBS="$7"
DRY_RUN="$8"

echo "[INFO] OUT_DIR=$OUT_DIR"
echo "[INFO] WORK_DIR(raw)=$WORK_DIR"
echo "[INFO] BUILDROOT_REPO=$BUILDROOT_REPO"
echo "[INFO] BUILDROOT_REF=$BUILDROOT_REF"
echo "[INFO] PROXY=$PROXY"
echo "[INFO] INSTALL_DEPS=$INSTALL_DEPS"
echo "[INFO] JOBS=$JOBS"
echo "[INFO] DRY_RUN=$DRY_RUN"

WORK_DIR="${WORK_DIR/#\~/$HOME}"
echo "[INFO] WORK_DIR=$WORK_DIR"

if [ -n "$PROXY" ]; then
  export http_proxy="$PROXY"
  export https_proxy="$PROXY"
  export HTTP_PROXY="$PROXY"
  export HTTPS_PROXY="$PROXY"
fi

mkdir -p "$OUT_DIR"
mkdir -p "$WORK_DIR"

if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY] would download bios and build buildroot output images"
  exit 0
fi

if [ "$INSTALL_DEPS" = "1" ]; then
  echo "[INFO] Installing dependencies (Ubuntu)..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    git ca-certificates curl file build-essential bc bison flex \
    libncurses-dev rsync unzip python3
fi

for tool in git curl make gcc g++ python3 rsync gzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[ERR] Missing tool in WSL: $tool"
    echo "      Re-run with -InstallDeps or install it manually."
    exit 2
  fi
done

echo "[INFO] Fetching TinyEMU-compatible RISC-V BIOS (bbl64.bin) from bellard.org..."
curl -fsSL -o "$OUT_DIR/bbl64.bin.tmp" "https://bellard.org/jslinux/bbl64.bin"
mv -f "$OUT_DIR/bbl64.bin.tmp" "$OUT_DIR/bbl64.bin"

BUILDROOT_DIR="$WORK_DIR/buildroot"
if [ ! -d "$BUILDROOT_DIR/.git" ]; then
  if [ -e "$BUILDROOT_DIR" ] && [ ! -d "$BUILDROOT_DIR/.git" ]; then
    echo "[ERR] WORK_DIR already has a non-git buildroot dir: $BUILDROOT_DIR"
    echo "      Please remove it manually in WSL and re-run:"
    echo "        rm -rf $BUILDROOT_DIR"
    exit 2
  fi

  echo "[INFO] Cloning Buildroot..."
  if git clone --depth 1 --branch "$BUILDROOT_REF" "$BUILDROOT_REPO" "$BUILDROOT_DIR"; then
    :
  else
    echo "[WARN] clone --branch $BUILDROOT_REF failed; cloning default branch then trying checkout..."
    git clone --depth 1 "$BUILDROOT_REPO" "$BUILDROOT_DIR"
    (cd "$BUILDROOT_DIR" && git fetch --depth 1 origin "$BUILDROOT_REF" && git checkout "$BUILDROOT_REF") || true
  fi
fi

cd "$BUILDROOT_DIR"

echo "[INFO] Configuring Buildroot (qemu_riscv64_virt_defconfig + cpio rootfs + getty on hvc0)..."
make qemu_riscv64_virt_defconfig

./utils/config --file .config --enable BR2_TARGET_ROOTFS_CPIO
./utils/config --file .config --disable BR2_TARGET_ROOTFS_EXT2
./utils/config --file .config --set-str BR2_TARGET_GENERIC_GETTY_PORT "hvc0"
./utils/config --file .config --set-str BR2_TARGET_GENERIC_GETTY_BAUDRATE "115200"
./utils/config --file .config --set-str BR2_TARGET_GENERIC_GETTY_TERM "linux"

make olddefconfig

if [ "$JOBS" -le 0 ]; then
  JOBS="$(nproc)"
fi

echo "[INFO] Building (this may take a while on first run)..."
make -j"$JOBS"

IMG_DIR="$BUILDROOT_DIR/output/images"
KERNEL_SRC="$IMG_DIR/Image"
INITRD_SRC=""
if [ -f "$IMG_DIR/rootfs.cpio" ]; then
  INITRD_SRC="$IMG_DIR/rootfs.cpio"
elif [ -f "$IMG_DIR/rootfs.cpio.gz" ]; then
  INITRD_SRC="$IMG_DIR/rootfs.cpio.gz"
fi

if [ ! -f "$KERNEL_SRC" ]; then
  echo "[ERR] Buildroot kernel Image not found: $KERNEL_SRC"
  ls -la "$IMG_DIR" || true
  exit 3
fi

if [ -z "$INITRD_SRC" ]; then
  echo "[ERR] Buildroot initrd (rootfs.cpio[.gz]) not found under: $IMG_DIR"
  ls -la "$IMG_DIR" || true
  exit 3
fi

echo "[INFO] Copying artifacts to OUT_DIR..."
cp -f "$KERNEL_SRC" "$OUT_DIR/kernel-riscv64.bin"
if [[ "$INITRD_SRC" == *.gz ]]; then
  gzip -dc "$INITRD_SRC" > "$OUT_DIR/initrd-riscv64.cpio.tmp"
  mv -f "$OUT_DIR/initrd-riscv64.cpio.tmp" "$OUT_DIR/initrd-riscv64.cpio"
else
  cp -f "$INITRD_SRC" "$OUT_DIR/initrd-riscv64.cpio"
fi

echo "[OK] Artifacts ready:"
ls -la "$OUT_DIR" | sed -e 's/^/[OUT] /'
'@

Write-Host "[INFO] Running WSL build script..."
& wsl.exe -e bash -lc $bashScript -- $outDirWsl $WslWorkDir $BuildrootRepo $BuildrootRef $Proxy ([int]$InstallDeps.IsPresent) $Jobs ([int]$DryRun.IsPresent)
if ($LASTEXITCODE -ne 0) { throw "WSL build failed (exit=$LASTEXITCODE)" }

Write-Host "[OK] Output: $outDirFull"
