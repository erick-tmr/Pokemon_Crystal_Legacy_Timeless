#!/usr/bin/env python3
"""savtool.py - safe byte-editor for Pokemon Crystal Legacy "Timeless" .sav files.

Fail-closed: writes nothing unless the .sym-derived addresses reproduce the save's
existing checksum. Always edits BOTH the primary and backup copies, recomputes both
checksums, and reads the file back to verify.

See docs/save_editing.md for the full reference (format, pockets, item IDs, caveats).

Usage:
    1. Build the ROM so pokecrystal11.sym exists (`make crystal11`).
    2. Edit the __main__ block below: set SAV (or pass the path as argv[1]),
       uncomment the edits you want, and uncomment s.save().
    3. python3 tools/savtool.py [path/to/your.sav]
"""
import re, os, sys

# Repo root is the parent of tools/ - derived from this file so it works anywhere.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYM  = os.path.join(ROOT, "pokecrystal11.sym")


def load_syms(path):
    s = {}
    with open(path) as f:
        for line in f:
            m = re.match(r'^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)\s*$', line.strip())
            if m and m.group(3) not in s:
                s[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    return s


class Sav:
    def __init__(self, sav_path, sym_path=SYM):
        if not os.path.exists(sym_path):
            raise SystemExit("missing %s - build the ROM first (make crystal11)" % sym_path)
        self.syms = load_syms(sym_path)
        self.data = bytearray(open(sav_path, "rb").read())
        self.path = sav_path
        if len(self.data) != 0x8000:
            raise SystemExit("expected 32768-byte .sav, got %d" % len(self.data))
        self.orig = bytes(self.data)
        self.GD,  self.GDE,  self.CHK  = map(self.soff, ("sGameData", "sGameDataEnd", "sChecksum"))
        self.BGD, self.BGDE, self.BCHK = map(self.soff, ("sBackupGameData", "sBackupGameDataEnd", "sBackupChecksum"))
        self.PD = self.syms["wPlayerData"][1]
        self._refuse_unless_checksums_reproduce()

    def soff(self, name):
        b, a = self.syms[name]; return b * 0x2000 + (a - 0xA000)

    def prim(self, wsym): return self.GD  + (self.syms[wsym][1] - self.PD)
    def bak(self,  wsym): return self.BGD + (self.syms[wsym][1] - self.PD)

    @staticmethod
    def sum16(buf, lo, hi):
        s = 0
        for i in range(lo, hi): s = (s + buf[i]) & 0xFFFF
        return s

    def _refuse_unless_checksums_reproduce(self):
        for lo, hi, co, name in [(self.GD, self.GDE, self.CHK, "primary"),
                                 (self.BGD, self.BGDE, self.BCHK, "backup")]:
            calc   = self.sum16(self.data, lo, hi)
            stored = self.data[co] | (self.data[co + 1] << 8)
            if calc != stored:
                raise SystemExit("REFUSE: %s checksum %04x != stored %04x "
                                 "(wrong addresses / different build?)" % (name, calc, stored))

    # --- edits (each writes to BOTH copies) ---
    def set_keyitems(self, ids, cap=25):
        assert len(ids) <= cap
        for base in (self.prim, self.bak):
            o = base("wNumKeyItems")
            self.data[o] = len(ids)
            for i in range(cap + 1): self.data[o + 1 + i] = 0
            for i, v in enumerate(ids): self.data[o + 1 + i] = v
            self.data[o + 1 + len(ids)] = 0xFF

    def set_list_pocket(self, count_sym, cap, pairs):   # bag/balls/pc: pairs=[(id,qty),...]
        assert len(pairs) <= cap
        for base in (self.prim, self.bak):
            o = base(count_sym)
            self.data[o] = len(pairs)
            for i in range(cap * 2 + 1): self.data[o + 1 + i] = 0
            j = o + 1
            for iid, q in pairs:
                self.data[j] = iid; self.data[j + 1] = q & 0xFF; j += 2
            self.data[j] = 0xFF

    def set_tmhm(self, tm_qty=99, hm_qty=1, num_tms=50, num_hms=7):
        for base in (self.prim, self.bak):
            o = base("wTMsHMs")
            for i in range(num_tms):          self.data[o + i] = tm_qty
            for i in range(num_hms):          self.data[o + num_tms + i] = hm_qty

    def set_spawn_bits(self, bits, nbytes=4):
        for base in (self.prim, self.bak):
            o = base("wVisitedSpawns")
            for i in range(nbytes): self.data[o + i] = 0
            for b in bits:          self.data[o + (b // 8)] |= (1 << (b % 8))

    def save(self, out=None):
        for lo, hi, co in [(self.GD, self.GDE, self.CHK), (self.BGD, self.BGDE, self.BCHK)]:
            s = self.sum16(self.data, lo, hi)
            self.data[co] = s & 0xFF; self.data[co + 1] = s >> 8
        out = out or self.path
        with open(out, "wb") as f:
            f.write(self.data); f.flush(); os.fsync(f.fileno())
        assert open(out, "rb").read() == bytes(self.data), "read-back mismatch"
        changed = sum(1 for i in range(len(self.data)) if self.data[i] != self.orig[i])
        print("saved + read-back verified: %s (%d bytes changed)" % (out, changed))


# All 25 key items (KEY_ITEM pocket, id order). See docs/save_editing.md appendix.
ALL_KEY_ITEMS = [0x07, 0x36, 0x37, 0x3A, 0x3B, 0x3D, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
                 0x73, 0x74, 0x7F, 0x80, 0x81, 0x82, 0x85, 0x86, 0x93, 0x94, 0x95, 0xAF, 0xB2]
# All 24 real fly destinations (12 Johto + 12 Kanto), from data/maps/flypoints.asm.
ALL_FLY_SPAWNS = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26]


if __name__ == "__main__":
    SAV = sys.argv[1] if len(sys.argv) > 1 else "/path/to/your.sav"   # <-- set this or pass as arg
    s = Sav(SAV, SYM)
    # --- uncomment what you want, then uncomment s.save() ---
    # s.set_keyitems(ALL_KEY_ITEMS)
    # s.set_tmhm(tm_qty=99, hm_qty=1)
    # s.set_spawn_bits(ALL_FLY_SPAWNS)
    # s.set_list_pocket("wNumItems", 84, [(0x12, 99), (0x0E, 99)])   # bag: Potion x99, Full Restore x99
    # s.save()
    print("loaded OK; both checksums reproduce (safe to edit). "
          "Uncomment edits + s.save() to apply.")
