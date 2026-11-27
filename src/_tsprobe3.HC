#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  printf("tS before init: %.4f\n", tS());
  InitHCCCompat;
  printf("tS after init: %.4f (t0.sec=%lld t0.nsec=%lld)\n", tS(), _hcc_t0.tv_sec, _hcc_t0.tv_nsec);
  _hcc_fb[0] = 1;
  Sleep(16);
  printf("tS after present: %.4f (t0.sec=%lld t0.nsec=%lld)\n", tS(), _hcc_t0.tv_sec, _hcc_t0.tv_nsec);
  Sleep(16);
  printf("tS after present2: %.4f\n", tS());
  return 0;
}
