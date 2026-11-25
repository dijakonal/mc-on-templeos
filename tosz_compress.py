#!/usr/bin/env python3
"""TempleOS LZW compressor (port of CompressBuf from Compress.HC)."""
import struct

ARC_MAX_BITS = 12
CT_NONE, CT_7_BIT, CT_8_BIT = 1, 2, 3

class ArcCompCtrl:
    def __init__(self, comp_type):
        self.min_bits = 7 if comp_type == CT_7_BIT else 8
        self.min_table_entry = 1 << self.min_bits
        self.free_idx = self.min_table_entry
        self.next_bits_in_use = self.min_bits + 1
        self.cur_bits_in_use = 0
        self.free_limit = 1 << self.next_bits_in_use
        self.saved_basecode = 0xFFFFFFFF
        self.entry_used = True
        self.table = {}          # code -> (basecode, ch)
        self.chains = {}         # basecode -> [codes], newest first
        self.cur_entry = None
        self.next_entry = None
        self.ArcEntryGet()
        self.entry_used = True

    def ArcEntryGet(self):
        if self.entry_used:
            i = self.free_idx
            self.entry_used = False
            self.cur_entry = self.next_entry
            self.cur_bits_in_use = self.next_bits_in_use
            if self.next_bits_in_use < ARC_MAX_BITS:
                self.next_entry = i
                i += 1
                if i == self.free_limit:
                    self.next_bits_in_use += 1
                    self.free_limit = 1 << self.next_bits_in_use
            else:
                while True:
                    i += 1
                    if i == self.free_limit:
                        i = self.min_table_entry
                    if not self.chains.get(i):
                        break
                self.next_entry = i
                if i in self.table:
                    bc, ch = self.table.pop(i)
                    try:
                        self.chains[bc].remove(i)
                    except ValueError:
                        pass
            self.free_idx = i

def compress(src):
    comp_type = CT_8_BIT if any(b & 0x80 for b in src) else CT_7_BIT
    c = ArcCompCtrl(comp_type)
    size = len(src)
    dst_size = (size + 18) * 8
    dst = bytearray((dst_size + 7) >> 3)
    bitpos = [18 * 8]  # sizeof(CArcCompress) == 17... builder starts at 17 bytes? see note

    # CompressBuf uses sizeof(CArcCompress)<<3; HolyC packs structs: 16+1+1=17? 
    # body[1] is part of the struct: 4*4+1+1 = 18? Terry's kernel writes from sizeof<<3.
    # TOSZ reads from (sizeof-1)<<3. With pack(1): sizeof=18, so TOSZ reads byte 17,
    # kernel writes byte 18?? -- resolved empirically below; try 17 first.
    bitpos[0] = 17 * 8

    def emit(code, nbits):
        p = bitpos[0]
        for i in range(nbits):
            if code & (1 << i):
                dst[(p + i) >> 3] |= 1 << ((p + i) & 7)
        bitpos[0] += nbits

    idx = 0
    if size:
        basecode = src[0]
        idx = 1
    else:
        basecode = 0
    ok = True
    while idx < size:
        c.ArcEntryGet()
        emitted = False
        while idx < size:
            ch = src[idx]
            idx += 1
            found = None
            for ecode in c.chains.get(basecode, []):
                if c.table[ecode][1] == ch:
                    found = ecode
                    break
            if found is not None:
                basecode = found
                continue
            if bitpos[0] + c.cur_bits_in_use > dst_size:
                ok = False
                break
            emit(basecode, c.cur_bits_in_use)
            c.entry_used = True
            tmp = c.cur_entry
            c.table[tmp] = (basecode, ch)
            c.chains.setdefault(basecode, []).insert(0, tmp)
            basecode = ch
            emitted = True
            break
        if not ok:
            break
    if ok:
        # ArcFinishCompression
        if bitpos[0] + c.cur_bits_in_use > dst_size:
            ok = False
        else:
            emit(c.saved_basecode if basecode == 0 else basecode, c.next_bits_in_use)
    if not (ok and idx == size):
        # fall back to uncompressed
        body = src
        comp_type = CT_NONE
    else:
        body = bytes(dst[17:((bitpos[0] + 7) >> 3)])
    total = 17 + len(body)
    hdr = struct.pack('<IIII', total, 0, size, 0) + bytes([comp_type])
    return hdr + body

if __name__ == '__main__':
    import sys, os
    sys.path.insert(0, '/tmp/opencode')
    from redsea import uncompress
    # round-trip test on a few ISO files with known original .Z bytes
    import glob
    tests = []
    rs_tests = [
        ('/home/dijakonal/minecraft-templeos/TempleOS.ISO', 'StartOS.HC.Z'),
        ('/home/dijakonal/minecraft-templeos/TempleOS.ISO', 'Demo/AcctExample/Once.HC.Z'),
        ('/home/dijakonal/minecraft-templeos/TempleOS.ISO', 'Kernel/KGlbls.HC.Z'),
    ]
    for iso, path in rs_tests:
        raw = open(iso, 'rb').read()
        from redsea import RedSea
        rs = RedSea(iso)
        attr, name, c, s = rs.find(path)
        orig = raw[c*512:c*512+s]
        plain = uncompress(orig)
        mine = compress(plain)
        # verify my compressed output decompresses back
        back = uncompress(mine)
        status = "ROUNDTRIP OK" if back == plain else "ROUNDTRIP FAIL"
        match = " (byte-identical to Terry's!)" if mine == orig else ""
        print(f"{path}: {len(plain)} -> {len(mine)} bytes, {status}{match}")
