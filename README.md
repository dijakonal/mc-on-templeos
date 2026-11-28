# HolyCraft — Minecraft in TempleOS/HolyC

A from-scratch voxel sandbox written in **HolyC** for **TempleOS**. No JVM, no
networking, no C libraries: it renders directly into `gr.dc->body` at 640x480
in TempleOS's 16-color palette.

There is also a first pass at a graphical layer: `MCRAFT_GPU.HC` is generated
from the same source but renders into an RGB back buffer and presents it through
one of two backends. QEMU's Bochs VBE gives 800x600x32 RGB with smooth block
colors, shaded faces and a gradient sky; without that controller it falls back
to TempleOS's native 640x480/16-color framebuffer instead of showing only a
text/error screen. The shipped `TempleOS-HolyCraft.ISO` boots straight into the
16-color game from the live CD — no typing, no mounting, no second disk
required. For the layered build, boot `TempleOS-HolyCraft-GPU.ISO` instead.

## Files

| File | Purpose |
| --- | --- |
| `TempleOS-HolyCraft.ISO` | Bootable TempleOS CD that auto-launches HolyCraft |
| `TempleOS-HolyCraft-GPU.ISO` | Bootable CD with the graphical-layer build (VBE RGB or 16-color fallback) |
| `TempleOS.ISO` | Pristine upstream TempleOS CD (rebuild input) |
| `src/MCRAFT.HC` | Complete HolyC game source |
| `src/JVM.HC`, `scripts/build_jvm_demo.py`, `src/java/` | HolyJVM: a Java bytecode interpreter for TempleOS + the javac demo build |
| `src/MCRAFT_GPU.HC`, `scripts/make_gpu_source.py` | Generated layered source and its generator |
| `scripts/gpu_hud.py` | HUD reader for the GPU build's inline 5x7 font |
| `scripts/patch_iso.py` | Repacks the game into the ISO and patches the boot launcher |
| `scripts/redsea.py`, `scripts/tosz_compress.py` | RedSea filesystem reader + Terry's LZW codec used by `scripts/patch_iso.py` |
| `scripts/runtest.py`, `scripts/qctl.py` | Headless-QEMU boot/screenshot/input helpers |
| `TempleOS-HolyCraft-DEV.ISO` | Dev ISO: boots into a supervisor that hot-reloads `MCRAFT.HC` from `fat.img` |
| `scripts/build_dev_iso.py`, `scripts/devbridge.py` | Build the dev ISO and run the hot-reload loop |
| `scripts/holyc_lint.py`, `scripts/glyph_ocr.py`, `holyc_font.json` | HolyC static checks + exact-glyph HUD reader |
| `tos/` | Extracted TempleOS headers/sources used by the linter |
| `run-qemu.sh`, `make-fat-image.sh`, `fat.img` | Optional: boot stock TempleOS with the source on an MBR/FAT32 disk |
| `screenshots/` | QEMU screenshots proving boot, walking, breaking, placing and both graphics backends |
| `compile-linux.sh` | Builds `build/mcraft`, a native Linux binary with an SDL2 window |
| `patches/hcc-scientific-notation.patch` | Required hcc lexer fix for the Linux port (scientific-notation literals) |
| `src/compat_hcc.HC`, `src/compat_gpu.HC`, `src/compat_font.HC` | Linux shims, SDL2 GPU blit/input layer, 8x8 HUD font |
| `scripts/raster_ab_test.py` | Boots the GPU ISO against an endpoint-affine baseline ISO and diffs them (rasterizer regression test) |

## Run it

```bash
qemu-system-x86_64 -m 512 -cdrom TempleOS-HolyCraft.ISO -boot d -vga std
```

Boot takes about a minute on TCG; HolyCraft opens automatically in the first
terminal. To play on real hardware, burn the ISO to a CD (or boot it as a
virtual CD) — nothing else is needed.

Optional manual route: `./run-qemu.sh` boots the stock CD with `fat.img`
attached; inside TempleOS run `#include "C:/MCRAFT.HC";`.

To try the layered build with QEMU's RGB backend:

```bash
qemu-system-x86_64 -m 512 -cdrom TempleOS-HolyCraft-GPU.ISO -boot d -vga std
```

The same ISO also runs on other VGA devices; for example `-vga cirrus` selects
the TempleOS 16-color fallback and still renders the full game. The RGB path is
QEMU/Bochs-specific, so the layered ISO is not the shipping ISO for real
hardware.

### Run natively on Linux

`compat_gpu.HC` translates the game's 640x480 indexed framebuffer and keyboard /
mouse into an SDL2 window, so it runs on a normal Linux desktop (install
`libsdl2-dev`). The compiler must be hcc v0.0.17-beta **with**
`patches/hcc-scientific-notation.patch` applied — without it hcc parses
`1e-9` as `(1 e) - 9` and every F64 constant multiply in the game (gravity,
noise, fog timing) is silently wrong:

