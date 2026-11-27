#ifdef __HCC__
#include "compat_hcc.HC"
#endif

I64 main()
{
  I64 x, y;
  InitHCCCompat;
  for (y = 0; y < 480; y++)
    for (x = 0; x < 640; x++) {
      if (x < 320 && y < 240)      _hcc_fb[y * 640 + x] = 1;   // blue
      else if (x >= 320 && y < 240) _hcc_fb[y * 640 + x] = 2;  // green
      else if (x < 320)             _hcc_fb[y * 640 + x] = 4;  // red
      else                          _hcc_fb[y * 640 + x] = 14; // yellow
    }
  while (1) { Sleep(16); }
  return 0;
}
