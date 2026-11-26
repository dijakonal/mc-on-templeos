// Linux SDL2 / 32-bit ARGB8888 presentation shim included by compat_hcc.HC.
#ifndef _COMPAT_GPU_HC
#define _COMPAT_GPU_HC

#ifndef NULL
#define NULL 0
#endif

// Colors omitted from compat_hcc.HC
#ifndef RED
#define RED 4
#endif
#ifndef PURPLE
#define PURPLE 5
#endif
#ifndef LTPURPLE
#define LTPURPLE 13
#endif

// libc / POSIX declarations
extern U8  *memset(U8 *s, I32 c, U64 n);
extern I32  printf(U8 *fmt, ...);
extern U0   exit(I32 status);

#define CLOCK_MONOTONIC 1

class timespec {
  I64 tv_sec;
  I64 tv_nsec;
};

extern I32 clock_gettime(I32 clk_id, timespec *tp);

// Minimal SDL2 declarations (x86_64 Linux ABI layouts)
class SDL_Keysym {
  I32 scancode;
  I32 sym;
  U16 mod;
  U16 _pad;
  U32 unused;
};

class SDL_KeyboardEvent {
  U32 type;
  U32 timestamp;
  U32 windowID;
  U8  state;
  U8  repeat;
  U8  padding2;
  U8  padding3;
  SDL_Keysym keysym;
};

class SDL_MouseMotionEvent {
  U32 type;
  U32 timestamp;
  U32 windowID;
  U32 which;
  U32 state;
  I32 x;
  I32 y;
  I32 xrel;
  I32 yrel;
};

class SDL_MouseButtonEvent {
  U32 type;
  U32 timestamp;
  U32 windowID;
  U32 which;
  U8  button;
  U8  state;
  U8  clicks;
  U8  padding1;
  I32 x;
  I32 y;
};

class SDL_WindowEvent {
  U32 type;
  U32 timestamp;
  U32 windowID;
  U8  event;
  I32 data1;
  I32 data2;
};

union SDL_Event {
  U32                  type;
  SDL_KeyboardEvent    key;
  SDL_MouseMotionEvent motion;
  SDL_MouseButtonEvent button;
  SDL_WindowEvent      window;
  U8                   padding[64];
};

#define SDL_INIT_VIDEO              0x00000020
#define SDL_WINDOWPOS_CENTERED      0x2FFF0000
#define SDL_WINDOW_SHOWN            0x00000004
#define SDL_RENDERER_ACCELERATED    0x00000002
#define SDL_RENDERER_SOFTWARE       0x00000001
#define SDL_PIXELFORMAT_ARGB8888    0x16362004
#define SDL_TEXTUREACCESS_STREAMING 1

#define SDL_WINDOWEVENT             0x108
#define SDL_WINDOWEVENT_NONE        0
#define SDL_WINDOWEVENT_SHOWN       1
#define SDL_WINDOWEVENT_HIDDEN      2
#define SDL_WINDOWEVENT_EXPOSED     3
#define SDL_WINDOWEVENT_MOVED       4
#define SDL_WINDOWEVENT_RESIZED     5
#define SDL_WINDOWEVENT_SIZE_CHANGED 6
#define SDL_WINDOWEVENT_MINIMIZED   7
#define SDL_WINDOWEVENT_MAXIMIZED   8
#define SDL_WINDOWEVENT_RESTORED    9
#define SDL_WINDOW_ENTER            10
#define SDL_WINDOW_LEAVE            11
#define SDL_WINDOW_FOCUS_GAINED     12
#define SDL_WINDOW_FOCUS_LOST       13

#define SDL_QUIT            0x100
#define SDL_KEYDOWN         0x300
#define SDL_KEYUP           0x301
#define SDL_MOUSEMOTION     0x400
#define SDL_MOUSEBUTTONDOWN 0x401
#define SDL_MOUSEBUTTONUP   0x402

#define SDL_BUTTON_LEFT  1
#define SDL_BUTTON_RIGHT 3

#define SDLK_ESCAPE       27
#define SDLK_SPACE        ' '
#define SDLK_1            '1'
#define SDLK_2            '2'
#define SDLK_3            '3'
#define SDLK_4            '4'
#define SDLK_5            '5'
#define SDLK_6            '6'
#define SDLK_a            'a'
#define SDLK_d            'd'
#define SDLK_f            'f'
#define SDLK_s            's'
#define SDLK_w            'w'
#define SDLK_LSHIFT       0x400000E1
#define SDLK_RSHIFT       0x400000E5
#define SDLK_RIGHT        0x4000004F
#define SDLK_LEFT         0x40000050
#define SDLK_DOWN         0x40000051
#define SDLK_UP           0x40000052

