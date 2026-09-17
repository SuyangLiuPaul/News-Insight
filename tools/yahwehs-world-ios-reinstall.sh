#!/bin/zsh
# Scheduled Yahweh's World reinstall — iPhone + iPad + this Mac.
#
# Exists for the same reason its sibling does: the free Apple ID
# signing certificate expires every 7 days, so a native install
# silently stops launching unless something re-signs it. Each fire:
#
#   1. git pull origin main          — pick up the latest committed code
#   2. flutter build ios --release   — signed via the Xcode account
#   3. xcrun devicectl install       — iPhone, then iPad
#   4. flutter build macos --release — replaces /Applications copy
#
# Deliberately a SEPARATE script from yswords-ios-reinstall.sh rather
# than another roster entry in it: that script carries flavor builds,
# alt-icon injection, and an Android leg this app has no use for, and
# it is the main app's working schedule — a shared edit risks both.
#
# Per-device failures are isolated: one device asleep must not stop
# the others. Exit 0 iff at least one target got the build.
#
# Triggered by: ~/Library/LaunchAgents/com.yahwehsworld.ios-reinstall.plist
# Log:          /tmp/yahwehs-world-ios-reinstall.log (rotates each run)
#
# Prerequisites (same as the sibling script):
#   1. Mac awake at the fire time.
#   2. iPhone + iPad on the same WiFi, paired via "Connect via network"
#      in Xcode → Devices and Simulators. Locked is fine; deep sleep or
#      airplane mode is not.
#   3. A signed-in Apple Account in Xcode → Settings → Accounts. When
#      that session expires the build fails with "No Accounts" and the
#      only fix is signing in again by hand.
#
# Manual run:
#   ~/Documents/CodingProject/yahwehs_world/tools/yahwehs-world-ios-reinstall.sh

# No `set -e` — a failure on one device must not abort the rest.

LOG="/tmp/yahwehs-world-ios-reinstall.log"
FLUTTER="/Users/pliu0036/flutter/bin/flutter"
PROJECT="/Users/pliu0036/Documents/CodingProject/yahwehs_world"
IOS_APP="$PROJECT/build/ios/iphoneos/Runner.app"
MACOS_APP="$PROJECT/build/macos/Build/Products/Release/News-Insight.app"
MACOS_DEST="/Applications/News Insight.app"

IOS_DEVICES=(
  "9FA8108D-E7E4-58F5-8326-3BD835C3A5E7|iPhone 16 Pro Max (Paul)"
  "D5B9E2F7-F74E-5F8A-8A08-83008BDBD13C|iPad Pro 11-inch (Paul Liu's iPad)"
)

exec > "$LOG" 2>&1
echo "=== Yahweh's World reinstall — $(date '+%Y-%m-%d %H:%M:%S') ==="

cd "$PROJECT" || { echo "FATAL: project directory missing"; exit 1; }

echo "--- git pull"
git pull --ff-only origin main || echo "WARN: pull failed; building whatever is checked out"

APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml | cut -d'+' -f1)"
APP_RELEASE_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "--- building v${APP_VERSION:-unknown} ($APP_RELEASE_TIME)"

# The version shown in the app header comes from --dart-define, not
# from pubspec: without these the build falls back to the literal in
# lib/constants/app_version.dart and the app misreports its own
# version. release_web.sh passes the same pair.
DEFINES=(
  --dart-define="APP_VERSION=$APP_VERSION"
  --dart-define="APP_RELEASE_TIME=$APP_RELEASE_TIME"
)

successes=0
failures=0

echo "--- flutter build ios --release"
if "$FLUTTER" build ios --release "${DEFINES[@]}"; then
  for entry in "${IOS_DEVICES[@]}"; do
    uuid="${entry%%|*}"
    name="${entry##*|}"
    echo "--- installing to $name"
    if xcrun devicectl device install app --device "$uuid" "$IOS_APP"; then
      echo "OK: $name"
      successes=$((successes + 1))
    else
      # The most common cause is NOT what this used to claim. A locked
      # device fails with kAMDMobileImageMounterDeviceLocked, because
      # the developer disk image cannot mount on one — and at 04:40 both
      # devices are locked, so this is the expected nightly outcome
      # rather than a transient network blip. The old wording ("asleep,
      # off WiFi, or unpaired") sent an investigation down the wrong
      # path; grep the log above for the real CoreDevice error.
      echo "FAIL: $name — check the error above:"
      echo "      'device is locked'  -> unlock it and re-run by hand;"
      echo "                             the 04:40 job cannot fix this."
      echo "      'could not find'    -> asleep, off WiFi, or unpaired."
      failures=$((failures + 1))
    fi
  done
else
  echo "FAIL: iOS build failed — check for an expired Xcode account session"
  failures=$((failures + ${#IOS_DEVICES[@]}))
fi

echo "--- flutter build macos --release"
if "$FLUTTER" build macos --release "${DEFINES[@]}" && [[ -d "$MACOS_APP" ]]; then
  # ditto, not cp: preserves the signature and bundle structure.
  if ditto "$MACOS_APP" "$MACOS_DEST"; then
    echo "OK: $MACOS_DEST"
    successes=$((successes + 1))
  else
    echo "FAIL: could not replace $MACOS_DEST"
    failures=$((failures + 1))
  fi
else
  echo "FAIL: macOS build failed"
  failures=$((failures + 1))
fi

echo "=== done: $successes succeeded, $failures failed ==="
[[ $successes -gt 0 ]] && exit 0
exit 1
