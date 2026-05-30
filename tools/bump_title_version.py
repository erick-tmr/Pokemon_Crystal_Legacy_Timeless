#!/usr/bin/env python3
"""bump_title_version.py - stamp the version number onto the title screen.

The title screen's copyright line ("©2026 SPP & ETM Vx.y.z") is baked into the
graphic gfx/title/logo.png (decompressed at run time by engine/movie/title.asm).
This tool re-renders just the "Vx.y.z" part of that line using an embedded pixel
font that matches the existing glyphs, so the version can be bumped before each
release without hand-editing pixels.

Only gfx/title/logo.png is tracked in git; the build regenerates logo.2bpp /
logo.2bpp.lz from it (they are .gitignore'd), so a version-bump change is just the
PNG plus the matching comment in engine/movie/title.asm.

Fail-closed: after writing the PNG it is read back and the version region is
compared against what we intended to draw; nothing is trusted blindly.

Usage:
    # edit the working tree (then `make crystal11` and review):
    python3 tools/bump_title_version.py 1.0.0

    # edit, commit on a fresh branch off origin/main, push, and open a PR
    # (requires a clean working tree so the PR contains only the bump):
    python3 tools/bump_title_version.py 1.0.0 --pr

Limitation: each of MAJOR.MINOR.PATCH must be a single digit (0-9). The copyright
line is centered for that width; a multi-digit component needs the title art
widened by hand. The tool refuses rather than silently clip.
"""

import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import png  # tools/png.py (bundled pypng)

LOGO = os.path.join(ROOT, "gfx", "title", "logo.png")
TITLE_ASM = os.path.join(ROOT, "engine", "movie", "title.asm")

# Pixel values in the title font (rgbgfx maps them to palette 7, idx = 3 - value):
#   1 = white glyph body (palette idx 2, white)
#   2 = gray edge/corner accent (palette idx 1, dark gray) — the shaded look
#   3 = field / hole (palette idx 0, black)
INK, GRAY, FIELD = 1, 2, 3

# Geometry of the version string inside logo.png, established from the shipped art.
GLYPH_TOP = 57          # top row of the 5px-tall glyphs
VERSION_X = 92          # left edge of the leading "V"
GAP = 1                 # blank columns between glyphs
CLEAR_BOX = (92, 56, 128, 64)  # x0, y0, x1, y1 (exclusive) wiped before drawing
STRIP_RIGHT = 127       # last column of the 16-tile copyright strip

# 5px-tall font. "#" = white body, "+" = gray accent, "." = field. Glyph width is
# the string length, so the period is naturally narrower than the digits. "V" and
# "0" are taken from the shipped art (note the gray pixels that give the shaded
# look); the rest match its blocky style with the same gray corner-rounding.
FONT = {
    "V": ["##.##", "##.##", "##+##", ".###.", "..#.."],
    ".": ["..", "..", "..", "##", "##"],
    "0": ["+###+", "##.##", "##.##", "##.##", "+###+"],
    "1": [".+#..", "+##..", ".##..", ".##..", "+###+"],
    "2": ["+###+", "...##", "#####", "##...", "+###+"],
    "3": ["+###+", "...##", "#####", "...##", "+###+"],
    "4": ["+#.#+", "##.##", "#####", "...##", "...#+"],
    "5": ["+###+", "##...", "#####", "...##", "+###+"],
    "6": ["+###+", "##...", "#####", "##.##", "+###+"],
    "7": ["+###+", "...##", "..##.", ".##..", ".##.."],
    "8": ["+###+", "##.##", "#####", "##.##", "+###+"],
    "9": ["+###+", "##.##", "#####", "...##", "+###+"],
}


def load_logo(path):
    w, h, rows, info = png.Reader(filename=path).read()
    if not (info.get("greyscale") and info.get("bitdepth") == 2):
        sys.exit("error: %s is not a 2-bit greyscale PNG (got %r)" % (path, info))
    return w, h, [list(r) for r in rows]


def save_logo(path, w, h, px):
    with open(path, "wb") as f:
        png.Writer(width=w, height=h, greyscale=True, bitdepth=2).write(f, px)


def glyph_runs(version):
    """Return [(glyph, x), ...] laid out left to right, plus the right edge."""
    major, minor, patch = version.split(".")
    glyphs = ["V", major, ".", minor, ".", patch]
    runs, x = [], VERSION_X
    for g in glyphs:
        runs.append((g, x))
        x += len(FONT[g][0]) + GAP
    return runs, x - GAP - 1  # last occupied column


