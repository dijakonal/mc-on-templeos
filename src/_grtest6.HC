#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
U8 buf2[256];
U0 GrPrintDbg(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
  I64 i;
  I64 nz;
  printf("dbg: fmt=[%s] argc=%lld\n", fmt, argc);
  HCC_FormatJoin(buf2, 256, fmt, argc, argv);
  printf("dbg: buf2=[%s]\n", buf2);
  nz = 0;
  for (i = 0; i < 8; i++) { if (buf2[i]) nz++; }
  printf("dbg: buf2 nz=%lld\n", nz);
}
I64 main()
{
  gr.dc = &_hcc_dc;
  GrPrintDbg(gr.dc, 0, 0, "HELLO");
  return 0;
}
