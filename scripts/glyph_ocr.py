#!/usr/bin/env python3
"""Read TempleOS 8x8 text from a screenshot using exact glyph bitmaps.

The templates were harvested from a known HolyCraft HUD line, so the HUD
parsing is exact. tesseract is only used as a fallback for error screens.
"""
import json
import os
import re
import subprocess
import sys
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
FONT = json.load(open(os.path.join(ROOT, 'holyc_font.json')))


def load(path):
    return Image.open(path).convert('L')


def glyphs(path, y0=4, y1=13, x0=4, xmax=640, cell=8, threshold=200):
    """Read TempleOS's fixed-width glyph cells.

    Grouping lit columns is wrong because adjacent glyphs often touch.
    HolyCraft's HUD starts at x=4 and uses the 8-pixel TempleOS font, so
    every character occupies one cell starting at 4 + cell * index.
    """
    im = load(path)
    rows = range(y0, y1)
    out = []
    for left in range(x0, xmax, cell):
        pat = ''.join(
            ''.join('#' if im.getpixel((x, y)) > threshold else '.'
                    for x in range(left, min(left + cell, xmax)))
            for y in rows
        )
        out.append(pat)
    return out


def decode(pats):
    return ''.join(' ' if set(p) == {'.'} else FONT.get(p, '?') for p in pats)


def hud(path):
    text = decode(glyphs(path, xmax=400)).replace(' ', '')
    m = re.search(r'HolyCraftFPS(\d+)X([0-9.]+)Y([0-9.]+)Z([0-9.]+)', text)
    if not m:
        return None
    return {
        'text': text,
        'fps': int(m.group(1)),
        'x': float(m.group(2)),
        'y': float(m.group(3)),
        'z': float(m.group(4)),
    }


def is_game(path):
    return decode(glyphs(path, xmax=120)).replace(' ', '').startswith('HolyCraft')


def ocr_fallback(path):
    """Best-effort text for compile-error screens."""
    try:
        im = Image.open(path).convert('RGB')
        scaled = '/tmp/opencode/devbridge_ocr.png'
        im.resize((1280, 960), Image.LANCZOS).save(scaled)
        out = subprocess.run(
            ['tesseract', scaled, 'stdout', '--psm', '11'],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, timeout=15
        ).stdout
        return ' '.join(line.strip() for line in out.splitlines() if line.strip())[:400]
    except Exception as exc:
        return '<tesseract unavailable: %s>' % exc


def report(path):
    result = {'game': is_game(path), 'hud': hud(path), 'text': ''}
    if not result['game']:
        result['text'] = ocr_fallback(path)
    return result


if __name__ == '__main__':
    for p in sys.argv[1:]:
        r = report(p)
        print(os.path.basename(p), 'game=' + str(r['game']), 'hud=' + str(r['hud']))
        if r['text']:
            print('  screen:', r['text'])