def stamp(px, version):
    x0, y0, x1, y1 = CLEAR_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[y][x] = FIELD
    runs, _ = glyph_runs(version)
    pen = {"#": INK, "+": GRAY}
    for g, gx in runs:
        for dy, line in enumerate(FONT[g]):
            for dx, ch in enumerate(line):
                if ch in pen:
                    px[GLYPH_TOP + dy][gx + dx] = pen[ch]


def verify(path, version):
    """Re-read the PNG and confirm the version region matches what we drew."""
    w, h, px = load_logo(path)
    expected = [[FIELD] * w for _ in range(h)]
    stamp(expected, version)
    x0, y0, x1, y1 = CLEAR_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[y][x] != expected[y][x]:
                sys.exit("error: verification failed at (%d,%d)" % (x, y))


def parse_version(s):
    s = s.lstrip("vV")
    m = re.fullmatch(r"(\d)\.(\d)\.(\d)", s)
    if not m:
        sys.exit(
            "error: version must be MAJOR.MINOR.PATCH with single digits, e.g. 1.0.0\n"
            "       (multi-digit components need the title art widened by hand)"
        )
    return s


def current_version():
    try:
        txt = open(TITLE_ASM).read()
    except OSError:
        return None
    m = re.search(r"V(\d+\.\d+\.\d+)", txt)
    return m.group(1) if m else None


def update_comment(version):
    txt = open(TITLE_ASM).read()
    new = re.sub(r'(ETM )V\d+\.\d+\.\d+', r"\g<1>V" + version, txt)
    if new != txt:
        open(TITLE_ASM, "w").write(new)
        return True
    return False


def git(*args, capture=False):
    kw = dict(cwd=ROOT, check=True)
    if capture:
        kw["text"] = True
        kw["stdout"] = subprocess.PIPE
    return subprocess.run(["git", *args], **kw)


def open_pr(version, old):
    if git("status", "--porcelain", "--untracked-files=no", capture=True).stdout.strip():
        sys.exit(
            "error: --pr needs a clean working tree (no modified tracked files) so the\n"
            "       PR contains only the version bump. Commit or stash other changes first."
        )
    branch = "chore/title-version-v%s" % version
    git("fetch", "origin")
    git("switch", "-c", branch, "origin/main")
    do_edit(version)  # render on the fresh branch
    git("add", "gfx/title/logo.png", "engine/movie/title.asm")
    title = "chore(title): bump title screen version to v%s" % version
    body = (
        "Re-renders the `Vx.y.z` text on the title-screen copyright line via "
        "`tools/bump_title_version.py`.\n\n"
        "- %s\n- only `gfx/title/logo.png` changes (the `.2bpp`/`.lz` are "
        "regenerated by the build)\n" % (
            "v%s -> v%s" % (old, version) if old else "set to v%s" % version
        )
    )
    git("commit", "-m", title, "-m", body)
    git("push", "-u", "origin", branch)
    subprocess.run(
        ["gh", "pr", "create",
         "--repo", "erick-tmr/Pokemon_Crystal_Legacy_Timeless",
         "--base", "main", "--head", branch,
         "--title", title, "--body", body],
        cwd=ROOT, check=True,
    )


def do_edit(version):
    w, h, px = load_logo(LOGO)
    _, right = glyph_runs(version)
    if right > STRIP_RIGHT:
        sys.exit("error: rendered version reaches column %d, past the copyright "
                 "strip (%d)" % (right, STRIP_RIGHT))
    stamp(px, version)
    save_logo(LOGO, w, h, px)
    verify(LOGO, version)
    update_comment(version)


def main():
    ap = argparse.ArgumentParser(description="Bump the title-screen version number.")
    ap.add_argument("version", help="new version, e.g. 1.0.0")
    ap.add_argument("--pr", action="store_true",
                    help="commit on a fresh branch off origin/main and open a PR")
    args = ap.parse_args()

    version = parse_version(args.version)
    old = current_version()

    if args.pr:
        open_pr(version, old)
        print("Opened PR for v%s." % version)
    else:
        do_edit(version)
        bump = "v%s -> v%s" % (old, version) if old else "set to v%s" % version
        print("Title screen version %s." % bump)
        print("gfx/title/logo.png and engine/movie/title.asm updated.")
        print("Run `make crystal11` and check the title screen, then commit.")


if __name__ == "__main__":
    main()
