#!/usr/bin/env python3
"""Rasterizer A/B regression test for the GPU build.

Verifies that the shipped per-pixel perspective rasterizer in
src/MCRAFT_GPU.HC (a) is temporally stable with a still camera and
(b) actually differs from the old endpoint-affine loop, which is the
texel drift users reported as "morphing".

Usage: python3 scripts/raster_ab_test.py [SHOT_SECONDS]

Boots TempleOS-HolyCraft-GPU.ISO twice (real + morphing baseline) and
diffs the two spawn-pose screenshots. Expect a diff of several percent
of pixels (the affine error field) and ~0 differing pixels between
consecutive still-camera frames of the real build.
"""
import os
import struct
import subprocess
import sys
import time
import zlib

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
sys.path.insert(0, BASE)
import qctl  # noqa: E402

GPU_ISO = os.path.join(ROOT, 'TempleOS-HolyCraft-GPU.ISO')
GPU_SRC = os.path.join(ROOT, 'src', 'MCRAFT_GPU.HC')
MORPH_ISO = '/tmp/opencode/ab_morph.ISO'
MORPH_SRC = '/tmp/opencode/ab_morph.HC'
FIXED_PNG = '/tmp/opencode/ab_fixed.png'
MORPH_PNG = '/tmp/opencode/ab_morph.png'
TMP_PPM = '/tmp/opencode/ab_tmp'

ANCHOR_START = '      // Interpolate u/z, v/z and 1/z linearly across the span, then divide'
ANCHOR_END = '      }\n    }\n  }\n}'


def make_morph_variant():
    """Swap the per-pixel perspective divide for the old endpoint-affine
    loop, keeping everything else (fog, water, fast paths) identical so
    the diff isolates the rasterizer difference."""
    old_block = '''      if (xr > xl) {
        xspan = xr - xl;
        wl = IClamp(wl, 1, 65536);  wr = IClamp(wr, 1, 65536);
        inv = gl_inv[wl];  upx = gl_inv[wr];
        ul = (ul * inv) >> 30;  vl = (vl * inv) >> 30;
        ur = (ur * upx) >> 30;  vr = (vr * upx) >> 30;
        du = ToI64((ur - ul) * 65536.0 / xspan);
        dv = ToI64((vr - vl) * 65536.0 / xspan);
        dw = ToI64((wr - wl) * 65536.0 / xspan);
        tu = ToI64((ul + (ur - ul) * t0) * 65536.0);
        tv = ToI64((vl + (vr - vl) * t0) * 65536.0);
        ww = ToI64((wl + (wr - wl) * t0) * 65536.0);
      } else {
        wl = IClamp(wl, 1, 65536);
        inv = gl_inv[wl];
        ul = (ul * inv) >> 30;  vl = (vl * inv) >> 30;
        du = 0;  dv = 0;  dw = 0;
        tu = ul << 16;  tv = vl << 16;  ww = wl << 16;
      }
      fullfog = ffogT[fi] == 255;
      band = ffogT[fi] > 0 && ffogT[fi] < 255;
      if (fullfog) {
        if (alpha == 255) {
          for (x = x0; x <= x1; x++) db[row + x] = mcr_fog_col;
        } else {
          for (x = x0; x <= x1; x++)
            db[row + x] = GpuMix(db[row + x], mcr_fog_col, alpha);
        }
      } else if (alpha == 255) {
        for (x = x0; x <= x1; x++) {
          tx = (tu >> 24) & 15;
          ty = (tv >> 24) & 15;
          c = face_cols[fbase + gt_tex[texbase + (ty << 4) + tx]];
          if (band) {
            fb = fog_w_lut[ww >> 22];
            if (fb > 0) c = GpuMix(c, mcr_fog_col, fb);
          }
          db[row + x] = c;
          tu += du;  tv += dv;  ww += dw;
        }
      } else {
        for (x = x0; x <= x1; x++) {
          tx = (tu >> 24) & 15;
          ty = (tv >> 24) & 15;
          c = face_cols[fbase + gt_tex[texbase + (ty << 4) + tx]];
          if (band) {
            fb = fog_w_lut[ww >> 22];
            if (fb > 0) c = GpuMix(c, mcr_fog_col, fb);
          }
          db[row + x] = GpuMix(db[row + x], c, alpha);
          tu += du;  tv += dv;  ww += dw;
        }
      }
    }
  }
}'''
    s = open(GPU_SRC).read()
    i = s.index(ANCHOR_START)
    j = s.index(ANCHOR_END, i) + len(ANCHOR_END)
    body = s[i:j]
    assert 'gl_inv[ww >> 16]' in body, 'unexpected FillFace body'
    open(MORPH_SRC, 'w').write(s[:i] + old_block + s[j:])
    env = dict(os.environ, HOLYCRAFT_GAME=MORPH_SRC, HOLYCRAFT_ISO=MORPH_ISO)
    subprocess.run([sys.executable, os.path.join(BASE, 'patch_iso.py')],
                   check=True, env=env, stdout=subprocess.DEVNULL)