#define SDL_TRUE 1
#define SDL_FALSE 0

#define SDLK_ESCAPE       27
#define SDLK_SPACE        ' '
#define SDLK_1            '1'
#define SDLK_2            '2'
#define SDLK_3            '3'
#define SDLK_4            '4'
#define SDLK_5            '5'
#define SDLK_6            '6'
#define SDLK_a            'a'
#define SDLK_d            'd'
#define SDLK_f            'f'
#define SDLK_s            's'
#define SDLK_w            'w'
#define SDLK_LSHIFT       0x400000E1
#define SDLK_RSHIFT       0x400000E5
#define SDLK_RIGHT        0x4000004F
#define SDLK_LEFT         0x40000050
#define SDLK_DOWN         0x40000051
#define SDLK_UP           0x40000052

#define SDL_TRUE 1
#define SDL_FALSE 0

#define SDLK_ESCAPE       27
#define SDLK_SPACE        ' '
#define SDLK_1            '1'
#define SDLK_2            '2'
#define SDLK_3            '3'
#define SDLK_4            '4'
#define SDLK_5            '5'
#define SDLK_6            '6'
#define SDLK_a            'a'
#define SDLK_d            'd'
#define SDLK_f            'f'
#define SDLK_s            's'
#define SDLK_w            'w'
#define SDLK_LSHIFT       0x400000E1
#define SDLK_RSHIFT       0x400000E5
#define SDLK_RIGHT        0x4000004F
#define SDLK_LEFT         0x40000050
#define SDLK_DOWN         0x40000051
#define SDLK_UP           0x40000052

extern I32  SDL_Init(U32 flags);
extern U0   SDL_Quit();
extern U8  *SDL_GetError();
extern U8  *SDL_CreateWindow(U8 *title, I32 x, I32 y, I32 w, I32 h, U32 flags);
extern U0   SDL_GetWindowSize(U8 *window, I32 *w, I32 *h);
extern U0   SDL_SetWindowSize(U8 *window, I32 w, I32 h);
extern U8  *SDL_CreateRenderer(U8 *window, I32 index, U32 flags);
extern I32  SDL_RenderClear(U8 *renderer);
extern I32  SDL_RenderCopy(U8 *renderer, U8 *texture, U8 *srcrect, U8 *dstrect);
extern U0   SDL_RenderPresent(U8 *renderer);
extern U8  *SDL_CreateTexture(U8 *renderer, U32 format, I32 access, I32 w, I32 h);
extern U0   SDL_DestroyTexture(U8 *texture);
extern I32  SDL_UpdateTexture(U8 *texture, U8 *rect, U8 *pixels, I32 pitch);
extern I32  SDL_PollEvent(SDL_Event *event);
extern U0   SDL_Delay(U32 ms);
extern U0   SDL_SetRelativeMouseMode(I32 enabled);
extern U0   SDL_ShowCursor(I32 enabled);

#define HCC_FB_W 640
#define HCC_FB_H 480

U32 _hcc_rgb[800 * 600];

U32 _hcc_pal[16] = {
  0x000000, 0x0000A8, 0x00A800, 0x00A8A8,
  0xA80000, 0xA800A8, 0xA85700, 0xA8A8A8,
  0x575757, 0x5757FF, 0x57FF57, 0x57FFFF,
  0xFF5757, 0xFF57FF, 0xFFFF57, 0xFFFFFF
};

U8  *_hcc_win = NULL;
U8  *_hcc_ren = NULL;
U8  *_hcc_tex = NULL;
I32  _hcc_tex_w = 0;
I32  _hcc_tex_h = 0;
I32  _hcc_inited = 0;
I32  _hcc_quit = 0;
timespec _hcc_t0;
I32  _hcc_relative_mouse = 0;  // 1 = relative mouse mode enabled

// HolyCraft GPU globals (remove any duplicate global declarations in MCRAFT/gpu)
U32  *gpu_back = NULL;
I64   gpu_w = 0;
I64   gpu_h = 0;
I64   gpu_stride = 0;
Bool  gl_vbe = FALSE;

U0 MemSetU32(U32 *dst, U32 val, I64 count)
{
  I64 i;
  if (!dst || count <= 0) return;
  for (i = 0; i < count; i++) dst[i] = val;
}

