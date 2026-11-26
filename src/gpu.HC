// HolyCraft GPU + texture module
// Separated from MCRAFT.HC for easier rendering code changes.
// Textures are 16x16 Minecraft-style, one U64 per row of 16 shade indices.

// ---- GPU constants ----
#define GPU_W            800
#define GPU_H            600
#define GPU_ALPHA_WATER  140

// ---- 16x16 Minecraft-style textures ->
// gt_rows[B_COUNT * 6 * 16] - packed 16x16 texel shade rows (one U64 per row)
// gt_tex[B_COUNT * 6 * 256] - unpacked texel shades for the hot loop
U64 gt_rows[B_COUNT * 6 * 16];
U8  gt_tex[B_COUNT * 6 * 256];

// ---- Texture initialization ----
// Packs gt_rows into gt_tex for the rasterizer inner loop
U0 GpuTextureInit()
{
  I64 idx, t, k;
  for (idx = 0; idx < B_COUNT * 6 * 16; idx++)
    for (t = 0; t < 16; t++) {
      k = (gt_rows[idx] >> ((15 - t) << 2)) & 15;
      gt_tex[idx * 16 + t] = k;
    }
}

// Look up texture shade index for a given block face texel
I64 GpuTexIndex(I64 blk, I64 dir, I64 tx, I64 ty)
{
  return gt_tex[(blk * 6 + dir) * 256 + ty * 16 + tx];
}

// ---- Block face colors ----
// Gets base and shade colors for a block face, applying height variation
U0 GpuBlockColor(I64 blk, I64 dir, I64 bx, I64 by, I64 bz, U32 *ca, U32 *cb)
{
  U32 base, shade, tmp;
  I64 vary;
  base = GpuRgb(200, 100, 50);
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
  }
  if (dir == D_NEGY) {
    tmp = base; base = shade; shade = tmp;
  }
  vary = 92 + (Hash3i(bx, by, bz) & 31);
  *ca = GpuScale(base, vary);
  *cb = GpuScale(shade, vary);
}

// ---- RGB color helpers ----
U32 GpuRgb(I64 r, I64 g, I64 b)
{
  return (r << 8) | (g << 8) | b;
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

U32 GpuScale(U32 c, I64 pct)
{
  I64 r, g, b;
  r = IClamp(((c >> 16) & 255) * pct / 100, 0, 255);
  g = IClamp(((c >> 8) & 255) * pct / 100, 0, 255);
  b = IClamp((c & 255) * pct / 100, 0, 255);
  return GpuRgb(r, g, b);
}

// ---- Presentation ----
// Presents the back buffer to the screen
// Uses gpu_back from MCRAFT.HC (allocated there)
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

// ---- Sky initialization ----
U0 GpuSkyInit()
{
  I64 y;
  for (y = 0; y < GPU_H; y++)
    sky_row[y] = GpuMix(GpuRgb(24, 66, 118), GpuRgb(169, 214, 242),
                        y * 256 / GPU_H);
  haze_col = GpuRgb(222, 240, 255);
}

// ---- Init GPU present pipeline ----
U0 GPUInit()
{
  I64 i;
  GLPaletteInit;
  gl_vbe = FALSE;
  gpu_fb = NULL;
  gl_tos_fb = gr.dc->body;
  gl_tos_stride = gr.dc->width_internal;
  gpu_w = 640;  gpu_h = 480;  gpu_stride = 640;
  gpu_focal = MC_FOCAL;
  GpuTextureInit;
  GpuSkyInit;
  // Initialize face colors from block colors (16 shades per face)
  face_cols = MAlloc(MC_MAX_FACES * 16 * 4);
  for (i = 0; i < MC_MAX_FACES * 16; i++) {
    face_cols[i] = GpuRgb(200, 100, 50);  // default gray
  }
}

// ---- Font rendering helpers (declared here for module consistency) ----
I64 GpuGlyphRow(U8 ch, I64 row)
{
  return (gpu_font[ch] >> (row * 5)) & 31;
}

U0 GpuChar(U8 ch, I64 x, I64 y, U32 c, I64 scale)
{
  I64 row, col, bits, px, py;
  if (ch < 32 || ch > 126) ch = 63;
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
  // Font definitions are emitted by make_gpu_source.py
}
