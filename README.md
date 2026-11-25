# HolyCraft — Minecraft in TempleOS/HolyC

A from-scratch voxel sandbox written in **HolyC** for **TempleOS**. No JVM, no
networking, no C libraries: it renders directly into `gr.dc->body` at 640x480
in TempleOS's 16-color palette.

The shipped `TempleOS-HolyCraft.ISO` boots straight into the game from the
live CD — no typing, no mounting, no second disk required.

## Files

| File | Purpose |
| --- | --- |
| `TempleOS-HolyCraft.ISO` | Bootable TempleOS CD that auto-launches HolyCraft |
| `TempleOS.ISO` | Pristine upstream TempleOS CD (rebuild input) |
| `MCRAFT.HC` | Complete HolyC game source |
| `patch_iso.py` | Repacks the game into the ISO and patches the boot launcher |
| `redsea.py`, `tosz_compress.py` | RedSea filesystem reader + Terry's LZW codec used by `patch_iso.py` |
| `runtest.py`, `qctl.py` | Headless-QEMU boot/screenshot/input helpers |
| `run-qemu.sh`, `make-fat-image.sh`, `fat.img` | Optional: boot stock TempleOS with the source on a FAT disk |
| `screenshots/` | QEMU screenshots proving boot, walking, breaking and placing |

## Run it

```bash
qemu-system-x86_64 -m 512 -cdrom TempleOS-HolyCraft.ISO -boot d -vga std
```

Boot takes about a minute on TCG; HolyCraft opens automatically in the first
terminal. To play on real hardware, burn the ISO to a CD (or boot it as a
virtual CD) — nothing else is needed.

Optional manual route: `./run-qemu.sh` boots the stock CD with `fat.img`
attached; inside TempleOS run `#include "D:/MCRAFT.HC";`.

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Walk / swim / fly horizontally |
| Mouse | Look around |
| `Space` | Jump, swim up, or fly up |
| `Shift` | Fly down (when flying) |
| `F` | Toggle creative flight |
| Left mouse button | Break the targeted block |
| Right mouse button | Place the selected block |
| `1`–`6` | Select hotbar slot (grass, dirt, stone, sand, wood, leaves) |
| Arrow keys | Alternative look controls |
| `Esc` | Quit back to TempleOS |

The HUD shows FPS, player coordinates, the block under the crosshair and the
hotbar. Bedrock cannot be broken; you cannot place a block inside yourself.

## What is implemented

* Deterministic 96 x 96 x 40 voxel world with value-noise/fBm terrain,
  sand beaches, snowy peaks, water at sea level, dirt/grass layers and trees.
* First-person camera with flight, gravity, swimming, AABB collision and
  spawn-point search that avoids trees and water.
* Amanatides–Woo voxel raycast for block targeting, breaking and placing.
* Direct frame-buffer renderer: near-plane clipping, perspective projection,
  convex-polygon scanline fill, depth-bucket painter sorting, Bayer-dithered
  shading and distance fog. Rendering is limited to 13 blocks around the
  player; the face list is allocated with `MAlloc`.
* 16-color block palette with distinct lit/shaded colors per face.

## How the ISO auto-launches

TempleOS executes the root directory's `Once.HC.Z` during startup. The patcher:

1. writes `MCRAFT.HC` into the clusters of the sacrificed
   `Demo/WebLogDemo/access_170622.log` and adds a root directory entry;
2. replaces `Once.HC.Z` with the one-line launcher
   `#include "::/MCRAFT.HC";`, compressed with TempleOS's own LZW format;
3. reads the ISO back through the filesystem parser to verify the bytes.

`patch_iso.py` always patches from the pristine `TempleOS.ISO`, so rebuilding
after an edit is repeatable:

```bash
python3 patch_iso.py
```

## Verification

The screenshots in `screenshots/` were captured from QEMU after booting the
patched ISO:

* `boot.png` — HolyCraft running automatically after boot (HUD, crosshair,
  hotbar and terrain visible).
* `walk.png` — scene and coordinates changed after holding `W`.
* `break.png` — targeted block removed with the left mouse button.
* `place.png` — block placed with the right mouse button.

Reproduce with:

```bash
python3 runtest.py check 85          # fresh boot + screenshot after 85s
python3 qctl.py key "w 1500"         # hold W
python3 qctl.py cmd "mouse_button 1" # press left button
python3 qctl.py cmd "mouse_button 0" # release
python3 qctl.py shot check2
```

## Notes / limitations

* TempleOS is a 640x480 16-color OS: the palette and draw distance are
  deliberately small. Expect a stylized, low-resolution Minecraft rather than
  a pixel clone.
* The world is regenerated deterministically on every launch; edits are not
  saved.
* `MCRAFT.HC` avoids HolyC constructs the TempleOS compiler does not support
  (`?:`, `continue`, initializer lists, forward references, function-like
  macros). A local helper named `peps` is used instead of `eps`, which is a
  built-in TempleOS macro for machine epsilon.
