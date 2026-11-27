#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
U8 buf[256];
I64 main()
{
  I64 i;
  I64 nz;
  gr.dc = &_hcc_dc;
  _hcc_dc.color = 15;
  MemSet(_hcc_fb, 0, 640 * 480);
  HCC_FormatJoin(buf, 256, "HELLO", 0, buf);
  printf("fmt-plain: [%s] len-check:", buf);
  nz = 0;
  for (i = 0; i < 8; i++) { if (buf[i]) nz++; }
  printf(" %lld\n", nz);
  GrPrint(gr.dc, 0, 0, "HELLO");
  nz = 0;
  for (i = 0; i < 640 * 8; i++) { if (_hcc_fb[i]) nz++; }
  printf("fb nonzero after GrPrint: %lld\n", nz);
  return 0;
}
