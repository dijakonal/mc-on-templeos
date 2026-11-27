#!/usr/bin/env python3
"""QEMU monitor helper: send keys, take screendumps, convert PPM->PNG."""
import socket, sys, time, os, zlib, struct

SOCK = "/tmp/opencode/qmon.sock"

def mon(cmd, wait=0.25):
    s = socket.socket(socket.AF_UNIX)
    s.connect(SOCK)
    s.settimeout(0.6)
    out = b""
    try:
        out += s.recv(65536)          # banner
    except socket.timeout:
        pass
    s.sendall((cmd + "\n").encode())
    time.sleep(wait)
    try:
        while True:
            b = s.recv(65536)
            if not b:
                break
            out += b
    except socket.timeout:
        pass
    s.close()
    return out.decode(errors="replace")

KEYMAP = {
    ' ': 'spc', '#': 'shift-3', '/': 'slash', '"': 'shift-apostrophe',
    ';': 'semicolon', ':': 'shift-semicolon', '.': 'dot', ',': 'comma',
    '-': 'minus', '_': 'shift-minus', '=': 'equal', '+': 'shift-equal',
    '(': 'shift-9', ')': 'shift-0', "'": 'apostrophe', '\\': 'backslash',
    '[': 'bracket_left', ']': 'bracket_right', '*': 'shift-8',
    '!': 'shift-1', '@': 'shift-2', '%': 'shift-5', '&': 'shift-7',
    '?': 'shift-slash', '<': 'shift-comma', '>': 'shift-dot',
    '^': 'shift-6', '~': 'shift-grave_accent', '`': 'grave_accent',
    '{': 'shift-bracket_left', '}': 'shift-bracket_right', '$': 'shift-4',
}

def type_text(text, delay=0.25):
    for ch in text:
        if ch == '\n':
            mon("sendkey ret", wait=0.05)
        else:
            k = KEYMAP.get(ch, ch)
            mon("sendkey " + k, wait=0.02)
        time.sleep(delay)

def screendump(path):
    mon("screendump " + path, wait=0.5)
    return os.path.exists(path) and os.path.getsize(path) > 0

def ppm_to_png(src, dst):
    d = open(src, 'rb').read()
    idx = d.find(b'255\n')
    hdr = d[:idx].split()
    w, h = int(hdr[1]), int(hdr[2])
    pix = d[idx + 4:]
    need = w * h * 3
    if len(pix) < need:
        raise ValueError("short ppm %d < %d" % (len(pix), need))
    raw = b''.join(b'\x00' + pix[y*w*3:(y+1)*w*3] for y in range(h))
    def chunk(t, data):
        c = struct.pack('>I', len(data)) + t + data
        return c + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 6))
    png += chunk(b'IEND', b'')
    open(dst, 'wb').write(png)

USAGE = """qctl.py — QEMU monitor helper (HMP socket /tmp/opencode/qmon.sock)
  qctl.py type TEXT        type text into the guest
  qctl.py key KEYSPEC      HMP sendkey (e.g. "w 1500" holds W for 1.5 s)
  qctl.py shot TAG         screendump -> TAG.ppm + TAG.png (absolute paths ok)
  qctl.py cmd HMP_COMMAND  raw monitor command
"""

if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] in ('--help', '-h'):
        print(USAGE)
        sys.exit(0 if len(sys.argv) > 1 else 1)
    if sys.argv[1] == 'type':
        type_text(sys.argv[2])
    elif sys.argv[1] == 'key':
        mon("sendkey " + sys.argv[2])
    elif sys.argv[1] == 'shot':
        p = sys.argv[2]
        if not os.path.isabs(p):
            p = os.path.join('/tmp/opencode', p)
        base = p[:-4] if p.endswith('.ppm') else p
        screendump(base + '.ppm')
        ppm_to_png(base + '.ppm', base + '.png')
        print(base + '.png')
    elif sys.argv[1] == 'cmd':
        print(mon(sys.argv[2]))
