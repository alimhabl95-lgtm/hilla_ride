#!/bin/bash
set -euo pipefail

BUILD_NAME="${BUILD_NAME:-1.0.59}"
BUILD_NUMBER="${BUILD_NUMBER:-${PROJECT_BUILD_NUMBER:-1}}"

echo "=== Hello Tuk-Tuk iOS release build $BUILD_NAME ($BUILD_NUMBER) ==="
flutter --version

flutter clean
rm -rf build ios/build ios/.symlinks ios/Flutter/ephemeral ios/Flutter/Flutter.framework

flutter pub get

# Config-only must not require Apple certs on CI (signing happens at ipa export).
flutter build ios --release --config-only --no-codesign \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

echo "=== Generated.xcconfig ==="
cat ios/Flutter/Generated.xcconfig

# Flutter 3.47+ may omit FLUTTER_BUILD_MODE from Generated.xcconfig; Release.xcconfig is authoritative.
if ! grep -q '^FLUTTER_BUILD_MODE=release' ios/Flutter/Release.xcconfig; then
  echo "ERROR: ios/Flutter/Release.xcconfig must force FLUTTER_BUILD_MODE=release"
  exit 1
fi
BUILD_MODE="$(grep '^FLUTTER_BUILD_MODE=' ios/Flutter/Generated.xcconfig 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || true)"
if [ -n "$BUILD_MODE" ] && [ "$BUILD_MODE" != "release" ]; then
  echo "ERROR: Generated.xcconfig FLUTTER_BUILD_MODE=$BUILD_MODE (expected release or unset)"
  exit 1
fi
echo "Release build mode confirmed (Release.xcconfig)"

cd ios
pod install
cd ..

EXPORT_PLIST="ios/exportOptions.plist"
if [ -n "${CM_BUILD_DIR:-}" ] && command -v xcode-project >/dev/null 2>&1; then
  echo "Applying Codemagic signing to Runner (after pod install)..."
  xcode-project use-profiles \
    --project "ios/Runner.xcodeproj" \
    --code-signing-setup-verbose-logging
  if [ -f "${HOME}/export_options.plist" ]; then
    EXPORT_PLIST="${HOME}/export_options.plist"
    echo "Using Codemagic export options: ${EXPORT_PLIST}"
  else
    echo "ERROR: ${HOME}/export_options.plist not found after use-profiles"
    exit 1
  fi
fi

flutter build ipa --release \
  --export-options-plist="${EXPORT_PLIST}" \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

IPA_PATH="$(find build/ios/ipa -name '*.ipa' -type f 2>/dev/null | head -1)"
if [ -z "${IPA_PATH}" ]; then
  echo "ERROR: flutter build ipa did not produce an IPA (export/signing likely failed)"
  exit 1
fi
echo "IPA created: ${IPA_PATH}"

bash ios/verify_release_ipa.sh "${IPA_PATH}"

echo "SUCCESS: Release IPA $BUILD_NAME ($BUILD_NUMBER) verified for TestFlight"
