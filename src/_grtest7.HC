#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
U8 buf2[256];
U0 GrLoc(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
  U8 buf[256];
  I64 i;
  I64 nz;
  HCC_FormatJoin(buf, 256, fmt, argc, argv);
  nz = 0;
  for (i = 0; i < 8; i++) { if (buf[i]) nz++; }
  printf("GrLoc: buf nz=%lld first=%c\n", nz, buf[0]);
}
U0 GrLoc1(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
  U8 buf[256];
  I64 i;
  I64 nz;
  HCC_FormatJoin(buf, 256, fmt, argc, argv);
  nz = 0;
  for (i = 0; i < 8; i++) { if (buf[i]) nz++; }
  printf("GrLoc1: buf nz=%lld first=%c\n", nz, buf[0]);
}
I64 main()
{
  gr.dc = &_hcc_dc;
  GrLoc(gr.dc, 0, 0, "HELLO");
  GrLoc1(gr.dc, 0, 0, "X %d", 7);
  return 0;
}
