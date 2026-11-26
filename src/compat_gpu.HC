// compat_gpu.HC — SDL2 GPU translation layer for running MCRAFT.HC on Linux.
//
// The game renders into a 640x480 8-bit indexed framebuffer (gr.dc->body).
// This layer uploads that buffer as an ARGB8888 streaming texture every frame
// (SDL's renderer blits it on the GPU), converts PC scan codes / mouse events
// into the TempleOS kbd/ms structures, and draws HUD text with an 8x8 font.
#ifndef COMPAT_GPU_HC
#define COMPAT_GPU_HC

// ---- SDL2 (resolved at link time with -l SDL2) ----
extern I64 SDL_Init(U32 flags);
extern U0  SDL_Quit();
extern U0 *SDL_CreateWindow(U8 *title, I64 x, I64 y, I64 w, I64 h, U32 flags);
extern U0 *SDL_CreateRenderer(U0 *win, I64 idx, U32 flags);
extern U0 *SDL_CreateTexture(U0 *ren, U32 fmt, I64 access, I64 w, I64 h);
extern I64 SDL_UpdateTexture(U0 *tex, U0 *rect, U0 *pixels, I64 pitch);
extern I64 SDL_RenderClear(U0 *ren);
extern I64 SDL_RenderCopy(U0 *ren, U0 *tex, U0 *src, U0 *dst);
extern U0  SDL_RenderPresent(U0 *ren);
extern I64 SDL_PollEvent(U0 *ev);
extern U32 SDL_GetTicks();
extern U0  SDL_Delay(U32 ms);
extern I64 SDL_SetRelativeMouseMode(I64 enabled);
extern U0  SDL_RaiseWindow(U0 *win);
extern U8 *SDL_GetCurrentVideoDriver();
extern U0  SDL_GetWindowPosition(U0 *win, I64 *x, I64 *y);
extern U0  SDL_GetWindowSize(U0 *win, I64 *w, I64 *h);
extern U8 *getenv(U8 *name);
extern U0  usleep(I64 usec);
extern U0 *fopen(U8 *path, U8 *mode);
extern I64 fwrite(U0 *ptr, I64 size, I64 nmemb, U0 *stream);
extern I64 fclose(U0 *stream);

#define SDL_INIT_TIMER              0x00000001
#define SDL_INIT_VIDEO              0x00000020
#define SDL_WINDOW_SHOWN            0x00000004
#define SDL_WINDOWPOS_CENTERED      0x2FFF0000
#define SDL_RENDERER_ACCELERATED    0x00000002
#define SDL_RENDERER_PRESENTVSYNC   0x00000004
#define SDL_TEXTUREACCESS_STREAMING 1
#define SDL_PIXELFORMAT_ARGB8888    0x16362004

#define SDL_QUIT             0x100
#define SDL_WINDOWEVENT      0x200
#define SDL_KEYDOWN          0x300
#define SDL_KEYUP            0x301
#define SDL_MOUSEMOTION      0x400
#define SDL_MOUSEBUTTONDOWN  0x401
#define SDL_MOUSEBUTTONUP    0x402

#define SDL_WINDOWEVENT_FOCUS_LOST 12
#define SDL_WINDOWEVENT_CLOSE      14

#define HCC_SCR_W 640
#define HCC_SCR_H 480

I64  _hcc_sdl_ok = FALSE;
U0  *_hcc_win;
U0  *_hcc_ren;
U0  *_hcc_tex;
U32  _hcc_rgb[HCC_SCR_W * HCC_SCR_H];
U32  _hcc_pal[16];
U8   hcc_scan[256];          // SDL scancode -> PC set-1 scancode

// TempleOS 16-colour VGA palette -> ARGB8888
U0 HCC_InitPalette()
{
  _hcc_pal[0]  = 0xFF000000;   // black
  _hcc_pal[1]  = 0xFF0000AA;   // blue
  _hcc_pal[2]  = 0xFF00AA00;   // green
  _hcc_pal[3]  = 0xFF00AAAA;   // cyan
  _hcc_pal[4]  = 0xFFAA0000;   // red
  _hcc_pal[5]  = 0xFFAA00AA;   // magenta
  _hcc_pal[6]  = 0xFFAA5500;   // brown
  _hcc_pal[7]  = 0xFFAAAAAA;   // light gray
  _hcc_pal[8]  = 0xFF555555;   // dark gray
  _hcc_pal[9]  = 0xFF5555FF;   // light blue
  _hcc_pal[10] = 0xFF55FF55;   // light green
  _hcc_pal[11] = 0xFF55FFFF;   // light cyan
  _hcc_pal[12] = 0xFFFF5555;   // light red
  _hcc_pal[13] = 0xFFFF55FF;   // light magenta
  _hcc_pal[14] = 0xFFFFFF55;   // yellow
  _hcc_pal[15] = 0xFFFFFFFF;   // white
}

