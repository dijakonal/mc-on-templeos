#!/bin/bash
# Boots TempleOS in QEMU with the game disk attached.
# The window opens on your desktop; play inside it.
# Usage: ./run-qemu.sh
set -e
cd "$(dirname "$0")"
[ -f TempleOS.ISO ] || { echo "TempleOS.ISO missing"; exit 1; }
[ -f fat.img ] || ./make-fat-image.sh
qemu-system-x86_64 \
  -m 512 \
  -cdrom TempleOS.ISO \
  -hda fat.img \
  -boot d \
  -vga std \
  -rtc base=localtime
echo ""
echo "Inside TempleOS, run the game with:"
echo '  #include "C:/MCRAFT.HC";'
echo "(fat.img is an MBR disk with one FAT32 partition; TempleOS mounts it as C:.)"
