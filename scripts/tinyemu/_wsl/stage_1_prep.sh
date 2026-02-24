#!/bin/bash
set -euo pipefail

WORK_DIR_DEFAULT="$HOME/.cache/jediterm_tinyemu_buildroot"
BR_VERSION_DEFAULT="2025.02.1"

WORK_DIR="$WORK_DIR_DEFAULT"
BR_VERSION="$BR_VERSION_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir)
      WORK_DIR="${2:-$WORK_DIR_DEFAULT}"
      shift 2
      ;;
    --version)
      BR_VERSION="${2:-$BR_VERSION_DEFAULT}"
      shift 2
      ;;
    *)
      echo "[ERR] Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$WORK_DIR_DEFAULT"
fi

BR_DIR="$WORK_DIR/buildroot-$BR_VERSION"
DL_DIR="$WORK_DIR/dl"

echo "=== Stage 1: prep ==="
echo "[INFO] WORK_DIR=$WORK_DIR"
echo "[INFO] BR_VERSION=$BR_VERSION"
echo "[INFO] BR_DIR=$BR_DIR"
echo "[INFO] DL_DIR=$DL_DIR"

echo "[INFO] Installing deps (idempotent)..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential gcc g++ make \
  libncurses5-dev unzip bc python3 rsync cpio wget file libssl-dev

mkdir -p "$WORK_DIR" "$DL_DIR"

if [[ ! -d "$BR_DIR" ]]; then
  echo "[INFO] Downloading Buildroot $BR_VERSION..."
  wget -c -P "$WORK_DIR" "https://buildroot.org/downloads/buildroot-${BR_VERSION}.tar.xz"
  tar xf "$WORK_DIR/buildroot-${BR_VERSION}.tar.xz" -C "$WORK_DIR"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[INFO] Copying defconfig + overlay..."
cp "$SCRIPT_DIR/config/jediterm_py312_defconfig" "$BR_DIR/configs/"
mkdir -p "$BR_DIR/board/jediterm-python"
cp "$SCRIPT_DIR/config/linux_min.config" "$BR_DIR/board/jediterm-python/"
rm -rf "$BR_DIR/board/jediterm-python/overlay"
cp -r "$SCRIPT_DIR/config/overlay" "$BR_DIR/board/jediterm-python/"

echo "[INFO] Applying defconfig..."
cd "$BR_DIR"
rm -f .config .config.old || true
make BR2_DL_DIR="$DL_DIR" jediterm_py312_defconfig
make BR2_DL_DIR="$DL_DIR" olddefconfig

echo "[INFO] Pre-downloading sources (resumable)..."
make BR2_DL_DIR="$DL_DIR" source

echo "=== Stage 1 DONE ==="
echo "=== BR_DIR: $BR_DIR ==="
echo "=== DL_DIR: $DL_DIR ==="
