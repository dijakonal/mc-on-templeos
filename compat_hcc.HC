// compat_hcc.HC — Linux shims for compiling MCRAFT.HC with hcc
#include <Math.HC>
#include <Mem.HC>
// usleep is a libc function; we'll call it via extern
extern U0 usleep(I64 usec);

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

U8 _hcc_fb[640 * 480];

U0 InitHCCCompat() {
  _hcc_dc.color = WHITE;
  _hcc_dc.body = _hcc_fb;
  _hcc_dc.width_internal = 640;
  _hcc_dc.width = 640;
  _hcc_dc.height = 480;
  gr.dc = &_hcc_dc;
}

Bool Bt(U0 *bitfield, I64 bit) { return FALSE; }
F64 tS() { return 0.0; }
U0 Sleep(I64 ms_delay) { usleep(ms_delay * 1000); }
U0 SettingsPush() {}
U0 SettingsPop() {}
U0 WinMax(...) {}
U0 DocCursor(...) {}
U0 DocClear() {}
U0 FlushMsgs() {}
U0 PutExcept() {}
U0 GrPrint(...) {}
