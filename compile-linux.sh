#!/usr/bin/env bash
# compile-linux.sh — build MCRAFT.HC into a Linux binary with hcc.
#
# The Linux port needs hcc >= v0.0.17-beta WITH the scientific-notation
# lexer patch (patches/hcc-scientific-notation.patch): without it hcc
# parses 1e-9 as (1 e) - 9 and every F64 constant multiply in the game
# is silently wrong. Build and install a patched hcc like so:
#
#   git clone https://github.com/Jamesbarford/holyc-lang.git
#   cd holyc-lang && git apply ../patches/hcc-scientific-notation.patch
#   make C_COMPILER=cc BUILD_TYPE=Release && sudo make install
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

# -lm:       terrain noise and the renderer use floor/sin/cos/ceil.
# -lSDL2:    the compat_gpu.HC translation layer opens a window and blits the
#            framebuffer through the GPU (install libsdl2-dev).
# -D__HCC__: selects the compat_hcc.HC shims inside the game source.
"$HCC" -o "$OUT" src/MCRAFT.HC -D__HCC__ -clibs='-lSDL2 -lm'

echo "built $OUT"

if [[ "${1:-}" == "--run" ]]; then
  exec "./$OUT"
fi
