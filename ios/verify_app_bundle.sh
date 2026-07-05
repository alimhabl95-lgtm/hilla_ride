#!/bin/bash
set -euo pipefail

APP="${1:?Usage: verify_app_bundle.sh /path/to/Runner.app}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
DISPLAY="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP/Info.plist")"
echo "Checking app bundle $VERSION ($BUILD), display name: $DISPLAY"

if echo "$DISPLAY" | grep -qi "DEBUG"; then
  echo "ERROR: Display name contains DEBUG ($DISPLAY)"
  exit 1
fi

FLUTTER_FRAMEWORK="$APP/Frameworks/Flutter.framework/Flutter"
APP_FRAMEWORK="$APP/Frameworks/App.framework/App"
ASSETS="$APP/Frameworks/App.framework/flutter_assets"

if [ ! -f "$FLUTTER_FRAMEWORK" ]; then
  echo "ERROR: Flutter.framework not found"
  exit 1
fi

if [ ! -f "$APP_FRAMEWORK" ]; then
  echo "ERROR: App.framework not found"
  exit 1
fi

FLUTTER_SIZE="$(stat -f%z "$FLUTTER_FRAMEWORK" 2>/dev/null || stat -c%s "$FLUTTER_FRAMEWORK")"
APP_SIZE="$(stat -f%z "$APP_FRAMEWORK" 2>/dev/null || stat -c%s "$APP_FRAMEWORK")"
echo "Flutter.framework size: $FLUTTER_SIZE bytes"
echo "App.framework size: $APP_SIZE bytes"

if [ "$FLUTTER_SIZE" -gt 25000000 ]; then
  echo "ERROR: Flutter.framework is too large for a release build ($FLUTTER_SIZE bytes)"
  exit 1
fi

if [ "$APP_SIZE" -lt 500000 ]; then
  echo "ERROR: App.framework is too small; AOT compile likely missing ($APP_SIZE bytes)"
  exit 1
fi

# ptrace/JIT helpers are compiled only into the debug iOS engine.
if nm "$FLUTTER_FRAMEWORK" 2>/dev/null | grep -qE "EnableTracingIfNecessaryImpl|_Dart_IsolateReload"; then
  echo "ERROR: Debug-only symbols found in Flutter.framework"
  exit 1
fi

if strings "$FLUTTER_FRAMEWORK" 2>/dev/null | grep -q "Cannot create a FlutterEngine instance in debug mode"; then
  echo "ERROR: Debug engine strings found in Flutter.framework"
  exit 1
fi

if [ -f "$ASSETS/vm_snapshot_data" ] || [ -f "$ASSETS/isolate_snapshot_data" ]; then
  echo "ERROR: Debug Dart snapshots found"
  exit 1
fi

if [ -f "$ASSETS/kernel_blob.bin" ]; then
  echo "ERROR: kernel_blob.bin found (JIT/debug build)"
  exit 1
fi

if nm "$APP_FRAMEWORK" 2>/dev/null | grep -qE "kDartIsolateSnapshotInstructions|kDartVmSnapshotInstructions"; then
  echo "App.framework contains AOT snapshot symbols"
else
  echo "ERROR: App.framework has no AOT snapshot symbols"
  exit 1
fi

if [ -f "$APP/embedded.mobileprovision" ]; then
  ENTITLEMENTS="$(mktemp)"
  security cms -D -i "$APP/embedded.mobileprovision" > "$ENTITLEMENTS"
  if /usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$ENTITLEMENTS" 2>/dev/null | grep -q "true"; then
    echo "ERROR: IPA signed with get-task-allow (development entitlement)"
    exit 1
  fi
fi

echo "App bundle release verification passed for $VERSION ($BUILD)"
