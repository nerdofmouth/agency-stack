#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

### VARS ###
CLIENT_DOMAIN="$1"
if [ -z "$CLIENT_DOMAIN" ]; then
  echo "❌ Usage: $0 client.domain.com"
  exit 1
fi

CLIENT_NAME="${CLIENT_DOMAIN%%.*}" # e.g. peacefestival
CLIENT_DIR="clients/${CLIENT_DOMAIN}"
ENV_FILE="${CLIENT_DIR}/.env"
COMPOSE_FILE="${CLIENT_DIR}/docker-compose.yml"

### DIR SETUP ###
echo "🚀 Bootstrapping client: $CLIENT_DOMAIN"
mkdir -p "$CLIENT_DIR"

### GENERATE .env ###
echo "📦 Generating .env for $CLIENT_DOMAIN"
cat > "$ENV_FILE" <<EOF
SITE_NAME=$CLIENT_DOMAIN
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
PEERTUBE_DOMAIN=media.${CLIENT_DOMAIN}
BUILDER_ENABLE=false
# The following will be populated by the builderio_provision.sh script if BUILDER_ENABLE=true
BUILDER_IO_SPACE_ID=
BUILDER_IO_API_KEY=
EOF

### GENERATE docker-compose.yml ###
echo "⚙️  Generating docker-compose.yml for $CLIENT_DOMAIN"
cat > "$COMPOSE_FILE" <<EOF
version: "3.7"
services:
  erpnext:
    image: frappe/erpnext:version-14
    container_name: erp_${CLIENT_DOMAIN}
    environment:
      - SITE_NAME=${CLIENT_DOMAIN}
      - MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.rule=Host(\`${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.routers.erpnext_${CLIENT_DOMAIN}.middlewares=offline-fallback@file"
    volumes:
      - ${CLIENT_DIR}/erpnext_data:/var/lib/mysql
    networks:
      - traefik

  peertube:
    image: chocobozzz/peertube:production-bookworm
    container_name: peertube_${CLIENT_DOMAIN}
    environment:
      - PEERTUBE_WEBSERVER_HOSTNAME=media.${CLIENT_DOMAIN}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.rule=Host(\`media.${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.routers.peertube_${CLIENT_DOMAIN}.middlewares=offline-fallback@file"
    volumes:
      - ${CLIENT_DIR}/peertube_data:/data
    networks:
      - traefik

  # Offline fallback static files server (used by Traefik for error pages)
  static:
    image: nginx:alpine
    container_name: static_${CLIENT_DOMAIN}
    volumes:
      - ${CLIENT_DIR}/static:/usr/share/nginx/html:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.rule=Host(\`static.${CLIENT_DOMAIN}\`)"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.static_${CLIENT_DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.services.static_${CLIENT_DOMAIN}.loadbalancer.server.port=80"
    networks:
      - traefik

networks:
  traefik:
    external: true
EOF

### CREATE DIRECTORIES FOR VOLUMES ###
mkdir -p "${CLIENT_DIR}/erpnext_data"
mkdir -p "${CLIENT_DIR}/peertube_data"
mkdir -p "${CLIENT_DIR}/static"

# Create basic offline fallback page
cat > "${CLIENT_DIR}/static/offline.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Temporarily Offline - $CLIENT_NAME</title>
  <style>
    body {
      font-family: sans-serif;
      text-align: center;
      padding: 50px;
    }
    h1 { color: #333; }
  </style>
</head>
<body>
  <h1>We'll be right back</h1>
  <p>Our services are temporarily unavailable. Please check back shortly.</p>
  <p><strong>$CLIENT_NAME</strong></p>
</body>
</html>
EOF

### PROVISION Builder.io space (optional) ###
echo "🔧 Checking for Builder.io integration..."

# Source the .env file to get the BUILDER_ENABLE variable
source "$ENV_FILE"

if [ "$BUILDER_ENABLE" = "true" ]; then
  echo "🔧 Provisioning Builder.io space for ${CLIENT_NAME}..."
  
  # Get the absolute path to the builderio_provision.sh script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
  BUILDERIO_SCRIPT="$REPO_ROOT/scripts/builderio_provision.sh"
  
  # Check if the script exists
  if [ -f "$BUILDERIO_SCRIPT" ]; then
    # Check if BUILDER_API_KEY is set in the environment
    if [ -z "$BUILDER_API_KEY" ]; then
      echo "❌ BUILDER_API_KEY environment variable is not set."
      echo "❌ Please set it with: export BUILDER_API_KEY=\"your_api_key\""
      echo "❌ Builder.io integration will be skipped."
    else
      bash "$BUILDERIO_SCRIPT" "$CLIENT_NAME" "$CLIENT_DOMAIN"
      
      # Create Traefik configuration for the Builder.io offline fallback
      # (This step is now handled by the builderio_provision.sh script)
    fi
  else
    echo "❌ Builder.io provisioning script not found at: $BUILDERIO_SCRIPT"
    echo "❌ Please ensure the script exists or update this script with the correct path."
  fi
fi

### DONE ###
echo "✅ Client ${CLIENT_DOMAIN} bootstrapped."
echo "🔧 Next step: cd ${CLIENT_DIR} && docker compose up -d"
echo ""
echo "📝 Available services after startup:"
echo "  • ERPNext:  https://${CLIENT_DOMAIN}"
echo "  • PeerTube: https://media.${CLIENT_DOMAIN}"
if [ "$BUILDER_ENABLE" = "true" ]; then
  echo "  • Builder.io integration is enabled - check your Builder.io dashboard"
fi
