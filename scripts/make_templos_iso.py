#!/usr/bin/env python3
"""Build a TempleOS ISO with HolyCraft support that runs in run-mc.

Uses the py files in the scripts folder (redsea, tosz_compress, patch_iso patterns)
to patch the base TempleOS.ISO with MCRAFT.HC and an auto-run launcher.

Usage:
    python3 scripts/make_templos_iso.py [output_iso]

If no output ISO is specified, defaults to TempleOS-HolyCraft-ISO.ISO
"""
import os
import sys
import struct

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redsea import RedSea
from tosz_compress import compress

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
SRC_ISO = os.path.join(ROOT, 'TempleOS.ISO')
DST_ISO = os.environ.get('HOLYCRAFT_ISO',
                         os.path.join(ROOT, 'TempleOS-HolyCraft-ISO.ISO'))
GAME = os.path.join(ROOT, 'src', 'MCRAFT.HC')

# Launcher text - auto-runs MCRAFT.HC at boot
LAUNCHER = b'''//HolyCraft launcher: runs in the first terminal at boot.
#include "::/MCRAFT.HC";
'''


def main():
    # Determine output ISO path
    if len(sys.argv) > 1:
        out_arg = sys.argv[1]
    else:
        out_arg = None

    if out_arg:
        DST_ISO = out_arg
    else:
        DST_ISO = os.environ.get('HOLYCRAFT_ISO',
                                 os.path.join(ROOT, 'TempleOS-HolyCraft-ISO.ISO'))

    print(f"Source ISO: {SRC_ISO}")
    print(f"Game source: {GAME}")
    print(f"Output ISO: {DST_ISO}")

    # Check source files exist
    if not os.path.exists(SRC_ISO):
        print(f"ERROR: Source ISO not found: {SRC_ISO}")
        sys.exit(1)
    if not os.path.exists(GAME):
        print(f"ERROR: Game source not found: {GAME}")
        sys.exit(1)

    # Read game data
    game_data = open(GAME, 'rb').read()
    print(f"Game: {len(game_data)} bytes -> {len(game_data)//512 + 1} blocks")

    # Add compat_hcc.HC include if not present (original ISO had it)
    compat_include = b'#include "::/compat_hcc.HC";\n'
    if compat_include not in game_data[:200]:
        game_data = compat_include + game_data
        print("Added #include '::/compat_hcc.HC' to MCRAFT.HC")

    # Read and parse source ISO
    rs = RedSea(SRC_ISO)
    data = bytearray(open(SRC_ISO, 'rb').read())

    # Locate the sacrificial file (access log) for cluster space
    try:
        attr, name, log_clus, log_size = rs.find('Demo/WebLogDemo/access_170622.log')
        print(f"Sacrificing {name}: clus={log_clus} size={log_size}")
    except FileNotFoundError:
        print("WARNING: No access log found, searching for other sacrificial file...")
        # Try to find any file in Demo/WebLogDemo
        try:
            entries = rs.ls(rs.root_clus)
            found = False
            for attr, name, c, s in entries:
                if 'access' in name.lower() or 'log' in name.lower():
                    attr, name, log_clus, log_size = rs.find(name)
                    print(f"Found: {name}: clus={log_clus} size={log_size}")
                    found = True
                    break
            if not found:
                print("ERROR: No sacrificial file found")
                sys.exit(1)
        except Exception as e:
            print(f"ERROR: {e}")
            sys.exit(1)

    blocks_needed = (len(game_data) + 511) // 512
    assert blocks_needed < log_size // 512, \
        f"Not enough room in log file: need {blocks_needed} blocks, have {log_size // 512}"

    # Write game data into the log file's clusters
    off = log_clus * 512
    data[off:off+len(game_data)] = game_data
    # Zero-pad to block boundary
    pad = (-len(game_data)) % 512
    data[off+len(game_data):off+len(game_data)+pad] = b'\x00' * pad
    print(f"Wrote MCRAFT.HC into {name} (cluster {log_clus})")

    # Add root directory entry for MCRAFT.HC
    root_off = rs.root_clus * 512
    # Find first zero-name slot after the used entries
    slot_off = None
    for k in range(0, 1536, 64):
        b = data[root_off+k:root_off+k+64]
        nm = b[2:40].split(b'\x00')[0]
        if not nm:
            slot_off = root_off + k
            break
    assert slot_off is not None, "no free root dir slot"
    print(f"Root dir entry at {slot_off:#x} (slot {(slot_off-root_off)//64})")

    # Copy datetime from StartOS.HC.Z entry
    dt = b'\x00' * 8
    for k in range(0, 1536, 64):
        b = data[root_off+k:root_off+k+64]
        if b[2:40].split(b'\x00')[0] == b'StartOS.HC.Z':
            dt = b[56:64]
            break

    ent = struct.pack('<H', 0x0C00)               # FIXED | CONTIGUOUS
    ent += b'MCRAFT.HC'.ljust(38, b'\x00')
    ent += struct.pack('<QQ', log_clus, len(game_data))
    ent += dt
    assert len(ent) == 64
    data[slot_off:slot_off+64] = ent
    print("Added MCRAFT.HC root directory entry")

    # Patch Once.HC.Z (root copy is the one that runs on boot)
    launcher_compressed = compress(LAUNCHER)
    print(f"Launcher compressed: {len(launcher_compressed)} bytes")

    # Find Once.HC.Z in root directory
    once_clus = once_size = entry_off = None
    for k in range(0, 1536, 64):
        b = data[root_off+k:root_off+k+64]
        nm = b[2:40].split(b'\x00')[0]
        if nm == b'Once.HC.Z':
            entry_off = root_off + k
            once_clus = struct.unpack('<Q', b[40:48])[0]
            once_size = struct.unpack('<Q', b[48:56])[0]
            break

    if entry_off is None:
        print("ERROR: Once.HC.Z not found in root directory")
        sys.exit(1)

    print(f"root Once.HC.Z: clus={once_clus} size={once_size}")
    assert len(launcher_compressed) <= ((once_size + 511) // 512) * 512, \
        "launcher too big"

    data[once_clus*512:once_clus*512+len(launcher_compressed)] = launcher_compressed
    struct.pack_into('<Q', data, entry_off+48, len(launcher_compressed))
    print("patched root Once.HC.Z")

    # Also patch the AcctExample copy for consistency
    try:
        attr, name, once2_clus, once2_size = rs.find('Demo/AcctExample/Once.HC.Z')
        data[once2_clus*512:once2_clus*512+len(launcher_compressed)] = launcher_compressed
        adir = 26724 * 512
        for k in range(0, 1024, 64):
            b = data[adir+k:adir+k+64]
            if b[2:40].split(b'\x00')[0] == b'Once.HC.Z':
                struct.pack_into('<Q', data, adir+k+48, len(launcher_compressed))
                break
        print("patched AcctExample Once.HC.Z too")
    except FileNotFoundError:
        print("no AcctExample Once (ok)")

    # Write the output ISO
    open(DST_ISO, 'wb').write(bytes(data))
    print(f"\nwrote {DST_ISO} ({len(data)} bytes)")

    # Sanity check: read back MCRAFT.HC via our extractor
    rs2 = RedSea(DST_ISO)
    back = rs2.read('MCRAFT.HC')
    print(f"read-back MCRAFT.HC: {len(back)} bytes, match: {back == game_data}")

    back2 = rs2.read('Once.HC.Z')
    print(f"read-back Once.HC.Z: {len(back2)} bytes, match: {back2 == LAUNCHER}")

    print(f"\nISO ready! Run with: run-mc.sh (or qemu -cdrom {DST_ISO})")


if __name__ == '__main__':
    main()