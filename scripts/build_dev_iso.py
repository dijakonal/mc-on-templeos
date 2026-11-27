#!/usr/bin/env python3
"""Build a TempleOS ISO with a persistent HolyCraft dev supervisor.

The supervisor polls for D:/RELOAD (or any other drive letter) and, when it
appears, compiles and runs that drive's MCRAFT.HC.  The host can replace the
source in fat.img without rebuilding the ISO.
"""
import os
import struct

from redsea import RedSea
from tosz_compress import compress

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
SRC = os.path.join(ROOT, 'TempleOS.ISO')
DST = os.path.join(ROOT, 'TempleOS-HolyCraft-DEV.ISO')

LAUNCHER = b'''//HolyCraft dev supervisor: create <drive>:/RELOAD to rebuild the game.
LBts(&sys_run_level, RLf_ADAM_SERVER);
MountIDEAuto;
DrvRep;
U8 dev_drv = 0, c;
U8 *dev_st;
DocClear;
Print("HolyCraft DEV: scanning drives...\\n");
for (c = 'C'; c <= 'Z'; c++) {
  dev_st = MStrPrint("%c:/MCRAFT.HC", c);
  if (FileFind(dev_st)) {
    Print("  found %c:/MCRAFT.HC\\n", c);
    if (!dev_drv) dev_drv = c;
  }
  Free(dev_st);
}
if (!dev_drv) dev_drv = 'D';
Print("HolyCraft DEV: using %c:  (make %c:/RELOAD to reload)\\n", dev_drv, dev_drv);
while (TRUE) {
  DskChg;
  dev_st = MStrPrint("%c:/RELOAD", dev_drv);
  if (FileFind(dev_st)) {
    Del(dev_st);
    Free(dev_st);
    DocClear;
    dev_st = MStrPrint("%c:/MCRAFT.HC", dev_drv);
    Print("HolyCraft DEV: compiling %s\\n", dev_st);
    try ExeFile(dev_st);
    catch PutExcept;
    Free(dev_st);
    DocClear;
  } else
    Free(dev_st);
  Sleep(10);
}
'''


def find_entry(data, root_off, name):
    for k in range(0, 1536, 64):
        b = data[root_off + k:root_off + k + 64]
        if b[2:40].split(b'\x00')[0] == name.encode():
            return root_off + k
    raise FileNotFoundError(name)


def patch_once(data, root_off, name, payload):
    entry_off = find_entry(data, root_off, name)
    b = data[entry_off:entry_off + 64]
    clus = struct.unpack('<Q', b[40:48])[0]
    size = struct.unpack('<Q', b[48:56])[0]
    cap = ((size + 511) // 512) * 512
    assert len(payload) <= cap, '%s: payload %d > capacity %d' % (name, len(payload), cap)
    data[clus * 512:clus * 512 + len(payload)] = payload
    data[clus * 512 + len(payload):clus * 512 + cap] = b'\x00' * (cap - len(payload))
    struct.pack_into('<Q', data, entry_off + 48, len(payload))


def main():
    rs = RedSea(SRC)
    data = bytearray(open(SRC, 'rb').read())
    root_off = rs.root_clus * 512
    comp = compress(LAUNCHER)

    patch_once(data, root_off, 'Once.HC.Z', comp)

    # Keep the AcctExample copy consistent so RedSea can read it back.
    try:
        attr, name, c, s = rs.find('Demo/AcctExample/Once.HC.Z')
        cap = ((s + 511) // 512) * 512
        assert len(comp) <= cap
        data[c * 512:c * 512 + len(comp)] = comp
        data[c * 512 + len(comp):c * 512 + cap] = b'\x00' * (cap - len(comp))
        adir = 26724 * 512
        for k in range(0, 1024, 64):
            b = data[adir + k:adir + k + 64]
            if b[2:40].split(b'\x00')[0] == b'Once.HC.Z':
                struct.pack_into('<Q', data, adir + k + 48, len(comp))
                break
    except FileNotFoundError:
        pass

    open(DST, 'wb').write(data)
    back = RedSea(DST).read('Demo/AcctExample/Once.HC.Z')
    print('wrote', DST, len(data), 'bytes')
    print('launcher read-back:', len(back), 'match:', back == LAUNCHER)


if __name__ == '__main__':
    main()
