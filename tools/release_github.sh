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

# The tag names origin/main, so origin/main must contain — exactly — what
# is about to be built. Three ways that can be false, and all three are
# now fatal on a real publish:
#
# `git status --porcelain`, not `git diff --quiet HEAD`: the latter does
# not see UNTRACKED files, and an untracked .dart file compiles into all
# four artifacts exactly like a modified one. This script itself was
# untracked while it was being written, and the note stayed silent.
#
# This was a NOTE, and a note is not a control. It prints before four
# multi-minute builds and has scrolled far off screen by the time
# `gh release create` runs. Uncommitted work is the same defect the
# ahead-of-origin check below already treats as fatal, only worse: an
# unpushed commit at least exists in a ref, whereas uncommitted bytes
# exist in no ref at all and nobody — including the owner, later — can
# rebuild that APK from the tag. Ruled 2026-09-06. There is deliberately
# no `--allow-dirty`: its only use would be publishing a Release nobody
# can reproduce, and the escape hatch is `git commit && git push`, which
# the next check demands anyway. --dry-run keeps the old note, because
# rehearsing the release path on a dirty tree is the normal way to work.
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "$DRY" = "1" ]]; then
    echo "  NOTE: working tree is dirty; these artifacts carry uncommitted"
    echo "  work. A real run refuses at this point."
  else
    echo "FATAL: working tree is dirty. Commit or stash first, or the tag" >&2
    echo "  will name source these artifacts were not built from." >&2
    exit 1
  fi
fi

# `origin/main..HEAD` was the wrong instrument for this, in two ways, and
# both were measured on throwaway repos:
#
#   * IT FAILS OPEN. With no origin/main ref at all (fresh clone of a
#     differently-named default branch, a detached worktree, a `git remote
#     remove` mid-session), `git log origin/main..HEAD` errors, `2>/dev/null`
#     swallows the message, the substitution is empty, and the guard PASSES.
#     Measured: a repo with no remote at all sails straight through it.
#   * IT IS BLIND TO BEING BEHIND. If origin/main has moved ahead of HEAD,
#     `origin/main..HEAD` is empty and the guard passes — but `gh release
#     create` below is called with no `--target`, so GitHub cuts the tag at
#     the DEFAULT BRANCH tip. The tag would then name newer source than the
#     artifacts were built from: the same mismatch, pointing the other way.
#
# SeekSparks' `tools/release_github.sh:64` uses `merge-base --is-ancestor`
# and fails closed on the first of those, so the first is a regression
# against a sibling that already had it right. It does not catch the
# second — it tags an explicit commit instead, a design this script does
# not share — so requiring equality is the check that covers both.
git rev-parse -q --verify origin/main >/dev/null || {
  echo "FATAL: no origin/main ref. Run 'git fetch origin' — do not skip" >&2
  echo "  this check; the tag is cut against origin/main." >&2
  exit 1; }
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "FATAL: HEAD is not on origin/main — push first, or the tag will" >&2
  echo "  name a commit GitHub cannot serve." >&2
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "FATAL: HEAD is behind origin/main. The tag would be cut at" >&2
  echo "  $(git rev-parse --short origin/main) while these artifacts are built from" >&2
  echo "  $(git rev-parse --short HEAD). Pull first." >&2
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
#
# ANCHORED, not `grep -F`. `-F "1.2.6"` is a SUBSTRING test, so a build
# stamped 1.2.60, 1.2.61, 1.2.65, 11.2.6 or 21.2.6 all satisfy it and
# publish as v1.2.6 — measured, all five pass -F and all five are
# rejected here. The version must not be flanked by another digit or a
# dot; `+`, `"`, `v` and whitespace are all still fine, so `1.2.6+16`
# and `v1.2.6` match as they must. Checked for false negatives against
# every real artifact of this release — three APK ABIs, main.dart.js,
# index.html, and both App.framework binaries — all seven still pass.
VERSION_RE="(^|[^0-9.])$(printf '%s' "$VERSION" | sed 's/\./\\./g')([^0-9.]|$)"
carries_version() {
  grep -qE "$VERSION_RE" <(strings -a "$1" 2>/dev/null)
}

