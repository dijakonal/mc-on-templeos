#!/usr/bin/env bash
# compile-linux.sh — build MCRAFT.HC into a Linux binary with hcc.
#
# Usage:
#   ./compile-linux.sh              # build build/mcraft
#   HCC=/path/to/hcc ./compile-linux.sh
#   ./compile-linux.sh --run        # build, then run it
set -euo pipefail

cd "$(dirname "$0")"

HCC="${HCC:-hcc}"
OUT="build/mcraft"

if ! command -v "$HCC" >/dev/null 2>&1; then
  echo "error: hcc not found (set HCC=/path/to/hcc)" >&2
  exit 1
fi

mkdir -p build

# -l m is required: terrain noise and the renderer use floor/sin/cos/ceil.
"$HCC" -o "$OUT" MCRAFT.HC -l m

echo "built $OUT"

if [[ "${1:-}" == "--run" ]]; then
  exec "./$OUT"
fi
