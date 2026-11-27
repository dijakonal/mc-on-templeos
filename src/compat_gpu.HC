// Linux SDL2 presentation shim included by compat_hcc.HC.
// Presents either the game's RGB back buffer (if it fills one) or the
// 640x480 16-color indexed framebuffer through one SDL texture.
#ifndef _COMPAT_GPU_HC
#define _COMPAT_GPU_HC

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

#define CLOCK_MONOTONIC 1

class timespec {
  I64 tv_sec;
  I64 tv_nsec;
};

extern "c" I32 clock_gettime(I32 clk_id, timespec *tp);

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

union SDL_Event {
  U32                  type;
  SDL_KeyboardEvent    key;
  SDL_MouseMotionEvent motion;
  SDL_MouseButtonEvent button;
  U8                   padding[64];
};

#define SDL_INIT_VIDEO              0x00000020
#define SDL_WINDOWPOS_CENTERED      0x2FFF0000
#define SDL_WINDOW_SHOWN            0x00000004
#define SDL_RENDERER_ACCELERATED    0x00000002
#define SDL_RENDERER_SOFTWARE       0x00000001
#define SDL_PIXELFORMAT_ARGB8888    0x16362004
#define SDL_TEXTUREACCESS_STREAMING 1

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

extern "c" I32  SDL_Init(U32 flags);
extern "c" U0   SDL_Quit();
extern "c" U8  *SDL_GetError();
extern "c" U8  *SDL_CreateWindow(U8 *title, I32 x, I32 y, I32 w, I32 h, U32 flags);
extern "c" U0   SDL_GetWindowSize(U8 *window, I32 *w, I32 *h);
extern "c" U0   SDL_SetWindowSize(U8 *window, I32 w, I32 h);
extern "c" U8  *SDL_CreateRenderer(U8 *window, I32 index, U32 flags);
extern "c" I32  SDL_RenderClear(U8 *renderer);
extern "c" I32  SDL_RenderCopy(U8 *renderer, U8 *texture, U8 *srcrect, U8 *dstrect);
extern "c" U0   SDL_RenderPresent(U8 *renderer);
extern "c" U8  *SDL_CreateTexture(U8 *renderer, U32 format, I32 access, I32 w, I32 h);
extern "c" U0   SDL_DestroyTexture(U8 *texture);
extern "c" I32  SDL_UpdateTexture(U8 *texture, U8 *rect, U8 *pixels, I32 pitch);
extern "c" I32  SDL_PollEvent(SDL_Event *event);
extern "c" U0   SDL_Delay(U32 ms);
extern "c" U0   SDL_SetRelativeMouseMode(I32 enabled);
extern "c" U0   SDL_ShowCursor(I32 enabled);

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

// HolyCraft GPU globals (the 16-color game leaves these at zero/NULL).
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
  I32 w = 800;
  I32 h = 600;
  if (_hcc_inited) return;
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    printf("SDL_Init failed: %s\n", SDL_GetError());
    Exit(1);
  }
  if (gpu_w > 0) w = gpu_w;
  if (gpu_h > 0) h = gpu_h;

  _hcc_win = SDL_CreateWindow("HolyCraft (Linux SDL2 RGB)",
                              SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED,
                              w,
                              h,
                              SDL_WINDOW_SHOWN);
  if (!_hcc_win) {
    printf("SDL_CreateWindow failed: %s\n", SDL_GetError());
    SDL_Quit();
    Exit(1);
  }
  _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, SDL_RENDERER_ACCELERATED);
  if (!_hcc_ren) {
    _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, SDL_RENDERER_SOFTWARE);
  }
  _hcc_ensure_texture(w, h);
  MemSet(_hcc_fb, 0, 640 * 480);
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
    }
  }
}

