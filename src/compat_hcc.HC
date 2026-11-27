// compat_hcc.HC — Linux shims for compiling/running MCRAFT.HC with hcc.
// Included from MCRAFT.HC only when __HCC__ is defined (compile-linux.sh
// passes -D__HCC__).  Nothing in here is seen by the TempleOS compiler.
#ifndef COMPAT_HCC_HC
#define COMPAT_HCC_HC

// hcc ships tos.HH automatically (TRUE/FALSE/NULL, MAlloc, MemSet, MemCpy,
// printf, StrPrint, Exit).  hcc's math.HC exposes the C names, so declare
// the ones we need and provide the TempleOS spellings below.
extern "c" F64 sin(F64 f1);
extern "c" F64 cos(F64 f1);
extern "c" F64 sqrt(F64 f1);
extern "c" F64 floor(F64 f1);
extern "c" F64 ceil(F64 f1);

F64 Sin(F64 x)   { return sin(x); }
F64 Cos(F64 x)   { return cos(x); }
F64 Sqrt(F64 x)  { return sqrt(x); }
F64 Floor(F64 x) { return floor(x); }
F64 Ceil(F64 x)  { return ceil(x); }
I64 ToI64(F64 x) { return x(I64); }

// Color constants (TempleOS 16-color palette indices)
#define BLACK   0
#define BLUE    1
#define GREEN   2
#define CYAN    3
#define BROWN   6
#define LTGRAY  7
#define DKGRAY  8
#define LTBLUE  9
#define LTGREEN 10
#define LTCYAN  11
#define LTRED   12
#define YELLOW  14
#define WHITE   15

// Scan codes
#define SC_CURSOR_LEFT  0x4B
#define SC_CURSOR_RIGHT 0x4D
#define SC_CURSOR_UP    0x48
#define SC_CURSOR_DOWN  0x50
#define SC_SHIFT        0x2A
#define SC_ESC          0x01

// Fallback scan codes if not defined in MCRAFT.HC
#ifndef MC_SC_1
#define MC_SC_1 0x02
#define MC_SC_2 0x03
#define MC_SC_3 0x04
#define MC_SC_4 0x05
#define MC_SC_5 0x06
#define MC_SC_6 0x07
#define MC_SC_F 0x21
#endif

// Device context & graphics stubs
class CHCCDC {
  I64 color;
  U8 *body;
  I64 width_internal;
  I64 width;
  I64 height;
};

class CHCCGr {
  CHCCDC *dc;
};

class CHCCPos {
  I64 x;
  I64 y;
};

class CHCCKbd {
  U64 down_bitmap[4];
  I64 scan_code;
};

class CHCCMs {
  CHCCPos pos;
  Bool lb;
  Bool rb;
};

CHCCDC _hcc_dc;
CHCCGr gr;
CHCCKbd kbd;
CHCCMs ms;

// 640x480 8-bit indexed framebuffer written directly by the game.
U8 _hcc_fb[640 * 480];

#include "compat_font.HC"
#include "compat_gpu.HC"

// TempleOS bit test: read bit `bit` of a bitmap.
Bool Bt(U0 *bitfield, I64 bit)
{
  U64 *p = bitfield;
  return (p[bit >> 6] >> (bit & 63)) & 1;
}

// Remaining TempleOS shims that have no Linux equivalent.
U0 SettingsPush() {}
U0 SettingsPop() {}
U0 WinMax(...) {}
U0 DocCursor(...) {}
U0 DocClear() {}
U0 FlushMsgs() {}
U0 PutExcept()
{
  printf("HolyCraft: caught exception, code 0x%llx\n", Fs->except_ch);
}

// The game prints two fixed strings on exit.
I64 Print(U8 *s)
{
  return printf("%s", s);
}

#endif // COMPAT_HCC_HC
