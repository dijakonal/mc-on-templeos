#!/usr/bin/env python3
"""Generate MCRAFT_GPU.HC: a graphical-layer build of HolyCraft.

The normal MCRAFT.HC stays 640x480/16-color for real TempleOS hardware.  This
script adds a small graphics layer: an RGB back buffer, a QEMU Bochs-VBE
800x600x32 backend, a TempleOS 16-color fallback backend, and classic
16x16 Minecraft-style face textures sampled with perspective-correct
fixed-point UV interpolation.
"""
import os
import random

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
SRC = os.path.join(ROOT, 'src', 'MCRAFT.HC')
DST = os.path.join(ROOT, 'src', 'MCRAFT_GPU.HC')

FONT = {
    ' ': ["00000"] * 7,
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    'C': ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    'D': ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'F': ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    'G': ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    'H': ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    'I': ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    'J': ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    'K': ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'N': ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'Q': ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'S': ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'V': ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    'W': ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    'X': ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    'Z': ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    '0': ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    '1': ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    '2': ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    '3': ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    '4': ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    '5': ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    '6': ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    '7': ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    '8': ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    '9': ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    '.': ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ':': ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    '-': ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
}

# Classic 16x16 Minecraft-style pixel patterns, emitted as one U64 per row.
# Digits are shade-ramp indices: 0 = lit/base color, 15 = dark/shade color.
B_COUNT = 14
SIDES = (0, 1, 4, 5)  # POSX, NEGX, POSZ, NEGZ


def _noise(seed, lo, hi):
    rng = random.Random(seed)
    return [[rng.randint(lo, hi) for _ in range(16)] for _ in range(16)]


def _grass_top(seed):
    rows = _noise(seed, 1, 6)
    rng = random.Random(seed + 1)
    for _ in range(26):
        rows[rng.randrange(16)][rng.randrange(16)] = rng.choice((0, 7, 8, 9, 10))
    return rows


def _dirt(seed):
    rows = _noise(seed, 2, 9)
    rng = random.Random(seed + 2)
    for _ in range(14):
        rows[rng.randrange(16)][rng.randrange(16)] = rng.choice((11, 12, 13))
    return rows


def _grass_side(seed):
    rows = _dirt(seed)
    rng = random.Random(seed + 3)
    for x in range(16):
        depth = 3 + rng.randrange(3)
        for y in range(16 - depth, 16):
            rows[y][x] = rng.choice((1, 2, 3, 4, 5, 6, 7, 8))
    return rows


def _stone(seed):
    rows = _noise(seed, 2, 7)
    rng = random.Random(seed + 4)
    for _ in range(12):
        rows[rng.randrange(16)][rng.randrange(16)] = rng.choice((9, 10, 11))
    for _ in range(3):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        for _ in range(5):
            if 0 <= x < 16 and 0 <= y < 16:
                rows[y][x] = 12
            x += rng.choice((-1, 0, 1))
            y += rng.choice((0, 1))
    return rows


def _sand(seed):
    rows = _noise(seed, 1, 6)
    rng = random.Random(seed + 5)
    for _ in range(12):
        rows[rng.randrange(16)][rng.randrange(16)] = rng.choice((7, 8, 9))
    return rows


def _water(seed):
    rows = _noise(seed, 2, 5)
    for y in (2, 7, 12):
        for x in range(16):
            if (x + y) % 7 != 0:
                rows[y][x] = 7 + (x % 3)
    return rows