U0 HCC_PresentRGB32(U32 *src, I64 w, I64 h, I64 stride_px)
{
  I32 iw;
  I32 ih;
  I32 pitch;
  I32 cur_w;
  I32 cur_h;
  if (!_hcc_inited) InitHCCCompat();
  HCC_PumpEvents();
  if (!src || w <= 0 || h <= 0) return;

  iw = w;
  ih = h;
  if (_hcc_win) {
    cur_w = 0;
    cur_h = 0;
    SDL_GetWindowSize(_hcc_win, &cur_w, &cur_h);
    if (cur_w != iw || cur_h != ih) {
      SDL_SetWindowSize(_hcc_win, iw, ih);
    }
  }
  _hcc_ensure_texture(iw, ih);
  if (!_hcc_ren || !_hcc_tex) return;

  if (stride_px <= 0) stride_px = w;
  pitch = stride_px * 4;
  SDL_UpdateTexture(_hcc_tex, NULL, src, pitch);
  SDL_RenderClear(_hcc_ren);
  SDL_RenderCopy(_hcc_ren, _hcc_tex, NULL, NULL);
  SDL_RenderPresent(_hcc_ren);
}

U0 HCC_Present()
{
  I64 w;
  I64 h;
  I64 s;
  I64 x;
  I64 y;
  if (!_hcc_inited) InitHCCCompat();
  HCC_PumpEvents();
  w = HCC_FB_W;
  h = HCC_FB_H;
  if (gpu_w > 0) w = gpu_w;
  if (gpu_h > 0) h = gpu_h;
  s = w;
  if (gpu_stride > 0) s = gpu_stride;

  if (gpu_back) {
    HCC_PresentRGB32(gpu_back, w, h, s);
    return;
  }
  for (y = 0; y < HCC_FB_H; y++) {
    for (x = 0; x < HCC_FB_W; x++) {
      _hcc_rgb[y * HCC_FB_W + x] = 0xFF000000 | _hcc_pal[_hcc_fb[y * HCC_FB_W + x] & 15];
    }
  }
  HCC_PresentRGB32(_hcc_rgb, HCC_FB_W, HCC_FB_H, HCC_FB_W);
}

F64 tS()
{
  timespec now;
  F64 sec;
  F64 nsec;
  if (!_hcc_inited) {
    clock_gettime(CLOCK_MONOTONIC, &_hcc_t0);
  }
  clock_gettime(CLOCK_MONOTONIC, &now);
  sec = now.tv_sec - _hcc_t0.tv_sec;
  nsec = now.tv_nsec - _hcc_t0.tv_nsec;
  return sec + nsec * 1e-9;
}

U0 Sleep(I64 ms_delay)
{
  HCC_Present();
  if (ms_delay > 0) {
    SDL_Delay(ms_delay);
  }
}

U16 PCIReadU16(I64 b, I64 d, I64 f, I64 off) { return 0xFFFF; }
U32 PCIReadU32(I64 b, I64 d, I64 f, I64 off) { return 0; }
U0  OutU16(I64 port, I64 val) {}
U16 InU16(I64 port) { return 0; }



// ---- text ----------------------------------------------------------------
// hcc's StrPrintJoin aborts the process on %f, and the HUD prints
// coordinates with %.1f, so do the formatting here.  Supports %d %u %x %c
// %s %%, and %.Nf / %N.f (one to six decimals) which is everything the
// game's HUD uses.  Runs on the TempleOS varargs convention: inside a
// varargs function, `argc` counts the extra args and `argv` holds them.
I64 _hcc_pow10(I64 n)
{
  I64 r = 1;
  while (n > 0) { r *= 10;  n--; }
  return r;
}

U0 HCC_PutNum(U8 *dst, I64 dst_len, I64 *di, I64 v)
{
  I64 nd = 1;
  I64 d;
  while (nd < 19 && v >= _hcc_pow10(nd)) nd++;
  while (nd > 0) {
    nd--;
    d = (v / _hcc_pow10(nd)) % 10;
    if (*di < dst_len - 1) {
      dst[*di] = '0' + d;
      *di = *di + 1;
    }
  }
}

U0 HCC_PutHex(U8 *dst, I64 dst_len, I64 *di, I64 v)
{
  I64 nd = 60;
  I64 d;
  I64 skip = 1;
  while (nd >= 0) {
    d = (v >> nd) & 15;
    if (d != 0) skip = 0;
    if (!skip || nd == 0) {
      if (*di < dst_len - 1) {
        if (d < 10) dst[*di] = '0' + d;
        else dst[*di] = 'a' + d - 10;
        *di = *di + 1;
      }
    }
    nd -= 4;
  }
}

