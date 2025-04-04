#!/bin/bash
# install_keycloak.sh - Identity and access management system installation
# Part of Launchbox by NerdofMouth.com

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}${BOLD}🔐 Installing Keycloak Identity Server...${NC}\n"

# Display motto
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MOTTO_PATH="$SCRIPT_DIR/../../scripts/motto.sh"
if [ -f "$MOTTO_PATH" ]; then
  source "$MOTTO_PATH" && random_motto
  echo ""
fi

# Source the port manager
source /home/revelationx/CascadeProjects/foss-server-stack/scripts/port_manager.sh

# Default port for Keycloak
DEFAULT_KEYCLOAK_PORT=8080
DEFAULT_POSTGRES_PORT=5432

# Register the ports and get assigned values
KEYCLOAK_PORT=$(register_port "keycloak" "$DEFAULT_KEYCLOAK_PORT" "flexible")
POSTGRES_PORT=$(register_port "keycloak_postgres" "$DEFAULT_POSTGRES_PORT" "flexible")

echo "🔌 Keycloak will use port: $KEYCLOAK_PORT"
echo "🔌 Keycloak PostgreSQL will use port: $POSTGRES_PORT"

# Create directory for Keycloak
mkdir -p /opt/keycloak/data

# Create the docker-compose.yml file for Keycloak
cat > /opt/keycloak/docker-compose.yml <<EOL
version: '3'

services:
  postgres:
    image: postgres:13
    container_name: keycloak_postgres
    restart: unless-stopped
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak_password
    ports:
      - "$POSTGRES_PORT:5432"
    networks:
      - keycloak_network

  keycloak:
    image: quay.io/keycloak/keycloak:20.0.5
    container_name: keycloak
    command: start-dev
    depends_on:
      - postgres
    restart: unless-stopped
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak_password
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin_password
      # Replace with actual hostname in production
      KC_HOSTNAME: keycloak.example.com
    volumes:
      - ./data/keycloak:/opt/keycloak/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak.rule=Host(\`keycloak.example.com\`)"
      - "traefik.http.routers.keycloak.entrypoints=websecure"
      - "traefik.http.routers.keycloak.tls.certresolver=myresolver"
      - "traefik.http.services.keycloak.loadbalancer.server.port=$KEYCLOAK_PORT"
    ports:
      - "$KEYCLOAK_PORT:8080"
    networks:
      - keycloak_network
      - traefik

networks:
  keycloak_network:
  traefik:
    external: true
EOL

# Create basic configuration script for post-installation
cat > /opt/keycloak/setup-realm.sh <<EOL
#!/bin/bash
# This script helps set up a basic realm in Keycloak

# Replace these variables with your actual values
KEYCLOAK_URL="https://keycloak.example.com"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin_password"
REALM_NAME="foss-stack"
CLIENT_ID="foss-server-stack"
CLIENT_SECRET=\$(openssl rand -hex 16)

# Get admin token
TOKEN=\$(curl -s -X POST "\$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=\$ADMIN_USER" \
  -d "password=\$ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

# Create a new realm
curl -s -X POST "\$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer \$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "'\$REALM_NAME'",
    "enabled": true,
    "displayName": "FOSS Server Stack",
    "displayNameHtml": "<div class=\"kc-logo-text\"><span>FOSS Server Stack</span></div>"
  }'

# Create a new client
curl -s -X POST "\$KEYCLOAK_URL/admin/realms/\$REALM_NAME/clients" \
  -H "Authorization: Bearer \$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "'\$CLIENT_ID'",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "secret": "'\$CLIENT_SECRET'",
    "redirectUris": ["*"],
    "webOrigins": ["+"],
    "protocol": "openid-connect",
    "publicClient": false,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": false,
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true
  }'

echo "Keycloak realm \$REALM_NAME and client \$CLIENT_ID created."
echo "Client secret: \$CLIENT_SECRET"
echo "Please save this secret in a secure location!"
EOL

chmod +x /opt/keycloak/setup-realm.sh

# Start Keycloak
cd /opt/keycloak
docker-compose up -d

echo "✅ Keycloak installed successfully!"
echo "🔐 Default admin credentials:"
echo "   - Username: admin"
echo "   - Password: admin_password"
echo "🌐 Access Keycloak at: https://keycloak.example.com (Internal port: $KEYCLOAK_PORT)"
echo "⚠️  IMPORTANT: Change the default credentials and update the hostname in the docker-compose.yml file!"
echo "🧰 Run the setup-realm.sh script after updating the variables to create a basic realm and client."
echo "📝 Port allocation information saved to $PORT_DB"
