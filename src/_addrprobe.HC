#ifdef __HCC__
#include "compat_hcc.HC"
#endif
extern "c" I64 printf(I8 *fmt, ...);
I64 main()
{
  printf("rgb=%llx t0=%llx fb=%llx\n", &_hcc_rgb, &_hcc_t0, &_hcc_fb);
  printf("dc=%llx gr=%llx kbd=%llx\n", &_hcc_dc, &gr, &kbd);
  printf("pal=%llx win=%llx\n", &_hcc_pal, &_hcc_win);
  return 0;
}
