// compat_hcc.HC — Linux shims for compiling/running MCRAFT.HC with hcc.
#ifndef COMPAT_HCC_HC
#define COMPAT_HCC_HC

#include <Math.HC>
#include <Mem.HC>

#ifndef Bool
#define Bool I64
#endif

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

// Scan codes & task flags
#define SC_CURSOR_LEFT  0x4B
#define SC_CURSOR_RIGHT 0x4D
#define SC_CURSOR_UP    0x48
#define SC_CURSOR_DOWN  0x50
#define SC_SHIFT        0x2A
#define SC_ESC          0x01
#define WIG_TASK_DFT    0

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

// TempleOS's CTask has a win_inhibit field; hcc's host CTask does not.
#ifdef __HCC__
#define SET_WIN_INHIBIT(x)
#else
#define SET_WIN_INHIBIT(x) Fs->win_inhibit = (x)
#endif

// Type conversion helper
I64 ToI64(F64 x) { return (I64)x; }

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

// TempleOS bit test: read bit `bit` of a 256-bit field (U64[4]).
Bool Bt(U0 *bitfield, I64 bit)
{
  U64 *p = (U64 *)bitfield;
  return (p[bit >> 6] >> (bit & 63)) & 1;
}

// Remaining TempleOS shims that have no Linux equivalent.
U0 SettingsPush() {}
U0 SettingsPop() {}
U0 WinMax(...) {}
U0 DocCursor(...) {}
U0 DocClear() {}
U0 FlushMsgs() {}
U0 PutExcept() {}

#endif // COMPAT_HCC_HC
