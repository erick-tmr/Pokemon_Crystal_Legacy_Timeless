# Crystal Legacy Timeless {{VERSION}} — Patching Instructions

**Crystal Legacy Timeless** is a fork of Pokémon Crystal Legacy with all Real-Time Clock (RTC)
dependence removed, shipped as an **MBC5** cartridge so it runs safely on RTC-less hardware
(FPGA cores, flash carts, emulators) without corrupting saves. See `TIMELESS.md` in the repo for
the full details and the event-by-event guide:
https://github.com/erick-tmr/Pokemon_Crystal_Legacy_Timeless/blob/main/TIMELESS.md

> ⚠️ This is a **0.x pre-release** — not yet verified on real hardware.

# What's in this release

* **No RTC dependence.** All clock reads/writes are removed; the clock is a frozen software
  value you set manually. Fixes the Box 8 / save-corruption bug on RTC-less hardware.
* **MBC5 header** (`$0147` = `0x1b`, RAM + battery, no timer). Save format unchanged —
  existing `.sav` files work as-is.
* **Frozen manual clock.** Time-of-day, weekday, and the day counter are set via the in-game
  clock screen, reachable from **New Game**, by holding **Down + B** at the Suicune title
  screen, or by holding **SELECT + UP** on the Pokégear's Clock card. Daily events refresh
  when you advance the day.
* **Incoming phone calls** re-driven by the play-time counter so they still fire on a frozen
  clock.
* **Selected daily freebies made always-available** (weekday/time gates kept): berry trees,
  Move Tutor, Trainer House, haircut brothers, Buena's Password, Indigo rival rematch,
  Goldenrod bargain shop.

See [TIMELESS.md](https://github.com/erick-tmr/Pokemon_Crystal_Legacy_Timeless/blob/main/TIMELESS.md)
for the full event-by-event reference.

# Requirements

* You will need a **clean** copy of an English **base Crystal ROM**.
    * We **cannot tell you how or where to get this**, as it is illegal. But if you google it,
      you can quite easily find out.
    * Make sure the ROM is clean — no randomizers, no previous versions of Crystal Legacy or any
      other hack.

## Resources

* **Recommended Patching Tool:** https://www.marcrobledo.com/RomPatcher.js/
* Generic written guide for all platforms:
  https://www.pokecommunity.com/threads/how-to-play-rom-hacks.458595/

# Instructions

* Before you start, load your base Crystal ROM into the ROM patcher (or a hash checker) and
  check the **SHA-1 hash**. It must match the hash for your version below. If it doesn't, you
  have a modified or bootleg ROM and will need to find a real one.

* There are two patch files here, one for each version of base Crystal:
    * **`base Crystal V1.0 / Rev 0 / USA`** — SHA-1 `f4cd194bdee0d04ca4eac29e09b8e4e9d818c133`
      → use the patch in **`Version USA`**.
    * **`base Crystal V1.1 / Rev 1 / USA, Europe`** — SHA-1 `f2f52230b536214ef7c9924f483392993e226cfb`
      → use the patch in **`Version USA, Europe Rev 1`**.
* Patch your base Crystal ROM with the matching `.bps` file using patching software (see the
  recommendation below). The two base revisions play identically for Crystal Legacy Timeless, so
  just use whichever clean ROM you have.
* Alternate-language versions are **not** compatible — they will cause bugs.
* After patching, rename the output ROM to `Crystal Legacy Timeless` so you can tell it apart.

## After patching: setting the clock

Timeless has **no real-time clock** — time is a value you set and it stays frozen until you
change it. Set it from **New Game**, or any time after using one of these shortcuts:

* **Hold Down + B at the title screen** (the one showing Suicune leaping over the water,
  before the Continue / New Game menu) — same screen Mr. Pokémon uses to reset the clock.
* **Hold SELECT + UP on the Pokégear's Clock card** — opens the same clock-setting screen
  from inside the game, no need to back out to the title.

Time-based events advance when you advance the day from either shortcut. Full guide in
`TIMELESS.md`.

## PC Users
* Recommended emulator: https://mgba.io/downloads.html
* Recommended patching tool: https://www.marcrobledo.com/RomPatcher.js/

## Android Users
* Recommended emulator: My Boy / a GBC-capable emulator from the Play Store
* Recommended patching tool: https://www.marcrobledo.com/RomPatcher.js/

## iPhone Users
* Recommended emulator: Delta — https://apps.apple.com/app/delta-game-emulator/id1048524688
* Recommended patching tool: https://www.marcrobledo.com/RomPatcher.js/
    * When downloading the patch files, choose "Send to Files" to save them.
    * Tap the `.zip` in Files to extract it.
    * Load RomPatcher.js, load the base ROM and the `.bps` file — the download it returns is a
      `.gbc` that Delta will recognize.

---

Built from https://github.com/erick-tmr/Pokemon_Crystal_Legacy_Timeless — a fork of
Pokémon Crystal Legacy by TheSmithPlays / cRz Shadows.
