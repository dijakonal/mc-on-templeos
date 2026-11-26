/* QEMU Bochs-VBE probe: set a 1024x768x32 linear framebuffer and paint it.
   This is intentionally standalone so it can be reloaded without touching
   the game source. */

U0 VbeSet(I64 idx, I64 val)
{
  OutU16(0x1CE, idx);
  OutU16(0x1CF, val);
}

I64 VbeGet(I64 idx)
{
  OutU16(0x1CE, idx);
  return InU16(0x1CF);
}

U0 GPUProbe()
{
  I64 b, d, f, vid, did, base, bar, id, ver, mem;
  U32 *fb;
  I64 x, y, w, h, c, r, g, bl;

  Print("GPUPROBE: scanning PCI\n");
  vid = did = 0;  b = d = f = -1;  bar = 0;
  for (b = 0; b < 4; b++)
    for (d = 0; d < 32; d++)
      for (f = 0; f < 8; f++) {
        if (PCIReadU16(b, d, f, 0) == 0x1234) {
          vid = PCIReadU16(b, d, f, 0);
          did = PCIReadU16(b, d, f, 2);
          bar = PCIReadU32(b, d, f, 0x10);
          goto found;
        }
      }
found:
  Print("GPUPROBE: vendor=%x dev=%x bus=%d dev=%d fun=%d bar0=%x\n",
        vid, did, b, d, f, bar);
  if (vid != 0x1234) {
    Print("GPUPROBE: no QEMU VGA controller found\n");
    return;
  }

  base = bar & 0xFFFFF000;
  id = VbeGet(0);  ver = VbeGet(1);  mem = VbeGet(0xA);
  Print("GPUPROBE: VBE id=%x ver=%x mem=%dK64 base=%x\n", id, ver, mem, base);

  VbeSet(4, 0);                 // disable while reprogramming
  VbeSet(1, 1024);              // XRES
  VbeSet(2, 768);               // YRES
  VbeSet(3, 32);                // BPP
  VbeSet(5, 0);                 // bank
  VbeSet(6, 1024);              // virtual width
  VbeSet(7, 768);               // virtual height
  VbeSet(8, 0);                 // x offset
  VbeSet(9, 0);                 // y offset
  VbeSet(4, 0x41);              // enabled + linear framebuffer

  fb = base;
  w = 1024;  h = 768;
  for (y = 0; y < h; y++)
    for (x = 0; x < w; x++) {
      r = (x * 255) / w;
      g = (y * 255) / h;
      bl = ((x + y) * 255) / (w + h);
      fb[y * w + x] = (r << 16) | (g << 8) | bl;
    }

  // Big white crosshair-like marker, so we can confirm the pixel format.
  for (c = 0; c < 64; c++) {
    for (x = 512 - 32; x <= 512 + 32; x++)
      fb[(384 + c - 32) * w + x] = 0x00FFFFFF;
    for (y = 384 - 32; y <= 384 + 32; y++)
      fb[y * w + (512 + c - 32)] = 0x00FFFFFF;
  }
  Print("GPUPROBE: painted 1024x768x32 framebuffer\n");
  Sleep(15000);
}

GPUProbe;