// ---- text (8x8 font from compat_font.HC) ----
U0 HCC_DrawText(CHCCDC *dc, I64 x, I64 y, U8 *s, U8 color)
{
  I64 cx = x, ch, row, col, px, py;
  U8 bits;
  while (*s) {
    ch = *s;
    if (ch < 0 || ch > 127) ch = 32;
    for (row = 0; row < 8; row++) {
      bits = hcc_font[ch * 8 + row];
      for (col = 0; col < 8; col++)
        if ((bits >> col) & 1) {
          px = cx + col;  py = y + row;
          if (px >= 0 && px < dc->width && py >= 0 && py < dc->height)
            dc->body[py * dc->width_internal + px] = color;
        }
    }
    cx += 8;
    s++;
  }
}

// ---- tiny printf for GrPrint (handles %d %u %x %c %s %f %%) ----
I64 HCC_Utoa(U8 *out, I64 cap, U64 v)
{
  U8 tmp[24];
  I64 t = 0, o = 0;
  if (v == 0) tmp[t++] = '0';
  while (v > 0) { tmp[t++] = '0' + (v % 10); v /= 10; }
  while (t > 0 && o < cap - 1) out[o++] = tmp[--t];
  return o;
}

I64 HCC_Ftoa(U8 *out, I64 cap, F64 v, I64 prec)
{
  I64 o = 0, p, d, ip, fr, total, neg = FALSE;
  U8 tmp[24];
  I64 t = 0;
  if (prec < 0) prec = 6;
  if (prec > 9) prec = 9;
  if (v < 0) { neg = TRUE; v = -v; }
  d = 1;
  for (p = 0; p < prec; p++) d *= 10;
  total = (I64)(v * d + 0.5);
  ip = total / d;
  fr = total % d;
  if (neg && o < cap - 1) out[o++] = '-';
  o += HCC_Utoa(out + o, cap - o, (U64)ip);
  if (prec > 0) {
    if (o < cap - 1) out[o++] = '.';
    for (p = 0; p < prec; p++) { tmp[t++] = '0' + (fr % 10); fr /= 10; }
    while (t > 0 && o < cap - 1) out[o++] = tmp[--t];
  }
  return o;
}

I64 HCC_Format(U8 *out, I64 cap, U8 *fmt, I64 *argv, I64 argc)
{
  I64 i = 0, ai = 0, o = 0, prec, v;
  U8 c, conv;
  U8 *s;
  while (fmt[i] && o < cap - 1) {
    c = fmt[i++];
    if (c != '%') {
      out[o++] = c;
    } else {
      while (fmt[i] == '-' || fmt[i] == '0' || fmt[i] == '+' || fmt[i] == ' ')
        i++;
      prec = -1;
      if (fmt[i] == '.') {
        i++;  prec = 0;
        while (fmt[i] >= '0' && fmt[i] <= '9') { prec = prec * 10 + (fmt[i] - '0'); i++; }
      }
      conv = fmt[i++];
      if (conv == '%') {
        out[o++] = '%';
      } else if (conv == 'd') {
        v = argv[ai++];
        if (v < 0) { if (o < cap - 1) out[o++] = '-'; v = -v; }
        o += HCC_Utoa(out + o, cap - o, (U64)v);
      } else if (conv == 'u') {
        o += HCC_Utoa(out + o, cap - o, (U64)argv[ai++]);
      } else if (conv == 'x' || conv == 'X') {
        U64 u = argv[ai++];
        U8 tmp[24]; I64 t = 0;
        if (u == 0) tmp[t++] = '0';
        while (u > 0) {
          I64 dg = u & 15;
          if (dg < 10) tmp[t++] = '0' + dg;
          else if (conv == 'X') tmp[t++] = 'A' + dg - 10;
          else tmp[t++] = 'a' + dg - 10;
          u >>= 4;
        }
        while (t > 0 && o < cap - 1) out[o++] = tmp[--t];
      } else if (conv == 'c') {
        out[o++] = (U8)argv[ai++];
      } else if (conv == 's') {
        s = (U8 *)argv[ai++];
        while (*s && o < cap - 1) out[o++] = *s++;
      } else if (conv == 'f' || conv == 'e' || conv == 'g') {
        o += HCC_Ftoa(out + o, cap - o, *(F64 *)(&argv[ai]), prec);
        ai++;
      }
    }
  }
  out[o] = 0;
  return o;
}

