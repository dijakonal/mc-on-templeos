#!/bin/bash
# Builds a FAT32 disk image containing MCRAFT.HC so TempleOS can mount it.
# Usage: ./make-fat-image.sh
set -e
cd "$(dirname "$0")"
rm -f fat.img
truncate -s 32M fat.img
mkfs.vfat -F 32 -n TEMPLE fat.img >/dev/null
mcopy -i fat.img MCRAFT.HC ::/MCRAFT.HC
mdir -i fat.img ::/
echo "fat.img ready."
