#!/usr/bin/env python3
"""RedSea filesystem extractor for TempleOS ISOs + Terry's LZW decompressor."""
import struct, sys, os

ARC_MAX_BITS = 12
CT_NONE, CT_7_BIT, CT_8_BIT = 1, 2, 3

class ArcCtrl:
    def __init__(self, comp_type):
        self.min_bits = 7 if comp_type == CT_7_BIT else 8
        self.min_table_entry = 1 << self.min_bits
        self.free_idx = self.min_table_entry
        self.next_bits_in_use = self.min_bits + 1
        self.free_limit = 1 << self.next_bits_in_use
        self.saved_basecode = 0xFFFFFFFF
        self.entry_used = True
        self.table = {}                 # code -> (basecode, ch)
        self.basecnt = {}               # code -> number of entries using it as basecode
        self.cur_entry = None
        self.next_entry = None
        self.last_ch = 0
        self.stk = []
        self.ArcEntryGet()
        self.entry_used = True

    def ArcEntryGet(self):
        if self.entry_used:
            i = self.free_idx
            self.entry_used = False
            self.cur_entry = self.next_entry
            if self.next_bits_in_use < ARC_MAX_BITS:
                self.next_entry = i
                i += 1
                if i == self.free_limit:
                    self.next_bits_in_use += 1
                    self.free_limit = 1 << self.next_bits_in_use
            else:
                # recycle: find a code that no entry uses as a basecode
                while True:
                    i += 1
                    if i == self.free_limit:
                        i = self.min_table_entry
                    if self.basecnt.get(i, 0) == 0:
                        break
                self.next_entry = i
                if i in self.table:      # evict the old entry at this code
                    bc, ch = self.table.pop(i)
                    self.basecnt[bc] -= 1
            self.free_idx = i

    def expand(self, src, expanded_size, src_pos):
        out = bytearray()
        self.src_buf = src
        src_size = len(src) * 8
        first = True
        while len(out) < expanded_size:
            if self.stk:
                out.append(self.stk.pop())
                continue
            if first and self.saved_basecode == 0xFFFFFFFF:
                lastcode = self.bfield(src_pos, self.next_bits_in_use)
                src_pos += self.next_bits_in_use
                out.append(lastcode & 0xFF)
                self.ArcEntryGet()
                self.last_ch = lastcode
                first = False
                continue
            if src_pos + self.next_bits_in_use > src_size:
                break
            basecode = self.bfield(src_pos, self.next_bits_in_use)
            src_pos += self.next_bits_in_use
            if self.cur_entry == basecode:
                self.stk.append(self.last_ch)
                code = lastcode
            else:
                code = basecode
            while code >= self.min_table_entry:
                bc, ch = self.table[code]
                self.stk.append(ch)
                code = bc
            self.stk.append(code)
            self.last_ch = code
            self.entry_used = True
            tmp = self.cur_entry
            self.table[tmp] = (lastcode, self.last_ch)
            self.basecnt[lastcode] = self.basecnt.get(lastcode, 0) + 1
            self.ArcEntryGet()
            while (self.stk or (len(out) < expanded_size)) and False:
                pass
            while self.stk and len(out) < expanded_size:
                out.append(self.stk.pop())
            lastcode = basecode
            self.saved_basecode = lastcode
            first = False
        return bytes(out[:expanded_size])

    def bfield(self, pos, bits):
        res = 0
        for i in range(bits):
            byte = self.src_buf[(pos + i) >> 3]
            if byte & (1 << ((pos + i) & 7)):
                res |= (1 << i)
        return res

def uncompress(data):
    csize, chi, esize, ehi = struct.unpack('<IIII', data[:16])
    ctype = data[16]
    body = data[17:17 + csize - 17]
    if ctype == CT_NONE:
        return body[:esize]
    c = ArcCtrl(ctype)
    return c.expand(body, esize, 0)

class RedSea:
    def __init__(self, iso_path):
        self.d = open(iso_path, 'rb').read()
        # find boot block: signature 0x88 at byte 3 of a 512-byte block, 0xAA55 at +510
        self.drv_offset = self.sects = self.root_clus = None
        for blk in range(len(self.d) // 512):
            off = blk * 512
            if self.d[off + 3] == 0x88 and struct.unpack('<H', self.d[off+510:off+512])[0] == 0xAA55:
                self.drv_offset = struct.unpack('<Q', self.d[off+8:off+16])[0]
                self.sects = struct.unpack('<Q', self.d[off+16:off+24])[0]
                self.root_clus = struct.unpack('<Q', self.d[off+24:off+32])[0]
                break
        if self.root_clus is None:
            raise ValueError("RedSea boot block not found")

    def ent(self, off):
        b = self.d[off:off+64]
        attr = struct.unpack('<H', b[0:2])[0]
        raw = b[2:40]
        z = raw.find(b'\x00')
        name = raw[:z].decode('latin1') if z > 0 else ''
        clus, size = struct.unpack('<QQ', b[40:56])
        return attr, name, clus, size

    def ls(self, clus, path=''):
        out = []
        off = clus * 512
        while True:
            attr, name, c, s = self.ent(off)
            if not name or not name.isprintable() or name == '\xff' * 4:
                break
            if name not in ('.', '..'):
                out.append((attr, name, c, s, path + name))
            off += 64
        return out

    def find(self, path):
        parts = [p for p in path.strip('/').split('/') if p]
        entries = self.ls(self.root_clus)
        cur_clus = None
        for i, part in enumerate(parts):
            found = None
            for attr, name, c, s, full in entries:
                if name.lower() == part.lower():
                    found = (attr, name, c, s)
                    break
            if not found:
                raise FileNotFoundError(path + ' (' + part + ')')
            attr, name, c, s = found
            if i < len(parts) - 1:
                if not (attr & 0x10):
                    raise NotADirectoryError(part)
                entries = self.ls(c)
            else:
                return attr, name, c, s
        raise FileNotFoundError(path)

    def read(self, path):
        attr, name, c, s = self.find(path)
        data = self.d[c*512:c*512 + s]
        if name.lower().endswith('.z'):
            return uncompress(data)
        return data

if __name__ == '__main__':
    rs = RedSea(sys.argv[1])
    print(f"drv_offset={rs.drv_offset} sects={rs.sects} root_clus={rs.root_clus}")
    for attr, name, c, s, full in rs.ls(rs.root_clus):
        kind = 'D' if attr & 0x10 else 'F'
        print(f"  {kind} clus={c:<8} size={s:<10} {name}")
    if len(sys.argv) > 2:
        data = rs.read(sys.argv[2])
        sys.stdout.buffer.write(data[:3000])