```bash
git clone https://github.com/Jamesbarford/holyc-lang.git
cd holyc-lang
git apply ../patches/hcc-scientific-notation.patch
make C_COMPILER=cc BUILD_TYPE=Release && sudo make install
cd ..
./compile-linux.sh          # builds build/mcraft
./compile-linux.sh --run    # builds and launches it
```

The port renders and plays the full game (measured ~88 FPS under Xvfb). The
underwater overlay, per-pixel fog and HUD text all go through the same code
paths as the TempleOS builds.

### HolyJVM: Java bytecode on TempleOS

`src/JVM.HC` is a from-scratch JVM (class-file parser + bytecode
interpreter) written in HolyC. It loads a real `javac`-compiled class
(embedded as bytes by `scripts/build_jvm_demo.py`), executes the
instruction set with an explicit call-frame stack, and supports int
arithmetic, static fields, int/boolean arrays, recursive static calls and
`Hos.print/println` builtins. The demo in `src/java/` computes Fibonacci,
a prime sieve and a sum-of-squares with plain `javac --release 8`, and the
results are verified on TempleOS:

```
HolyJVM v0.1: Java bytecode interpreter on TempleOS
HolyJVM: class parsed
4 methods parsed
6106765
168
HolyJVM: run() returned 338350
```

To rebuild the demo class: edit `src/java/JvmDemo.java`, run
`javac --release 8 src/java/JvmDemo.java src/java/Hos.java`, then
`python3 scripts/build_jvm_demo.py` and rebuild the ISO. This proves Java
bytecode runs on TempleOS; running *Minecraft* itself through it would
additionally require the JDK class library, LWJGL's JNI natives and
OpenGL — see the rendering discussion above.

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Walk / swim / fly horizontally |
| Mouse | Look around |
| `Space` | Jump, swim up, or fly up |
| `Ctrl` (hold) | Sprint |
| `Shift` | Sneak on the ground; fly down when flying |
| `F` | Toggle creative flight |
| Left mouse button (hold) | Mine the targeted block — cracks spread, then it drops into the hotbar |
| Right mouse button | Place the selected block (consumes one) |
| `1`–`6` | Select hotbar slot |
| Arrow keys | Alternative look controls |
| `Esc` | Quit back to TempleOS |

The HUD shows FPS, player coordinates, the block under the crosshair, a
mining progress bar and the hotbar with stack counts. Bedrock cannot be
broken; you cannot place a block inside yourself; placing needs items in
the selected slot.

## What is implemented

* Deterministic 96 x 96 x 40 voxel world generated with domain-warped gradient
  noise: continents, eroded hills, ridged mountains, winding river valleys,
  sand/desert beaches, snowy peaks, gravel seabeds, cave systems, coal/iron
  ore and humidity/temperature-driven forests.
* First-person camera with Java-like movement constants (4.3 m/s walk,
  5.6 m/s sprint, 32 m/s² gravity, 8.4 m/s jump), fixed 30 Hz physics
  substeps, ground/air acceleration, water drag/buoyancy, flight, AABB
  collision and a spawn search that prefers open grass or snow.
* Amanatides–Woo voxel raycast for block targeting, breaking and placing.
* Direct frame-buffer renderer: near-plane clipping, perspective projection,
  convex-polygon scanline fill, depth-bucket painter sorting, Bayer-dithered
  shading and distance fog. Rendering is limited to 13 blocks around the
  player; the face list is allocated with `MAlloc`.
* 16-color block palette with distinct lit/shaded colors per face.
* First graphical layer: all drawing goes into one RGB back buffer. `GLInit`
  selects a backend and `GLPresent` publishes a finished frame, so the HUD no
  longer flickers while a frame is being composed.
  * Bochs VBE backend: PCI probe, 800x600x32 linear framebuffer, RGB block
    colors with per-column variation, smoothed sky gradient with a soft haze
    falloff at the horizon, translucent water, inline 5x7 HUD font and
    precomputed shading/fog/sky lookup tables.
  * TempleOS backend: converts the RGB back buffer to the native 640x480
    16-color framebuffer if Bochs VBE is absent. Conversion uses a
    saturation-aware 15-bit lookup table, so sky stays blue and grass stays
    green instead of collapsing into the palette's gray entries.
  Render distance is reduced to 9 blocks in the layered build to keep TCG
  performance usable.
* Per-pixel distance fog in the layered build: faces inside the fog
  transition band blend fog per pixel through a reciprocal-depth lookup
  table (the same interpolated `1/z` the texturing uses), which removes the
  per-face fog stair-stepping between adjacent blocks. Fully fogged faces
  take a fast path that skips texel sampling entirely. The underwater
  overlay blends through a precomputed 16-entry Bayer lookup instead of
  half a million `GpuMix` calls per frame.
