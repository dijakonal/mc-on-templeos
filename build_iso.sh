#!/bin/bash
# build_iso.sh — Build HolyCraft ISO for TempleOS
#
# Usage:
#   ./build_iso.sh              # build TempleOS-HolyCraft-ISO.ISO (uses make_gpu_source.py)
#   ./build_iso.sh --modular    # build with modular GPU module (src/gpu.HC)
#
# This script builds a TempleOS ISO with HolyCraft support.
# Two build modes are available:

# Default mode: uses the original autogenerator (make_gpu_source.py)
#   - Generates MCRAFT_GPU.HC from MCRAFT.HC
#   - Proven to work with the original TempleOS setup
#   - ./build_iso.sh

# Modular mode: uses the separated GPU module (src/gpu.HC)
#   - src/gpu.HC contains texture data and rendering functions
#   - Easier to change rendering code by modifying gpu.HC
#   - Requires MCRAFT.HC to include "gpu.HC"
#   - ./build_iso.sh --modular

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse mode flag
MODE="default"
if [[ "${1:-}" == "--modular" ]]; then
    MODE="modular"
fi

echo "HolyCraft ISO Builder - Mode: $MODE"

if [[ "$MODE" == "modular" ]]; then
    # Modular mode: src/gpu.HC is already included in MCRAFT.HC
    # Just build the ISO directly
    echo "Building TempleOS-HolyCraft ISO (modular GPU module)..."
    python3 "${SCRIPT_DIR}/scripts/make_templos_iso.py"
else
    # Default mode: generate MCRAFT_GPU.HC using make_gpu_source.py
    echo "Generating MCRAFT_GPU.HC from MCRAFT.HC..."
    python3 "${SCRIPT_DIR}/scripts/make_gpu_source.py"
    
    echo "Building TempleOS-HolyCraft ISO..."
    python3 "${SCRIPT_DIR}/scripts/make_templos_iso.py"
fi

echo "ISO ready! Run with: run-mc.sh (or qemu -cdrom <iso_path>)"