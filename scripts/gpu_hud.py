#!/usr/bin/env python3
"""Read the inline HUD drawn by MCRAFT_GPU.HC from a screenshot."""
import os
import sys

from PIL import Image

from make_gpu_source import FONT

SCALE = 2
X0 = 6
Y0 = 5
ADV = 6 * SCALE
MAX_CHARS = 80

REVERSE = {}
for ch, rows in FONT.items():
    bits = 0
    for r, row in enumerate(rows):
        for c, bit in enumerate(row):
            if bit == '1':
                bits |= 1 << (r * 5 + c)
    REVERSE[bits] = ch


def read_glyph(im, x, y, scale=SCALE):
    bits = 0
    for r in range(7):
        for c in range(5):
            r0, g0, b0 = im.getpixel((x + (c + 1) * scale, y + r * scale))
            if r0 > 180 and g0 > 180 and b0 > 180:
                bits |= 1 << (r * 5 + c)
    return REVERSE.get(bits, '?')


def hud(path):
    im = Image.open(path).convert('RGB')
    max_chars = min(MAX_CHARS, (im.width - X0) // ADV)
    text = ''
    for i in range(max_chars):
        ch = read_glyph(im, X0 + i * ADV, Y0)
        if ch == ' ':
            text += ch
        elif ch == '?':
            # Trailing blanks and undecoded cells both end the string.
            break
        else:
            text += ch
    result = {'text': text.strip(), 'fps': None, 'x': None, 'y': None, 'z': None}
    parts = text.split()
    for j, part in enumerate(parts):
        if part == 'FPS' and j + 1 < len(parts):
            result['fps'] = int(parts[j + 1])
        if part == 'X' and j + 1 < len(parts):
            result['x'] = float(parts[j + 1])
        if part == 'Y' and j + 1 < len(parts):
            result['y'] = float(parts[j + 1])
        if part == 'Z' and j + 1 < len(parts):
            result['z'] = float(parts[j + 1])
    return result


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/opencode/devreload.png'
    print(os.path.basename(path), hud(path))