# ── Verify the SHIPPED file, not the thing it was made from ───────────
# Every check in this script used to run against the build tree and then
# hand the bytes to `zip`, so nothing in $OUT was ever re-opened. Three
# separate holes followed from that, and all three are closed below.
#
# 1. `zip -qr` into an EXISTING archive MERGES; it does not replace. A
#    file deleted from the source tree since the last build stays in the
#    archive and ships, having never been checked. Reproduced: an asset
#    removed between two builds is still listed in the re-zipped archive.
#    So every archive is deleted before it is written.
# 2. Nothing asserted the artifact was even non-empty. A 0-byte file
#    prints "0.0" in the size banner and passes. The smallest real artifact
#    of this release is the iOS zip at 21,624,861 bytes, so a 1 MiB floor
#    sits ~20x below anything legitimate and can only catch a truncated
#    or absent build.
# 3. The archive was never opened, so a corrupt one would publish.
MIN_BYTES=1048576

# Delete first, then write. The subshell `cd` is the caller's business.
drop_stale_archive() { rm -f "$1"; }

# $1 archive, $2 member path inside it, $3 human label.
# `unzip -p` to a file, not down a pipe: `set -o pipefail` is on and this
# is the same SIGPIPE trap documented above `carries_version`.
verify_artifact() {
  local file="$1" member="$2" label="$3" size tmp
  [[ -f "$file" ]] || { echo "FATAL: $label was not written to \$OUT" >&2; exit 1; }
  size="$(stat -f%z "$file")"
  [[ "$size" -ge "$MIN_BYTES" ]] || {
    echo "FATAL: $label is only $size bytes — the build is truncated or empty." >&2
    exit 1; }
  unzip -tqq "$file" >/dev/null 2>&1 || {
    echo "FATAL: $label is not a readable archive." >&2; exit 1; }
  tmp="$(mktemp -t yw_verify)"
  unzip -p "$file" "$member" > "$tmp" 2>/dev/null || {
    echo "FATAL: $label does not contain $member." >&2; rm -f "$tmp"; exit 1; }
  [[ -s "$tmp" ]] || {
    echo "FATAL: $member is empty inside $label." >&2; rm -f "$tmp"; exit 1; }
  carries_version "$tmp" || {
    echo "FATAL: the SHIPPED $label does not carry $VERSION." >&2
    echo "  ($member was checked; the build lost its --dart-define.)" >&2
    rm -f "$tmp"; exit 1; }
  rm -f "$tmp"
  echo "    verified in the shipped file: $member carries $VERSION"
}

echo "==> web"
# release_web.sh now proves main.dart.js and the splash BOTH carry the
# version before it will exit 0 — the same anchored matcher as here — so
# the three checks that used to sit at this spot were doing that job
# twice. What was NOT being done is checking the zip, which is what
# actually gets uploaded, so that is what happens below instead.
tools/release_web.sh --build
drop_stale_archive "$OUT/NewsInsight-Web.zip"
( cd build/web && zip -qr "$OUT/NewsInsight-Web.zip" . )
verify_artifact "$OUT/NewsInsight-Web.zip" "main.dart.js" "the Web zip"

echo "==> android"
"$FLUTTER" build apk --release "${DEFINES[@]}"
APK="build/app/outputs/flutter-apk/app-release.apk"
# Copy FIRST, then check the copy. The APK that gets uploaded is the one
# in $OUT, and it was previously only ever checked in its build-tree form.
drop_stale_archive "$OUT/NewsInsight-Android.apk"
cp "$APK" "$OUT/NewsInsight-Android.apk"
APK_OUT="$OUT/NewsInsight-Android.apk"
[[ "$(stat -f%z "$APK_OUT")" -ge "$MIN_BYTES" ]] || {
  echo "FATAL: the copied APK is truncated or empty." >&2; exit 1; }
unzip -tqq "$APK_OUT" >/dev/null 2>&1 || {
  echo "FATAL: the copied APK is not a readable archive." >&2; exit 1; }

# CLEAN THE EXTRACTION DIR FIRST. It was never removed before extraction,
# only after, so a run that crashed anywhere between the two left a full
# set of ABI directories behind. The next run's `unzip -o` overwrites only
# the ABIs the new APK actually contains, and the loop below then counts
# the leftovers as though they came out of this build. Reproduced with
# this repo's own binaries: a ONE-ABI APK, extracted over a stale
# three-ABI directory, prints "all 3 ABIs carry 1.2.6" and exits 0 — two
# of the three files it read were never in the APK being shipped.
rm -rf "$OUT/_apkcheck"
unzip -o -q "$APK_OUT" 'lib/*/libapp.so' -d "$OUT/_apkcheck"

