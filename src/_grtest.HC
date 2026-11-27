#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  I64 x, y;
  gr.dc = &_hcc_dc;
  _hcc_dc.color = 15;
  MemSet(_hcc_fb, 0, 640 * 480);
  GrPrint(gr.dc, 0, 0, "HolyCraft  FPS %d  X %.1f Y %.1f Z %.1f", 100, 45.5, 16.0, 49.5);
  for (y = 0; y < 8; y++) {
    for (x = 0; x < 40; x++) {
      if (_hcc_fb[y * 640 + x]) printf("#");
      else printf(".");
    }
    printf("\n");
  }
  return 0;
}
