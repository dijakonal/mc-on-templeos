#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  F64 a;
  F64 b;
  I64 i;
  a = tS();
  for (i = 0; i < 5; i++) {
    Sleep(20);
    b = tS();
    printf("tS=%.4f delta=%.4f\n", b, b - a);
    a = b;
  }
  return 0;
}
