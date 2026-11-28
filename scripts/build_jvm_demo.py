#!/usr/bin/env python3
"""Compile the Java demo with javac and embed the class bytes into src/JVM.HC.

Usage: python3 scripts/build_jvm_demo.py [CLASS_FILE] [JVM_HC]
"""
import os
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
DEMO_DIR = '/tmp/jvm'
CLASS_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(DEMO_DIR, 'JvmDemo.class')
JVM_HC = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'src', 'JVM.HC')


def main():
    src = os.path.join(DEMO_DIR, 'JvmDemo.java')
    stub = os.path.join(DEMO_DIR, 'Hos.java')
    if not os.path.exists(CLASS_FILE):
        subprocess.run(['javac', '--release', '8', src, stub], check=True,
                       stderr=subprocess.DEVNULL)
    data = open(CLASS_FILE, 'rb').read()

    s = open(JVM_HC).read()
    a = s.find('I64 kbytes_len =')
    b = s.find('PrintF("HolyJVM v0.1')
    assert a > 0 and b > a, 'placeholders not found'
    assign_lines = []
    for off in range(0, len(data), 8):
        chunk = data[off:off + 8]
        assign_lines.append('  ' + ' '.join('kbytes[%d]=0x%02X;' % (off + k, x)
                                            for k, x in enumerate(chunk)))
    repl = ('I64 kbytes_len = %d;\n'
            'U8 kbytes[%d];\n%s\n' % (len(data), len(data), '\n'.join(assign_lines)))
    s = s[:a] + repl + s[b:]
    open(JVM_HC, 'w').write(s)
    print('embedded %s (%d bytes) into %s' % (CLASS_FILE, len(data), JVM_HC))


if __name__ == '__main__':
    main()
