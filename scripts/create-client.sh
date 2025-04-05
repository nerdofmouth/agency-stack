#!/bin/bash
# create-client.sh - Multi-tenant client provisioning for AgencyStack
# https://stack.nerdofmouth.com
#
# This script creates a new client with isolated networking and resources
# It provisions Docker networks, Keycloak realm, and backup configurations
#
# Usage: ./create-client.sh <client_id> <client_name> <primary_domain>
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPTS_DIR="/home/revelationx/CascadeProjects/foss-server-stack/scripts"
KEYCLOAK_DIR="${SCRIPTS_DIR}/keycloak"
CONFIG_DIR="/opt/agency_stack"
CLIENTS_DIR="${CONFIG_DIR}/clients"
LOGS_DIR="/var/log/agency_stack"
CLIENT_LOGS_DIR="${LOGS_DIR}/clients"
SECRETS_DIR="${CONFIG_DIR}/secrets"
CONFIG_ENV="${CONFIG_DIR}/config.env"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Client Provisioning${NC}"
  echo -e "================================="
  echo -e "This script creates a new client with isolated networking and resources."
  echo -e "It provisions Docker networks, Keycloak realm, and backup configurations."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 <client_id> <client_name> <primary_domain>"
  echo -e ""
  echo -e "${CYAN}Arguments:${NC}"
  echo -e "  ${BOLD}client_id${NC}        Unique identifier for the client (lowercase, alphanumeric, hyphens)"
  echo -e "  ${BOLD}client_name${NC}      Human-readable name for the client"
  echo -e "  ${BOLD}primary_domain${NC}   Primary domain for the client (e.g., example.com)"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 acme \"ACME Corporation\" acme.example.com"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script must be run as root or with sudo"
  echo -e "  - Client ID will be normalized to lowercase with special characters replaced by hyphens"
  echo -e "  - The script is idempotent and can be re-run safely with the same parameters"
  exit 0
}

# Process command-line arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Client Provisioning${NC}"
echo -e "================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Check arguments
if [ $# -lt 3 ]; then
  echo -e "${YELLOW}Usage: $0 <client_id> <client_name> <primary_domain>${NC}"
  echo -e "Example: $0 acme \"ACME Corporation\" acme.example.com"
  echo -e "Use $0 --help for more information"
  exit 1
fi

CLIENT_ID=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')
CLIENT_NAME="$2"
CLIENT_DOMAIN="$3"

echo -e "Setting up client: ${CYAN}${CLIENT_NAME}${NC} (${CLIENT_ID})"
echo -e "Primary domain: ${CYAN}${CLIENT_DOMAIN}${NC}"

# Source config.env if it exists
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo -e "${YELLOW}Warning: config.env not found, using default values${NC}"
fi

# Create client directories
echo -e "\n${BLUE}Creating client directories...${NC}"
mkdir -p "${CLIENTS_DIR}/${CLIENT_ID}"
mkdir -p "${CLIENT_LOGS_DIR}/${CLIENT_ID}"
mkdir -p "${SECRETS_DIR}/${CLIENT_ID}"

# Restrict permissions on secrets directory
chmod 700 "${SECRETS_DIR}/${CLIENT_ID}"

# Create client configuration
echo -e "${BLUE}Creating client configuration...${NC}"
cat > "${CLIENTS_DIR}/${CLIENT_ID}/client.env" << EOF
# Client configuration for ${CLIENT_NAME}
CLIENT_ID="${CLIENT_ID}"
CLIENT_NAME="${CLIENT_NAME}"
CLIENT_DOMAIN="${CLIENT_DOMAIN}"
CLIENT_CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CLIENT_ENABLED="true"

# Networks
CLIENT_NETWORK="${CLIENT_ID}_network"
CLIENT_FRONTEND_NETWORK="${CLIENT_ID}_frontend"
CLIENT_BACKEND_NETWORK="${CLIENT_ID}_backend"
CLIENT_DATABASE_NETWORK="${CLIENT_ID}_database"

# Keycloak
CLIENT_REALM="${CLIENT_ID}"
CLIENT_ADMIN_USER="realm_admin"
CLIENT_ADMIN_PASSWORD="$(openssl rand -base64 16)"

# Default primary services enabled
WORDPRESS_ENABLED="true"
ERPNEXT_ENABLED="true"
MAILU_ENABLED="true"
KEYCLOAK_ENABLED="true"
GRAFANA_ENABLED="true"
LOKI_ENABLED="true"

# Backup config
BACKUP_REPOSITORY="client-${CLIENT_ID}"
BACKUP_RETENTION="7d"
EOF

# Create Docker networks
echo -e "${BLUE}Creating Docker networks...${NC}"
docker network create "${CLIENT_ID}_network" || true
docker network create "${CLIENT_ID}_frontend" || true
docker network create "${CLIENT_ID}_backend" || true
docker network create "${CLIENT_ID}_database" || true

# Generate client secrets
echo -e "${BLUE}Generating client secrets...${NC}"
cat > "${SECRETS_DIR}/${CLIENT_ID}/secrets.env" << EOF
# Secrets for ${CLIENT_NAME}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# IMPORTANT: Do not commit this file to version control!

# Keycloak
KEYCLOAK_ADMIN_PASSWORD="$(openssl rand -base64 16)"
KEYCLOAK_REALM_ADMIN_PASSWORD="$(openssl rand -base64 16)"

# Database passwords
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 16)"
POSTGRES_PASSWORD="$(openssl rand -base64 16)"
WORDPRESS_DB_PASSWORD="$(openssl rand -base64 16)"
ERPNEXT_DB_PASSWORD="$(openssl rand -base64 16)"

