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
echo "IPA bundle version: $VERSION ($BUILD)"

if [ -f "$APP/Frameworks/App.framework/flutter_assets/vm_snapshot_data" ] || \
   [ -f "$APP/Frameworks/App.framework/flutter_assets/isolate_snapshot_data" ]; then
  echo "ERROR: Debug Dart snapshots found in IPA (not a release build)"
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
