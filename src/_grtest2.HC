#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
U8 buf[256];
I64 main()
{
  I64 i;
  gr.dc = &_hcc_dc;
  _hcc_dc.color = 15;
  MemSet(_hcc_fb, 0, 640 * 480);
  GrPrint(gr.dc, 0, 0, "HELLO");
  printf("fb[0..7]: ");
  for (i = 0; i < 8; i++) printf("%lld ", _hcc_fb[i]);
  printf("\n");
  HCC_FormatJoin(buf, 256, "A %d B", 1, 5);
  printf("fmt-d: [%s]\n", buf);
  HCC_FormatJoin(buf, 256, "X %.1f", 1, 45.5);
  printf("fmt-f: [%s]\n", buf);
  return 0;
}
