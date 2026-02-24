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

cd "$BR_DIR"

echo "=== Stage 2: build (incremental) ==="
echo "[INFO] BR_DIR=$BR_DIR"
echo "[INFO] DL_DIR=$DL_DIR"
echo "[INFO] jobs=$(nproc)"

make BR2_DL_DIR="$DL_DIR" -j"$(nproc)"

echo "=== Stage 2 DONE ==="
echo "[INFO] Images: $BR_DIR/output/images/"
ls -lh "$BR_DIR/output/images/" || true

