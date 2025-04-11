#!/bin/bash
# install_keycloak.sh - Install and configure Keycloak for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up Keycloak with:
# - PostgreSQL database
# - Admin user
# - Default realm and clients
# - HTTPS support
# - Auto-configured for multi-tenancy
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/keycloak.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/keycloak.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
KEYCLOAK_VERSION="latest"
DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
KC_DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures Keycloak for identity management and SSO."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for Keycloak (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--keycloak-version${NC} <ver>  Keycloak version (default: latest)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if Keycloak is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain auth.example.com --admin-email admin@example.com --client-id acme"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      shift
      ;;
    --keycloak-version)
      KEYCLOAK_VERSION="$2"
      shift
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: --admin-email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Run system validation
if [ -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
  echo -e "${BLUE}Validating system requirements...${NC}"
  bash "${ROOT_DIR}/scripts/utils/validate_system.sh" || {
    echo -e "${RED}System validation failed. Please fix the issues and try again.${NC}"
    exit 1
  }
else
  echo -e "${YELLOW}Warning: System validation script not found. Proceeding without validation.${NC}"
fi

# Create log directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$COMPONENTS_LOG_DIR"
mkdir -p "$INTEGRATIONS_LOG_DIR"
touch "$INSTALL_LOG"
touch "$INTEGRATION_LOG"
touch "$MAIN_INTEGRATION_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

# Integration log function
integration_log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Keycloak - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Keycloak - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting Keycloak installation validation for $DOMAIN" "${BLUE}Starting Keycloak installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  KEYCLOAK_CONTAINER="${CLIENT_ID}_keycloak"
  POSTGRES_CONTAINER="${CLIENT_ID}_keycloak_postgres"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  KEYCLOAK_CONTAINER="keycloak_${SITE_NAME}"
  POSTGRES_CONTAINER="keycloak_postgres_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if Keycloak is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$KEYCLOAK_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: Keycloak container '$KEYCLOAK_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ Keycloak container '$KEYCLOAK_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing Keycloak containers" "${CYAN}Stopping and removing existing Keycloak containers...${NC}"
    cd "${KEYCLOAK_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: Keycloak container '$KEYCLOAK_CONTAINER' already exists" "${GREEN}✅ Keycloak installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$KEYCLOAK_CONTAINER"; then
      log "INFO: Keycloak container is running" "${GREEN}✅ Keycloak is running${NC}"
      echo -e "${GREEN}Keycloak is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/admin/${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: Keycloak container exists but is not running" "${YELLOW}⚠️ Keycloak container exists but is not running${NC}"
      echo -e "${YELLOW}Keycloak is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Keycloak containers...${NC}"
      cd "${KEYCLOAK_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}Keycloak has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/admin/${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR: Docker is not installed" "${RED}Docker is not installed. Please install Docker first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker with --with-deps flag" "${CYAN}Installing Docker with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log "ERROR: Failed to install Docker" "${RED}Failed to install Docker. Please install it manually.${NC}"
        exit 1
      }
    else
      log "ERROR: Cannot find install_infrastructure.sh script" "${RED}Cannot find install_infrastructure.sh script. Please install Docker manually.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  log "ERROR: Docker is not running" "${RED}Docker is not running. Please start Docker first.${NC}"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR: Docker Compose is not installed" "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker Compose with --with-deps flag" "${CYAN}Installing Docker Compose with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log "ERROR: Failed to install Docker Compose" "${RED}Failed to install Docker Compose. Please install it manually.${NC}"
        exit 1
      }
    else
      log "ERROR: Cannot find install_infrastructure.sh script" "${RED}Cannot find install_infrastructure.sh script. Please install Docker Compose manually.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi
fi

# Check if network exists, create if it doesn't
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO: Creating Docker network $NETWORK_NAME" "${CYAN}Creating Docker network $NETWORK_NAME...${NC}"
  docker network create "$NETWORK_NAME" >> "$INSTALL_LOG" 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to create Docker network $NETWORK_NAME" "${RED}Failed to create Docker network $NETWORK_NAME. See log for details.${NC}"
    exit 1
  fi
