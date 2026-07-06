#!/bin/bash
# Create a fresh App Store provisioning profile linked to the active distribution certificate.
# Fixes: "Provisioning profile ... doesn't include signing certificate ..."

set -euo pipefail

BUNDLE_ID="${1:-com.hillaride.hillaRide}"
TEAM_CERT_NAME="${2:-Ali Al-Isawi}"
PROFILES_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"

echo "Looking up Bundle ID resource: ${BUNDLE_ID}"
BUNDLE_JSON="$(app-store-connect bundle-ids list \
  --bundle-id-identifier "${BUNDLE_ID}" \
  --strict-match-identifier \
  --json)"
BUNDLE_RESOURCE_ID="$(echo "${BUNDLE_JSON}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('data', [])
if not items:
    raise SystemExit('Bundle ID not found')
print(items[0]['id'])
")"

echo "Looking up distribution certificate: ${TEAM_CERT_NAME}"
CERT_JSON="$(app-store-connect certificates list \
  --type IOS_DISTRIBUTION \
  --profile-type IOS_APP_STORE \
  --json)"
CERT_RESOURCE_ID="$(echo "${CERT_JSON}" | TEAM_CERT_NAME="${TEAM_CERT_NAME}" python3 -c "
import json, os, sys
name = os.environ['TEAM_CERT_NAME']
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('data', [])
matches = [item for item in items if name in item.get('attributes', {}).get('displayName', '')]
if not matches:
    for item in items:
        dn = item.get('attributes', {}).get('displayName', '')
        if 'Apple Distribution' in dn and 'XAZ6V7UTYT' in dn:
            matches.append(item)
if not matches:
    raise SystemExit(f'No IOS_DISTRIBUTION certificate matched: {name}')
print(matches[0]['id'])
")"

echo "Removing stale local provisioning profiles"
mkdir -p "${PROFILES_DIR}"
rm -f "${PROFILES_DIR}/"*.mobileprovision 2>/dev/null || true

PROFILE_NAME="Hello Tuk-Tuk Codemagic AppStore $(date +%Y%m%d%H%M)"
echo "Creating App Store profile: ${PROFILE_NAME}"
app-store-connect profiles create "${BUNDLE_RESOURCE_ID}" \
  --certificate-ids "${CERT_RESOURCE_ID}" \
  --type IOS_APP_STORE \
  --name "${PROFILE_NAME}" \
  --save

echo "Profiles ready:"
ls -la "${PROFILES_DIR}" || true