* Day/night cycle on a 20-minute Minecraft clock: the sun and moon ride a
  rotating arc (drawn with soft edges on the GPU build), stars fade in at
  night, the GPU build dims block colors and fog with the light level, and
  the 16-color build dithers between day and night sky palettes.
* Drifting translucent clouds in the layered build, generated from a hashed
  cell grid and sorted into the painter pass at cloud height.
* Survival basics: hold the left button to mine (per-block hardness, crack
  dither overlay on the block and a HUD progress bar), broken blocks drop
  Minecraft-style (grass drops dirt, stone drops cobblestone, leaves drop
  nothing) into hotbar slots with stack counts, and placing consumes from
  the selected slot. Cobblestone is a new block with its own texture.
* Gravity blocks: sand and gravel fall cell-by-cell when the support under
  them is removed, cascading down whole columns.
* Minecraft control layout: `Ctrl` sprints, `Shift` sneaks on the ground
  (and still descends while flying).
* Classic 16x16 Minecraft-style face textures. Each face carries UV
  coordinates through near-plane clipping and scanline rasterization.
  `u/z`, `v/z` and `1/z` are interpolated linearly across every scanline and
  divided per pixel through a fixed-point reciprocal table, so texels stay
  locked to block faces instead of swimming as the camera moves. (An earlier
  build divided only at the scanline endpoints and lerped the quotients
  across the span, which let oblique texels slide.) Patterns include grass
  edges, dirt speckles, stone cracks, wood grain/rings, ore blobs, sand, water
  ripples, leaf holes, snow, gravel and bedrock. These are original
  approximations, not Mojang texture assets.

## How the ISO auto-launches

TempleOS executes the root directory's `Once.HC.Z` during startup. The patcher:

1. writes `MCRAFT.HC` into the clusters of the sacrificed
   `Demo/WebLogDemo/access_170622.log` and adds a root directory entry;
2. replaces `Once.HC.Z` with the one-line launcher
   `#include "::/MCRAFT.HC";`, compressed with TempleOS's own LZW format;
3. reads the ISO back through the filesystem parser to verify the bytes.

`scripts/patch_iso.py` always patches from the pristine `TempleOS.ISO`, so rebuilding
after an edit is repeatable:

```bash
python3 scripts/patch_iso.py
```

To rebuild the layered ISO instead:

```bash
python3 scripts/make_gpu_source.py
python3 scripts/holyc_lint.py src/MCRAFT_GPU.HC
HOLYCRAFT_GAME=$PWD/src/MCRAFT_GPU.HC \
HOLYCRAFT_ISO=$PWD/TempleOS-HolyCraft-GPU.ISO python3 scripts/patch_iso.py
```

`scripts/runtest.py` accepts the same `HOLYCRAFT_ISO` environment variable, plus
`HOLYCRAFT_VGA` to select the QEMU VGA device (`std` by default, `cirrus` for
the TempleOS fallback).

## Development: fast hot-reload loop

Rebuilding and rebooting the ISO for every edit is slow (~90 s per iteration).
The dev bridge keeps one QEMU VM booted and reloads source from `fat.img` in
about 30 s, including a full HolyC recompile.

```bash
./make-fat-image.sh                # MBR + FAT32 disk with MCRAFT.HC on C:
python3 scripts/build_dev_iso.py           # build the dev supervisor ISO (once)
python3 scripts/devbridge.py boot          # boot the VM (~45 s)
python3 scripts/devbridge.py reload        # copy edited source + hot-reload (~35 s)
python3 scripts/devbridge.py key "w 1500"  # send input
python3 scripts/devbridge.py shot          # screenshot + parsed HUD
python3 scripts/devbridge.py stop
```

How it works:

* The dev ISO's `Once.HC.Z` runs a supervisor that scans drives for
  `MCRAFT.HC` (it finds `C:`), then waits for `C:/RELOAD`.
* `scripts/devbridge.py` injects a small dev-only hook into a **copy** of the source
  that polls for `C:/RELOAD` and exits the game; `MCRAFT.HC` itself stays
  clean. `DskChg` invalidates TempleOS's disk cache so host-side writes are
  visible.
* `DskChg;` with no argument works; passing a drive letter argument fails to
  compile in this TempleOS build.
* The supervisor calls `MountIDEAuto` and `DskChg`, then recompiles the new
  source with `ExeFile` inside a `try`/`catch`.
* `scripts/holyc_lint.py` catches HolyC pitfalls before booting (`eps` macro
  collisions, bare `tS`, `?:`, `continue`, function-like macros). Run it after
  every edit: `python3 scripts/holyc_lint.py`.