// ---- SDL init / present / input ----
U0 InitHCCCompat()
{
  _hcc_dc.color = WHITE;
  _hcc_dc.body = _hcc_fb;
  _hcc_dc.width_internal = HCC_SCR_W;
  _hcc_dc.width = HCC_SCR_W;
  _hcc_dc.height = HCC_SCR_H;
  gr.dc = &_hcc_dc;
  HCC_InitPalette;
  HCC_InitScanMap;
  if (SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO) != 0) {
    _hcc_sdl_ok = FALSE;
    return;
  }
  _hcc_win = SDL_CreateWindow("HolyCraft", SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED, HCC_SCR_W, HCC_SCR_H,
                              SDL_WINDOW_SHOWN);
  if (!_hcc_win) { _hcc_sdl_ok = FALSE; return; }
  _hcc_ren = SDL_CreateRenderer(_hcc_win, -1,
                                SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!_hcc_ren) _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, SDL_RENDERER_ACCELERATED);
  if (!_hcc_ren) _hcc_ren = SDL_CreateRenderer(_hcc_win, -1, 0);
  if (!_hcc_ren) { _hcc_sdl_ok = FALSE; return; }
  _hcc_tex = SDL_CreateTexture(_hcc_ren, SDL_PIXELFORMAT_ARGB8888,
                               SDL_TEXTUREACCESS_STREAMING, HCC_SCR_W, HCC_SCR_H);
  if (!_hcc_tex) { _hcc_sdl_ok = FALSE; return; }
  SDL_RaiseWindow(_hcc_win);
  SDL_SetRelativeMouseMode(TRUE);
  _hcc_sdl_ok = TRUE;
  if (getenv("HCC_DEBUG")) {
    I64 wx = 0, wy = 0, ww = 0, wh = 0;
    SDL_GetWindowPosition(_hcc_win, &wx, &wy);
    SDL_GetWindowSize(_hcc_win, &ww, &wh);
    Print("HCC: driver=%s win=%p ren=%p tex=%p pos=%d,%d size=%dx%d\n",
          SDL_GetCurrentVideoDriver(), _hcc_win, _hcc_ren, _hcc_tex,
          wx, wy, ww, wh);
  }
}

