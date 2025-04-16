#!/bin/bash
# builderio_provision.sh
#
# This script creates a new Builder.io space for a client and configures the necessary integrations.
# It can be called directly or from the bootstrap_client.sh script.
#
# Usage:
#   BUILDER_API_KEY="your_api_key" ./builderio_provision.sh client_name domain.com
#
# Example:
#   BUILDER_API_KEY="12345" ./builderio_provision.sh acme acme.com
#
# Note: Replace YOUR_ORG_ID in the script with your actual Builder.io organization ID.

# Prereqs: You must have your Builder.io personal token exported as:
# export BUILDER_API_KEY="..."

# Client identifier (e.g., "peacefestival")
CLIENT_NAME=$1
DOMAIN=$2

if [ -z "$BUILDER_API_KEY" ] || [ -z "$CLIENT_NAME" ] || [ -z "$DOMAIN" ]; then
  echo "❌ Usage: BUILDER_API_KEY=... $0 client_name domain"
  exit 1
fi

# Determine directory locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="../clients/${DOMAIN}"
ENV_FILE="${CLIENT_DIR}/.env"
OFFLINE_DIR="${CLIENT_DIR}/static"

# Verify the client directory and env file exist
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Client environment file not found: $ENV_FILE"
  echo "❌ Make sure to run bootstrap_client.sh first to create the client directory and .env file."
  exit 1
fi

echo "🔧 Creating Builder.io space for $CLIENT_NAME..."

# Step 1: Create a new space for the client
SPACE_RESPONSE=$(curl -s -X POST https://builder.io/api/v1/organizations/YOUR_ORG_ID/spaces \
  -H "Authorization: Bearer $BUILDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$CLIENT_NAME"'",
    "url": "'"https://$DOMAIN"'"
  }')

echo "✅ Space creation response: $SPACE_RESPONSE"

