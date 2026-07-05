#!/bin/bash
set -euo pipefail

IPA="${1:-$(ls build/ios/ipa/*.ipa | head -1)}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Verifying IPA: $IPA"
unzip -q "$IPA" -d "$TMPDIR"

APP="$TMPDIR/Payload/Runner.app"
if [ ! -d "$APP" ]; then
  echo "ERROR: Runner.app not found in IPA"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
DISPLAY="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Info.plist")"
echo "IPA bundle version: $VERSION ($BUILD)"
echo "IPA display name: $DISPLAY"

if echo "$DISPLAY" | grep -qi "DEBUG"; then
  echo "ERROR: IPA display name contains DEBUG ($DISPLAY) — Xcode built Debug, not Release"
  exit 1
fi

FLUTTER_FRAMEWORK="$APP/Frameworks/Flutter.framework/Flutter"
APP_FRAMEWORK="$APP/Frameworks/App.framework/App"
ASSETS="$APP/Frameworks/App.framework/flutter_assets"

if [ ! -f "$FLUTTER_FRAMEWORK" ]; then
  echo "ERROR: Flutter.framework not found in IPA"
  exit 1
fi

if [ ! -f "$APP_FRAMEWORK" ]; then
  echo "ERROR: App.framework not found in IPA"
  exit 1
fi

FLUTTER_SIZE="$(stat -f%z "$FLUTTER_FRAMEWORK" 2>/dev/null || stat -c%s "$FLUTTER_FRAMEWORK")"
APP_SIZE="$(stat -f%z "$APP_FRAMEWORK" 2>/dev/null || stat -c%s "$APP_FRAMEWORK")"
echo "Flutter.framework size: $FLUTTER_SIZE bytes"
echo "App.framework size: $APP_SIZE bytes"

# Debug JIT engine is much larger than release AOT engine on iOS.
if [ "$FLUTTER_SIZE" -gt 30000000 ]; then
  echo "ERROR: Flutter.framework is ${FLUTTER_SIZE} bytes (likely debug JIT engine)"
  exit 1
fi

if [ "$APP_SIZE" -lt 500000 ]; then
  echo "ERROR: App.framework is only ${APP_SIZE} bytes (AOT compile likely missing)"
  exit 1
fi

if [ -f "$ASSETS/vm_snapshot_data" ] || [ -f "$ASSETS/isolate_snapshot_data" ]; then
  echo "ERROR: Debug Dart snapshots found in IPA"
  exit 1
fi

if [ -f "$ASSETS/kernel_blob.bin" ]; then
  echo "ERROR: kernel_blob.bin found in IPA (not an AOT release build)"
  exit 1
fi

if nm "$APP_FRAMEWORK" 2>/dev/null | grep -q "kDartIsolateSnapshotInstructions"; then
  echo "App.framework contains AOT snapshot instructions"
elif nm "$APP_FRAMEWORK" 2>/dev/null | grep -q "kDartVmSnapshotInstructions"; then
  echo "App.framework contains AOT VM snapshot instructions"
else
  echo "ERROR: App.framework has no AOT snapshot symbols"
  exit 1
fi

if [ -f "$APP/embedded.mobileprovision" ]; then
  ENTITLEMENTS="$(mktemp)"
  security cms -D -i "$APP/embedded.mobileprovision" > "$ENTITLEMENTS"
  if /usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$ENTITLEMENTS" 2>/dev/null | grep -q "true"; then
    echo "ERROR: IPA is signed with get-task-allow (development/debug entitlement)"
    exit 1
  fi
fi

echo "IPA release verification passed for $VERSION ($BUILD)"
