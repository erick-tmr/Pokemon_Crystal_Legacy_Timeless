# Claude conventions for Pokémon Crystal Legacy Timeless

## Building

When building locally to test changes, default to the **USA/EU 1.1** variant:

    make crystal11

This produces `pokecrystal11.gbc` — our reference build. Plain `make` (the default `crystal` target) builds USA 1.0 as `pokecrystal.gbc`; only use it when you specifically need to compare against the 1.0 variant.

`tools/release.sh` must keep building both variants so the release zip ships a `.bps` patch for each base ROM — don't trim that.