U0 HCC_FormatJoin(U8 *dst, I64 dst_len, U8 *fmt, I64 argc, I64 *argv)
{
  I64 di = 0;
  I64 sp = 0;
  I64 fi = 0;
  I64 prec;
  I64 ip;
  I64 fp;
  I64 scale;
  I64 tmp;
  I64 tmp2;
  F64 f;
  U8 ch;
  U8 spec;
  U8 *s;
  ch = fmt[fi];  fi++;
  while (ch && di < dst_len - 1) {
    if (ch == '%') {
      ch = fmt[fi];  fi++;
      prec = -1;
      while (ch >= '0' && ch <= '9') { ch = fmt[fi];  fi++; }
      if (ch == '.') {
        prec = 0;
        ch = fmt[fi];  fi++;
        while (ch >= '0' && ch <= '9') {
          prec = prec * 10 + (ch - '0');
          ch = fmt[fi];  fi++;
        }
      }
      spec = ch;
      if (spec) { ch = fmt[fi];  fi++; }
      if (spec == 'd' || spec == 'i' || spec == 'u') {
        tmp = argv[sp];  sp++;
        if (tmp < 0 && spec != 'u') {
          if (di < dst_len - 1) { dst[di] = '-';  di++; }
          tmp = -tmp;
        }
        HCC_PutNum(dst, dst_len, &di, tmp);
      } else if (spec == 'x') {
        tmp = argv[sp];  sp++;
        HCC_PutHex(dst, dst_len, &di, tmp);
      } else if (spec == 'c') {
        if (di < dst_len - 1) { dst[di] = argv[sp] & 0xFF;  di++; }
        sp++;
      } else if (spec == 's') {
        s = argv[sp](U8*);  sp++;
        while (*s && di < dst_len - 1) {
          dst[di] = *s;  s++;  di++;
        }
      } else if (spec == 'f') {
        if (prec < 0) prec = 6;
        if (prec > 6) prec = 6;
        // hcc reads argv[i](F64) as an F64-array access here (non-varargs
        // context), so reinterpret the 64-bit slot explicitly instead.
        MemCpy(&f, &argv[sp], 8);
        sp++;
        if (f < 0.0) {
          if (di < dst_len - 1) { dst[di] = '-';  di++; }
          f = -f;
        }
        scale = _hcc_pow10(prec);
        ip = ToI64(f);
        fp = ToI64((f - ip) * scale + 0.5);
        if (fp >= scale) { ip++;  fp -= scale; }
        HCC_PutNum(dst, dst_len, &di, ip);
        if (prec > 0) {
          if (di < dst_len - 1) { dst[di] = '.';  di++; }
          tmp = scale / 10;
          while (tmp > 0 && di < dst_len - 1) {
            tmp2 = (fp / tmp) % 10;
            dst[di] = '0' + tmp2;
            di++;
            tmp /= 10;
          }
        }
      } else if (spec == '%') {
        if (di < dst_len - 1) { dst[di] = '%';  di++; }
      } else {
        if (di < dst_len - 1) { dst[di] = spec;  di++; }
      }
    } else {
      dst[di] = ch;  di++;
      ch = fmt[fi];  fi++;
    }
  }
  dst[di] = 0;
}

// Draw a string with the 8x8 font into the indexed framebuffer.  Only
// foreground pixels are written, like TempleOS GrPrint with a plain dc.
U0 GrPrint(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
  U8 buf[256];
  I64 i = 0;
  I64 cx = x;
  I64 gx;
  I64 gy;
  I64 xx;
  I64 yy;
  U8 ch;
  U8 row;
  HCC_FormatJoin(buf, 256, fmt, argc, argv);
  ch = buf[i];
  while (ch) {
    if (ch == '\n') {
      cx = x;
      y += 8;
    } else if (ch >= 32 && ch < 127) {
      for (gy = 0; gy < 8; gy++) {
        row = hcc_font[ch * 8 + gy];
        for (gx = 0; gx < 8; gx++) {
          if ((row >> gx) & 1) {
            xx = cx + gx;
            yy = y + gy;
            if (xx >= 0 && xx < dc->width && yy >= 0 && yy < dc->height)
              dc->body[yy * dc->width_internal + xx] = dc->color;
          }
        }
      }
    }
    cx += 8;
    i++;
    ch = buf[i];
  }
}

#endif // _COMPAT_GPU_HC
