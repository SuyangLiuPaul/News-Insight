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

if [[ "${1:-}" == "--build" ]]; then
  echo "✓ built only (--build)"
  exit 0
fi

echo "==> deploying to production"
"$NETLIFY" deploy --prod --site "$SITE_ID" --dir build/web \
  --message "v$APP_VERSION"

echo
echo "✓ v$APP_VERSION deployed."