* `scripts/glyph_ocr.py` reads the HUD from fixed 8-pixel TempleOS glyph cells using
  exact bitmaps in `holyc_font.json`, so fps and coordinates can be checked
  without looking at the image.

The FAT disk must have an **MBR partition table** — TempleOS's ATA mount path
parses partition entries and will not find a bare superfloppy. `make-fat-image.sh`
creates a 1 MiB-aligned FAT32 partition at offset 1048576; host tools use the
`fat.img@@1048576` mtools suffix.

`scripts/qctl.py` uses QEMU's HMP monitor at `/tmp/opencode/qdev.sock`; mouse buttons
are numeric (`mouse_button 1` = press left, `0` = release).

The layered build does **not** use the hot-reload loop: in-game `DskChg` polling
was both slow and unstable at VBE resolutions. Regenerate `MCRAFT_GPU.HC`,
rebuild `TempleOS-HolyCraft-GPU.ISO`, and boot a fresh VM instead. The clean
GPU source stays free of dev hooks.

## Verification

The screenshots in `screenshots/` were captured from QEMU after booting the
patched ISO:

* `boot.png` — HolyCraft running automatically after boot (HUD, crosshair,
  hotbar and terrain visible).
* `walk.png` — scene and coordinates changed after holding `W`.
* `break.png` — targeted block removed with the left mouse button.
* `place.png` — block placed with the right mouse button.
* `gpu.png` — layered build on QEMU/VBE with 800x600x32 RGB visuals and
  classic 16x16 Minecraft-style face textures.
* `gpu_fallback.png` — the same ISO on `-vga cirrus`, using the TempleOS
  16-color backend with the same textures instead of showing only text.

Latest final-ISO check: `HolyCraft FPS 8 X 45.5 Y 16.0 Z 49.5`; holding `W`
moved 2.42 blocks; left click changed 8059 pixels and right click changed
3597 pixels. Jump raised the player from Y 16.0 to 17.2 and landed back at
16.0.

GPU-ISO check on `-vga std`: `HOLYCRAFT FPS 7 X 45.5 Y 16.0 Z 49.5` at
800x600x32 (6-8 FPS while moving with per-pixel fog), HUD readable in every
screenshot. The same ISO on `-vga cirrus` renders the full 640x480 16-color
scene at ~10 FPS with a readable HUD; the fallback is dominated by
brown/green/blue instead of gray after the saturation-aware quantization
fix. Rendering sanity on the textured build: consecutive static-camera
screenshots are pixel-identical outside the HUD row (no shimmer), and
rotation/walking frames keep texture features attached to block edges.
`scripts/raster_ab_test.py` automates the rasterizer regression check: it
builds an endpoint-affine baseline ISO (same fog, water and fast paths,
only the UV interpolation differs), boots both at the identical spawn pose
and diffs them — expect a substantial pixel difference (the perspective
error field; ~62% at the spawn pose since the per-pixel fog amplifies it)
and a failure if the two rasterizers ever look identical.
`scripts/gpu_hud.py` reads this HUD with the same exact-bitmap approach as
`scripts/glyph_ocr.py`, but for the inline 5x7 font.

Reproduce with:

```bash
python3 scripts/runtest.py check 85          # fresh boot + screenshot after 85s
python3 scripts/qctl.py key "w 1500"         # hold W
python3 scripts/qctl.py cmd "mouse_button 1" # press left button
python3 scripts/qctl.py cmd "mouse_button 0" # release
python3 scripts/qctl.py shot check2

HOLYCRAFT_ISO=$PWD/TempleOS-HolyCraft-GPU.ISO python3 scripts/runtest.py gpu_check 120
python3 scripts/gpu_hud.py /tmp/opencode/gpu_check.png

HOLYCRAFT_ISO=$PWD/TempleOS-HolyCraft-GPU.ISO HOLYCRAFT_VGA=cirrus \
python3 scripts/runtest.py gpu_fallback_check 120
python3 scripts/gpu_hud.py /tmp/opencode/gpu_fallback_check.png
```

## Notes / limitations

* TempleOS is a 640x480 16-color OS, so the shipping game uses small palette
  and draw distance. Expect a stylized, low-resolution Minecraft rather than
  a pixel clone.
* The RGB backend only targets QEMU's Bochs VBE (`-vga std`). It detects PCI
  vendor `1234:` and programs the linear framebuffer directly; without that
  controller the layered ISO uses the TempleOS 16-color backend. This is not a
  general real-hardware GPU driver.
* The world is regenerated deterministically on every launch; edits are not
  saved.
* `MCRAFT.HC` avoids HolyC constructs the TempleOS compiler does not support
  (`?:`, `continue`, initializer lists, forward references, function-like
  macros). A local helper named `peps` is used instead of `eps`, which is a
  built-in TempleOS macro for machine epsilon.
