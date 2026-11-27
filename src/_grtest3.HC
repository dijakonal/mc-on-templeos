#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
U8 buf[256];
I64 main()
{
  I64 i;
  I64 a[4];
  F64 dv;
  gr.dc = &_hcc_dc;
  _hcc_dc.color = 15;
  MemSet(_hcc_fb, 0, 640 * 480);
  GrPrint(gr.dc, 0, 0, "HELLO");
  printf("fb[0..7]: ");
  for (i = 0; i < 8; i++) printf("%lld ", _hcc_fb[i]);
  printf("\n");
  a[0] = 5;
  HCC_FormatJoin(buf, 256, "A %d B", 1, a);
  printf("fmt-d: [%s]\n", buf);
  dv = 45.5;
  MemCpy(&a[0], &dv, 8);
  HCC_FormatJoin(buf, 256, "X %.1f", 1, a);
  printf("fmt-f: [%s]\n", buf);
  return 0;
}
