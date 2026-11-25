#!/usr/bin/env python3
"""Boot the current HolyCraft ISO in headless QEMU and take a screenshot.

Usage: python3 runtest.py TAG [DELAY_SECONDS]
QEMU's monitor is exposed on /tmp/opencode/qmon.sock so qctl.py can send
input and take more screenshots afterwards.
"""
import os
import subprocess
import sys
import time

import qctl

BASE = os.path.dirname(os.path.abspath(__file__))
ISO = os.path.join(BASE, 'TempleOS-HolyCraft.ISO')
SOCK = '/tmp/opencode/qmon.sock'
SHOT_DIR = '/tmp/opencode/'


def kill():
    # Never use a pattern that matches this command line itself.
    subprocess.run(['pkill', '-f', 'qemu-syste[m]'], check=False)
    time.sleep(1)
    try:
        os.unlink(SOCK)
    except FileNotFoundError:
        pass


def boot(tag, delay=85):
    kill()
    proc = subprocess.Popen([
        'qemu-system-x86_64', '-m', '512', '-cdrom', ISO, '-boot', 'd',
        '-vga', 'std', '-display', 'none',
        '-monitor', 'unix:' + SOCK + ',server,nowait',
        '-accel', 'tcg,thread=multi'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(delay)
    path = os.path.join(SHOT_DIR, tag)
    qctl.screendump(path + '.ppm')
    qctl.ppm_to_png(path + '.ppm', path + '.png')
    return proc


if __name__ == '__main__':
    tag = sys.argv[1] if len(sys.argv) > 1 else 'holycraft'
    delay = int(sys.argv[2]) if len(sys.argv) > 2 else 85
    boot(tag, delay)
    print(SHOT_DIR + tag + '.png')