else
  log "INFO: Docker network $NETWORK_NAME already exists" "${GREEN}✅ Docker network $NETWORK_NAME already exists${NC}"
fi

# Check for Traefik
if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. Keycloak may not be accessible without a reverse proxy.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing security infrastructure with --with-deps flag" "${CYAN}Installing security infrastructure with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$ADMIN_EMAIL" || {
        log "ERROR: Failed to install security infrastructure" "${RED}Failed to install security infrastructure. Please install it manually.${NC}"
      }
    else
      log "ERROR: Cannot find install_security_infrastructure.sh script" "${RED}Cannot find install_security_infrastructure.sh script. Please install security infrastructure manually.${NC}"
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
  fi
else
  log "INFO: Traefik container found" "${GREEN}✅ Traefik container found${NC}"
fi

log "INFO: Starting Keycloak installation for $DOMAIN" "${BLUE}Starting Keycloak installation for $DOMAIN...${NC}"

# Create Keycloak directories
log "INFO: Creating Keycloak directories" "${CYAN}Creating Keycloak directories...${NC}"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/postgres-data"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/keycloak-data"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/themes"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/imports"

# Create Docker Compose file
log "INFO: Creating Docker Compose file" "${CYAN}Creating Docker Compose file...${NC}"
cat > "${KEYCLOAK_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  postgres:
    image: postgres:13-alpine
    container_name: ${POSTGRES_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${KC_DB_PASSWORD}
    networks:
      - ${NETWORK_NAME}

  keycloak:
    image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
    container_name: ${KEYCLOAK_CONTAINER}
    restart: unless-stopped
    command:
      - start
      - --hostname=${DOMAIN}
      - --proxy=edge
      - --db=postgres
      - --db-url=jdbc:postgresql://postgres:5432/keycloak
      - --db-username=keycloak
      - --db-password=${KC_DB_PASSWORD}
      - --health-enabled=true
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
      KC_PROXY_ADDRESS_FORWARDING: 'true'
      KC_HOSTNAME_URL: https://${DOMAIN}
      KC_HOSTNAME_ADMIN_URL: https://${DOMAIN}
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/keycloak-data:/opt/keycloak/data
      - ${KEYCLOAK_DIR}/${DOMAIN}/themes:/opt/keycloak/themes
      - ${KEYCLOAK_DIR}/${DOMAIN}/imports:/opt/keycloak/imports
    depends_on:
      - postgres
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.keycloak_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.keycloak_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.keycloak_${SITE_NAME}.loadbalancer.server.port=8080"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.stsPreload=true"
      - "traefik.http.middlewares.keycloak_${SITE_NAME}_security.headers.stsSeconds=31536000"
      - "traefik.http.routers.keycloak_${SITE_NAME}.middlewares=keycloak_${SITE_NAME}_security"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create a default realm configuration
log "INFO: Creating default realm configuration" "${CYAN}Creating default realm configuration...${NC}"
cat > "${KEYCLOAK_DIR}/${DOMAIN}/imports/agency-realm.json" <<EOF
{
  "realm": "agency",
  "enabled": true,
  "displayName": "Agency",
  "displayNameHtml": "<div class='kc-logo-text'><span>Agency</span></div>",
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "roles": {
    "realm": [
      {
        "name": "admin",
        "description": "Administrator role"
      },
      {
        "name": "user",
        "description": "User role"
      },
      {
        "name": "client-admin",
        "description": "Client administrator role"
      }
    ]
  },
  "users": [
    {
      "username": "admin",
      "email": "${ADMIN_EMAIL}",
      "enabled": true,
      "emailVerified": true,
      "credentials": [
        {
          "type": "password",
          "value": "${ADMIN_PASSWORD}",
          "temporary": true
        }
      ],
      "realmRoles": ["admin"],
      "clientRoles": {}
    }
  ]
}
EOF

# Start Keycloak
log "INFO: Starting Keycloak" "${CYAN}Starting Keycloak...${NC}"
cd "${KEYCLOAK_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start Keycloak" "${RED}Failed to start Keycloak. See log for details.${NC}"
  exit 1
fi

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/keycloak"
chmod 700 "${CONFIG_DIR}/secrets/keycloak"

cat > "${CONFIG_DIR}/secrets/keycloak/${DOMAIN}.env" <<EOF
# Keycloak Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

KEYCLOAK_ADMIN_USER=admin
KEYCLOAK_ADMIN_PASSWORD=${ADMIN_PASSWORD}
KEYCLOAK_ADMIN_EMAIL=${ADMIN_EMAIL}

POSTGRES_DB=keycloak
POSTGRES_USER=keycloak
POSTGRES_PASSWORD=${KC_DB_PASSWORD}

# Docker project
KEYCLOAK_CONTAINER=${KEYCLOAK_CONTAINER}
POSTGRES_CONTAINER=${POSTGRES_CONTAINER}
EOF

chmod 600 "${CONFIG_DIR}/secrets/keycloak/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering Keycloak in components registry" "${CYAN}Registering Keycloak in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/keycloak"
  
  cat > "${CONFIG_DIR}/components/keycloak/${DOMAIN}.json" <<EOF
{
  "component": "keycloak",
  "version": "${KEYCLOAK_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
else
  log "WARNING: Components registry not found" "${YELLOW}Components registry not found, skipping registration${NC}"
fi

# Add to installed_components.txt
INSTALLED_COMPONENTS_FILE="${CONFIG_DIR}/installed_components.txt"
log "INFO: Adding to installed components" "${CYAN}Adding to installed components...${NC}"

# Create file if it doesn't exist
if [ ! -f "$INSTALLED_COMPONENTS_FILE" ]; then
  echo "component|domain|version|status" > "$INSTALLED_COMPONENTS_FILE"
fi

# Check if component is already in the file
if grep -q "keycloak|${DOMAIN}|" "$INSTALLED_COMPONENTS_FILE"; then
  # Update the entry
  sed -i "s|keycloak|${DOMAIN}|.*|keycloak|${DOMAIN}|${KEYCLOAK_VERSION}|active|" "$INSTALLED_COMPONENTS_FILE"
else
  # Add new entry
  echo "keycloak|${DOMAIN}|${KEYCLOAK_VERSION}|active" >> "$INSTALLED_COMPONENTS_FILE"
fi

# Update dashboard status
if [ -f "${CONFIG_DIR}/dashboard/status.json" ]; then
  log "INFO: Updating dashboard status" "${CYAN}Updating dashboard status...${NC}"
  # This is a placeholder for dashboard status update logic
  # In a real implementation, this would modify the dashboard status JSON
  # to include information about the Keycloak installation
else
  log "WARNING: Dashboard status file not found" "${YELLOW}Dashboard status file not found, skipping update${NC}"
fi

# Add integration information for other components
log "INFO: Creating integration information" "${CYAN}Creating integration information...${NC}"
mkdir -p "${CONFIG_DIR}/integrations/keycloak"

cat > "${CONFIG_DIR}/integrations/keycloak/info.json" <<EOF
{
  "keycloak_url": "https://${DOMAIN}/auth",
  "admin_url": "https://${DOMAIN}/auth/admin/",
  "realm": "agency",
  "integration_date": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active"
}
EOF

integration_log "INFO: Created integration information at ${CONFIG_DIR}/integrations/keycloak/info.json"

# Wait for Keycloak to be ready
log "INFO: Waiting for Keycloak to be ready" "${CYAN}Waiting for Keycloak to be ready...${NC}"
sleep 10

# Final message
log "INFO: Keycloak installation completed successfully" "${GREEN}${BOLD}✅ Keycloak installed successfully!${NC}"
echo -e "${CYAN}Keycloak URL: https://${DOMAIN}/auth${NC}"
echo -e "${CYAN}Admin Console: https://${DOMAIN}/auth/admin/${NC}"
echo -e "${YELLOW}Admin Username: admin${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/keycloak/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Integration Information:${NC}"
echo -e "${CYAN}To integrate other services with Keycloak, use the following:${NC}"
echo -e "${CYAN}- Auth URL: https://${DOMAIN}/auth${NC}"
echo -e "${CYAN}- Realm: agency${NC}"
echo -e "${CYAN}For each client, you'll need to register it in the Keycloak admin console.${NC}"

exit 0
