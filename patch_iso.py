#!/usr/bin/env python3
"""Patch TempleOS.ISO: add MCRAFT.HC + auto-run launcher in Once.HC."""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redsea import RedSea
from tosz_compress import compress

BASE = os.path.dirname(os.path.abspath(__file__))
SRC_ISO = os.path.join(BASE, 'TempleOS.ISO')
DST_ISO = os.path.join(BASE, 'TempleOS-HolyCraft.ISO')
GAME    = os.path.join(BASE, 'MCRAFT.HC')

LAUNCHER = b'''//HolyCraft launcher: runs in the first terminal at boot.
#include "::/MCRAFT.HC";
'''

rs = RedSea(SRC_ISO)
d = bytearray(open(SRC_ISO, 'rb').read())
game = open(GAME, 'rb').read()
print(f"game: {len(game)} bytes -> {len(game)//512 + 1} blocks")

# ---- locate the sacrificial file (access log) for cluster space ----
attr, name, log_clus, log_size = rs.find('Demo/WebLogDemo/access_170622.log')
print(f"sacrificing {name}: clus={log_clus} size={log_size}")
blocks_needed = (len(game) + 511) // 512
assert blocks_needed < log_size // 512, "not enough room in log file"

# ---- write game data ----
off = log_clus * 512
d[off:off+len(game)] = game
# zero-pad to block boundary
pad = (-len(game)) % 512
d[off+len(game):off+len(game)+pad] = b'\x00' * pad

# ---- add root dir entry ----
root_off = rs.root_clus * 512
# find first zero-name slot after the used entries
slot_off = None
for k in range(0, 1536, 64):
    b = d[root_off+k:root_off+k+64]
    nm = b[2:40].split(b'\x00')[0]
    if not nm:
        slot_off = root_off + k
        break
assert slot_off is not None, "no free root dir slot"
print(f"root dir entry at {slot_off:#x} (slot {(slot_off-root_off)//64})")
# datetime: copy from StartOS.HC.Z entry (search dir for it)
dt = b'\x00' * 8
for k in range(0, 1536, 64):
    b = d[root_off+k:root_off+k+64]
    if b[2:40].split(b'\x00')[0] == b'StartOS.HC.Z':
        dt = b[56:64]
        break
ent = struct.pack('<H', 0x0C00)               # FIXED | CONTIGUOUS
ent += b'MCRAFT.HC'.ljust(38, b'\x00')
ent += struct.pack('<QQ', log_clus, len(game))
ent += dt
assert len(ent) == 64
d[slot_off:slot_off+64] = ent

# ---- patch Once.HC.Z (root copy is the one that runs on live CD) ----
LAUNCHER = b'''//HolyCraft launcher: runs in the first terminal at boot.
#include "::/MCRAFT.HC";
'''
comp = compress(LAUNCHER)
print(f"launcher compressed: {len(comp)} bytes")
for attr, name, c, s, full in rs.ls(rs.root_clus):
    if name == 'Once.HC.Z':
        once_clus, once_size, entry_off = c, s, None
for k in range(0, 1536, 64):
    b = d[root_off+k:root_off+k+64]
    if b[2:40].split(b'\x00')[0] == b'Once.HC.Z':
        entry_off = root_off + k
        once_clus = struct.unpack('<Q', b[40:48])[0]
        once_size = struct.unpack('<Q', b[48:56])[0]
        break
assert entry_off is not None, "root Once.HC.Z entry not found"
print(f"root Once.HC.Z: clus={once_clus} size={once_size}")
assert len(comp) <= ((once_size + 511) // 512) * 512, "launcher too big"
d[once_clus*512:once_clus*512+len(comp)] = comp
struct.pack_into('<Q', d, entry_off+48, len(comp))
print("root Once.HC.Z patched")

# also patch the AcctExample copy for consistency
try:
    attr, name, once2_clus, once2_size = rs.find('Demo/AcctExample/Once.HC.Z')
    d[once2_clus*512:once2_clus*512+len(comp)] = comp
    adir = 26724 * 512
    for k in range(0, 1024, 64):
        b = d[adir+k:adir+k+64]
        if b[2:40].split(b'\x00')[0] == b'Once.HC.Z':
            struct.pack_into('<Q', d, adir+k+48, len(comp))
            break
    print("AcctExample Once.HC.Z patched too")
except FileNotFoundError:
    print("no AcctExample Once")

open(DST_ISO, 'wb').write(d)
print(f"wrote {DST_ISO} ({len(d)} bytes)")

# ---- sanity: read back via our extractor ----
rs2 = RedSea(DST_ISO)
back = rs2.read('MCRAFT.HC')
print("read-back MCRAFT.HC:", len(back), "bytes, match:", back == game)
back2 = rs2.read('Demo/AcctExample/Once.HC.Z')
print("read-back Once.HC.Z:", len(back2), "bytes, match:", back2 == LAUNCHER)
