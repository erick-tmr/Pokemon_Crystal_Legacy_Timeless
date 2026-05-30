# Editing `.sav` files (Timeless)

A practical reference for byte-editing Pokémon Crystal Legacy **Timeless** save files
(`.sav`), based on what we reverse-engineered from this build. Written for setting up
test saves quickly (all key items, all fly points, all TMs/HMs, etc.) without booting
PKHeX or replaying the game.

> ⚠️ **Addresses are build-specific.** Every offset below was derived from
> `pokecrystal11.sym` for the current build and verified against a real save. If the
> hack's WRAM layout changes (new variables in `wram.asm` shift everything after them),
> these numbers move. **Always re-derive from the `.sym`** — see
> [Regenerating addresses](#regenerating-addresses-after-a-rebuild). The scripts here
> fail-closed: they refuse to write if the addresses don't reproduce the save's existing
> checksum, so a stale address can't silently corrupt a save.

---

## Table of contents

1. [The `.sav` file format](#the-sav-file-format)
2. [Save block structure (why there are two copies)](#save-block-structure)
3. [The checksum](#the-checksum)
4. [The golden rules (safe-edit procedure)](#the-golden-rules)
5. [Address quick-reference](#address-quick-reference)
6. [Pocket formats](#pocket-formats)
   - [Bag / Balls / PC items (id+qty lists)](#bag--balls--pc-items)
   - [Key items (id-only list)](#key-items)
   - [TMs / HMs (fixed quantity array)](#tms--hms)
   - [Fly destinations (visited-spawn flags)](#fly-destinations)
7. [Item IDs](#item-ids)
8. [The reusable tool: `savtool.py`](#the-reusable-tool-savtoolpy)
9. [Regenerating addresses after a rebuild](#regenerating-addresses-after-a-rebuild)
10. [Caveats & gotchas](#caveats--gotchas)
11. [Appendix: full lists](#appendix-full-lists)

---

## The `.sav` file format

- A Timeless `.sav` is **32768 bytes** (`0x8000`) — a flat dump of the cart's 4 SRAM
  banks, `0x2000` bytes each, in order (bank 0, 1, 2, 3).
- The `.sym` file gives every symbol as `BB:AAAA name` where `BB` is the SRAM bank and
  `AAAA` is the GameBoy address in the `0xA000–0xBFFF` window.
- **Address → file offset:**

  ```
  file_offset = bank * 0x2000 + (gb_addr - 0xA000)
  ```

  Example: `sChecksum` is `01:ad0d` → `1*0x2000 + (0xAD0D-0xA000)` = `0x2D0D`.

The structure (`sram.asm`) is otherwise the **vanilla Crystal skeleton** — the only
"different" parts for our purposes are *inside* the saved data (the item pockets), not
the SRAM layout itself.

---

## Save block structure

The data we care about lives in one contiguous **game-data block**, and the game keeps
**two copies**: a primary and a full backup.

| Region              | Primary           | Backup            |
|---------------------|-------------------|-------------------|
| Options             | `0x2000`          | `0x1200`          |
| Check value 1       | `0x2008`          | `0x1208`          |
| **Game data start** | `0x2009` (`sGameData`)     | `0x1209` (`sBackupGameData`) |
| **Game data end**   | `0x2B83` (`sGameDataEnd`)   | `0x1D83` (`sBackupGameDataEnd`) |
| **Checksum (dw)**   | `0x2D0D` (`sChecksum`)      | `0x1F0D` (`sBackupChecksum`) |
| Check value 2       | `0x2D0F`          | `0x1F0F`          |

The game data holds, in order: player data → current-map data → Pokémon data. All the
item pockets live in the **player-data** part.

**Key fact:** the primary and backup copies have an *identical internal layout*. The
backup of any field is simply `primary_offset − 0xE00`. So **every edit must be applied
to both copies**, or the game may load the stale backup (or flag corruption).

When the game loads a save it (1) checks the two check-value sentinels, (2) recomputes
the checksum and compares it to the stored one, and (3) falls back to the backup copy if
the primary fails. That's why we update **both copies and both checksums**.

---

## The checksum

Verified by reproducing the stored value on an untouched save, and by the game accepting
our edits:

- **Algorithm:** 16-bit sum of every byte in `[sGameData, sGameDataEnd)` (i.e.
  `[0x2009, 0x2B83)`), taken mod `0x10000`.
- **Stored:** little-endian (low byte first) at `sChecksum` (`0x2D0D`).
- **Backup:** same algorithm over `[0x1209, 0x1D83)`, stored at `sBackupChecksum`
  (`0x1F0D`).

```python
def checksum16(buf, lo, hi):
    s = 0
    for i in range(lo, hi):
        s = (s + buf[i]) & 0xFFFF
    return s
```

Notes:
- The reserved padding between `sGameDataEnd` and `sChecksum` is all zero on a normal
  save, so summing to either point happens to give the same number — but
  `sGameDataEnd` is the canonical end the game uses. Stick with it.
- The check-value sentinels (`sCheckValue1/2`) are **not** part of the checksum and are
  fixed magic constants. **Don't touch them.** Options (`0x2000–0x2008`) are also outside
  the checksum range — editing options needs a different approach (not covered here).

---

## The golden rules

The safe procedure (what `tools/savtool.py` does):

1. **Back up the file first.** The SD card's save folder is often mounted read-only for
   *new* files, so put the backup somewhere writable: `cp the.sav the.sav.bak`.
2. **Re-derive offsets from `pokecrystal11.sym`** — don't hard-code blindly.
3. **Prove the checksum algorithm reproduces the save's *existing* checksum before
   writing anything.** If it doesn't, your addresses or algorithm are wrong → **abort,
   change nothing.** This single check is what makes byte-editing safe.
4. Apply each edit to **both** the primary and backup copies.
5. **Recompute both checksums** after editing.
6. Verify **only the bytes you intended** changed (diff against the original).
7. Write, then **read the file back** and confirm it matches.

Fail-closed: if any check fails, write nothing.

---

## Address quick-reference

Build-derived (`pokecrystal11.sym`), primary and backup. Backup = primary − `0xE00`.

| Field                         | WRAM symbol      | Primary  | Backup   | Notes |
|-------------------------------|------------------|----------|----------|-------|
| Bag items count               | `wNumItems`      | `0x2420` | `0x1620` | then list |
| Bag items list                | `wItems`         | `0x2421` | `0x1621` | `[id,qty]…[FF]`, cap **84** |
| Key items count               | `wNumKeyItems`   | `0x24CA` | `0x16CA` | then list |
| Key items list                | `wKeyItems`      | `0x24CB` | `0x16CB` | `[id]…[FF]`, cap **25** |
| Ball pocket count             | `wNumBalls`      | `0x254F` | `0x174F` | then list |
| Ball pocket list              | `wBalls`         | `0x2550` | `0x1750` | `[id,qty]…[FF]`, cap **12** |
| PC items count                | `wNumPCItems`    | `0x259C` | `0x179C` | then list |
| PC items list                 | `wPCItems`       | `0x259D` | `0x179D` | `[id,qty]…[FF]`, cap **49** |
| TM/HM quantities              | `wTMsHMs`        | `0x23E7` | `0x15E7` | fixed **57**-byte array, no count |
| Visited spawns (Fly)          | `wVisitedSpawns` | `0x2833` | `0x1A33` | 28-bit flag array (4 bytes) |
| Checksum (primary/backup)     | `sChecksum`      | `0x2D0D` | `0x1F0D` | dw, little-endian |

Capacities come from `constants/item_data_constants.asm`:
`MAX_ITEMS=84`, `MAX_BALLS=12`, `MAX_KEY_ITEMS=25`, `MAX_PC_ITEMS=49`,
`MAX_ITEM_STACK=99` (per-slot quantity cap). Counts: `NUM_TMS=50`, `NUM_HMS=7`.

---

## Pocket formats

### Bag / Balls / PC items

These three are **id+quantity lists** (`wram.asm`: `ds MAX * 2 + 1`):

```
[count] [id1] [qty1] [id2] [qty2] … [0xFF]
```

- `count` = number of distinct slots used (the byte at the `wNum…` offset).
- Each slot is **2 bytes**: item id, then quantity (1–99).
- Terminated by `0xFF`.
- `count` must match the number of pairs, and you can't exceed the pocket cap.

Example (a real bag): `1A 09 03 4A 05 …` → `count=0x1A` (26 slots), then item `0x09`×3,
item `0x4A`×5, …

### Key items

A **list of ids only** — you hold exactly one of each (`wram.asm`: `ds MAX_KEY_ITEMS + 1`):

```
[count] [id1] [id2] … [0xFF]
```

- No quantity bytes.
- Cap **25** (`MAX_KEY_ITEMS`).
- "All key items" we wrote (25): see [appendix](#all-key-items). Bytes:
  `07 36 37 3A 3B 3D 42 43 44 45 46 47 73 74 7F 80 81 82 85 86 93 94 95 AF B2`, count
  `0x19`, terminator `FF`.

### TMs / HMs

**No list and no count byte** — this is the part that differs most from the other
pockets. It's a **fixed 57-byte array** (`wram.asm`: `wTMsHMs:: ds NUM_TMS + NUM_HMS`),
one byte per TM/HM holding its **quantity**:

```
index  0 … 49   = TM01 … TM50   (quantity each)
index 50 … 56   = HM01 … HM07   (quantity each)
```

- **There is no distinct-count limit** — every TM/HM has a permanent slot, so you can own
  all 57 at once. The only limit is the per-slot quantity cap `MAX_ITEM_STACK=99`.
- `0` in a slot means "not owned"; non-zero means owned with that quantity.
- HM slot order (50→56): **Cut, Fly, Surf, Strength, Flash, Whirlpool, Waterfall**
  (the `add_hm` order in `constants/item_constants.asm`).
- "All TMs/HMs" we wrote = TM slots → `99` (`0x63`), HM slots → `1`. Bytes: fifty `63`
  then seven `01`.

### Fly destinations

Fly availability is the **visited-spawn flag array** `wVisitedSpawns` — 4 bytes = 28 bits,
one bit per `SPAWN_*` constant (`constants/map_data_constants.asm`):

```
bit n set  ⇔  SPAWN_n has been visited  ⇔  it shows up on the Fly map
byte = n // 8,   mask = 1 << (n % 8)      (LSB-first within each byte)
```

- The Fly map only lists a city when its bit is set (`CheckIfVisitedFlypoint` in
  `engine/pokegear/pokegear.asm`).
- The **authoritative list of real fly destinations** is `data/maps/flypoints.asm` — 24
  cities (12 Johto + 12 Kanto). Set exactly those bits.
- **Leave the non-destinations off** (`SPAWN_HOME=0`, `SPAWN_DEBUG=1`,
  `SPAWN_UNION_CAVE=17`, `SPAWN_FAST_SHIP=27`) — they aren't on the Fly map and would just
  be orphan bits.
- "All fly" we wrote = bytes `FC FF FD 07` (see [appendix](#all-fly-destinations) for the
  bit math). This unlocks the *destinations*; you still need a Pokémon that knows Fly to
  use it in the field.

---

## Item IDs

Item ids come from `constants/item_constants.asm`, counting from the `const_def` block:
`NO_ITEM = 0`, `MASTER_BALL = 1`, `ULTRA_BALL = 2`, … (`const_skip` advances the counter
without naming an item). To get an id, count down the list, or grep the symbol and let a
script resolve it.

To find which items belong to a pocket, look at `data/items/attributes.asm`: each
`item_attribute` line's **5th argument** is the pocket
(`ITEM` / `BALL` / `KEY_ITEM` / `TM_HM`), and table entry *k* corresponds to item id
*k+1* (the table starts at `MASTER_BALL`). Key items are the rows whose pocket is
`KEY_ITEM`.

---

## The reusable tool: `savtool.py`

A consolidated, fail-closed editor lives at **`tools/savtool.py`**. It re-derives all
offsets from the `.sym`, refuses to run if the checksum doesn't reproduce, edits both
copies, recomputes both checksums, and reads back to verify.

Usage:

```bash
# 1. build so the symbol file exists
make crystal11
# 2. edit the __main__ block: uncomment the edits you want + uncomment s.save()
# 3. run, passing your save path (a copy!) as the argument
python3 tools/savtool.py /path/to/your.sav
```

The `Sav` class exposes one method per pocket — each writes to **both** the primary and
backup copies; `save()` recomputes both checksums and reads back to verify:

```python
from tools.savtool import Sav, ALL_KEY_ITEMS, ALL_FLY_SPAWNS

s = Sav("/path/to/your.sav")          # constructor aborts if checksums don't reproduce
s.set_keyitems(ALL_KEY_ITEMS)         # all 25 key items
s.set_tmhm(tm_qty=99, hm_qty=1)       # all TMs x99, all HMs x1
s.set_spawn_bits(ALL_FLY_SPAWNS)      # all 24 fly destinations
s.set_list_pocket("wNumItems", 84, [(0x12, 99), (0x0E, 99)])  # bag: Potion x99, Full Restore x99
s.save()                              # recompute checksums + write + verify
```

It will `raise SystemExit` (writing nothing) if the `.sym`-derived addresses don't
reproduce the save's existing checksum — i.e. if the build changed or the file isn't what
you think it is. The `ALL_KEY_ITEMS` / `ALL_FLY_SPAWNS` constants are defined in the
module.

---

## Regenerating addresses after a rebuild

If the ROM is rebuilt and `wram.asm` changed, re-derive offsets. `tools/sav_addr_table.py`
prints the whole table from `pokecrystal11.sym`:

```bash
python3 tools/sav_addr_table.py
```

It maps each WRAM item symbol through `wPlayerData` into both the primary and backup
blocks and prints the save offsets. Because every editor here first checks that the
addresses reproduce the save's stored checksum, a stale address can't corrupt a save — it
just aborts.

---

## Caveats & gotchas

- **Event-flag-gated key items:** adding a key item to the pocket gives you the *item*,
  but some are also gated by an event flag in scripts. If a specific key item doesn't
  trigger its event, its `event_flags.asm` flag may also need setting (not covered here).
- **Fly needs the move:** unlocking spawn flags makes cities appear on the Fly map; you
  still need a party Pokémon that knows Fly (HM02) to actually fly.
- **SD card is often read-only for new files:** on the test rig the save folder rejects
  *new* files (so backups go in the repo) but allows **in-place overwrite** of the
  existing `.sav`. The tool overwrites in place and reads back to confirm.
- **`MAX_ITEM_QUANTITY` doesn't exist here** — the stack cap constant is
  `MAX_ITEM_STACK` (`= 99`) in `constants/item_data_constants.asm`.
- **Parsing `map_data_constants.asm`:** it contains several `const_def` enum blocks, so a
  naïve "increment a counter only on `SPAWN_` lines" gives the wrong total (a later block
  resets the counter). Derive `NUM_SPAWNS` from `max(id)+1`.
- **Two copies, always:** forgetting the backup copy is the classic mistake — the game may
  silently load the stale backup. Every edit goes to both.
- **`.sav` size:** this assumes the standard 32 KB flat SRAM dump. An emulator that writes
  a different size (RTC footer, etc.) would shift nothing inside the 32 KB but may append
  trailing bytes — operate on the first `0x8000` bytes.

---

## Appendix: full lists

### All key items
(25; `KEY_ITEM` pocket, in id order)

| id | name | id | name | id | name |
|----|------|----|------|----|------|
| `07` | BICYCLE | `46` | CLEAR_BELL | `82` | LOST_ITEM |
| `36` | COIN_CASE | `47` | SILVER_WING | `85` | BASEMENT_KEY |
| `37` | ITEMFINDER | `73` | GS_BALL | `86` | PASS |
| `3A` | OLD_ROD | `74` | BLUE_CARD | `93` | OLD_AMBER |
| `3B` | GOOD_ROD | `7F` | CARD_KEY | `94` | DOME_FOSSIL |
| `3D` | SUPER_ROD | `80` | MACHINE_PART | `95` | HELIX_FOSSIL |
| `42` | RED_SCALE | `81` | EGG_TICKET | `AF` | SQUIRTBOTTLE |
| `43` | SECRETPOTION | | | `B2` | RAINBOW_WING |
| `44` | S_S_TICKET | | | | |
| `45` | MYSTERY_EGG | | | | |

### Spawns / fly
`constants/map_data_constants.asm`, bits 0–27. **Bold** = real fly destination
(`flypoints.asm`); the other four are intentionally left off.

```
 0 HOME            7 VERMILION*     14 NEW_BARK*      21 OLIVINE*
 1 DEBUG           8 LAVENDER*      15 CHERRYGROVE*   22 ECRUTEAK*
 2 PALLET*         9 SAFFRON*       16 VIOLET*        23 MAHOGANY*
 3 VIRIDIAN*      10 CELADON*       17 UNION_CAVE     24 LAKE_OF_RAGE*
 4 PEWTER*        11 FUCHSIA*       18 AZALEA*        25 BLACKTHORN*
 5 CERULEAN*      12 CINNABAR*      19 CIANWOOD*      26 MT_SILVER*
 6 ROCK_TUNNEL*   13 INDIGO*        20 GOLDENROD*     27 FAST_SHIP
```

### All fly destinations
Bits to set: `2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,22,23,24,25,26`
→ `wVisitedSpawns` bytes = **`FC FF FD 07`**.

Bit math:
- byte0 (bits 0–7): 2–7 set → `0b1111_1100` = `FC`
- byte1 (bits 8–15): all set → `FF`
- byte2 (bits 16–23): 16,18–23 set (17 off) → `0b1111_1101` = `FD`
- byte3 (bits 24–27): 24,25,26 set (27 off) → `0b0000_0111` = `07`

### HM slot order
TM/HM array indices 50–56:

```
50 HM01 CUT   51 HM02 FLY   52 HM03 SURF   53 HM04 STRENGTH
54 HM05 FLASH   55 HM06 WHIRLPOOL   56 HM07 WATERFALL
```

---

*Derived from build `pokecrystal11` and verified against a real save.
Tooling: `tools/savtool.py` (editor) and `tools/sav_addr_table.py` (offset table).*
