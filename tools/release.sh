#!/usr/bin/env bash
# tools/release.sh — Cut a Crystal Legacy Timeless release locally.
#
# Pipeline:
#   1. Bump semver from the latest v* tag (patch/minor/major)
#   2. Verify your local base Crystal ROMs (.baseroms/) match roms.sha1
#   3. Build pokecrystal.gbc and pokecrystal11.gbc via make
#   4. Generate .bps patches with flips against each base ROM
#   5. Bundle patches + README into a zip matching the v0.1.0 layout
#   6. Tag HEAD, push the tag, and create a GitHub release with the zip
#
# Requires: rgbds 0.5.2, flips, gh (authenticated), zip, sha1sum, awk
#
# Usage:
#   tools/release.sh <patch|minor|major> "<description>" [options]
#
# Options:
#   --prerelease            Mark the GitHub release as pre-release
#   --draft                 Create as a draft (does not publish)
#   --notes-file <path>     Use a file as the release body
#                           (default: description + auto-generated changelog)
#   --skip-build            Reuse existing pokecrystal*.gbc instead of rebuilding
#   -h, --help              Show this help

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

if [ $# -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage; exit 0
fi

BUMP="$1"; shift
case "$BUMP" in
  major|minor|patch) ;;
  *) echo "error: bump must be one of major, minor, patch" >&2; usage; exit 2 ;;
esac

if [ $# -lt 1 ]; then
  echo "error: description is required" >&2; usage; exit 2
fi
DESCRIPTION="$1"; shift

PRERELEASE=0
DRAFT=0
NOTES_FILE=""
SKIP_BUILD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prerelease) PRERELEASE=1; shift ;;
    --draft)      DRAFT=1; shift ;;
    --notes-file)
      [ $# -ge 2 ] || { echo "error: --notes-file needs a path" >&2; exit 2; }
      NOTES_FILE="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# -- preflight ----------------------------------------------------------------
for cmd in git make flips gh zip sha1sum awk sed; do
  command -v "$cmd" >/dev/null \
    || { echo "error: missing required tool: $cmd" >&2; exit 1; }
done

gh auth status >/dev/null 2>&1 \
  || { echo "error: gh is not authenticated. Run 'gh auth login'." >&2; exit 1; }

[ -f Makefile ] && [ -d .git ] \
  || { echo "error: must run from the project root" >&2; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is dirty — commit or stash first" >&2
  git status --short >&2
  exit 1
fi

BRANCH="$(git symbolic-ref --short -q HEAD || true)"
if [ -n "$BRANCH" ] \
   && git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null \
   && ! git merge-base --is-ancestor HEAD "origin/$BRANCH"; then
  echo "error: HEAD has commits not on origin/$BRANCH — push them first" >&2
  exit 1
fi

# -- base ROMs ---------------------------------------------------------------
BASE_DIR=".baseroms"
BASE_1_0="$BASE_DIR/baserom_usa_1_0.gbc"
BASE_1_1="$BASE_DIR/baserom_usa_1_1.gbc"

if [ ! -f "$BASE_1_0" ] || [ ! -f "$BASE_1_1" ]; then
  cat <<EOF >&2
error: missing base Crystal ROMs. Place clean copies at:
  $BASE_1_0  (USA 1.0;       SHA-1 f4cd194bdee0d04ca4eac29e09b8e4e9d818c133)
  $BASE_1_1  (USA / EU 1.1;  SHA-1 f2f52230b536214ef7c9924f483392993e226cfb)
The .baseroms/ folder is gitignored, so they stay local.
EOF
  exit 1
fi

EXPECTED_1_0="$(awk '/pokecrystal\.gbc$/   {print $1}' roms.sha1)"
EXPECTED_1_1="$(awk '/pokecrystal11\.gbc$/ {print $1}' roms.sha1)"
ACTUAL_1_0="$(sha1sum "$BASE_1_0"  | awk '{print $1}')"
ACTUAL_1_1="$(sha1sum "$BASE_1_1"  | awk '{print $1}')"
[ "$ACTUAL_1_0" = "$EXPECTED_1_0" ] \
  || { echo "error: $BASE_1_0 SHA-1 mismatch (got $ACTUAL_1_0, want $EXPECTED_1_0)" >&2; exit 1; }
[ "$ACTUAL_1_1" = "$EXPECTED_1_1" ] \
  || { echo "error: $BASE_1_1 SHA-1 mismatch (got $ACTUAL_1_1, want $EXPECTED_1_1)" >&2; exit 1; }

# -- version -----------------------------------------------------------------
LATEST="$(git tag -l 'v*.*.*' --sort=-v:refname | head -n1)"
LATEST="${LATEST:-v0.0.0}"
IFS='.' read -r M m p <<< "${LATEST#v}"
case "$BUMP" in
  major) M=$((M + 1)); m=0; p=0 ;;
  minor) m=$((m + 1)); p=0 ;;
  patch) p=$((p + 1)) ;;
