#!/usr/bin/env bash
# 2026-09-05: build the four native artifacts and publish them as a
# GitHub Release, so the portal's download buttons stop serving an old
# version.
#
#   tools/release_github.sh            # build, verify, publish
#   tools/release_github.sh --dry-run  # build and verify, publish nothing
#
# ── Why this is NOT the script the other two apps use ─────────────────
# YsWords and Yahweh's Sword each ship `tools/release_github.sh` too,
# and both are one-liners in effect: they push a `v*` tag and five
# `.github/workflows/release-*.yml` do the building. Neither shape works
# here, and copying either would have made things worse rather than
# better:
#
#   * THIS REPO HAS NO WORKFLOWS AT ALL — no `.github` directory. A tag
#     would create a Release with no assets attached, and the portal's
#     buttons point at `releases/latest`, so downloads would go from
#     "two versions stale" to "nothing there".
#   * Their green-CI gate looks up a workflow named "Flutter CI". There
#     is no CI here to look up, so that guard would silently pass on a
#     repo where nothing had been tested.
#
# So this one builds locally and uploads, which is what
# `docs/OPEN-ITEMS.md` said the fix was, and substitutes a local
# `analyze` + `test` for the CI gate it cannot have.
#
# ── The hazard this repo actually has ─────────────────────────────────
# `kAppVersion` here is `String.fromEnvironment('APP_VERSION',
# defaultValue: 'dev')` — deliberately, because a hard-coded literal
# went stale and "the app on a phone claimed to be v1.1.6 for months".
# The consequence is that the version exists ONLY if every build is
# passed `--dart-define`. Miss it on one leg and that artifact ships
# calling itself `dev`, while the Release beside it says 1.2.6.
#
# The other apps guard the mirror image of this — their two version
# sources must agree — and that guard is meaningless here. So instead
# every built artifact is opened and checked for the version string
# before anything is uploaded. A build that cannot prove its version is
# not published.
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"

DRY=0
# Both sibling scripts parse with a loop and reject anything they do not
# recognise, and that is not decoration. This was `[[ "${1:-}" ==
# "--dry-run" ]] && DRY=1`, which silently leaves DRY=0 for `--dryrun`,
# `--dry`, `-n` or any other near-miss — i.e. a typo in the flag whose
# entire purpose is "publish nothing" makes the script PUBLISH. Measured:
# the old form exits 0 with DRY=0 on `--dryrun` and says nothing.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2
       echo "usage: tools/release_github.sh [--dry-run]" >&2
       exit 2 ;;
  esac
done

VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
VERSION="${VERSION%%+*}"
TAG="v$VERSION"
RELEASE_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DEFINES=(--dart-define="APP_VERSION=$VERSION"
         --dart-define="APP_RELEASE_TIME=$RELEASE_TIME")

[[ -n "$VERSION" ]] || { echo "FATAL: no version in pubspec.yaml" >&2; exit 1; }

# Fetch FIRST. SeekSparks fetches before it looks the tag up; this
# script had the two the other way round, so the local ref it consulted
# could be stale. The `ls-remote` half also fails open — no network means
# a non-zero exit, which reads here as "the tag does not exist" — so the
# local half is the one that has to be looking at fresh refs.
git fetch --quiet origin

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
   || git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "FATAL: $TAG already exists. Bump the version first." >&2
  exit 1
fi

# The tag will name origin/main, so main must actually contain what is
# about to be built. A dirty tree is allowed — this script is run by
# hand — but it is said out loud, because the artifacts will carry the
# working tree and the tag will not.
#
# `git status --porcelain`, not `git diff --quiet HEAD`: the latter does
# not see UNTRACKED files, and an untracked .dart file compiles into all
# four artifacts exactly like a modified one. This script itself was
# untracked while it was being written, and the note stayed silent.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "  NOTE: working tree is dirty; artifacts will include uncommitted work"
fi
if [[ -n "$(git log --oneline origin/main..HEAD 2>/dev/null)" ]]; then
  echo "FATAL: HEAD is ahead of origin/main — push first, or the tag will" >&2
  echo "  name a commit GitHub cannot serve." >&2
  exit 1
fi

# Check the credential BEFORE the builds, not after. The only `gh` call
# is the very last line, so an unauthenticated shell would run analyze,
# test and all four platform builds — the slow part of this script by a
# wide margin — only to fail at the upload with everything already built.
# Skipped on --dry-run, which never calls gh. Nothing is printed either
# way: `gh auth status` goes to /dev/null, so no token can reach a log.
if [[ "$DRY" = "0" ]]; then
  gh auth status >/dev/null 2>&1 || {
    echo "FATAL: gh is not authenticated, so the upload at the end would" >&2
    echo "  fail after every build has already run. Run: gh auth login" >&2
    exit 1; }
fi

# Stands in for the green-CI gate the other two repos have. Nothing
# downstream of this script runs the suite, so this is the last point a
# broken build can be stopped before it is a download.
echo "==> analyze + test (there is no CI in this repo)"
"$FLUTTER" analyze
"$FLUTTER" test

OUT="$PROJECT/build/release-$VERSION"
mkdir -p "$OUT"