def _wood_side(seed):
    rows = _noise(seed, 3, 7)
    rng = random.Random(seed + 6)
    for x in range(16):
        if x % 4 == 0:
            for y in range(16):
                rows[y][x] = 10 + ((x // 4) % 3)
    cx, cy = 5 + rng.randrange(5), 6 + rng.randrange(4)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if 0 <= cx + dx < 16 and 0 <= cy + dy < 16 and abs(dx) + abs(dy) <= 2:
                rows[cy + dy][cx + dx] = 12 + ((abs(dx) + abs(dy)) & 1)
    return rows


def _wood_top(seed):
    rows = [[0] * 16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            v = 2 + (int(d * 1.7) % 5) * 2
            if int(d) % 3 == 0:
                v += 2
            rows[y][x] = min(v, 15)
    return rows


def _leaves(seed):
    rows = _noise(seed, 2, 7)
    rng = random.Random(seed + 7)
    for y in range(16):
        for x in range(16):
            if rng.random() < 0.12:
                rows[y][x] = rng.choice((13, 14, 15))
    return rows


def _snow(seed):
    rows = _noise(seed, 0, 3)
    rng = random.Random(seed + 8)
    for _ in range(8):
        rows[rng.randrange(16)][rng.randrange(16)] = 5
    return rows


def _bedrock(seed):
    rows = _noise(seed, 9, 13)
    for y in range(16):
        for x in range(16):
            if ((x // 2) + (y // 2)) % 2 == 0:
                rows[y][x] = 11 + ((x + y) & 1) * 3
    return rows


def _gravel(seed):
    rows = _noise(seed, 3, 9)
    rng = random.Random(seed + 9)
    for _ in range(16):
        rows[rng.randrange(16)][rng.randrange(16)] = rng.choice((11, 12, 13))
    return rows


def _ore(seed, vals):
    rows = _stone(seed)
    rng = random.Random(seed + 10)
    for bx, by in ((2, 2), (10, 3), (5, 9), (12, 11)):
        for dy in range(3):
            for dx in range(3):
                if rng.random() < 0.82:
                    rows[by + dy][bx + dx] = rng.choice(vals)
    return rows


def _cobble(seed):
    # Rounded stone chunks separated by dark mortar; per-cell brightness
    # variation makes the individual cobbles read clearly.
    rows = [[0] * 16 for _ in range(16)]
    rng = random.Random(seed + 11)
    for y in range(16):
        for x in range(16):
            gx, gy = x // 4, y // 4
            mx, my = x % 4, y % 4
            base = 7 + ((gx * 3 + gy * 5 + ((gx * gy) & 3)) & 3)
            if mx == 0 or my == 0:
                base -= 3
            v = base + rng.randrange(2)
            rows[y][x] = max(2, min(13, v))
    return rows


def _texture_rows(blk, direction):
    seed = blk * 101 + direction * 17 + 5
    if blk == 1:    # grass
        if direction == 2: return _grass_top(seed)
        if direction == 3: return _dirt(seed)
        return _grass_side(seed)
    if blk == 2: return _dirt(seed)                 # dirt
    if blk == 3: return _stone(seed)                # stone
    if blk == 4: return _sand(seed)                 # sand
    if blk == 5: return _water(seed)                # water
    if blk == 6:                                    # wood
        return _wood_top(seed) if direction in (2, 3) else _wood_side(seed)
    if blk == 7: return _leaves(seed)               # leaves
    if blk == 8: return _snow(seed)                 # snow
    if blk == 9: return _bedrock(seed)              # bedrock
    if blk == 10: return _gravel(seed)              # gravel
    if blk == 11: return _ore(seed, (14, 15))       # coal ore
    if blk == 12: return _ore(seed, (12, 13, 14))   # iron ore
    if blk == 13: return _cobble(seed)              # cobblestone
    return _stone(seed)


def _texture_code():
    out = []
    for blk in range(B_COUNT):
        for direction in range(6):
            rows = _texture_rows(blk, direction)
            for y, row in enumerate(rows):
                val = 0
                for digit in row:
                    val = (val << 4) | (digit & 15)
                idx = (blk * 6 + direction) * 16 + y
                out.append('  gt_rows[%d] = 0x%016X;' % (idx, val))
    return '\n'.join(out)


GPU_BLOCK = r'''#define GPU_W            800
#define GPU_H            600
#define GPU_ALPHA_WATER  140
#define GPU_ALPHA_CLOUD  185
#define MC_CLOUD_Y       34.0
#define GPU_PERSPECTIVE_SCALE 4096

// HolyCraft graphical layer: one RGB back buffer, two backends.
//   * QEMU Bochs VBE: 800x600x32, one MemCpy present
//   * TempleOS native: 640x480x8, RGB converted to the 16-color palette
U32 *gpu_fb;                             // VBE linear framebuffer, NULL otherwise
U32 *gpu_back;                           // RGB back buffer
U8  *gl_tos_fb;                          // gr.dc->body in fallback mode
I64  gl_tos_stride;
Bool gl_vbe;
I64  gpu_w, gpu_h, gpu_stride;
F64  gpu_focal;
U32  gl_pal[16];
U8  *gl_lut;
U64  gpu_font[128];
U32  sky_row[GPU_H];
U32  sky_row_n[GPU_H];                   // night gradient (scaled day rows)
U32  haze_col;
U32 *face_cols;
U64 gt_rows[B_COUNT * 6 * 16];           // 16 rows of packed 16x16 texel shades
U8  gt_tex[B_COUNT * 6 * 256];           // unpacked texel shades for the hot loop
U32 gl_inv[65537];                       // fixed-point reciprocals for perspective divide

I64 GLColorToIndexSlow(U32 c)
{
  I64 i, dr, dg, db, best = 1e18, d, bi = 0;
  I64 cr = (c >> 16) & 255, cg = (c >> 8) & 255, cb = c & 255;
  I64 mx = cr, mn = cr, sat, pen;
  if (cg > mx) mx = cg;
  if (cb > mx) mx = cb;
  if (cg < mn) mn = cg;
  if (cb < mn) mn = cb;
  sat = mx - mn;
  for (i = 0; i < 16; i++) {
    dr = cr - ((gl_pal[i] >> 16) & 255);
    dg = cg - ((gl_pal[i] >> 8) & 255);
    db = cb - (gl_pal[i] & 255);
    d = dr * dr + dg * dg + db * db;
    pen = 0;
    if (sat >= 24 && (i == 7 || i == 8 || i == 15)) pen = 400000;
    if (d + pen < best) { best = d + pen; bi = i; }
  }
  return bi;
}

U0 GLPaletteInit()
{
  I64 r, g, b, idx;
  gl_lut = MAlloc(32768);
  gl_pal[0]  = 0x000000;  gl_pal[1]  = 0x0000A8;
  gl_pal[2]  = 0x00A800;  gl_pal[3]  = 0x00A8A8;
  gl_pal[4]  = 0xA80000;  gl_pal[5]  = 0xA800A8;
  gl_pal[6]  = 0xA85700;  gl_pal[7]  = 0xA8A8A8;
  gl_pal[8]  = 0x575757;  gl_pal[9]  = 0x5757FF;
  gl_pal[10] = 0x57FF57;  gl_pal[11] = 0x57FFFF;
  gl_pal[12] = 0xFF5757;  gl_pal[13] = 0xFF57FF;
  gl_pal[14] = 0xFFFF57;  gl_pal[15] = 0xFFFFFF;
  for (r = 0; r < 32; r++)
    for (g = 0; g < 32; g++)
      for (b = 0; b < 32; b++) {
        idx = (r << 10) | (g << 5) | b;
        gl_lut[idx] = GLColorToIndexSlow((r << 19) | (g << 11) | (b << 3));
      }
}

I64 GLColorToIndex(U32 c)
{
  I64 r5 = (c >> 19) & 31, g5 = (c >> 11) & 31, b5 = (c >> 3) & 31;
  return gl_lut[(r5 << 10) | (g5 << 5) | b5];
}

U0 GpuVbeSet(I64 idx, I64 val)
{
  OutU16(0x1CE, idx);
  OutU16(0x1CF, val);
}

I64 GpuVbeGet(I64 idx)
{
  OutU16(0x1CE, idx);
  return InU16(0x1CF);
}

U0 GLInit()
{
  I64 b, d, f, bar, base, vid;
  GLPaletteInit;
  gl_vbe = FALSE;
  gpu_fb = NULL;
  gl_tos_fb = gr.dc->body;
  gl_tos_stride = gr.dc->width_internal;
  gpu_w = 640;  gpu_h = 480;  gpu_stride = 640;
  gpu_focal = MC_FOCAL;
  vid = 0;  b = d = f = 0;  bar = 0;
  for (b = 0; b < 4 && !vid; b++)
    for (d = 0; d < 32 && !vid; d++)
      for (f = 0; f < 8 && !vid; f++)
        if (PCIReadU16(b, d, f, 0) == 0x1234) {
          vid = 0x1234;
          bar = PCIReadU32(b, d, f, 0x10);
        }
  if (!vid) {
    Print("HolyCraft GL: no Bochs VBE; using TempleOS 16-color backend\n");
    return;
  }
  base = bar & 0xFFFFF000;
  GpuVbeSet(4, 0);                       // disable while reprogramming
  GpuVbeSet(1, GPU_W);
  GpuVbeSet(2, GPU_H);
  GpuVbeSet(3, 32);
  GpuVbeSet(5, 0);
  GpuVbeSet(6, GPU_W);
  GpuVbeSet(7, GPU_H);
  GpuVbeSet(8, 0);
  GpuVbeSet(9, 0);
  GpuVbeSet(4, 0x41);                    // enabled + linear framebuffer
  gpu_fb = base;
  gl_vbe = TRUE;
  gpu_w = GPU_W;  gpu_h = GPU_H;  gpu_stride = GPU_W;
  gpu_focal = MC_FOCAL * GPU_W / 640.0;  // keep the 640x480 field of view
  Print("HolyCraft GL: Bochs VBE %d x %d x 32 at %x\n", gpu_w, gpu_h, base);
}

U32 GpuRgb(I64 r, I64 g, I64 b)
{
  return (r << 16) | (g << 8) | b;
}

U32 GpuMix(U32 a, U32 b, I64 t)
{
  I64 ar, ag, ab, br, bg, bb;
  t = IClamp(t, 0, 256);
  ar = (a >> 16) & 255;  ag = (a >> 8) & 255;  ab = a & 255;
  br = (b >> 16) & 255;  bg = (b >> 8) & 255;  bb = b & 255;
  return GpuRgb((ar * (256 - t) + br * t) >> 8,
                (ag * (256 - t) + bg * t) >> 8,
                (ab * (256 - t) + bb * t) >> 8);
}

// Underwater tint lookup: the overlay color depends only on the 4x4 Bayer
// pattern, so the 16 blends are precomputed once instead of calling
// GpuMix half a million times per frame.
U32 uwater_lut[16];
U0 GpuUnderwaterInit()
{
  I64 i;
  for (i = 0; i < 16; i++)
    uwater_lut[i] = GpuMix(GpuRgb(0, 34, 68), GpuRgb(0, 102, 170), i * 17);
}

// Per-pixel distance fog: fog_w_lut[q] is the fog amount (0..255) for a
// reciprocal-depth slot.  FillFace indexes it with ww >> 22, where ww is
// the linearly interpolated 1/z attribute (fiw << 16), so q == fiw >> 6
// and q * 64 + 32 approximates fiw.  Fog is blended per pixel only on
// faces inside the transition band, which removes the per-face fog
// stair-stepping between adjacent blocks.
U32 mcr_fog_col;
U8  fog_w_lut[1024];
U0 GpuFogInit()
{
  I64 q;
  F64 z, fogt;
  mcr_fog_col = GpuRgb(169, 214, 242);
  for (q = 0; q < 1024; q++) {
    z = GPU_PERSPECTIVE_SCALE / (q * 64.0 + 32.0);
    fogt = (z - MC_FOG_START) / MC_FOG_SPAN;
    fogt = FClamp(fogt, 0.0, 1.0);
    fog_w_lut[q] = ToI64(fogt * 255.0);
  }
}

U32 GpuScale(U32 c, I64 pct)
{
  I64 r, g, b;
  r = IClamp(((c >> 16) & 255) * pct / 100, 0, 255);
  g = IClamp(((c >> 8) & 255) * pct / 100, 0, 255);
  b = IClamp((c & 255) * pct / 100, 0, 255);
  return GpuRgb(r, g, b);
}

U0 GLPresent()
{
  I64 x, y;
  U8 *dst;
  if (gl_vbe) {
    MemCpy(gpu_fb, gpu_back, gpu_w * gpu_h * 4);
    return;
  }
  dst = gl_tos_fb;
  for (y = 0; y < gpu_h; y++)
    for (x = 0; x < gpu_w; x++)
      dst[y * gl_tos_stride + x] = GLColorToIndex(gpu_back[y * gpu_stride + x]);
}

U0 GpuSkyInit()
{
  I64 y;
  for (y = 0; y < GPU_H; y++)
    sky_row[y] = GpuMix(GpuRgb(24, 66, 118), GpuRgb(169, 214, 242),
                        y * 256 / GPU_H);
  haze_col = GpuRgb(222, 240, 255);
  // Night sky: the day gradient scaled way down, mixed back in per frame
  // by the light level.
  for (y = 0; y < GPU_H; y++)
    sky_row_n[y] = GpuScale(sky_row[y], 42);
}

U0 GpuBlockColor(I64 blk, I64 dir, I64 bx, I64 by, I64 bz, U32 *ca, U32 *cb)
{
  U32 base, shade, tmp;
  I64 vary;
  base = GpuRgb(150, 150, 150);
  shade = GpuRgb(90, 90, 90);
  if (blk == B_GRASS) {
    if (dir == D_POSY) { base = GpuRgb(86, 168, 66); shade = GpuRgb(48, 118, 46); }
    else if (dir == D_NEGY) { base = GpuRgb(134, 96, 67); shade = GpuRgb(88, 60, 41); }
    else { base = GpuRgb(134, 96, 67); shade = GpuRgb(66, 152, 60); }
  } else if (blk == B_DIRT) {
    base = GpuRgb(134, 96, 67);   shade = GpuRgb(88, 60, 41);
  } else if (blk == B_STONE) {
    base = GpuRgb(140, 140, 142); shade = GpuRgb(82, 82, 86);
  } else if (blk == B_SAND) {
    base = GpuRgb(222, 202, 137); shade = GpuRgb(174, 152, 96);
  } else if (blk == B_WATER) {
    base = GpuRgb(52, 120, 214);  shade = GpuRgb(24, 72, 148);
  } else if (blk == B_WOOD) {
    base = GpuRgb(124, 88, 52);   shade = GpuRgb(74, 48, 28);
  } else if (blk == B_LEAVES) {
    base = GpuRgb(62, 152, 58);   shade = GpuRgb(26, 88, 34);
  } else if (blk == B_SNOW) {
    base = GpuRgb(246, 249, 252); shade = GpuRgb(202, 220, 232);
  } else if (blk == B_BEDROCK) {
    base = GpuRgb(74, 74, 78);    shade = GpuRgb(32, 32, 36);
  } else if (blk == B_GRAVEL) {
    base = GpuRgb(152, 148, 138); shade = GpuRgb(84, 82, 78);
  } else if (blk == B_COAL_ORE) {
    base = GpuRgb(140, 140, 142); shade = GpuRgb(26, 26, 30);
  } else if (blk == B_IRON_ORE) {
    base = GpuRgb(140, 140, 142); shade = GpuRgb(224, 158, 92);
  } else if (blk == B_COBBLE) {
    base = GpuRgb(150, 150, 152); shade = GpuRgb(88, 88, 92);
  }
  if (dir == D_NEGY) {
    tmp = base; base = shade; shade = tmp;
  }
  vary = 92 + (Hash3i(bx, by, bz) & 31);
  *ca = GpuScale(base, vary);
  *cb = GpuScale(shade, vary);
}

// 16x16 Minecraft-style textures.  Each U64 holds one row of 16 shade
// indices; unpack once into bytes so the rasterizer stays a single array read.
U0 GpuTextureInit()
{
  I64 idx, t, k, q;
  gl_inv[0] = 1073741824;
  for (q = 1; q <= 65536; q++)
    gl_inv[q] = 1073741824 / q;
GT_ROW_ASSIGNMENTS
  for (idx = 0; idx < B_COUNT * 6 * 16; idx++)
    for (t = 0; t < 16; t++) {
      k = (gt_rows[idx] >> ((15 - t) << 2)) & 15;
      gt_tex[idx * 16 + t] = k;
    }
}

I64 GpuTexIndex(I64 blk, I64 dir, I64 tx, I64 ty)
{
  return gt_tex[(blk * 6 + dir) * 256 + ty * 16 + tx];
}

U0 GpuRect(I64 x0, I64 y0, I64 x1, I64 y1, U32 c)
{
  I64 x, y;
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > scr_w) x1 = scr_w;
  if (y1 > scr_h) y1 = scr_h;
  for (y = y0; y < y1; y++)
    for (x = x0; x < x1; x++)
      db[y * stride + x] = c;
}

U0 GpuPixel(I64 x, I64 y, U32 c)
{
  if (x < 0 || x >= scr_w || y < 0 || y >= scr_h) return;
  db[y * stride + x] = c;
}

I64 GpuGlyphRow(U8 ch, I64 row)
{
  return (gpu_font[ch] >> (row * 5)) & 31;
}

U0 GpuChar(U8 ch, I64 x, I64 y, U32 c, I64 scale)
{
  I64 row, col, bits, px, py;
  if (ch < 32 || ch > 126) ch = 63;       // '?' as ASCII without a literal
  for (row = 0; row < 7; row++) {
    bits = GpuGlyphRow(ch, row);
    for (col = 0; col < 5; col++)
      if (bits & (1 << col))
        for (py = 0; py < scale; py++)
          for (px = 0; px < scale; px++)
            GpuPixel(x + (col + 1) * scale + px, y + row * scale + py, c);
  }
}

U0 GpuText(U8 *s, I64 x, I64 y, U32 c, I64 scale)
{
  I64 i, cx;
  cx = x;
  for (i = 0; s[i]; i++) {
    if (s[i] == ' ') cx += 6 * scale;
    else {
      GpuChar(s[i], cx, y, c, scale);
      cx += 6 * scale;
    }
  }
}

U0 GpuTextUpper(U8 *s, I64 x, I64 y, U32 c, I64 scale)
{
  I64 i, cx;
  U8 ch;
  cx = x;
  for (i = 0; s[i]; i++) {
    ch = s[i];
    if (ch >= 'a' && ch <= 'z') ch -= 32;
    if (ch == ' ') cx += 6 * scale;
    else {
      GpuChar(ch, cx, y, c, scale);
      cx += 6 * scale;
    }
  }
}

U0 GpuFontInit()
{
  GPU_FONT_ASSIGNMENTS
}

'''

CLOUDS_CODE = """U0 EmitClouds()
{
  // Translucent white quads drifting east at cloud height, from a hashed
  // 24-block cell grid so clumps stay stable in world space.  Both facings
  // are emitted: from below you see the underside, from above the top.
  // Clouds ignore terrain fog (they read as above-weather) and only cull
  // at 40 blocks of forward distance.
  F64 t2, sxx, syy, depth, xmin, xmax, ymin, ymax, wx0, wz0, off;
  F64 cx4[4], cy4[4], cz4[4], ox[5], oy[5], oz[5], wx, wy, wz;
  I64 pcx, pcz, cx, cz, i, nv, ci, cj, fi, k, dir, j;
  I64 lightpct;
  U32 ca, cb;
  if (fcount > MC_MAX_FACES - 16) return;
  off = t0 * 0.55;
  pcx = ToI64(Floor((P.x + off) / 24.0));
  pcz = ToI64(Floor(P.z / 24.0));
  lightpct = 35 + ToI64(day_light * 65.0);
  for (cx = pcx - 2; cx <= pcx + 2; cx++) {
    for (cz = pcz - 2; cz <= pcz + 2; cz++) {
      if ((Hash2i(cx, cz) & 7) < 3) {
        wx0 = cx * 24 - off;
        wz0 = cz * 24;
        for (dir = 3; dir >= 2; dir--) {
          if (fcount > MC_MAX_FACES - 8) break;
          for (k = 0; k < 4; k++) {
            i = face_corners[dir][k];
            cx4[k] = wx0 + corn_x[i] * 24;
            cy4[k] = MC_CLOUD_Y;
            cz4[k] = wz0 + corn_z[i] * 24;
          }
          nv = 0;
          for (i = 0; i < 4; i++) {
            wx = cx4[i] - cam_ex;
            wy = cy4[i] - cam_ey;
            wz = cz4[i] - cam_ez;
            cz4[i] = wx * cam_fx + wy * cam_fy + wz * cam_fz;
            cy4[i] = wx * cam_ux + wy * cam_uy + wz * cam_uz;
            cx4[i] = wx * cam_rx + wy * cam_ry + wz * cam_rz;
          }
          for (i = 0; i < 4; i++) {
            ci = cz4[i] >= MC_NEAR;
            cj = cz4[(i + 1) & 3] >= MC_NEAR;
            if (ci) {
              ox[nv] = cx4[i];  oy[nv] = cy4[i];  oz[nv] = cz4[i];  nv++;
            }
            if (ci != cj) {
              t2 = (MC_NEAR - cz4[i]) / (cz4[(i + 1) & 3] - cz4[i]);
              ox[nv] = cx4[i] + (cx4[(i + 1) & 3] - cx4[i]) * t2;
              oy[nv] = cy4[i] + (cy4[(i + 1) & 3] - cy4[i]) * t2;
              oz[nv] = MC_NEAR;
              nv++;
            }
          }
          if (nv >= 3) {
            depth = 0;
            for (i = 0; i < nv; i++) {
              sxx = scr_w * 0.5 + ox[i] * gpu_focal / oz[i];
              syy = scr_h * 0.5 - oy[i] * gpu_focal / oz[i];
              fxs[fcount * 5 + i] = sxx;
              fys[fcount * 5 + i] = syy;
              // Textureless: UVs are 0 so every texel lands on shade 0,
              // and fiw keeps the perspective divide in range.
              ftu[fcount * 5 + i] = 0;
              ftv[fcount * 5 + i] = 0;
              fiw[fcount * 5 + i] = ToI64(GPU_PERSPECTIVE_SCALE / oz[i]);
              depth += oz[i];
            }
            depth /= nv;
            if (depth <= 40.0) {
              xmin = xmax = fxs[fcount * 5];
              ymin = ymax = fys[fcount * 5];
              for (i = 1; i < nv; i++) {
                sxx = fxs[fcount * 5 + i];
                syy = fys[fcount * 5 + i];
                if (sxx < xmin) xmin = sxx;
                if (sxx > xmax) xmax = sxx;
                if (syy < ymin) ymin = syy;
                if (syy > ymax) ymax = syy;
              }
              if (xmax >= 0 && xmin < scr_w && ymax >= 0 && ymin < scr_h) {
                fi = fcount;
                fnverts[fi] = nv;
                ca = GpuScale(GpuRgb(246, 248, 252), lightpct);
                cb = GpuScale(GpuRgb(214, 224, 236), lightpct);
                for (k = 0; k < 16; k++) face_cols[fi * 16 + k] = GpuMix(ca, cb, k * 16);
                fcolA[fi] = ca;
                fcolB[fi] = cb;
                falpha[fi] = GPU_ALPHA_CLOUD;
                fblk[fi] = B_AIR;
                fdir[fi] = dir;
                ffogT[fi] = 0;
                fdepth[fi] = depth;
                fcount++;
              }
            }
          }
        }
      }
    }
  }
}

"""
FILL_FACE = r'''U0 FillFace(I64 fi){
  I64 n, e, a, b2, y, ymin, ymax, x, x0, x1, row, tx, ty, alpha, blk, dir, texbase;
  I64 fbase, ul, ur, vl, vr, wl, wr, tu, tv, ww, du, dv, dw, upx, upy, inv;
  I64 ua, ub, va, vb, wa, wb, fb, band, fullfog;
  U32 c;
  F64 xl, xr, t, yy0, yy1, xa, xb, fmin, fmax, xspan, t0;
  n = fnverts[fi];
  alpha = falpha[fi];  blk = fblk[fi];  dir = fdir[fi];
  texbase = (blk * 6 + dir) * 256;
  fbase = fi * 16;
  fmin = 1e30;  fmax = -1e30;
  for (e = 0; e < n; e++) {
    if (fys[fi * 5 + e] < fmin) fmin = fys[fi * 5 + e];
    if (fys[fi * 5 + e] > fmax) fmax = fys[fi * 5 + e];
  }
  ymin = IClamp(ToI64(Ceil(fmin)), 0, scr_h - 1);
  ymax = IClamp(ToI64(Floor(fmax)), 0, scr_h - 1);
  for (y = ymin; y <= ymax; y++) {
    xl = 1e9;  xr = -1e9;  ul = ur = vl = vr = wl = wr = 0;
    for (e = 0; e < n; e++) {
      a = e;  b2 = (e + 1) % n;
      yy0 = fys[fi * 5 + a];  yy1 = fys[fi * 5 + b2];
      if (yy0 != yy1 && ((y >= yy0 && y < yy1) || (y >= yy1 && y < yy0))) {
        t = (y - yy0) / (yy1 - yy0);
        xa = fxs[fi * 5 + a];  xb = fxs[fi * 5 + b2];
        ua = ftu[fi * 5 + a];  ub = ftu[fi * 5 + b2];
        va = ftv[fi * 5 + a];  vb = ftv[fi * 5 + b2];
        wa = fiw[fi * 5 + a];  wb = fiw[fi * 5 + b2];
        x = xa + (xb - xa) * t;
        if (x < xl) {
          xl = x;
          ul = ToI64(ua + (ub - ua) * t);  vl = ToI64(va + (vb - va) * t);
          wl = ToI64(wa + (wb - wa) * t);
        }
        if (x > xr) {
          xr = x;
          ur = ToI64(ua + (ub - ua) * t);  vr = ToI64(va + (vb - va) * t);
          wr = ToI64(wa + (wb - wa) * t);
        }
      }
    }
    if (xr >= xl) {
      x0 = IClamp(ToI64(Ceil(xl)), 0, scr_w - 1);
      x1 = IClamp(ToI64(Floor(xr)), 0, scr_w - 1);
      row = y * stride;
      // Interpolate u/z, v/z and 1/z linearly across the span, then divide
      // per pixel through the reciprocal table.  Dividing only at the ends
      // and lerping the quotients lets texels swim on oblique faces; the
      // per-pixel divide pins every texel to its world position.
      if (xr > xl) {
        xspan = xr - xl;
        wl = IClamp(wl, 1, 65536);  wr = IClamp(wr, 1, 65536);
        t0 = (x0 - xl) / xspan;
        du = ToI64((ur - ul) * 65536.0 / xspan);
        dv = ToI64((vr - vl) * 65536.0 / xspan);
        dw = ToI64((wr - wl) * 65536.0 / xspan);
        tu = ToI64((ul + (ur - ul) * t0) * 65536.0);
        tv = ToI64((vl + (vr - vl) * t0) * 65536.0);
        ww = ToI64((wl + (wr - wl) * t0) * 65536.0);
      } else {
        wl = IClamp(wl, 1, 65536);
        du = 0;  dv = 0;  dw = 0;
        tu = ul << 16;  tv = vl << 16;  ww = wl << 16;
      }
      fullfog = ffogT[fi] == 255;
      band = ffogT[fi] > 0 && ffogT[fi] < 255;
      if (fullfog) {
        // Beyond the fog end no texels are visible; just paint the fog.
        if (alpha == 255) {
          for (x = x0; x <= x1; x++) db[row + x] = mcr_fog_col;
        } else {
          for (x = x0; x <= x1; x++)
            db[row + x] = GpuMix(db[row + x], mcr_fog_col, alpha);
        }
      } else if (alpha == 255) {
        for (x = x0; x <= x1; x++) {
          inv = gl_inv[ww >> 16];
          upx = (tu * inv) >> 46;
          upy = (tv * inv) >> 46;
          tx = (upx >> 8) & 15;
          ty = (upy >> 8) & 15;
          c = face_cols[fbase + gt_tex[texbase + (ty << 4) + tx]];
          if (band) {
            fb = fog_w_lut[ww >> 22];
            if (fb > 0) c = GpuMix(c, mcr_fog_col, fb);
          }
          db[row + x] = c;
          tu += du;  tv += dv;  ww += dw;
        }
      } else {
        for (x = x0; x <= x1; x++) {
          inv = gl_inv[ww >> 16];
          upx = (tu * inv) >> 46;
          upy = (tv * inv) >> 46;
          tx = (upx >> 8) & 15;
          ty = (upy >> 8) & 15;
          c = face_cols[fbase + gt_tex[texbase + (ty << 4) + tx]];
          if (band) {
            fb = fog_w_lut[ww >> 22];
            if (fb > 0) c = GpuMix(c, mcr_fog_col, fb);
          }
          db[row + x] = GpuMix(db[row + x], c, alpha);
          tu += du;  tv += dv;  ww += dw;
        }
      }
    }
  }
}

'''

SKY_HUD = r'''U0 DrawSkyBody(F64 dx, F64 dy, F64 dz, I64 radius, U32 core, U32 ring, I64 alpha){
  // Project a celestial body direction and stamp a dithered disc.
  F64 sx, sy, u, v, t, cz, px, py;
  I64 x, y;
  px = dx * cam_rx + dy * cam_ry + dz * cam_rz;
  py = dx * cam_ux + dy * cam_uy + dz * cam_uz;
  cz = dx * cam_fx + dy * cam_fy + dz * cam_fz;
  if (cz < 0.1) return;
  sx = scr_w * 0.5 + px * gpu_focal / cz;
  sy = scr_h * 0.5 - py * gpu_focal / cz;
  for (v = -radius - 3; v <= radius + 3; v++)
    for (u = -radius - 3; u <= radius + 3; u++) {
      x = ToI64(sx) + u;  y = ToI64(sy) + v;
      if (x >= 0 && x < scr_w && y >= 0 && y < scr_h) {
        t = Sqrt(u * u + v * v);
        if (t < radius) db[y * stride + x] = GpuMix(db[y * stride + x], core, alpha);
        else if (t < radius + 2.5)
          db[y * stride + x] = GpuMix(db[y * stride + x], ring, alpha >> 1);
      }
    }
}

U0 DrawSky()
{
  F64 sx, sy, u, v, t, cz, a, dx, dy, dz, px, py, fade;
  I64 y, row, x, horizon, hw, i, lightv, starn, sx_i, sy_i;
  U32 c, day, night;
  horizon = scr_h * 0.5 + Sin(P.pitch) / Cos(P.pitch) * gpu_focal;
  horizon = IClamp(horizon, -scr_h, 2 * scr_h);
  lightv = ToI64(day_light * 255.0);
  for (y = 0; y < scr_h; y++) {
    day = sky_row[y];
    night = sky_row_n[y];
    // Haze peaks at the horizon and fades out over +/-6 rows instead of
    // being a hard band.
    hw = 255 - ToI64(FFabs(y - horizon) * 42.5);
    c = GpuMix(night, day, lightv);
    if (hw > 0) c = GpuMix(c, haze_col, hw);
    MemSetU32(db + y * stride, c, scr_w);
  }
  // stars: hashed dome positions rotating with the sun arc, fading in as
  // the light level drops
  if (day_light < 0.55) {
    starn = ToI64((0.55 - day_light) * 2.0 * 255.0);
    a = day_time * 6.2832;
    for (i = 0; i < 56; i++) {
      dx = Cos(a + (Hash2i(i * 3 + 1, 7) & 1023) * 0.0061) * 0.85;
      dy = Sin(a + (Hash2i(i * 5 + 2, 11) & 511) * 0.0061) * 0.9;
      dz = 0.35 + (Hash2i(i * 7 + 3, 13) & 255) * 0.0012;
      px = dx * cam_rx + dy * cam_ry + dz * cam_rz;
      py = dx * cam_ux + dy * cam_uy + dz * cam_uz;
      cz = dx * cam_fx + dy * cam_fy + dz * cam_fz;
      if (cz >= 0.1) {
        sx = scr_w * 0.5 + px * gpu_focal / cz;
        sy = scr_h * 0.5 - py * gpu_focal / cz;
        sx_i = ToI64(sx);  sy_i = ToI64(sy);
        if (sx_i >= 0 && sx_i < scr_w && sy_i >= 0 && sy_i < scr_h)
          db[sy_i * stride + sx_i] = GpuMix(db[sy_i * stride + sx_i],
                                            GpuRgb(255, 255, 255), starn);
      }
    }
  }
  // fog follows the light level so night fog goes dark too
  mcr_fog_col = GpuMix(GpuRgb(22, 30, 56), GpuRgb(169, 214, 242), lightv);
  // sun and moon ride opposite ends of the same rotating arc: noon is
  // day_time 0.25, midnight 0.75
  a = day_time * 6.2832;
  dx = Cos(a) * 0.85;
  dy = Sin(a);
  dz = 0.35;
  fade = FClamp(dy * 4.0 + 0.5, 0.0, 1.0);
  if (fade > 0.02)
    DrawSkyBody(dx, dy, dz, 7, GpuRgb(255, 238, 170), GpuRgb(255, 214, 96),
                ToI64(fade * 255.0));
  fade = FClamp(-dy * 4.0 + 0.5, 0.0, 1.0);
  if (fade > 0.02)
    DrawSkyBody(-dx, -dy, -dz, 6, GpuRgb(228, 232, 240), GpuRgb(150, 158, 176),
                ToI64(fade * 255.0));
}

U0 DrawCrackOverlay()
{
  // Darkening dither over the block being mined; the density grows with
  // the progress so it reads as cracks spreading over the block.
  // BLACK index 0 / RGB 0 both read as black, so this is backend-neutral.
  F64 vx[8], vy[8], vz[8], cx, cy, cz, sxx[8], syy[8], frac, t, ya, yb, xa, xb, xl, xr;
  I64 i, j, f, k, stage, x, y, x0, x1, y0, y1, row, c[4];
  if (!mining || mine_progress <= 0.0) return;
  frac = mine_progress / blk_hard[world[WIdx(mine_hx, mine_hy, mine_hz)]];
  frac = FClamp(frac, 0.0, 0.999);
  stage = ToI64(frac * 8.0) + 1;
  for (i = 0; i < 8; i++) {
    vx[i] = mine_hx + corn_x[i] - cam_ex;
    vy[i] = mine_hy + corn_y[i] - cam_ey;
    vz[i] = mine_hz + corn_z[i] - cam_ez;
    cz = vx[i] * cam_fx + vy[i] * cam_fy + vz[i] * cam_fz;
    if (cz < MC_NEAR) return;           // only when fully visible
    cx = vx[i] * cam_rx + vy[i] * cam_ry + vz[i] * cam_rz;
    cy = vx[i] * cam_ux + vy[i] * cam_uy + vz[i] * cam_uz;
    sxx[i] = scr_w * 0.5 + cx * gpu_focal / cz;
    syy[i] = scr_h * 0.5 - cy * gpu_focal / cz;
  }
  for (f = 0; f < 6; f++) {
    for (k = 0; k < 4; k++) c[k] = face_corners[f][k];
    y0 = scr_h;  y1 = 0;
    for (k = 0; k < 4; k++) {
      if (ToI64(syy[c[k]]) < y0) y0 = ToI64(syy[c[k]]);
      if (ToI64(syy[c[k]]) > y1) y1 = ToI64(syy[c[k]]);
    }
    y0 = IClamp(y0, 0, scr_h - 1);
    y1 = IClamp(y1, 0, scr_h - 1);
    for (y = y0; y <= y1; y++) {
      xl = 1e9;  xr = -1e9;
      for (j = 0; j < 4; j++) {
        k = (j + 1) & 3;
        ya = syy[c[j]];  yb = syy[c[k]];
        if (ya != yb && ((y >= ya && y < yb) || (y >= yb && y < ya))) {
          t = (y - ya) / (yb - ya);
          xa = sxx[c[j]] + (sxx[c[k]] - sxx[c[j]]) * t;
          if (xa < xl) xl = xa;
          if (xa > xr) xr = xa;
        }
      }
      if (xr >= xl) {
        x0 = IClamp(ToI64(Ceil(xl)), 0, scr_w - 1);
        x1 = IClamp(ToI64(Floor(xr)), 0, scr_w - 1);
        row = y * stride;
        for (x = x0; x <= x1; x++)
          if (bayer[(x & 3) + ((y & 3) << 2)] < stage) db[row + x] = BLACK;
      }
    }
  }
}

U0 DrawPixelLine(I64 x0, I64 y0, I64 x1, I64 y1, U32 c)
{
  I64 dx = IAbs(x1 - x0), dy = IAbs(y1 - y0), sx, sy, err, e2;
  if (x0 < x1) sx = 1; else sx = -1;
  if (y0 < y1) sy = 1; else sy = -1;
  err = dx - dy;
  while (TRUE) {
    GpuPixel(x0, y0, c);
    if (x0 == x1 && y0 == y1) break;
    e2 = 2 * err;
    if (e2 > -dy) { err -= dy; x0 += sx; }
    if (e2 <  dx) { err += dx; y0 += sy; }
  }
}

U0 DrawBoxWire(I64 bx, I64 by, I64 bz, U32 c)
{
  F64 vx[8], vy[8], vz[8], cx, cy, cz, sxx[8], syy[8];
  I64 i, j;
  I64 edges[24];
  edges[0] = 0;  edges[1] = 1;   edges[2] = 1;  edges[3] = 5;
  edges[4] = 5;  edges[5] = 4;   edges[6] = 4; edges[7] = 0;
  edges[8] = 2;  edges[9] = 3;   edges[10] = 3; edges[11] = 7;
  edges[12] = 7; edges[13] = 6;  edges[14] = 6; edges[15] = 2;
  edges[16] = 0; edges[17] = 2;  edges[18] = 1; edges[19] = 3;
  edges[20] = 5; edges[21] = 7;  edges[22] = 4; edges[23] = 6;
  for (i = 0; i < 8; i++) {
    vx[i] = bx + corn_x[i] - cam_ex;
    vy[i] = by + corn_y[i] - cam_ey;
    vz[i] = bz + corn_z[i] - cam_ez;
    cz = vx[i] * cam_fx + vy[i] * cam_fy + vz[i] * cam_fz;
    if (cz < MC_NEAR) return;
    cx = vx[i] * cam_rx + vy[i] * cam_ry + vz[i] * cam_rz;
    cy = vx[i] * cam_ux + vy[i] * cam_uy + vz[i] * cam_uz;
    sxx[i] = scr_w * 0.5 + cx * gpu_focal / cz;
    syy[i] = scr_h * 0.5 - cy * gpu_focal / cz;
  }
  for (j = 0; j < 12; j++)
    DrawPixelLine(ToI64(sxx[edges[j * 2]]), ToI64(syy[edges[j * 2]]),
                  ToI64(sxx[edges[j * 2 + 1]]), ToI64(syy[edges[j * 2 + 1]]), c);
}

U0 DrawCrosshair()
{
  I64 cx = scr_w / 2, cy = scr_h / 2, i;
  for (i = -8; i <= 8; i++) {
    if (IAbs(i) > 3) {
      GpuPixel(cx + i, cy, GpuRgb(255, 255, 255));
      GpuPixel(cx, cy + i, GpuRgb(255, 255, 255));
    }
  }
}

U0 DrawHotbar()
{
  I64 i, x0, x, y, b;
  U32 ca, cb;
  x0 = scr_w / 2 - 6 * 40 / 2;
  for (i = 0; i < 6; i++) {
    b = hotbar_items[i];
    GpuBlockColor(b, D_POSZ, 0, 0, 0, &ca, &cb);
    for (y = 0; y < 34; y++)
      for (x = 0; x < 34; x++) {
        if (y == 0 || y == 33 || x == 0 || x == 33 || y == 4 || x == 4) {
          if (i == hotbar_sel) db[(scr_h - 44 + y) * stride + (x0 + i * 40 + x)] = GpuRgb(255, 255, 255);
          else db[(scr_h - 44 + y) * stride + (x0 + i * 40 + x)] = GpuRgb(40, 44, 52);
        } else {
          db[(scr_h - 44 + y) * stride + (x0 + i * 40 + x)] = ca;
        }
      }
  }
}

U0 DrawHud(I64 fps)
{
  I64 hitx, hity, hitz, hitface;
  Bool hit;
  U8 *s;
  GpuRect(0, 0, scr_w, 24, GpuRgb(16, 24, 36));
  s = MStrPrint("HOLYCRAFT FPS %d X %.1f Y %.1f Z %.1f", fps, P.x, P.y, P.z);
  GpuText(s, 6, 5, GpuRgb(255, 255, 255), 2);
  Free(s);
  if (P.flying) GpuText("FLYING", 6, 28, GpuRgb(255, 213, 79), 2);
  hit = Raycast(&hitx, &hity, &hitz, &hitface);
  if (hit) {
    GpuTextUpper(blkinfo[world[WIdx(hitx, hity, hitz)]].name,
                 scr_w - 180, 5, GpuRgb(220, 235, 255), 2);
    DrawBoxWire(hitx, hity, hitz, GpuRgb(255, 255, 255));
  }
  DrawHotbar;
  DrawCrosshair();
}

'''

ASSIGNMENTS = []
for ch, rows in FONT.items():
    val = 0
    for r, row in enumerate(rows):
        for i, bit in enumerate(row):
            if bit == '1':
                val |= 1 << (r * 5 + i)
    ASSIGNMENTS.append('  gpu_font[%d] = 0x%X;' % (ord(ch), val))
FONT_CODE = '\n'.join(ASSIGNMENTS)


def replace_once(s, old, new, label):
    if old not in s:
        raise SystemExit('missing replacement anchor: ' + label)
    return s.replace(old, new, 1)


def cut_replace(s, start, end, new, label):
    if start not in s or end not in s:
        raise SystemExit('missing cut anchors: ' + label)
    a = s.index(start)
    b = s.index(end, a)
    return s[:a] + new + s[b:]


def main():
    s = open(SRC).read()

    # Keep the base constant as the FOV calibration value, but make the
    # renderer use the scaled runtime focal length.
    focal_def = '#define MC_FOCAL        450.0           // projection focal length in pixels\n'
    if focal_def not in s:
        raise SystemExit('focal anchor missing')
    head, tail = s.split(focal_def, 1)
    s = head + focal_def + tail.replace('MC_FOCAL', 'gpu_focal')

    s = replace_once(s, '#define MC_RENDER_DIST  13', '#define MC_RENDER_DIST  9',
                     'gpu render distance')
    # The fog boundaries are plain literals in the shared source (hcc
    # miscompiles constant arithmetic), so scale them for the 9-block view.
    s = replace_once(s, '#define MC_FOG_START    5.85', '#define MC_FOG_START    4.05',
                     'gpu fog start')
    s = replace_once(s, '#define MC_FOG_END      12.35', '#define MC_FOG_END      8.55',
                     'gpu fog end')
    s = replace_once(s, '#define MC_FOG_CULL     12.597', '#define MC_FOG_CULL     8.721',
                     'gpu fog cull')
    s = replace_once(s, '#define MC_FOG_SPAN     6.5', '#define MC_FOG_SPAN     4.5',
                     'gpu fog span')
    s = replace_once(s, 'U8  *db;', 'U32 *db;', 'db type')

    # Put the GPU helpers after Hash3i and the framebuffer globals.  HolyC
    # has no forward references for functions or globals.
    global_anchor = 'I64  scr_w, scr_h;'
    s = replace_once(s, global_anchor,
                     global_anchor + '\n\n' +
                        GPU_BLOCK.replace('GPU_FONT_ASSIGNMENTS', FONT_CODE)
                                 .replace('GT_ROW_ASSIGNMENTS', _texture_code()),
                     'gpu helpers after framebuffer globals')
    s = replace_once(s, 'U8   *fcolA;\nU8   *fcolB;',
                     'U32  *fcolA;\nU32  *fcolB;\nU8   *falpha;\n'
                        'I64  *ftu;\nI64  *ftv;\nI64  *fiw;\nI64  *fblk;\nI64  *fdir;', 'face colors')
    s = replace_once(s, '  fcolA   = MAlloc(MC_MAX_FACES);\n  fcolB   = MAlloc(MC_MAX_FACES);',
                     '  fcolA   = MAlloc(MC_MAX_FACES * 4);\n  fcolB   = MAlloc(MC_MAX_FACES * 4);\n  falpha  = MAlloc(MC_MAX_FACES);\n'
                        '  ftu     = MAlloc(MC_MAX_FACES * 5 * 8);\n'
                        '  ftv     = MAlloc(MC_MAX_FACES * 5 * 8);\n'
                        '  fiw     = MAlloc(MC_MAX_FACES * 5 * 8);\n'
                        '  fblk    = MAlloc(MC_MAX_FACES * 8);\n'
                        '  fdir    = MAlloc(MC_MAX_FACES * 8);\n'
                        '  face_cols = MAlloc(MC_MAX_FACES * 16 * 4);', 'face alloc')
    s = replace_once(s, '  face_light[D_POSZ] = 0.45; face_light[D_NEGZ] = 0.45;\n}',
                     '  face_light[D_POSZ] = 0.45; face_light[D_NEGZ] = 0.45;\n'
                        '  GpuTextureInit;\n  GpuFontInit;\n  GpuSkyInit;\n}', 'font init')
    s = cut_replace(s, 'U0 FillFace(I64 fi)\n{', '// camera basis for the current frame',
                    FILL_FACE, 'fill face')

    s = replace_once(s, '  CBlockInfo *bi;\n  bi = &blkinfo[world[WIdx(bx, by, bz)]];\n'
                        '  if (dir == D_POSY)      { fcolA[fcount] = bi->top_a;  fcolB[fcount] = bi->top_b; }\n'
                        '  else if (dir == D_NEGY) { fcolA[fcount] = bi->bot_a;  fcolB[fcount] = bi->bot_b; }\n'
                        '  else                    { fcolA[fcount] = bi->side_a; fcolB[fcount] = bi->side_b; }',
                     '  U32 ca, cb, c;\n'
                        '  I64 lightpct;\n'
                        '  blk = world[WIdx(bx, by, bz)];\n'
                        '  GpuBlockColor(blk, dir, bx, by, bz, &ca, &cb);\n'
                        '  // Night dims block colors down to ~35% brightness.\n'
                        '  lightpct = 35 + ToI64(day_light * 65.0);\n'
                        '  ca = GpuScale(ca, lightpct);\n'
                        '  cb = GpuScale(cb, lightpct);\n'
                        '  fcolA[fcount] = ca;  fcolB[fcount] = cb;\n'
                        '  fblk[fcount] = blk;  fdir[fcount] = dir;\n'
                        '  if (blk == B_WATER) falpha[fcount] = GPU_ALPHA_WATER;\n'
                        '  else falpha[fcount] = 255;', 'emit face colors')
    s = replace_once(s, '  I64 i, j, nv, ci, cj, fi, cidx, x, y, sx, sy, xmin, xmax, ymin, ymax, st;',
                     '  I64 i, j, nv, ci, cj, fi, cidx, x, y, sx, sy, xmin, xmax, ymin, ymax, st, blk;',
                     'emit face vars')
    s = replace_once(s, '  F64 cx[4], cy[4], cz[4], ox[5], oy[5], oz[5], t, wx, wy, wz, depth, fogt;',
                     '  F64 cx[4], cy[4], cz[4], ox[5], oy[5], oz[5], t, wx, wy, wz, depth, fogt, pp;\n'
                        '  I64 ou[5], ov[5], cu[5], cv[5];', 'emit face uv arrays')
    s = replace_once(s, '    wz = bz + corn_z[cidx] - cam_ez;\n'
                        '    cx[i] = wx * cam_rx + wy * cam_ry + wz * cam_rz;',
                     '    wz = bz + corn_z[cidx] - cam_ez;\n'
                        '    if (dir == D_POSX || dir == D_NEGX) {\n'
                        '      ou[i] = corn_z[cidx] * 4096;  ov[i] = corn_y[cidx] * 4096;\n'
                        '    } else if (dir == D_POSY || dir == D_NEGY) {\n'
                        '      ou[i] = corn_x[cidx] * 4096;  ov[i] = corn_z[cidx] * 4096;\n'
                        '    } else {\n'
                        '      ou[i] = corn_x[cidx] * 4096;  ov[i] = corn_y[cidx] * 4096;\n'
                        '    }\n'
                        '    cx[i] = wx * cam_rx + wy * cam_ry + wz * cam_rz;', 'corner uvs')
    s = replace_once(s, '      ox[nv] = cx[i]; oy[nv] = cy[i]; oz[nv] = cz[i]; nv++;',
                     '      ox[nv] = cx[i]; oy[nv] = cy[i]; oz[nv] = cz[i];\n'
                        '      cu[nv] = ou[i]; cv[nv] = ov[i]; nv++;', 'keep vertex uv')
    s = replace_once(s, '      oz[nv] = MC_NEAR;\n      nv++;',
                     '      oz[nv] = MC_NEAR;\n'
                        '      cu[nv] = ToI64(ou[i] + (ou[j] - ou[i]) * t);\n'
                        '      cv[nv] = ToI64(ov[i] + (ov[j] - ov[i]) * t);\n'
                        '      nv++;', 'clip vertex uv')
    s = replace_once(s, '    fys[fcount * 5 + i] = syy;',
                     '    fys[fcount * 5 + i] = syy;\n'
                        '    pp = GPU_PERSPECTIVE_SCALE / oz[i];\n'
                        '    ftu[fcount * 5 + i] = ToI64(cu[i] * pp);\n'
                        '    ftv[fcount * 5 + i] = ToI64(cv[i] * pp);\n'
                        '    fiw[fcount * 5 + i] = ToI64(pp);', 'project uv')
    s = replace_once(s, '  st = face_light[dir] * 15;', '  st = face_light[dir] * 255;', 'shade scale')
    s = replace_once(s, '  ffogT[fi]   = fogt * 15;',
                     '  ffogT[fi]   = fogt * 255;\n'
                        '  for (i = 0; i < 16; i++) {\n'
                        '    face_cols[fi * 16 + i] = GpuMix(ca, cb, i * 16);\n'
                        '  }', 'fog scale')

    s = cut_replace(s, 'U0 DrawSkyBody(F64 dx, F64 dy, F64 dz, I64 radius, U8 core, U8 ring)',
                    '// =============================== GAMEPLAY',
                    SKY_HUD, 'sky and hud')

    # Clouds: replace the 16-color stub with translucent drifting quads at
    # cloud height (both facings, so they read from above and below).
    s = cut_replace(s, 'U0 EmitClouds()\n{', 'U0 BuildFaceList()', CLOUDS_CODE,
                    'clouds')

    s = replace_once(s, '        if (bayer[(x & 3) + ((y & 3) << 2)] < 10.0) db[y * stride + x] = BLUE;\n'
                        '        else db[y * stride + x] = LTBLUE;',
                     '            db[y * stride + x] = uwater_lut[ToI64(bayer[(x & 3) + ((y & 3) << 2)])];',
                     'underwater')

    s = replace_once(s, '  InitBlocks;\n  InitRendererTables;',
                     '  InitBlocks;\n  GLInit;\n  GpuUnderwaterInit;\n  GpuFogInit;\n  InitRendererTables;', 'gl init call')
    s = replace_once(s, '  db = gr.dc->body;\n  stride = gr.dc->width_internal;\n'
                        '  scr_w = gr.dc->width;\n  scr_h = gr.dc->height;',
                     '  gpu_back = MAlloc(gpu_w * gpu_h * 4);\n'
                        '  db = gpu_back;\n'
                        '  stride = gpu_stride;\n'
                        '  scr_w = gpu_w;\n  scr_h = gpu_h;', 'fb init')
    s = s.replace('  scr_w = gr.dc->width;\n  scr_h = gr.dc->height;\n',
                  '  scr_w = gpu_w;\n  scr_h = gpu_h;\n')
    s = replace_once(s, '  Sleep(5);',
                     '  GLPresent;\n'
                        '  Sleep(5);', 'present frame')

    s = ('// HolyCraft graphical-layer build generated by make_gpu_source.py.\n'
         '// RGB back buffer with Bochs VBE 800x600x32 when available, otherwise\n'
         '// the TempleOS 640x480/16-color backend. Frames are double-buffered\n'
         '// and block faces use classic 16x16 Minecraft-style textures with\n'
         '// perspective-correct fixed-point UV interpolation.\n') + s
    open(DST, 'w').write(s)
    print('wrote', DST, len(s), 'bytes')


if __name__ == '__main__':
    main()
