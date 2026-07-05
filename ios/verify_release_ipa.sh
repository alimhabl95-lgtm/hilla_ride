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

bash ios/verify_app_bundle.sh "$APP"