# Cross-check the count against what the shipped APK itself lists, so the
# number in the line below is a fact about this APK rather than about
# whatever happens to be on disk.
expected="$(unzip -l "$APK_OUT" 'lib/*/libapp.so' | grep -c 'libapp\.so$' || true)"

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
[[ "$total" -eq "$expected" ]] || {
  echo "FATAL: checked $total libapp.so but the APK lists $expected." >&2
  echo "  Stale files in $OUT/_apkcheck would make this claim false." >&2
  exit 1; }
[[ -z "$missing" ]] || {
  echo "FATAL: these ABIs in the APK do not carry $VERSION:$missing" >&2
  echo "  The build lost its --dart-define and would ship calling" >&2
  echo "  itself 'dev'." >&2
  exit 1; }
echo "    all $total ABIs of the shipped APK carry $VERSION"
rm -rf "$OUT/_apkcheck"

echo "==> macos"
"$FLUTTER" build macos --release "${DEFINES[@]}"
MAC_APP="build/macos/Build/Products/Release/yahwehs_world.app"
drop_stale_archive "$OUT/NewsInsight-macOS.zip"
( cd "$(dirname "$MAC_APP")" && zip -qry "$OUT/NewsInsight-macOS.zip" "$(basename "$MAC_APP")" )
# `Versions/A/App`, NOT `App.framework/App`. On disk the latter resolves,
# which is why the old pre-zip check worked; inside the archive `zip -y`
# has stored it as what it is — a 20-byte symlink reading
# "Versions/Current/App". Verifying that member would `strings` twenty
# bytes of text and fail every time. Measured on this release's macOS zip.
# The real binary is 9,579,520 bytes and carries the version four times,
# because it is a universal binary with an x86_64 and an arm64 slice.
verify_artifact "$OUT/NewsInsight-macOS.zip" \
  "yahwehs_world.app/Contents/Frameworks/App.framework/Versions/A/App" \
  "the macOS zip"

echo "==> ios"
"$FLUTTER" build ios --release --no-codesign "${DEFINES[@]}"
IOS_APP="build/ios/iphoneos/Runner.app"
drop_stale_archive "$OUT/NewsInsight-iOS.zip"
( cd "$(dirname "$IOS_APP")" && zip -qry "$OUT/NewsInsight-iOS.zip" "$(basename "$IOS_APP")" )
# iOS frameworks are flat — no Versions/ — so here App IS the binary.
verify_artifact "$OUT/NewsInsight-iOS.zip" \
  "Runner.app/Frameworks/App.framework/App" "the iOS zip"

echo
echo "==> $TAG — four artifacts, each verified to carry $VERSION"
# The four names, spelled out, NOT `ls -la "$OUT"`. That listed whatever
# was in the directory: a crashed run's leftovers and the _apkcheck dir
# were both observed printing under a banner that says "four artifacts,
# each verified" — six lines, two of them files this script never made
# and never checked. It also took `$NF` from `ls -la`, which is the wrong
# field the moment a filename contains a space.
#
# MiB, not MB, and the divisor is the one that was already right: `ls -lh`
# and `du -h` on this Mac and GitHub's own asset list are all 1024-based,
# so these figures match every surface the operator will compare them
# against. Only the label was wrong. (Decimal MB would read 62.4 / 31.7 /
# 28.9 / 21.6 for this release and would agree with nothing but Finder.)
for f in NewsInsight-Android.apk NewsInsight-iOS.zip \
         NewsInsight-macOS.zip NewsInsight-Web.zip; do
  awk -v n="$f" -v s="$(stat -f%z "$OUT/$f")" \
    'BEGIN {printf "    %-32s %6.1f MiB\n", n, s/1048576}'
done

if [[ "$DRY" = "1" ]]; then
  echo
  echo "DRY RUN — built and verified, nothing published."
  exit 0
fi

gh release create "$TAG" \
  --title "$TAG" \
  --notes "News Insight $VERSION — built $RELEASE_TIME" \
  "$OUT/NewsInsight-Android.apk" \
  "$OUT/NewsInsight-iOS.zip" \
  "$OUT/NewsInsight-macOS.zip" \
  "$OUT/NewsInsight-Web.zip"

echo
echo "Published $TAG. The portal's releases/latest buttons now serve it."