// Build the full SDL (USB HID usage) -> PC set-1 scancode table.
U0 HCC_InitScanMap()
{
  I64 i;
  for (i = 0; i < 256; i++) hcc_scan[i] = 0;

  // letters
  hcc_scan[4]  = 0x1E; hcc_scan[5]  = 0x30; hcc_scan[6]  = 0x2E;
  hcc_scan[7]  = 0x20; hcc_scan[8]  = 0x12; hcc_scan[9]  = 0x21;
  hcc_scan[10] = 0x22; hcc_scan[11] = 0x23; hcc_scan[12] = 0x17;
  hcc_scan[13] = 0x24; hcc_scan[14] = 0x25; hcc_scan[15] = 0x26;
  hcc_scan[16] = 0x32; hcc_scan[17] = 0x31; hcc_scan[18] = 0x18;
  hcc_scan[19] = 0x19; hcc_scan[20] = 0x10; hcc_scan[21] = 0x13;
  hcc_scan[22] = 0x1F; hcc_scan[23] = 0x14; hcc_scan[24] = 0x16;
  hcc_scan[25] = 0x2F; hcc_scan[26] = 0x11; hcc_scan[27] = 0x2D;
  hcc_scan[28] = 0x15; hcc_scan[29] = 0x2C;

  // digits 1..0
  hcc_scan[30] = 0x02; hcc_scan[31] = 0x03; hcc_scan[32] = 0x04;
  hcc_scan[33] = 0x05; hcc_scan[34] = 0x06; hcc_scan[35] = 0x07;
  hcc_scan[36] = 0x08; hcc_scan[37] = 0x09; hcc_scan[38] = 0x0A;
  hcc_scan[39] = 0x0B;

  // control / punctuation
  hcc_scan[40] = 0x1C;  // Return
  hcc_scan[41] = 0x01;  // Escape
  hcc_scan[42] = 0x0E;  // Backspace
  hcc_scan[43] = 0x0F;  // Tab
  hcc_scan[44] = 0x39;  // Space
  hcc_scan[45] = 0x0C;  // -
  hcc_scan[46] = 0x0D;  // =
  hcc_scan[47] = 0x1A;  // [
  hcc_scan[48] = 0x1B;  // ]
  hcc_scan[49] = 0x2B;  // backslash
  hcc_scan[50] = 0x2B;  // non-US hash
  hcc_scan[51] = 0x27;  // ;
  hcc_scan[52] = 0x28;  // '
  hcc_scan[53] = 0x29;  // `
  hcc_scan[54] = 0x33;  // ,
  hcc_scan[55] = 0x34;  // .
  hcc_scan[56] = 0x35;  // /
  hcc_scan[57] = 0x3A;  // CapsLock

  // function keys
  hcc_scan[58] = 0x3B; hcc_scan[59] = 0x3C; hcc_scan[60] = 0x3D;
  hcc_scan[61] = 0x3E; hcc_scan[62] = 0x3F; hcc_scan[63] = 0x40;
  hcc_scan[64] = 0x41; hcc_scan[65] = 0x42; hcc_scan[66] = 0x43;
  hcc_scan[67] = 0x44; hcc_scan[68] = 0x57; hcc_scan[69] = 0x58;

  // navigation
  hcc_scan[70] = 0x37;  // PrintScreen
  hcc_scan[71] = 0x46;  // ScrollLock
  hcc_scan[72] = 0x45;  // Pause
  hcc_scan[73] = 0x52;  // Insert
  hcc_scan[74] = 0x47;  // Home
  hcc_scan[75] = 0x49;  // PageUp
  hcc_scan[76] = 0x53;  // Delete
  hcc_scan[77] = 0x4F;  // End
  hcc_scan[78] = 0x51;  // PageDown
  hcc_scan[79] = 0x4D;  // Right
  hcc_scan[80] = 0x4B;  // Left
  hcc_scan[81] = 0x50;  // Down
  hcc_scan[82] = 0x48;  // Up

  // keypad
  hcc_scan[83] = 0x45;  // NumLock
  hcc_scan[84] = 0x35;  // KP /
  hcc_scan[85] = 0x37;  // KP *
  hcc_scan[86] = 0x4A;  // KP -
  hcc_scan[87] = 0x4E;  // KP +
  hcc_scan[88] = 0x1C;  // KP Enter
  hcc_scan[89] = 0x4F; hcc_scan[90] = 0x50; hcc_scan[91] = 0x51;
  hcc_scan[92] = 0x4B; hcc_scan[93] = 0x4C; hcc_scan[94] = 0x4D;
  hcc_scan[95] = 0x47; hcc_scan[96] = 0x48; hcc_scan[97] = 0x49;
  hcc_scan[98] = 0x52; hcc_scan[99] = 0x53;  // KP 0, KP .
  hcc_scan[100] = 0x2B; // non-US backslash
  hcc_scan[101] = 0x5D; // Menu
  hcc_scan[103] = 0x59; // KP =

  // modifiers
  hcc_scan[224] = 0x1D; // LeftCtrl
  hcc_scan[225] = 0x2A; // LeftShift
  hcc_scan[226] = 0x38; // LeftAlt
  hcc_scan[227] = 0x5B; // LeftGUI
  hcc_scan[228] = 0x1D; // RightCtrl
  hcc_scan[229] = 0x36; // RightShift
  hcc_scan[230] = 0x38; // RightAlt
  hcc_scan[231] = 0x5C; // RightGUI
}

I64 HCC_MapScan(I64 sc)
{
  if (sc < 0 || sc > 255) return 0;
  return hcc_scan[sc];
}

