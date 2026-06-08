#!/usr/bin/env bash
# =============================================================================
# testflight.sh — Archive Story of My Life and open Xcode Organizer for upload
#
# Usage:  make tf
#         ./scripts/testflight.sh
#
# What it does:
#   1. Confirms you are on the release branch
#   2. Bumps build number (TestFlight requires a unique build per version)
#   3. Clears DerivedData
#   4. Archives with the Release configuration
#   5. Opens Xcode Organizer so you can validate & upload
#   6. Commits the build number bump to git
# =============================================================================
set -euo pipefail

SCHEME="StoryOfMyLife"
APP_NAME="StoryOfMyLife"
EXPECTED_BRANCH_PREFIX="release/"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/$APP_NAME.xcodeproj"
ARCHIVES_DIR="$PROJECT_ROOT/.build/archives"
DERIVED_DATA="$PROJECT_ROOT/.build/DerivedData"

bold()  { echo -e "\033[1m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
red()   { echo -e "\033[31m$*\033[0m"; }
yellow(){ echo -e "\033[33m$*\033[0m"; }
step()  { echo; bold "▸ $*"; }

# ── 1. Branch check ───────────────────────────────────────────────────────────
step "Branch check"
cd "$PROJECT_ROOT"
BRANCH=$(git branch --show-current)
echo "  Current branch: $BRANCH"

if [[ "$BRANCH" != ${EXPECTED_BRANCH_PREFIX}* ]]; then
  yellow "  ⚠ You are not on a release/* branch."
  read -rp "  Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

# Warn about uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  yellow "  ⚠ You have uncommitted changes:"
  git status --short
  read -rp "  Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi
green "  ✓ Branch OK"

# ── 2. Bump build number ──────────────────────────────────────────────────────
step "Bumping build number"
CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))
agvtool new-version -all "$NEW_BUILD" >/dev/null

MARKETING=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "?")
green "  ✓ v$MARKETING build $CURRENT_BUILD → $NEW_BUILD"

# ── 3. Clear DerivedData ──────────────────────────────────────────────────────
step "Clearing DerivedData"
rm -rf "$DERIVED_DATA"
for dd in ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*; do
  [ -d "$dd" ] && rm -rf "$dd" && echo "  Removed: $(basename "$dd")"
done
mkdir -p "$DERIVED_DATA"
green "  ✓ DerivedData cleared"

# ── 4. Archive ────────────────────────────────────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_PATH="$ARCHIVES_DIR/StoryOfMyLife_v${MARKETING}_b${NEW_BUILD}_${TIMESTAMP}.xcarchive"
mkdir -p "$ARCHIVES_DIR"

step "Archiving (Release configuration)"
echo "  Output: $ARCHIVE_PATH"
echo "  This takes 2–5 minutes…"
echo

BUILD_LOG="$PROJECT_ROOT/.build/last-archive.log"

set +e
xcodebuild \
  -project         "$PROJECT_FILE" \
  -scheme          "$SCHEME" \
  -configuration   Release \
  -destination     "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -archivePath     "$ARCHIVE_PATH" \
  archive \
  2>&1 | tee "$BUILD_LOG" | \
    grep --line-buffered -E \
      "error:|Build succeeded|FAILED|Compiling|Linking|Signing|Archive" | \
    sed 's|'"$PROJECT_ROOT/"'||g'

ARCHIVE_STATUS=${PIPESTATUS[0]}
set -e

if [ "$ARCHIVE_STATUS" -ne 0 ]; then
  red ""
  red "✗ Archive FAILED (exit $ARCHIVE_STATUS)"
  echo "  Full log: $BUILD_LOG"
  grep "error:" "$BUILD_LOG" | tail -10
  # Rollback build number
  agvtool new-version -all "$CURRENT_BUILD" >/dev/null
  red "  Build number rolled back to $CURRENT_BUILD"
  exit 1
fi

green ""
green "  ✓ Archive succeeded"

# ── 5. Open Organizer ─────────────────────────────────────────────────────────
step "Opening Xcode Organizer"
open -a Xcode "$ARCHIVE_PATH"
echo "  In Organizer: select the archive → Distribute App → TestFlight"

# ── 6. Commit build number bump ───────────────────────────────────────────────
step "Committing build number bump"
git add StoryOfMyLife.xcodeproj/project.pbxproj
git commit -m "Bump build to $NEW_BUILD for TestFlight v$MARKETING

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
green "  ✓ Committed build $NEW_BUILD"

green ""
green "✅ Archive ready: v$MARKETING (build $NEW_BUILD)"
echo "   Upload via Xcode Organizer or run:  make upload"
echo