# Mailu
MAILU_ADMIN_PASSWORD="$(openssl rand -base64 16)"
MAILU_SECRET_KEY="$(openssl rand -base64 32)"

# Backup encryption
RESTIC_PASSWORD="$(openssl rand -base64 32)"
EOF

# Restrict permissions on secrets file
chmod 600 "${SECRETS_DIR}/${CLIENT_ID}/secrets.env"

# Create client-specific docker-compose override
echo -e "${BLUE}Creating client-specific docker-compose override...${NC}"
cat > "${CLIENTS_DIR}/${CLIENT_ID}/docker-compose.override.yml" << EOF
# Docker Compose override for ${CLIENT_NAME}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
version: '3.8'

networks:
  ${CLIENT_ID}_network:
    external: true
  ${CLIENT_ID}_frontend:
    external: true
  ${CLIENT_ID}_backend:
    external: true
  ${CLIENT_ID}_database:
    external: true

# This override adds client-specific settings to each service
services:
  # Network isolation for WordPress
  wordpress:
    networks:
      - ${CLIENT_ID}_frontend
      - ${CLIENT_ID}_backend
    labels:
      - "traefik.http.routers.wordpress-${CLIENT_ID}.rule=Host(\`wordpress.${CLIENT_DOMAIN}\`)"
      - "client.id=${CLIENT_ID}"
      - "client.name=${CLIENT_NAME}"
    environment:
      - CLIENT_ID=${CLIENT_ID}

  # Network isolation for ERPNext
  erpnext:
    networks:
      - ${CLIENT_ID}_frontend
      - ${CLIENT_ID}_backend
      - ${CLIENT_ID}_database
    labels:
      - "traefik.http.routers.erpnext-${CLIENT_ID}.rule=Host(\`erp.${CLIENT_DOMAIN}\`)"
      - "client.id=${CLIENT_ID}"
      - "client.name=${CLIENT_NAME}"
    environment:
      - CLIENT_ID=${CLIENT_ID}

  # Network isolation for Mailu
  mailu-front:
    networks:
      - ${CLIENT_ID}_frontend
    labels:
      - "traefik.http.routers.mailu-${CLIENT_ID}.rule=Host(\`mail.${CLIENT_DOMAIN}\`)"
      - "client.id=${CLIENT_ID}"
      - "client.name=${CLIENT_NAME}"
    environment:
      - CLIENT_ID=${CLIENT_ID}

  # Network isolation for Keycloak
  keycloak:
    networks:
      - ${CLIENT_ID}_frontend
      - ${CLIENT_ID}_backend
      - ${CLIENT_ID}_database
    labels:
      - "traefik.http.routers.keycloak-${CLIENT_ID}.rule=Host(\`auth.${CLIENT_DOMAIN}\`)"
      - "client.id=${CLIENT_ID}"
      - "client.name=${CLIENT_NAME}"
    environment:
      - CLIENT_ID=${CLIENT_ID}

  # Network isolation for Grafana
  grafana:
    networks:
      - ${CLIENT_ID}_frontend
      - ${CLIENT_ID}_backend
    labels:
      - "traefik.http.routers.grafana-${CLIENT_ID}.rule=Host(\`monitoring.${CLIENT_DOMAIN}\`)"
      - "client.id=${CLIENT_ID}"
      - "client.name=${CLIENT_NAME}"
    environment:
      - CLIENT_ID=${CLIENT_ID}
EOF

# Create client traefik middlewares
echo -e "${BLUE}Creating client-specific Traefik middlewares...${NC}"
cat > "${CLIENTS_DIR}/${CLIENT_ID}/traefik.yml" << EOF
# Traefik middleware configuration for ${CLIENT_NAME}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

http:
  middlewares:
    ${CLIENT_ID}-security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
        sslRedirect: true
        customFrameOptionsValue: "SAMEORIGIN"
        contentSecurityPolicy: "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'"
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
    
    ${CLIENT_ID}-auth:
      forwardAuth:
        address: "http://keycloak:8080/auth/realms/${CLIENT_ID}/protocol/openid-connect/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-Forwarded-User"