U0 HCC_PollEvents()
{
  U8 ev[64];
  U32 type;
  I64 sc, s1, i, esc = FALSE;
  U8 state;
  while (SDL_PollEvent(ev)) {
    type = *(U32 *)ev;
    if (type == SDL_QUIT) {
      esc = TRUE;
    } else if (type == SDL_WINDOWEVENT) {
      if (ev[12] == SDL_WINDOWEVENT_CLOSE) {
        esc = TRUE;
      } else if (ev[12] == SDL_WINDOWEVENT_FOCUS_LOST) {
        // release everything so keys don't stick when focus leaves
        for (i = 0; i < 4; i++) kbd.down_bitmap[i] = 0;
      }
    } else if (type == SDL_KEYDOWN || type == SDL_KEYUP) {
      sc = *(I32 *)(ev + 16);
      state = ev[12];
      s1 = HCC_MapScan(sc);
      if (s1) {
        i = s1 >> 6;
        if (state) {
          kbd.down_bitmap[i] |= ((U64)1 << (s1 & 63));
          kbd.scan_code = s1;
          if (s1 == SC_ESC) esc = TRUE;
        } else {
          kbd.down_bitmap[i] &= ~((U64)1 << (s1 & 63));
        }
      }
    } else if (type == SDL_MOUSEMOTION) {
      ms.pos.x += *(I32 *)(ev + 28);
      ms.pos.y += *(I32 *)(ev + 32);
    } else if (type == SDL_MOUSEBUTTONDOWN || type == SDL_MOUSEBUTTONUP) {
      state = ev[17];
      if (ev[16] == 1) ms.lb = state;
      if (ev[16] == 3) ms.rb = state;
    }
  }
  // Latch Esc so a quick press+release in one poll still quits.
  if (esc) kbd.scan_code = SC_ESC;
}

I64 _hcc_frame = 0;

// Debug helper: dump the indexed framebuffer as a binary PPM (P6).
U0 HCC_SavePPM(U8 *path)
{
  U0 *f = fopen(path, "wb");
  I64 x, y, i;
  U8 line[640 * 3];
  U8 hdr[32];
  I64 n;
  if (!f) return;
  n = 0;
  hdr[n++] = 'P'; hdr[n++] = '6'; hdr[n++] = '\n';
  hdr[n++] = '6'; hdr[n++] = '4'; hdr[n++] = '0'; hdr[n++] = ' ';
  hdr[n++] = '4'; hdr[n++] = '8'; hdr[n++] = '0'; hdr[n++] = '\n';
  hdr[n++] = '2'; hdr[n++] = '5'; hdr[n++] = '5'; hdr[n++] = '\n';
  fwrite(hdr, 1, n, f);
  for (y = 0; y < HCC_SCR_H; y++) {
    for (x = 0; x < HCC_SCR_W; x++) {
      U32 p = _hcc_pal[_hcc_fb[y * HCC_SCR_W + x] & 15];
      line[x * 3]     = (p >> 16) & 0xFF;
      line[x * 3 + 1] = (p >> 8) & 0xFF;
      line[x * 3 + 2] = p & 0xFF;
    }
    fwrite(line, 1, HCC_SCR_W * 3, f);
  }
  fclose(f);
  Print("HCC: wrote %s\n", path);
}

U0 HCC_Present()
{
  I64 i;
  if (!_hcc_sdl_ok) return;
  HCC_PollEvents;
  _hcc_frame++;
  if (getenv("HCC_PPM") && (_hcc_frame % 60) == 0)
    HCC_SavePPM(getenv("HCC_PPM"));
  for (i = 0; i < HCC_SCR_W * HCC_SCR_H; i++)
    _hcc_rgb[i] = _hcc_pal[_hcc_fb[i] & 15];
  SDL_UpdateTexture(_hcc_tex, 0, _hcc_rgb, HCC_SCR_W * 4);
  SDL_RenderClear(_hcc_ren);
  SDL_RenderCopy(_hcc_ren, _hcc_tex, 0, 0);
  SDL_RenderPresent(_hcc_ren);
}

// ---- TempleOS shims backed by SDL ----
U0 Sleep(I64 ms_delay)
{
  if (_hcc_sdl_ok) {
    HCC_Present;
    SDL_Delay(ms_delay);
  } else {
    usleep(ms_delay * 1000);
  }
}

F64 tS()
{
  return SDL_GetTicks() / 1000.0;
}

U0 GrPrint(CHCCDC *dc, I64 x, I64 y, U8 *fmt, ...)
{
  U8 buf[512];
  HCC_Format(buf, 512, fmt, argv, argc);
  HCC_DrawText(dc, x, y, buf, dc->color);
}

#endif // COMPAT_GPU_HC
