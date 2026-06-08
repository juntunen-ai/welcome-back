#!/usr/bin/env bash
# =============================================================================
# dev-install.sh — Clean build & install Story of My Life on Dirti Harri
#
# Usage:  make install
#         ./scripts/dev-install.sh [--no-bump]
#
# What it does:
#   1. Verifies the git branch and device connectivity
#   2. Bumps the build number (prevents iOS from skipping the install)
#   3. Wipes ALL DerivedData for this project (eliminates stale cache)
#   4. Runs a clean xcodebuild for the physical device
#   5. Installs the resulting .app via xcrun devicectl
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
# Hardware UDID — used by xcodebuild -destination
DEVICE_ID="00008130-001659462E8B803A"   # Dirti Harri (hardware UDID)
# CoreDevice UUID — used by xcrun devicectl (Xcode 15+)
COREDEVICE_UUID="7ABD2D9D-DAAF-5F34-85DC-89BBBBC0DE38"
DEVICE_NAME="Dirti Harri"
SCHEME="StoryOfMyLife"
CONFIGURATION="Debug"
APP_NAME="StoryOfMyLife"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/$APP_NAME.xcodeproj"
DERIVED_DATA="$PROJECT_ROOT/.build/DerivedData"

BUMP_BUILD=true
for arg in "$@"; do
  [[ "$arg" == "--no-bump" ]] && BUMP_BUILD=false
done

# ── Helpers ───────────────────────────────────────────────────────────────────
bold()  { echo -e "\033[1m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
red()   { echo -e "\033[31m$*\033[0m"; }
step()  { echo; bold "▸ $*"; }

# ── 1. Preflight ──────────────────────────────────────────────────────────────
step "Preflight checks"

BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")
echo "  Branch : $BRANCH"
echo "  Project: $PROJECT_FILE"

# Verify device is reachable (match by name to work with any ID format)
if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_NAME"; then
  red "  ✗ $DEVICE_NAME not found."
  echo "    Make sure the iPhone is connected, unlocked, and trusts this Mac."
  exit 1
fi
green "  ✓ $DEVICE_NAME is connected"

# ── 2. Bump build number ──────────────────────────────────────────────────────
if $BUMP_BUILD; then
  step "Bumping build number"
  cd "$PROJECT_ROOT"
  CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
  NEW_BUILD=$((CURRENT_BUILD + 1))
  agvtool new-version -all "$NEW_BUILD" >/dev/null
  green "  ✓ Build $CURRENT_BUILD → $NEW_BUILD"
else
  cd "$PROJECT_ROOT"
  CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "?")
  echo "  Build number unchanged: $CURRENT_BUILD (--no-bump)"
fi

# ── 3. Clear DerivedData ──────────────────────────────────────────────────────
step "Clearing DerivedData"

# Clear both the local .build cache and any global Xcode DerivedData for this project
rm -rf "$DERIVED_DATA"
for dd in ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*; do
  [ -d "$dd" ] && rm -rf "$dd" && echo "  Removed: $(basename "$dd")"
done
mkdir -p "$DERIVED_DATA"
green "  ✓ DerivedData cleared"

# ── 4. Build ──────────────────────────────────────────────────────────────────
step "Building $APP_NAME ($CONFIGURATION) for $DEVICE_NAME"
echo "  This takes ~1 min on first build, ~20 s after that."
echo

BUILD_LOG="$PROJECT_ROOT/.build/last-build.log"
mkdir -p "$(dirname "$BUILD_LOG")"

set +e
xcodebuild \
  -project       "$PROJECT_FILE" \
  -scheme        "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination   "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  clean build \
  CODE_SIGN_STYLE=Automatic \
  GCC_OPTIMIZATION_LEVEL=0 \
  SWIFT_OPTIMIZATION_LEVEL="-Onone" \
  2>&1 | tee "$BUILD_LOG" | \
    grep --line-buffered -E \
      "error:|warning: (deprecated|unused)|Build succeeded|FAILED|Compiling|Linking|Signing" | \
    sed 's|'"$PROJECT_ROOT/"'||g'

BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
  red ""
  red "✗ Build FAILED (exit $BUILD_STATUS)"
  echo "  Full log: $BUILD_LOG"
  echo "  Last errors:"
  grep "error:" "$BUILD_LOG" | tail -10
  exit 1
fi

green ""
green "  ✓ Build succeeded"

# ── 5. Find the .app ──────────────────────────────────────────────────────────
step "Locating compiled app"
APP_PATH=$(find "$DERIVED_DATA" -name "$APP_NAME.app" \
  -not -path "*/PlugIns/*" \
  -not -path "*simulator*" \
  | sort -r | head -1)

if [ -z "$APP_PATH" ]; then
  red "  ✗ Could not locate $APP_NAME.app in DerivedData"
  echo "  DerivedData contents:"
  find "$DERIVED_DATA" -name "*.app" 2>/dev/null | head -10
  exit 1
fi
echo "  Found: $APP_PATH"

# ── 6. Install ────────────────────────────────────────────────────────────────
step "Installing on $DEVICE_NAME"

xcrun devicectl device install app \
  --device "$COREDEVICE_UUID" \
  "$APP_PATH" 2>&1 | grep -v "^$"

green ""
green "✅ Story of My Life (build ${NEW_BUILD:-$CURRENT_BUILD}) installed on $DEVICE_NAME"
echo "   Open the app on your iPhone — changes are live."
echo
