#!/usr/bin/env bash
# =============================================================================
# fetch-tts-assets.sh — Download the neural TTS frameworks + Piper voices
#
# These assets are NOT in git (large binaries). Run once after cloning:
#   ./scripts/fetch-tts-assets.sh
#
# Installs:
#   Frameworks/sherpa-onnx.xcframework      (static, v1.13.3, TTS-enabled)
#   Frameworks/onnxruntime.xcframework      (static, 1.26.0)
#   StoryOfMyLife/Resources/TTSVoices/fi/   (Piper fi_FI-harri-medium, 22.05kHz)
#   StoryOfMyLife/Resources/TTSVoices/en/   (Piper en_US-lessac-medium, 22.05kHz)
#   StoryOfMyLife/Resources/TTSVoices/espeak-ng-data/
# =============================================================================
set -euo pipefail

SHERPA_VERSION="v1.13.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "▸ Downloading sherpa-onnx $SHERPA_VERSION iOS frameworks…"
curl -sL -o "$TMP/ios.tar.bz2" \
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/$SHERPA_VERSION/sherpa-onnx-$SHERPA_VERSION-ios.tar.bz2"
echo "▸ Downloading Finnish voice (fi_FI-harri-medium)…"
curl -sL -o "$TMP/fi.tar.bz2" \
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-fi_FI-harri-medium.tar.bz2"
echo "▸ Downloading English voice (en_US-lessac-medium)…"
curl -sL -o "$TMP/en.tar.bz2" \
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2"

echo "▸ Extracting…"
tar xjf "$TMP/ios.tar.bz2" -C "$TMP"
tar xjf "$TMP/fi.tar.bz2" -C "$TMP"
tar xjf "$TMP/en.tar.bz2" -C "$TMP"

echo "▸ Installing frameworks…"
rm -rf "$ROOT/Frameworks/sherpa-onnx.xcframework" "$ROOT/Frameworks/onnxruntime.xcframework"
cp -RL "$TMP/build-ios/sherpa-onnx.xcframework" "$ROOT/Frameworks/"
cp -RL "$TMP/build-ios/ios-onnxruntime/"*/onnxruntime.xcframework "$ROOT/Frameworks/"

echo "▸ Installing voices…"
VOICES="$ROOT/StoryOfMyLife/Resources/TTSVoices"
mkdir -p "$VOICES/fi" "$VOICES/en"
cp "$TMP/vits-piper-fi_FI-harri-medium/fi_FI-harri-medium.onnx" "$VOICES/fi/"
cp "$TMP/vits-piper-fi_FI-harri-medium/tokens.txt" "$VOICES/fi/"
cp "$TMP/vits-piper-en_US-lessac-medium/en_US-lessac-medium.onnx" "$VOICES/en/"
cp "$TMP/vits-piper-en_US-lessac-medium/tokens.txt" "$VOICES/en/"
rm -rf "$VOICES/espeak-ng-data"
cp -R "$TMP/vits-piper-fi_FI-harri-medium/espeak-ng-data" "$VOICES/"

echo "✅ TTS assets installed."