esac
VERSION="v${M}.${m}.${p}"

if git rev-parse --verify --quiet "refs/tags/$VERSION" >/dev/null; then
  echo "error: tag $VERSION already exists" >&2; exit 1
fi

echo ">> Releasing $LATEST -> $VERSION  (HEAD: $(git rev-parse --short HEAD))"

# -- build -------------------------------------------------------------------
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo ">> Building ROMs (make tidy && make && make crystal11)"
  make tidy
  make
  make crystal11
fi

[ -f pokecrystal.gbc   ] || { echo "error: pokecrystal.gbc not produced"   >&2; exit 1; }
[ -f pokecrystal11.gbc ] || { echo "error: pokecrystal11.gbc not produced" >&2; exit 1; }

echo "   pokecrystal.gbc   sha1 $(sha1sum pokecrystal.gbc   | awk '{print $1}')"
echo "   pokecrystal11.gbc sha1 $(sha1sum pokecrystal11.gbc | awk '{print $1}')"

# -- stage assets ------------------------------------------------------------
STAGE="$(mktemp -d -t release.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

ROOT_NAME="Crystal Legacy Timeless $VERSION Patches"
ROOT="$STAGE/$ROOT_NAME"
mkdir -p \
  "$ROOT/Version USA" \
  "$ROOT/Version USA, Europe Rev 1" \
  "$ROOT/Patching Instructions"

echo ">> Generating .bps patches"
flips --create --bps-delta "$BASE_1_0" pokecrystal.gbc \
  "$ROOT/Version USA/Pokemon_Crystal_Legacy_Timeless_USA_1.0_Patch.bps" >/dev/null
flips --create --bps-delta "$BASE_1_1" pokecrystal11.gbc \
  "$ROOT/Version USA, Europe Rev 1/Pokemon_Crystal_Legacy_Timeless_USA_1.1_Patch.bps" >/dev/null

echo ">> Rendering patching README"
sed "s/{{VERSION}}/$VERSION/g" tools/release-readme.template.md \
  > "$ROOT/Patching Instructions/README.md"
cp "$ROOT/Patching Instructions/README.md" \
   "$ROOT/Patching Instructions/README.txt"

# -- zip --------------------------------------------------------------------
mkdir -p release
ZIP_NAME="Pokemon.Crystal.Legacy.Timeless.$VERSION.Patches.zip"
ZIP_PATH="$PROJECT_ROOT/release/$ZIP_NAME"
rm -f "$ZIP_PATH"
(cd "$STAGE" && zip -r "$ZIP_PATH" "$ROOT_NAME" >/dev/null)
echo ">> Built $ZIP_PATH"

# -- tag --------------------------------------------------------------------
echo ">> Tagging and pushing $VERSION"
git tag -a "$VERSION" -m "Release $VERSION

$DESCRIPTION"
git push origin "$VERSION"

# -- release notes ----------------------------------------------------------
NOTES_PATH="$STAGE/notes.md"
if [ -n "$NOTES_FILE" ]; then
  [ -f "$NOTES_FILE" ] || { echo "error: notes file not found: $NOTES_FILE" >&2; exit 1; }
  cp "$NOTES_FILE" "$NOTES_PATH"
else
  REPO_FULL="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  GEN_ARGS=(-f tag_name="$VERSION")
  if [ "$LATEST" != "v0.0.0" ] \
     && git rev-parse --verify --quiet "refs/tags/$LATEST" >/dev/null; then
    GEN_ARGS+=(-f previous_tag_name="$LATEST")
  fi
  {
    printf '%s\n\n' "$DESCRIPTION"
    gh api --method POST \
      -H "Accept: application/vnd.github+json" \
      "/repos/$REPO_FULL/releases/generate-notes" \
      "${GEN_ARGS[@]}" --jq .body
  } > "$NOTES_PATH"
fi

# -- create release ---------------------------------------------------------
RELEASE_FLAGS=(--title "$VERSION — $DESCRIPTION" --notes-file "$NOTES_PATH")
[ "$PRERELEASE" -eq 1 ] && RELEASE_FLAGS+=(--prerelease)
[ "$DRAFT"      -eq 1 ] && RELEASE_FLAGS+=(--draft)

echo ">> Creating GitHub release"
gh release create "$VERSION" "${RELEASE_FLAGS[@]}" "$ZIP_PATH"

echo ">> Done. Release $VERSION created."
