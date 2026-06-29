# Claude conventions for Pokémon Crystal Legacy Timeless

## Building

When building locally to test changes, default to the **USA/EU 1.1** variant:

    make crystal11

This produces `pokecrystal11.gbc` — our reference build. Plain `make` (the default `crystal` target) builds USA 1.0 as `pokecrystal.gbc`; only use it when you specifically need to compare against the 1.0 variant.

`tools/release.sh` must keep building both variants so the release zip ships a `.bps` patch for each base ROM — don't trim that.

## Releasing

`main` is protected (PR + green `build` check required). Never push release
artifacts straight to it — put **everything the release needs in the change PR**
so it all lands on `main` through the normal merge:

- the code/asset changes
- the title-screen version bump (`tools/bump_title_version.py X.Y.Z`)
- the matching `release-notes/vX.Y.Z.md` (user-facing bullets; summarize
  internal/tooling work as "General improvements")

After that PR merges, cut the release from an up-to-date `main` with
`tools/release.sh <patch|minor|major> "<description>"` — it tags `main`'s HEAD,
builds both ROMs, and publishes the GitHub release. Do **not** commit release
notes directly to `main`.
