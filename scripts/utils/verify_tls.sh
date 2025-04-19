#!/bin/bash
# Usage: verify_tls.sh <domain> [<path>]
DOMAIN="$1"
PATH="${2:-/}"

if curl -s --head --max-time 10 "https://${DOMAIN}${PATH}" | grep -q "200 OK"; then
  echo "TLS verification succeeded for https://${DOMAIN}${PATH}"
  exit 0
else
  echo "TLS verification FAILED for https://${DOMAIN}${PATH}"
  exit 1
fi
