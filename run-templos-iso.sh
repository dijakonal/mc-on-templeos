#!/bin/bash
# Command: run-templos-iso.sh
# Creates a TempleOS ISO with HolyCraft support that runs in run-mc (qemu)
# Uses the Python script in the scripts folder
#
# Usage:
#   run-templos-iso.sh              # Create default ISO and run it
#   run-templos-iso.sh <iso_name>   # Use custom ISO name

set -e

# Project directory
PROJECT_DIR="/home/lexi/Desktop/mc-on-templeos"

# Determine output ISO
if [ $# -ge 1 ]; then
    OUT_ISO="$1"
else
    OUT_ISO="$PROJECT_DIR/TempleOS-HolyCraft-ISO.ISO"
fi

echo "=== Creating TempleOS ISO with HolyCraft support ==="
echo "Output ISO: $OUT_ISO"

# Create the ISO using the Python script
# This script uses py files (redsea, tosz_compress) to patch the ISO
python3 "$PROJECT_DIR/scripts/make_templos_iso.py" "$OUT_ISO"

echo ""
echo "=== Running ISO in run-mc (qemu) ==="

# Run with qemu similar to run-mc.sh but using our ISO
qemu-system-x86_64 -m 512 -cdrom "$OUT_ISO" -boot d -vga std