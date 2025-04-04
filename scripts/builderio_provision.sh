#!/bin/bash
# builderio_provision.sh

# Prereqs: You must have your Builder.io personal token exported as:
# export BUILDER_API_KEY="..."

# Client identifier (e.g., "peacefestival")
CLIENT_NAME=$1
DOMAIN=$2

if [ -z "$BUILDER_API_KEY" ] || [ -z "$CLIENT_NAME" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: BUILDER_API_KEY=... $0 client_name domain"
  exit 1
fi

echo "🔧 Creating Builder.io space for $CLIENT_NAME..."

RESPONSE=$(curl -s -X POST https://builder.io/api/v1/organizations/YOUR_ORG_ID/spaces \
  -H "Authorization: Bearer $BUILDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$CLIENT_NAME"'",
    "url": "'"https://$DOMAIN"'"
  }')

echo "✅ Response: $RESPONSE"
