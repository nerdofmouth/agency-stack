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
    networks:
      - traefik

networks:
  traefik:
    external: true
EOF

### PROVISION Builder.io space (optional, Claude-insertable step) ###
echo "🔧 Checking for Builder.io integration..."

# Source the .env file to get the BUILDER_ENABLE variable
source "$ENV_FILE"

if [ "$BUILDER_ENABLE" = "true" ]; then
  echo "🔧 Provisioning Builder.io space for ${CLIENT_NAME}..."
  # Correct path to the builderio_provision.sh script
  bash ../../scripts/builderio_provision.sh "$CLIENT_NAME" "$CLIENT_DOMAIN"
fi

### DONE ###
echo "✅ Client ${CLIENT_DOMAIN} bootstrapped."
echo "🔧 Next step: cd ${CLIENT_DIR} && docker compose up -d"