U0 _hcc_set_key(I64 sc, I32 down)
{
  if (sc < 0 || sc >= 256) return;
  if (down) {
    kbd.down_bitmap[sc >> 6] |= 1 << (sc & 63);
    kbd.scan_code = sc;
  } else {
    kbd.down_bitmap[sc >> 6] &= ~(1 << (sc & 63));
    if (kbd.scan_code == sc) kbd.scan_code = 0;
  }
}

I64 _hcc_sdl_to_sc(I32 sym)
{
  switch (sym) {
    case SDLK_w:      return 0x11;
    case SDLK_a:      return 0x1E;
    case SDLK_s:      return 0x1F;
    case SDLK_d:      return 0x20;
    case SDLK_f:      return 0x21;
    case SDLK_1:      return 0x02;
    case SDLK_2:      return 0x03;
    case SDLK_3:      return 0x04;
    case SDLK_4:      return 0x05;
    case SDLK_5:      return 0x06;
    case SDLK_6:      return 0x07;
    case SDLK_SPACE:  return 0x39;
    case SDLK_LSHIFT:
    case SDLK_RSHIFT: return SC_SHIFT;
    case SDLK_ESCAPE: return SC_ESC;
    case SDLK_UP:     return SC_CURSOR_UP;
    case SDLK_DOWN:   return SC_CURSOR_DOWN;
    case SDLK_LEFT:   return SC_CURSOR_LEFT;
    case SDLK_RIGHT:  return SC_CURSOR_RIGHT;
    default:          return -1;
  }
}

U0 _hcc_ensure_texture(I32 w, I32 h)
{
  if (!_hcc_ren) return;
  if (_hcc_tex && _hcc_tex_w == w && _hcc_tex_h == h) return;
  if (_hcc_tex) {
    SDL_DestroyTexture(_hcc_tex);
    _hcc_tex = NULL;
  }
  _hcc_tex = SDL_CreateTexture(
    _hcc_ren,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    w,
    h
  );
  _hcc_tex_w = w;
  _hcc_tex_h = h;
}

U0 InitHCCCompat()
{
  if (_hcc_inited) return;
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    printf("SDL_Init failed: %s\n", SDL_GetError());
    exit(1);
  }
  I32 w = 800;
  I32 h = 600;
  if (gpu_w > 0) w = gpu_w;
  if (gpu_h > 0) h = gpu_h;

  _hcc_win = SDL_CreateWindow(
    "HolyCraft (Linux SDL2 RGB)",
                              SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED,
                              w,
                              h,
                              SDL_WINDOW_SHOWN
  );
  if (!_hcc_win) {
    printf("SDL_CreateWindow failed: %s\n", SDL_GetError());
    SDL_Quit();
    exit(1);
  }
  _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, SDL_RENDERER_ACCELERATED);
  if (!_hcc_ren) {
    _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, SDL_RENDERER_SOFTWARE);
  }
  _hcc_ensure_texture(w, h);
  memset(_hcc_fb, 0, sizeof(_hcc_fb));
  _hcc_dc.body = _hcc_fb;
  _hcc_dc.width_internal = HCC_FB_W;
  _hcc_dc.width = HCC_FB_W;
  _hcc_dc.height = HCC_FB_H;
  gr.dc = &_hcc_dc;
  clock_gettime(CLOCK_MONOTONIC, &_hcc_t0);
  _hcc_inited = 1;
  
  // Enable relative mouse mode for mouse capture / continuous look
  SDL_SetRelativeMouseMode(SDL_TRUE);
  SDL_ShowCursor(SDL_FALSE);
  _hcc_relative_mouse = 1;
}

