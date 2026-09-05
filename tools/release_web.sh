#!/usr/bin/env bash
# Build + deploy Yahweh's World.
#
# Exists because the version and build time now appear in two places
# that a plain `flutter build web` cannot fill in:
#
#   * the Dart side, via --dart-define (feed header)
#   * web/index.html's boot splash, which paints BEFORE Dart runs and so
#     cannot read a Dart constant — its __APP_VERSION__ token is
#     substituted into the built copy here
#
# Both are stamped from pubspec.yaml, so there is one source of truth
# and no chance of the splash and the header disagreeing.
#
# Usage:  tools/release_web.sh            # build + deploy to prod
#         tools/release_web.sh --build    # build only
set -euo pipefail

cd "$(dirname "$0")/.."

# Parse with a loop that REJECTS what it does not recognise. This was
# `[[ "${1:-}" == "--build" ]]`, and the default branch of that test is
# "deploy to production" — so every near-miss shipped. Measured against a
# stubbed netlify: `--dry-run`, `--build-only`, `--biuld`, `-b` and
# `--definitely-not-a-flag` ALL exited 0 having called
# `netlify deploy --prod`. Only the exact string `--build` did not. There
# is one web site and it is production, so a typo here is a live deploy.
# release_github.sh:54 was given this same shape on 2026-09-05; this is
# the script that actually runs daily, and it was left behind.
BUILD_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD_ONLY=1; shift ;;
    *) echo "unknown argument: $1" >&2
       echo "usage: tools/release_web.sh [--build]" >&2
       exit 2 ;;
  esac
done

FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
NETLIFY="${NETLIFY:-$HOME/Documents/CodingProject/SmartHome/node_modules/.bin/netlify}"
SITE_ID="410313ea-f47e-4cda-872a-fa857581993d"

# One awk, not `grep | head -1 | sed | cut`. That four-stage pipeline runs
# under the `set -o pipefail` above, and `head -1` closes the pipe the
# moment it has its line — so `grep` can die of SIGPIPE and pipefail then
# takes 141 as the status of the whole substitution. It happens to survive
# today only because one short `version:` line fits in the pipe buffer
# before head exits; the identical shape with more to write measures 141.
# The same trap cost real time in release_github.sh's `carries_version`.
# awk with `exit` reads a FILE, so there is no pipe and nothing to race.
# This is also the exact form release_github.sh:63 uses, so the two
# scripts can no longer disagree about what the version is.
APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
APP_VERSION="${APP_VERSION%%+*}"
APP_RELEASE_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "==> building v$APP_VERSION ($APP_RELEASE_TIME)"
"$FLUTTER" build web --release \
  --dart-define="APP_VERSION=$APP_VERSION" \
  --dart-define="APP_RELEASE_TIME=$APP_RELEASE_TIME"

# The splash is static HTML — substitute in the built output only, so
# the checked-in source keeps its placeholder and stays diff-clean.
if grep -q '__APP_VERSION__' build/web/index.html; then
  # BSD sed (macOS) needs the empty -i argument.
  sed -i '' "s/__APP_VERSION__/$APP_VERSION/g" build/web/index.html
  echo "==> stamped splash with v$APP_VERSION"
else
  echo "!!  __APP_VERSION__ token missing from build/web/index.html" >&2
  echo "!!  the splash would show the literal placeholder — aborting" >&2
  exit 1
fi

# The splash now says v1.2.6. Nothing yet has asked whether the DART side
# does, and those are two independent substitutions: the sed above reads
# pubspec, while `kAppVersion` exists only if --dart-define reached the
# compiler. Reproduced on a stub build: index.html rendered `v1.2.6` over a
# main.dart.js whose kAppVersion was `dev`, and this script exited 0 and
# deployed it. That is exactly the split-brain release_github.sh's header
# describes at length — and this is the script that ships it daily, so the
# check belongs here, not only there.
#
# main.dart.js and NOT `grep -r build/web`: of the three files under
# build/web carrying the version, version.json is emitted straight from
# pubspec and index.html was just substituted from this script's own
# pubspec read. Neither has any connection to --dart-define. main.dart.js
# is the only one whose copy proves APP_VERSION reached the compiler.
#
# Anchored, not `grep -F`: a plain substring test passes a build stamped
# 1.2.60 or 11.2.6 as 1.2.6. Same matcher as release_github.sh's
# `carries_version`, so the two scripts cannot disagree about what
# "carries the version" means.
VERSION_RE="(^|[^0-9.])$(printf '%s' "$APP_VERSION" | sed 's/\./\\./g')([^0-9.]|$)"
[[ -f build/web/main.dart.js ]] \
  || { echo "!!  build/web/main.dart.js is missing; the build's version" >&2
       echo "!!  cannot be proved — aborting" >&2; exit 1; }
grep -qE "$VERSION_RE" build/web/main.dart.js \
  || { echo "!!  build/web/main.dart.js does not carry $APP_VERSION — the" >&2
       echo "!!  build lost its --dart-define and the header would read" >&2
       echo "!!  'dev' under a splash saying v$APP_VERSION. Aborting." >&2
       exit 1; }
grep -qE "$VERSION_RE" build/web/index.html \
  || { echo "!!  the boot splash was not stamped with $APP_VERSION" >&2
       exit 1; }
echo "==> verified: splash and main.dart.js both carry $APP_VERSION"

if [[ "$BUILD_ONLY" = "1" ]]; then
  echo "✓ built only (--build)"
  exit 0
fi

echo "==> deploying to production"
"$NETLIFY" deploy --prod --site "$SITE_ID" --dir build/web \
  --message "v$APP_VERSION"

echo
echo "✓ v$APP_VERSION deployed."
