#!/bin/bash
# Builds an MBR-partitioned FAT32 disk image containing MCRAFT.HC.
# TempleOS parses the MBR when auto-mounting ATA drives, so a bare
# superfloppy (filesystem at sector 0) is not enough.
# Usage: ./make-fat-image.sh
set -e
cd "$(dirname "$0")"
IMG=fat.img
OFF=$((2048 * 512))          # partition starts at sector 2048 (1 MiB)
rm -f "$IMG"
truncate -s 64M "$IMG"
parted -s "$IMG" mklabel msdos mkpart primary fat32 1MiB 100% >/dev/null
mformat -i "$IMG@@$OFF" -F -v TEMPLE :: >/dev/null
mcopy -i "$IMG@@$OFF" src/MCRAFT.HC ::/MCRAFT.HC
echo "Partition offset: $OFF bytes (sector 2048)"
mdir -i "$IMG@@$OFF" ::/
echo "fat.img ready."
