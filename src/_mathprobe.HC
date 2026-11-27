#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  printf("Sin(1)=%.4f Cos(1)=%.4f Sqrt(4)=%.4f\n", Sin(1.0), Cos(1.0), Sqrt(4.0));
  printf("Floor(2.7)=%.2f Ceil(2.1)=%.2f ToI64(45.9)=%lld\n", Floor(2.7), Ceil(2.1), ToI64(45.9));
  printf("tS=%.3f\n", tS());
  return 0;
}
