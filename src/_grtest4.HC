#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  I64 i;
  I64 nz = 0;
  F64 dv;
  I64 a[2];
  F64 out;
  for (i = 0; i < 1024; i++) { if (hcc_font[i] != 0) nz++; }
  printf("font nonzero bytes: %lld (glyph H row0=0x%llx)\n", nz, hcc_font[72 * 8]);
  dv = 45.5;
  a[0] = 0; a[1] = 0;
  MemCpy(&a[0], &dv, 8);
  MemCpy(&out, &a[0], 8);
  printf("memcpy roundtrip: %.2f\n", out);
  return 0;
}