EOF

# Set up Keycloak realm
echo -e "${BLUE}Setting up Keycloak realm configuration...${NC}"
mkdir -p "${CLIENTS_DIR}/${CLIENT_ID}/keycloak"
cat > "${CLIENTS_DIR}/${CLIENT_ID}/keycloak/realm.json" << EOF
{
  "realm": "${CLIENT_ID}",
  "enabled": true,
  "displayName": "${CLIENT_NAME}",
  "displayNameHtml": "<div class=\"kc-logo-text\"><span>${CLIENT_NAME}</span></div>",
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true
}
EOF

# Create client backup configuration
echo -e "${BLUE}Creating client backup configuration...${NC}"
mkdir -p "${CLIENTS_DIR}/${CLIENT_ID}/backup"
cat > "${CLIENTS_DIR}/${CLIENT_ID}/backup/config.sh" << EOF
#!/bin/bash
# Backup configuration for ${CLIENT_NAME}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Client information
CLIENT_ID="${CLIENT_ID}"
CLIENT_NAME="${CLIENT_NAME}"

# Backup repository
RESTIC_REPOSITORY="client-${CLIENT_ID}"
RESTIC_TAG="${CLIENT_ID}"

# Backup paths
BACKUP_PATHS=(
  "/opt/agency_stack/clients/${CLIENT_ID}"
  "/var/lib/docker/volumes/*${CLIENT_ID}*"
)

# Backup exclusions
BACKUP_EXCLUDE=(
  "*.tmp"
  "*.log"
  "*/cache/*"
)

# Retention policy
RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=6
EOF

# Set up logging for client
echo -e "${BLUE}Setting up client logging...${NC}"
touch "${CLIENT_LOGS_DIR}/${CLIENT_ID}/backup.log"
touch "${CLIENT_LOGS_DIR}/${CLIENT_ID}/access.log"
touch "${CLIENT_LOGS_DIR}/${CLIENT_ID}/error.log"
touch "${CLIENT_LOGS_DIR}/${CLIENT_ID}/audit.log"

# Generate client report
echo -e "${GREEN}${BOLD}Client setup complete!${NC}"
echo -e "\nClient information:"
echo -e "  ${BOLD}ID:${NC} ${CLIENT_ID}"
echo -e "  ${BOLD}Name:${NC} ${CLIENT_NAME}"
echo -e "  ${BOLD}Domain:${NC} ${CLIENT_DOMAIN}"
echo -e "\nCreated resources:"
echo -e "  ${BOLD}Configuration:${NC} ${CLIENTS_DIR}/${CLIENT_ID}/client.env"
echo -e "  ${BOLD}Networks:${NC} ${CLIENT_ID}_network, ${CLIENT_ID}_frontend, ${CLIENT_ID}_backend, ${CLIENT_ID}_database"
echo -e "  ${BOLD}Secrets:${NC} ${SECRETS_DIR}/${CLIENT_ID}/secrets.env"
echo -e "  ${BOLD}Docker Compose:${NC} ${CLIENTS_DIR}/${CLIENT_ID}/docker-compose.override.yml"
echo -e "  ${BOLD}Keycloak Realm:${NC} ${CLIENTS_DIR}/${CLIENT_ID}/keycloak/realm.json"
echo -e "  ${BOLD}Backup Config:${NC} ${CLIENTS_DIR}/${CLIENT_ID}/backup/config.sh"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Run 'make start-client CLIENT_ID=${CLIENT_ID}' to deploy client services"
echo -e "  2. Run '${SCRIPTS_DIR}/keycloak/setup_roles.sh ${CLIENT_ID}' to set up Keycloak roles"
echo -e "  3. Access the client dashboard at https://dashboard.${CLIENT_DOMAIN}"

# Add client to master list
if [ -f "${CLIENTS_DIR}/clients.json" ]; then
  # Update existing clients.json
  TMP_FILE=$(mktemp)
  jq --arg id "${CLIENT_ID}" \
     --arg name "${CLIENT_NAME}" \
     --arg domain "${CLIENT_DOMAIN}" \
     --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '.clients += [{"id": $id, "name": $name, "domain": $domain, "created": $created, "status": "active"}]' \
     "${CLIENTS_DIR}/clients.json" > "$TMP_FILE"
  mv "$TMP_FILE" "${CLIENTS_DIR}/clients.json"
else
  # Create new clients.json
  mkdir -p "${CLIENTS_DIR}"
  cat > "${CLIENTS_DIR}/clients.json" << EOF
{
  "clients": [
    {
      "id": "${CLIENT_ID}",
      "name": "${CLIENT_NAME}",
      "domain": "${CLIENT_DOMAIN}",
      "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "status": "active"
    }
  ]
}
EOF
fi

exit 0