def load_png(path):
    d = open(path, 'rb').read()
    pos, w, h, idat = 8, None, None, b''
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        if typ == b'IHDR':
            w, h = struct.unpack('>II', d[pos + 8:pos + 16])
        elif typ == b'IDAT':
            idat += d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 3
    out = bytearray(w * h * 3)
    prev = bytearray(stride)
    o = 0
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        if f == 1:
            for i in range(3, stride):
                line[i] = (line[i] + line[i - 3]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - 3] if i >= 3 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - 3] if i >= 3 else 0
                c = prev[i - 3] if i >= 3 else 0
                b = prev[i]
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[o:o + stride] = line
        o += stride
        prev = line
    return w, h, bytes(out)


def diff_pct(pa, pb):
    (w, h, a), (_, _, b) = pa, pb
    diff = sum(1 for i in range(w * h) if a[i * 3:i * 3 + 3] != b[i * 3:i * 3 + 3])
    return 100.0 * diff / (w * h)


def boot_and_shot(iso, tag, delay=100):
    subprocess.run(['pkill', '-f', 'qemu-syste[m]'], check=False)
    time.sleep(1)
    try:
        os.unlink(qctl.SOCK)
    except FileNotFoundError:
        pass
    proc = subprocess.Popen([
        'qemu-system-x86_64', '-m', '512', '-cdrom', iso, '-boot', 'd',
        '-vga', 'std', '-display', 'none',
        '-monitor', 'unix:' + qctl.SOCK + ',server,nowait',
        '-accel', 'tcg,thread=multi'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(delay)
    qctl.screendump(TMP_PPM + '.ppm')
    qctl.ppm_to_png(TMP_PPM + '.ppm', tag)
    subprocess.run(['pkill', '-f', 'qemu-syste[m]'], check=False)
    time.sleep(1)
    return tag


def main():
    delay = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    print('building morphing baseline ISO...')
    make_morph_variant()
    print('booting per-pixel build...')
    boot_and_shot(GPU_ISO, FIXED_PNG, delay)
    print('booting endpoint-affine baseline...')
    boot_and_shot(MORPH_ISO, MORPH_PNG, delay)
    fixed = load_png(FIXED_PNG)
    morph = load_png(MORPH_PNG)
    pct = diff_pct(fixed, morph)
    print('spawn-pose diff per-pixel vs endpoint-affine: %.3f%% of pixels' % pct)
    if pct < 1.0:
        print('FAIL: rasterizers look identical; the A/B lost its signal.')
        sys.exit(1)
    print('OK: the two rasterizers differ materially (perspective error '
          'field visible); per-pixel build is the reference.')
    print('screenshots: %s / %s' % (FIXED_PNG, MORPH_PNG))


if __name__ == '__main__':
    main()
