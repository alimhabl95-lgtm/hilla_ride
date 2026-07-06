#!/bin/bash
# Optional: generate a new OpenSSL private key for Codemagic certificate creation.
# Run locally ONLY if Team settings → Generate certificate asks for a key,
# or to store CERTIFICATE_PRIVATE_KEY in Codemagic Application variables.
#
# Usage:
#   bash hilla_ride_ios/scripts/generate_certificate_key.sh
#   Then paste the printed key into Codemagic → Application → Environment variables
#   as CERTIFICATE_PRIVATE_KEY (secure), or use Team → Code signing → Generate certificate.

set -euo pipefail

OUT="${1:-certificate_private_key.pem}"

openssl genrsa -out "$OUT" 2048
chmod 600 "$OUT"

echo "Wrote private key to: $OUT"
echo ""
echo "Next steps (choose ONE):"
echo "  A) Codemagic → Team settings → Code signing identities → iOS certificates"
echo "     → Generate certificate → Apple Distribution → select API key codemagic"
echo "  B) Export your Mac .p12 distribution cert → Upload to same page"
echo "  C) Codemagic → Team settings → iOS provisioning profiles → Fetch profiles"
echo "     → App Store profile for com.hillaride.hillaRide"
echo ""
echo "Reference name suggestions: hilla_ride_distribution / hilla_ride_appstore"