# Extract the space ID from the response using grep and cut
SPACE_ID=$(echo $SPACE_RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SPACE_ID" ]; then
  echo "❌ Failed to extract space ID from response"
  exit 1
fi

echo "✅ Created space with ID: $SPACE_ID"

# Step 2: Generate an API key for the space
KEY_RESPONSE=$(curl -s -X POST "https://builder.io/api/v1/spaces/$SPACE_ID/api-keys" \
  -H "Authorization: Bearer $BUILDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$CLIENT_NAME-api-key"'",
    "description": "API key for '"$CLIENT_NAME"'",
    "permissions": ["write", "read"]
  }')

echo "✅ API key creation response: $KEY_RESPONSE"

# Extract the API key from the response
API_KEY=$(echo $KEY_RESPONSE | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
  echo "❌ Failed to extract API key from response"
  exit 1
fi

echo "✅ Generated API key: $API_KEY"

# Step 3: Save the space ID and API key to the client's .env file
echo "🔧 Updating client .env file with Builder.io credentials..."

# Read the existing .env file
if [ -f "$ENV_FILE" ]; then
  # Check if the variables already exist in the .env file
  grep -q "BUILDER_IO_SPACE_ID" "$ENV_FILE"
  SPACE_ID_EXISTS=$?
  grep -q "BUILDER_IO_API_KEY" "$ENV_FILE"
  API_KEY_EXISTS=$?

  # Update or append the variables
  if [ $SPACE_ID_EXISTS -eq 0 ]; then
    # Replace existing space ID
    sed -i "s/BUILDER_IO_SPACE_ID=.*/BUILDER_IO_SPACE_ID=$SPACE_ID/" "$ENV_FILE"
  else
    # Append space ID
    echo "BUILDER_IO_SPACE_ID=$SPACE_ID" >> "$ENV_FILE"
  fi

  if [ $API_KEY_EXISTS -eq 0 ]; then
    # Replace existing API key
    sed -i "s/BUILDER_IO_API_KEY=.*/BUILDER_IO_API_KEY=$API_KEY/" "$ENV_FILE"
  else
    # Append API key
    echo "BUILDER_IO_API_KEY=$API_KEY" >> "$ENV_FILE"
  fi
else
  echo "❌ Client .env file not found at: $ENV_FILE"
  exit 1
fi

echo "✅ Updated client .env file with Builder.io credentials"

# Step 4: Create an offline fallback page
echo "🔧 Creating offline fallback page..."

# Create the static directory if it doesn't exist
mkdir -p "$OFFLINE_DIR"

# Create the offline.html file
cat > "$OFFLINE_DIR/offline.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Temporarily Offline - $CLIENT_NAME</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #f7f9fc;
      color: #333;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      padding: 20px;
      text-align: center;
    }
    .container {
      max-width: 600px;
      padding: 40px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    h1 {
      margin-top: 0;
      color: #2d3748;
    }
    p {
      font-size: 16px;
      line-height: 1.6;
      color: #4a5568;
    }
    .logo {
      margin-bottom: 20px;
      font-size: 48px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">🚧</div>
    <h1>We'll be right back</h1>
    <p>Our services are temporarily undergoing maintenance. Please check back in a few minutes.</p>
    <p><strong>$CLIENT_NAME</strong> &bull; <a href="https://$DOMAIN">$DOMAIN</a></p>
  </div>
</body>
</html>
EOF

echo "✅ Created offline fallback page at: $OFFLINE_DIR/offline.html"

# Step 5: Update Traefik configuration to serve the offline page as a fallback
echo "🔧 Adding Traefik configuration for offline fallback..."

TRAEFIK_FILE="${CLIENT_DIR}/traefik.toml"
mkdir -p "$(dirname "$TRAEFIK_FILE")"

cat > "$TRAEFIK_FILE" <<EOF
[http.middlewares.offline-fallback]
  [http.middlewares.offline-fallback.errors]
    status = ["500-599"]
    service = "offline-service"
    query = "/{status}.html"
    
[http.services.offline-service.loadBalancer]
  [[http.services.offline-service.loadBalancer.servers]]
    url = "file://${OFFLINE_DIR}/"
EOF

echo "✅ Created Traefik configuration for offline fallback"

# Step 6: Inject Builder.io API key into frontend templates (if any)
echo "🔧 Checking for frontend templates..."

TEMPLATES_DIR="${CLIENT_DIR}/templates"
if [ -d "$TEMPLATES_DIR" ]; then
  echo "🔧 Injecting Builder.io API key into frontend templates..."
  
  # Find HTML and JS files and inject the Builder.io API key
  find "$TEMPLATES_DIR" -type f \( -name "*.html" -o -name "*.js" \) | while read file; do
    # For HTML files, add the Builder.io script tag
    if [[ "$file" == *.html ]]; then
      sed -i '/<\/head>/i \  <script src="https://cdn.builder.io/js/webcomponents"></script>\n  <script>window.BuilderIOKey = "'"$API_KEY"'";</script>' "$file"
    fi
    
    # For JS files, add the Builder.io configuration
    if [[ "$file" == *.js ]]; then
      sed -i '/import/a \const BUILDER_API_KEY = "'"$API_KEY"'";\nconst BUILDER_SPACE_ID = "'"$SPACE_ID"'";' "$file"
    fi
  done
  
  echo "✅ Injected Builder.io API key into frontend templates"
else
  echo "⚠️ No frontend templates directory found. Skipping template injection."
fi

echo "✅ Builder.io integration completed successfully!"
echo "🔍 Space ID: $SPACE_ID"
echo "🔑 API Key: $API_KEY (saved to .env file)"
echo "🌐 Domain: $DOMAIN"
echo "🔧 Next Steps:"
echo "  1. Update docker-compose.yml to include the offline fallback configuration"
echo "  2. Restart the client services: cd $CLIENT_DIR && docker-compose up -d"
