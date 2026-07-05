#!/bin/bash
set -euo pipefail

BUILD_NAME="${BUILD_NAME:-1.0.59}"
BUILD_NUMBER="${BUILD_NUMBER:-${PROJECT_BUILD_NUMBER:-1}}"

echo "=== Hello Tuk-Tuk iOS release build $BUILD_NAME ($BUILD_NUMBER) ==="
flutter --version

flutter clean
rm -rf build ios/build ios/.symlinks ios/Flutter/ephemeral ios/Flutter/Flutter.framework

flutter pub get

flutter build ios --release --config-only \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

echo "=== Generated.xcconfig ==="
cat ios/Flutter/Generated.xcconfig

BUILD_MODE="$(grep '^FLUTTER_BUILD_MODE=' ios/Flutter/Generated.xcconfig | cut -d= -f2- | tr -d '[:space:]')"
if [ "$BUILD_MODE" != "release" ]; then
  echo "ERROR: Generated.xcconfig FLUTTER_BUILD_MODE=$BUILD_MODE (expected release)"
  exit 1
fi

if ! grep -q '^FLUTTER_BUILD_MODE=release' ios/Flutter/Release.xcconfig; then
  echo "ERROR: ios/Flutter/Release.xcconfig must force FLUTTER_BUILD_MODE=release"
  exit 1
fi

cd ios
pod install
cd ..

flutter build ipa --release \
  --export-options-plist=ios/exportOptions.plist \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

ARCHIVE_APP="$(find build/ios/archive -path '*/Products/Applications/Runner.app' -type d 2>/dev/null | head -1)"
if [ -n "$ARCHIVE_APP" ]; then
  echo "Verifying archived app before TestFlight upload..."
  bash ios/verify_app_bundle.sh "$ARCHIVE_APP"
else
  echo "WARNING: Archive Runner.app not found; verifying exported IPA only"
fi

bash ios/verify_release_ipa.sh

echo "SUCCESS: Release IPA $BUILD_NAME ($BUILD_NUMBER) verified for TestFlight"
