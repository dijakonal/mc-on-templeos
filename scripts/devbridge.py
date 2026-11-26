#!/usr/bin/env python3
"""HolyCraft development bridge.

Keeps one QEMU VM booted with the dev supervisor ISO.  Source edits go into
fat.img (no ISO rebuild); a RELOAD file tells the running game to exit and the
supervisor to recompile it.  HUD state is read back from a screenshot with the
exact-glyph OCR in glyph_ocr.py.

Usage:
  python3 scripts/devbridge.py boot          boot the dev VM (first time)
  python3 scripts/devbridge.py reload        copy MCRAFT.HC + trigger a hot reload
  python3 scripts/devbridge.py shot [NAME]   screenshot + HUD report
  python3 scripts/devbridge.py key KEYS      send a key sequence (qctl.py syntax)
  python3 scripts/devbridge.py stop          stop the VM
"""
import os
import subprocess
import sys
import time

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
ISO = os.path.join(ROOT, 'TempleOS-HolyCraft-DEV.ISO')
DISK = os.path.join(ROOT, 'fat.img')
SOCK = '/tmp/opencode/qdev.sock'
PART_OFFSET = 2048 * 512
SHOTS = '/tmp/opencode/'

sys.path.insert(0, BASE)
import qctl
import glyph_ocr

HOOK_OLD = '      if (kbd.scan_code == SC_ESC) quit = TRUE;'
HOOK_NEW = HOOK_OLD + '''
      if (!(frames & 31)) {
        DskChg;
        if (FileFind("C:/RELOAD")) quit = TRUE;
      }'''


def disk(arg):
    return DISK + '@@' + str(PART_OFFSET) + (('::/' + arg) if arg else '')


def mcopy(src, dest):
    subprocess.run(['mcopy', '-o', '-i', disk(''), src, '::/' + dest], check=True)


def mdel(dest):
    subprocess.run(['mdel', '-i', disk(''), '::/' + dest], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def dev_source():
    """Return source with the dev-only hot-reload hook injected."""
    src = open(os.path.join(ROOT, 'src', 'MCRAFT.HC')).read()
    if HOOK_OLD not in src:
        raise RuntimeError('dev hook anchor not found in MCRAFT.HC')
    return src.replace(HOOK_OLD, HOOK_NEW, 1)


def kill():
    subprocess.run(['pkill', '-f', 'qemu-syste[m]'], check=False)
    time.sleep(1)
    if os.path.exists(SOCK):
        os.unlink(SOCK)


def boot(delay=45):
    kill()
    mdel('RELOAD')
    tmp = '/tmp/opencode/MCRAFT.dev.HC'
    open(tmp, 'w').write(dev_source())
    mcopy(tmp, 'MCRAFT.HC')
    proc = subprocess.Popen([
        'qemu-system-x86_64', '-m', '512', '-cdrom', ISO,
        '-drive', 'file=' + DISK + ',format=raw,cache=none',
        '-boot', 'd', '-vga', 'std', '-display', 'none',
        '-monitor', 'unix:' + SOCK + ',server,nowait',
        '-accel', 'tcg,thread=multi'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(delay)
    qctl.SOCK = SOCK
    tmpf = SHOTS + 'devboot'
    qctl.screendump(tmpf + '.ppm')
    qctl.ppm_to_png(tmpf + '.ppm', tmpf + '.png')
    return proc


def connect():
    qctl.SOCK = SOCK
    if not os.path.exists(SOCK):
        raise RuntimeError('dev VM is not running; use: scripts/devbridge.py boot')


def shot(name='devshot'):
    connect()
    path = SHOTS + name
    qctl.screendump(path + '.ppm')
    qctl.ppm_to_png(path + '.ppm', path + '.png')
    report = glyph_ocr.report(path + '.png')
    print(path + '.png')
    print('game:', report['game'], 'hud:', report['hud'])
    if report['text']:
        print('screen:', report['text'])
    return report


def reload(wait=35):
    connect()
    tmp = '/tmp/opencode/MCRAFT.dev.HC'
    open(tmp, 'w').write(dev_source())
    mcopy(tmp, 'MCRAFT.HC')
    # The running game polls ::/RELOAD and exits; the supervisor then recompiles.
    open('/tmp/opencode/RELOAD', 'w').write('x')
    mcopy('/tmp/opencode/RELOAD', 'RELOAD')
    time.sleep(wait)
    return shot('devreload')


def key(keys):
    connect()
    # Pass the whole HMP sendkey argument, e.g. "w 1500" to hold W.
    qctl.mon('sendkey ' + keys, 0.2)
    time.sleep(0.5)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'shot'
    if cmd == 'boot':
        boot(int(sys.argv[2]) if len(sys.argv) > 2 else 45)
        shot('devboot')
    elif cmd == 'reload':
        reload(int(sys.argv[2]) if len(sys.argv) > 2 else 35)
    elif cmd == 'shot':
        shot(sys.argv[2] if len(sys.argv) > 2 else 'devshot')
    elif cmd == 'key':
        key(' '.join(sys.argv[2:]))
    elif cmd == 'stop':
        kill()
        print('stopped')
    else:
        print(__doc__)
        sys.exit(1)
