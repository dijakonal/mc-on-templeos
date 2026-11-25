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
echo '  #include "D:/MCRAFT.HC";'
echo "(If the game is not on D:, first run: Mount(1);  then check the drive letter it prints.)"