# Returns 0 if $1 contains the version string somewhere. Binaries are
# searched with `strings` because the constant is compiled into the AOT
# snapshot, not stored as a file.
#
# PROCESS SUBSTITUTION, NOT A PIPE, and that is the whole point of this
# comment. `set -o pipefail` is on. Written as `strings … | grep -q …`
# the pipeline returns **141** (128 + SIGPIPE) on a SUCCESSFUL match:
# grep stops reading at the first hit, `strings` dies on the closed pipe,
# and pipefail takes the status from that. Re-measured 2026-09-05 on this
# repo's own 1.2.6 APK — arm64-v8a, armeabi-v7a and x86_64 each carry the
# version twice over, and `strings -a … | grep -qF` returned 141 on all
# three, i.e. the check reported a lost --dart-define on a build that had
# it.
#
# Dropping `-q` does avoid the 141 — measured 0 on all three ABIs, since
# grep then reads to EOF and never closes the pipe early. An earlier
# revision of this comment claimed otherwise; it was wrong. It is still
# the worse fix: it drags every byte of a ~4 MB AOT snapshot through grep
# to answer a boolean, and it leaves the trap armed for whoever later
# re-adds `-q` or appends `| head`. Feeding grep from `<(...)` keeps
# `strings` out of the pipeline status altogether, so the answer does not
# depend on how grep happens to read.
carries_version() {
  grep -qF "$VERSION" <(strings -a "$1" 2>/dev/null)
}

echo "==> web"
tools/release_web.sh --build
# Named files, NOT `grep -r build/web`. The recursive form was decorative:
# of the three files under build/web that contain the version, TWO are
# derived from pubspec.yaml and cannot fail — `version.json` is emitted by
# the web tool straight from pubspec, and index.html's copy is substituted
# by release_web.sh from its own pubspec read. Neither has any connection
# to --dart-define. Measured: `grep -rqF "$VERSION" build/web
# --exclude=main.dart.js` still passes, so the guard was satisfied without
# a single byte of Dart evidence. main.dart.js is the only file whose copy
# proves APP_VERSION actually reached the compiler.
[[ -f build/web/main.dart.js ]] \
  || { echo "FATAL: build/web/main.dart.js is missing; the web build's" >&2
       echo "  version cannot be proved." >&2; exit 1; }
grep -qF "$VERSION" build/web/main.dart.js \
  || { echo "FATAL: build/web/main.dart.js does not carry $VERSION — the" >&2
       echo "  web build lost its --dart-define." >&2; exit 1; }
grep -qF "$VERSION" build/web/index.html \
  || { echo "FATAL: the boot splash was not stamped with $VERSION." >&2
       exit 1; }
( cd build/web && zip -qr "$OUT/YahwehsWorld-Web.zip" . )

echo "==> android"
"$FLUTTER" build apk --release "${DEFINES[@]}"
APK="build/app/outputs/flutter-apk/app-release.apk"
unzip -o -q "$APK" 'lib/*/libapp.so' -d "$OUT/_apkcheck"
# EVERY ABI must carry it, not just one. This was `found=1` on the first
# hit, which passes a fat APK where arm64 is fine and armeabi-v7a shipped
# as 'dev' — and armeabi-v7a is the one an older phone installs. Arrays
# are avoided deliberately: /bin/bash here is 3.2, where expanding an
# empty array under `set -u` is itself an error.
total=0
missing=""
for so in "$OUT/_apkcheck"/lib/*/libapp.so; do
  [[ -f "$so" ]] || continue          # unmatched glob stays literal
  total=$((total + 1))
  carries_version "$so" || missing="$missing $(basename "$(dirname "$so")")"
done
[[ "$total" -ge 1 ]] || {
  echo "FATAL: no libapp.so came out of the APK, so nothing was checked." >&2
  exit 1; }
[[ -z "$missing" ]] || {
  echo "FATAL: these ABIs in the APK do not carry $VERSION:$missing" >&2
  echo "  The build lost its --dart-define and would ship calling" >&2
  echo "  itself 'dev'." >&2
  exit 1; }
echo "    all $total ABIs carry $VERSION"
rm -rf "$OUT/_apkcheck"
cp "$APK" "$OUT/YahwehsWorld-Android.apk"

echo "==> macos"
"$FLUTTER" build macos --release "${DEFINES[@]}"
MAC_APP="build/macos/Build/Products/Release/yahwehs_world.app"
carries_version "$MAC_APP/Contents/Frameworks/App.framework/App" \
  || { echo "FATAL: the macOS build does not carry $VERSION" >&2; exit 1; }
( cd "$(dirname "$MAC_APP")" && zip -qry "$OUT/YahwehsWorld-macOS.zip" "$(basename "$MAC_APP")" )

echo "==> ios"
"$FLUTTER" build ios --release --no-codesign "${DEFINES[@]}"
IOS_APP="build/ios/iphoneos/Runner.app"
carries_version "$IOS_APP/Frameworks/App.framework/App" \
  || { echo "FATAL: the iOS build does not carry $VERSION" >&2; exit 1; }
( cd "$(dirname "$IOS_APP")" && zip -qry "$OUT/YahwehsWorld-iOS.zip" "$(basename "$IOS_APP")" )

echo
echo "==> $TAG — four artifacts, each verified to carry $VERSION"
ls -la "$OUT" | awk 'NR>1 && $NF !~ /^\.\.?$/ {printf "    %-32s %6.1f MB\n", $NF, $5/1048576}'

if [[ "$DRY" = "1" ]]; then
  echo
  echo "DRY RUN — built and verified, nothing published."
  exit 0
fi

gh release create "$TAG" \
  --title "$TAG" \
  --notes "Yahweh's World $VERSION — built $RELEASE_TIME" \
  "$OUT/YahwehsWorld-Android.apk" \
  "$OUT/YahwehsWorld-iOS.zip" \
  "$OUT/YahwehsWorld-macOS.zip" \
  "$OUT/YahwehsWorld-Web.zip"

echo
echo "Published $TAG. The portal's releases/latest buttons now serve it."