U0 HCC_PumpEvents()
{
  SDL_Event ev;
  I64 sc;
  while (SDL_PollEvent(&ev)) {
    switch (ev.type) {
      case SDL_QUIT:
        _hcc_quit = 1;
        _hcc_set_key(SC_ESC, 1);
        break;
      case SDL_KEYDOWN:
        sc = _hcc_sdl_to_sc(ev.key.keysym.sym);
        if (sc >= 0) _hcc_set_key(sc, 1);
        break;
      case SDL_KEYUP:
        sc = _hcc_sdl_to_sc(ev.key.keysym.sym);
        if (sc >= 0) _hcc_set_key(sc, 0);
        break;
      case SDL_MOUSEMOTION:
        if (_hcc_relative_mouse) {
          ms.pos.x += ev.motion.xrel;
          ms.pos.y += ev.motion.yrel;
        } else {
          ms.pos.x = ev.motion.x;
          ms.pos.y = ev.motion.y;
        }
        break;
      case SDL_MOUSEBUTTONDOWN:
        ms.pos.x = ev.button.x;
        ms.pos.y = ev.button.y;
        if (ev.button.button == SDL_BUTTON_LEFT)  ms.lb = TRUE;
        if (ev.button.button == SDL_BUTTON_RIGHT) ms.rb = TRUE;
        break;
      case SDL_MOUSEBUTTONUP:
        ms.pos.x = ev.button.x;
        ms.pos.y = ev.button.y;
        if (ev.button.button == SDL_BUTTON_LEFT)  ms.lb = FALSE;
        if (ev.button.button == SDL_BUTTON_RIGHT) ms.rb = FALSE;
        break;
      case SDL_WINDOWEVENT:
        if (ev.window.event == SDL_WINDOW_FOCUS_GAINED ||
            ev.window.event == SDL_WINDOW_ENTER) {
          // Re-enable relative mouse mode if it was disabled on focus loss
          SDL_SetRelativeMouseMode(SDL_TRUE);
          SDL_ShowCursor(SDL_FALSE);
          _hcc_relative_mouse = 1;
        }
        break;
    }
  }
}

U0 HCC_PresentRGB32(U32 *src, I64 w, I64 h, I64 stride_px)
{
  if (!_hcc_inited) InitHCCCompat();
  HCC_PumpEvents();
  if (!src || w <= 0 || h <= 0) return;

  I32 iw = w;
  I32 ih = h;
  if (_hcc_win) {
    I32 cur_w = 0;
    I32 cur_h = 0;
    SDL_GetWindowSize(_hcc_win, &cur_w, &cur_h);
    if (cur_w != iw || cur_h != ih) {
      SDL_SetWindowSize(_hcc_win, iw, ih);
    }
  }
  _hcc_ensure_texture(iw, ih);
  if (!_hcc_ren || !_hcc_tex) return;

  if (stride_px <= 0) stride_px = w;
  I32 pitch = stride_px * 4;
  SDL_UpdateTexture(_hcc_tex, NULL, src, pitch);
  SDL_RenderClear(_hcc_ren);
  SDL_RenderCopy(_hcc_ren, _hcc_tex, NULL, NULL);
  SDL_RenderPresent(_hcc_ren);
}

U0 HCC_Present()
{
  if (!_hcc_inited) InitHCCCompat();
  HCC_PumpEvents();
  I64 w = HCC_FB_W;
  I64 h = HCC_FB_H;
  if (gpu_w > 0) w = gpu_w;
  if (gpu_h > 0) h = gpu_h;
  I64 s = w;
  if (gpu_stride > 0) s = gpu_stride;

  if (gpu_back) {
    HCC_PresentRGB32(gpu_back, w, h, s);
    return;
  }
  // Use texture-based 32-bit presentation instead of software palette
  // Convert 16-color framebuffer to 32-bit ARGB8888 for texture
  I64 x, y;
  for (y = 0; y < HCC_FB_H; y++) {
    for (x = 0; x < HCC_FB_W; x++) {
      // Expand 4-bit palette index to 8-bit RGB using the palette, with full alpha
      U8 pal_idx = _hcc_fb[y * HCC_FB_W + x] & 15;
      _hcc_rgb[y * HCC_FB_W + x] = 0xFF000000 | _hcc_pal[pal_idx];
    }
  }
  HCC_PresentRGB32(_hcc_rgb, HCC_FB_W, HCC_FB_H, HCC_FB_W);
}

F64 tS()
{
  if (!_hcc_inited) {
    clock_gettime(CLOCK_MONOTONIC, &_hcc_t0);
  }
  timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  F64 sec = now.tv_sec - _hcc_t0.tv_sec;
  F64 nsec = now.tv_nsec - _hcc_t0.tv_nsec;
  return sec + nsec * 1e-9;
}

U0 Sleep(I64 ms_delay)
{
  HCC_Present();
  if (ms_delay > 0) {
    U32 d = ms_delay;
    SDL_Delay(d);
  }
}

U16 PCIReadU16(I64 b, I64 d, I64 f, I64 off) { return 0xFFFF; }
U32 PCIReadU32(I64 b, I64 d, I64 f, I64 off) { return 0; }
U0  OutU16(I64 port, I64 val) {}
U16 InU16(I64 port) { return 0; }

U8 *MStrPrint(U8 *fmt, ...)
{
  return fmt;
}


U0 GrPrint(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
}


#endif // _COMPAT_GPU_HC
