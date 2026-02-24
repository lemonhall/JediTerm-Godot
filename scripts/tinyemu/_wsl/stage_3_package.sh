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
IMAGES_DIR="$BR_DIR/output/images"

OUT_DIR="${OUT_DIR:-$WORK_DIR/rom-python}"
mkdir -p "$OUT_DIR"

echo "=== Stage 3: package ROM ==="
echo "[INFO] IMAGES_DIR=$IMAGES_DIR"
echo "[INFO] OUT_DIR=$OUT_DIR"

if [[ -f "$IMAGES_DIR/fw_payload.elf" ]]; then
  cp "$IMAGES_DIR/fw_payload.elf" "$OUT_DIR/kernel-riscv64.bin"
elif [[ -f "$IMAGES_DIR/Image" ]]; then
  cp "$IMAGES_DIR/Image" "$OUT_DIR/kernel-riscv64.bin"
else
  echo "[ERR] missing kernel (fw_payload.elf or Image) under: $IMAGES_DIR" >&2
  ls -la "$IMAGES_DIR" || true
  exit 3
fi

if [[ -f "$IMAGES_DIR/rootfs.ext2" ]]; then
  cp "$IMAGES_DIR/rootfs.ext2" "$OUT_DIR/root-py312-riscv64.bin"
else
  echo "[ERR] missing rootfs.ext2 under: $IMAGES_DIR" >&2
  ls -la "$IMAGES_DIR" || true
  exit 3
fi

if [[ ! -f "$OUT_DIR/bbl64.bin" ]]; then
  echo "[INFO] fetching bbl64.bin..."
  wget -O "$OUT_DIR/bbl64.bin.tmp" "https://bellard.org/jslinux/bbl64.bin"
  mv -f "$OUT_DIR/bbl64.bin.tmp" "$OUT_DIR/bbl64.bin"
fi

echo "--- ROM artifacts ---"
ls -lh "$OUT_DIR/" || true

echo ""
echo "=== Stage 3 DONE ==="
echo "=== Copy $OUT_DIR/* to addons/jediterm/native/tinyemu/images/python/ ==="

