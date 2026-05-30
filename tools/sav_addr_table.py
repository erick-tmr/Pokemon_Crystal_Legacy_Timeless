#!/usr/bin/env python3
"""sav_addr_table.py - print the build-derived save-file offset table.

Re-derives every save-editing offset from pokecrystal11.sym so the numbers in
docs/save_editing.md can be regenerated after a rebuild (a change to wram.asm shifts
everything after it). See docs/save_editing.md.

Usage: python3 tools/sav_addr_table.py
"""
import re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYM  = os.path.join(ROOT, "pokecrystal11.sym")

if not os.path.exists(SYM):
    raise SystemExit("missing %s - build the ROM first (make crystal11)" % SYM)

syms = {}
with open(SYM) as f:
    for line in f:
        m = re.match(r'^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)\s*$', line.strip())
        if m and m.group(3) not in syms:
            syms[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))


def soff(n):  # SRAM symbol -> flat .sav offset
    b, a = syms[n]; return b * 0x2000 + (a - 0xA000)


PD = syms["wPlayerData"][1]
GD = soff("sGameData"); BGD = soff("sBackupGameData")


def prim(w): return GD + (syms[w][1] - PD)    # WRAM item symbol -> primary save offset
def bak(w):  return BGD + (syms[w][1] - PD)


rows = [
    ("Bag items count",      "wNumItems"),
    ("Bag items list",       "wItems"),
    ("Key items count",      "wNumKeyItems"),
    ("Key items list",       "wKeyItems"),
    ("Ball pocket count",    "wNumBalls"),
    ("Ball pocket list",     "wBalls"),
    ("PC items count",       "wNumPCItems"),
    ("PC items list",        "wPCItems"),
    ("TM/HM array",          "wTMsHMs"),
    ("Visited spawns (Fly)", "wVisitedSpawns"),
]

print("delta primary-backup = 0x%X" % (GD - BGD))
print("%-22s %-12s %-8s %-8s" % ("field", "wram", "primary", "backup"))
for label, w in rows:
    if w in syms:
        print("%-22s %02x:%04x    0x%04X   0x%04X" % (label, syms[w][0], syms[w][1], prim(w), bak(w)))
    else:
        print("%-22s MISSING" % label)

print()
for n in ["sOptions", "sCheckValue1", "sGameData", "sGameDataEnd", "sChecksum", "sCheckValue2",
          "sBackupOptions", "sBackupCheckValue1", "sBackupGameData", "sBackupGameDataEnd",
          "sBackupChecksum", "sBackupCheckValue2"]:
    if n in syms:
        print("%-22s %02x:%04x  off=0x%04X" % (n, syms[n][0], syms[n][1], soff(n)))
