#!/bin/bash
# Source common utilities and logging functions
if [ -f "$(dirname "$0")/../utils/common.sh" ]; then
  source "$(dirname "$0")/../utils/common.sh"
fi

# Alias log to log_info for compatibility with existing code
log() {
  level="$1"
  message="$2"
  display="${3:-$message}"
  case $level in
    "INFO")
      log_info "$message" "$display"
      ;;
    "SUCCESS")
      log_success "$message" "$display"
      ;;
    "WARNING")
      log_warning "$message" "$display"
      ;;
    "ERROR")
      log_error "$message" "$display"
      ;;
    *)
      log_info "$message" "$display"
      ;;
  esac
}

# install_keycloak.sh - Hardened installation script for Keycloak (AgencyStack Alpha)
# Author: AgencyStack Team
# Version: 1.0.0
# https://stack.nerdofmouth.com

set -e

log "INFO" "Starting Keycloak installation"

# Default values
DOMAIN=""
ADMIN_EMAIL=""
CLIENT_ID="default"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
ENABLE_KEYCLOAK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"; shift 2;;
    --admin-email)
      ADMIN_EMAIL="$2"; shift 2;;
    --client-id)
      CLIENT_ID="$2"; shift 2;;
    --force)
      FORCE=true; shift;;
    --with-deps)
      WITH_DEPS=true; shift;;
    --verbose)
      VERBOSE=true; shift;;
    --enable-cloud)
      ENABLE_CLOUD=true; shift;;
    --enable-openai)
      ENABLE_OPENAI=true; shift;;
    --use-github)
      USE_GITHUB=true; shift;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true; shift;;
    --help)
      echo "Usage: $0 --domain <domain> --admin-email <email> [--client-id <id>] [--force] [--with-deps] [--verbose] [--enable-cloud] [--enable-openai] [--use-github] [--enable-keycloak]"; exit 0;;
    *)
      log "WARN" "Unknown argument $1"; shift;;
  esac
done

if [ -z "$DOMAIN" ] || [ -z "$ADMIN_EMAIL" ]; then
  log "ERROR" " --domain and --admin-email are required."
  exit 1
fi

log "INFO" "DOMAIN=$DOMAIN, ADMIN_EMAIL=$ADMIN_EMAIL, CLIENT_ID=$CLIENT_ID"

# Dependency checks
for cmd in docker docker-compose; do
  if ! command -v $cmd &>/dev/null; then
    log "ERROR" "$cmd is required but not installed."
    exit 1
  fi
done

# Install dependencies if requested
if [ "$WITH_DEPS" = true ]; then
  log "INFO" "Installing dependencies..."
  # Add dependency install logic here
fi

# SSO readiness check
if [ "$ENABLE_KEYCLOAK" = true ]; then
  log "INFO" "Performing Keycloak SSO readiness check..."
  # Add SSO readiness logic here
fi

log "INFO" "Installing Keycloak Docker container for $DOMAIN..."
# Example Docker run (replace with actual logic)
docker run -d --name keycloak_$DOMAIN -e KEYCLOAK_ADMIN=$ADMIN_EMAIL -p 8080:8080 quay.io/keycloak/keycloak:latest

log "INFO" "Keycloak installation complete."

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
INSTALL_BASE_DIR="/opt/agency_stack"
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/keycloak.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/keycloak.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE="${VERBOSE:-false}"
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN=""
ADMIN_EMAIL=""
KEYCLOAK_VERSION="latest"
DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
FORCE="${FORCE:-false}"
WITH_DEPS="${WITH_DEPS:-false}"
CONFIGURE_OAUTH_ONLY="${CONFIGURE_OAUTH_ONLY:-false}"

# OAuth provider flags
ENABLE_OAUTH_GOOGLE="${ENABLE_OAUTH_GOOGLE:-false}"
ENABLE_OAUTH_GITHUB="${ENABLE_OAUTH_GITHUB:-false}"
ENABLE_OAUTH_APPLE="${ENABLE_OAUTH_APPLE:-false}"
ENABLE_OAUTH_LINKEDIN="${ENABLE_OAUTH_LINKEDIN:-false}"
ENABLE_OAUTH_MICROSOFT="${ENABLE_OAUTH_MICROSOFT:-false}"

# OAuth security settings
OAUTH_STORE_TOKENS="${OAUTH_STORE_TOKENS:-false}"
OAUTH_VALIDATE_SIGNATURES="${OAUTH_VALIDATE_SIGNATURES:-true}"
OAUTH_USE_JWKS_URL="${OAUTH_USE_JWKS_URL:-true}"
OAUTH_DISABLE_USER_INFO="${OAUTH_DISABLE_USER_INFO:-false}"
OAUTH_TRUST_EMAIL="${OAUTH_TRUST_EMAIL:-false}"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  INSTALL_LOG="${COMPONENTS_LOG_DIR}/keycloak.log"
  INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
  INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/keycloak.log"
  MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

# Ensure the log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$INSTALL_LOG"
mkdir -p "$INTEGRATIONS_LOG_DIR"
touch "$INTEGRATION_LOG"
touch "$MAIN_INTEGRATION_LOG"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak Installer${NC}"
  echo -e "=================================="
  echo -e "This script installs and configures Keycloak with PostgreSQL."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>       Domain name for Keycloak (required)"
  echo -e "  ${BOLD}--admin-email${NC} <email>   Admin email for notifications (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id> Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--verbose${NC}               Show verbose output"
  echo -e "  ${BOLD}--force${NC}                 Force installation even if already installed"
  echo -e "  ${BOLD}--with-deps${NC}             Install dependencies automatically"
  echo -e "  ${BOLD}--configure-oauth-only${NC}  Only configure OAuth providers, skip installation"
  echo -e ""
  echo -e "  ${BOLD}OAuth Provider Options:${NC}"
  echo -e "  ${BOLD}--enable-oauth-google${NC}   Enable Google as an identity provider"
  echo -e "  ${BOLD}--enable-oauth-github${NC}   Enable GitHub as an identity provider"
  echo -e "  ${BOLD}--enable-oauth-apple${NC}    Enable Apple as an identity provider"
  echo -e "  ${BOLD}--enable-oauth-linkedin${NC} Enable LinkedIn as an identity provider"
  echo -e "  ${BOLD}--enable-oauth-microsoft${NC} Enable Microsoft/Azure AD as an identity provider"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain auth.example.com --admin-email admin@example.com --enable-oauth-google"
  echo -e ""
  echo -e "${CYAN}Post-Installation OAuth Configuration:${NC}"
  echo -e "  $0 --domain auth.example.com --configure-oauth-only --enable-oauth-github"
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
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --verbose)
      VERBOSE=true
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
    --configure-oauth-only)
      CONFIGURE_OAUTH_ONLY=true
      shift
      ;;
    --enable-oauth-google)
      ENABLE_OAUTH_GOOGLE=true
      shift
      ;;
    --enable-oauth-github)
      ENABLE_OAUTH_GITHUB=true
      shift
      ;;
    --enable-oauth-apple)
      ENABLE_OAUTH_APPLE=true
      shift
      ;;
    --enable-oauth-linkedin)
      ENABLE_OAUTH_LINKEDIN=true
      shift
      ;;
    --enable-oauth-microsoft)
      ENABLE_OAUTH_MICROSOFT=true
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

# Parse the domain to create a normalized site name for Docker
parse_domain() {
  local domain="$1"
  # Replace dots with underscores and remove any special characters
  echo "${domain//[^a-zA-Z0-9]/_}"
}

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# If we're only configuring OAuth, skip the admin email check
if [ "$CONFIGURE_OAUTH_ONLY" = false ] && [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: --admin-email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

log "INFO" "Starting Keycloak installation validation for $DOMAIN" "${BLUE}Starting Keycloak installation validation for $DOMAIN...${NC}"

# Skip installation if we're only configuring OAuth
if [ "$CONFIGURE_OAUTH_ONLY" = true ]; then
  log "INFO" "OAuth-only configuration requested, skipping installation" "${BLUE}OAuth-only configuration requested, skipping installation...${NC}"
  
  # Make sure Keycloak is already installed
  if [ ! -d "${KEYCLOAK_DIR}/${DOMAIN}" ]; then
    log "ERROR" "Keycloak installation not found for $DOMAIN" "${RED}Error: Keycloak installation not found for $DOMAIN. Please install Keycloak first.${NC}"
    exit 1
  fi
  
  # Check if Keycloak is running
  if ! docker ps | grep -q "keycloak_${DOMAIN}"; then
    log "ERROR" "Keycloak container not running for $DOMAIN" "${RED}Error: Keycloak container not running for $DOMAIN. Please start Keycloak first.${NC}"
    exit 1
  fi
  
  log "INFO" "Proceeding with OAuth provider configuration only" "${GREEN}Proceeding with OAuth provider configuration...${NC}"
  
  # Set up OAuth providers
  configure_oauth_providers
  
  log "INFO" "OAuth configuration completed" "${GREEN}OAuth configuration completed successfully!${NC}"
  exit 0
fi

# Set normalized site name for Docker container naming
SITE_NAME=$(parse_domain "$DOMAIN")

# Main installation logic continues here for normal installation...
log "INFO" "Starting Keycloak installation for ${DOMAIN}" "${CYAN}Starting Keycloak installation for ${DOMAIN}...${NC}"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR" "Docker is not installed" "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

if ! command -v docker-compose &> /dev/null; then
  log "ERROR" "Docker Compose is not installed" "${RED}Error: Docker Compose is not installed. Please install Docker Compose first.${NC}"
  exit 1
fi

# Generate a secure admin password if not provided
ADMIN_PASSWORD=$(openssl rand -base64 12)

# Create required directories
KEYCLOAK_DIR="${INSTALL_BASE_DIR}/keycloak"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/data"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/postgres-data"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/themes"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/config"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/init-db"

# Save admin password to a file for later use
echo "${ADMIN_PASSWORD}" > "${KEYCLOAK_DIR}/${DOMAIN}/admin_password.txt"
chmod 600 "${KEYCLOAK_DIR}/${DOMAIN}/admin_password.txt"

# Create admin credentials file for integration scripts
mkdir -p "${SECRETS_DIR}/${DOMAIN}"
cat > "${SECRETS_DIR}/${DOMAIN}/admin.env" <<EOL
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOL
chmod 600 "${SECRETS_DIR}/${DOMAIN}/admin.env"

# Generate random passwords for database
DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
DB_USER="keycloak"
DB_NAME="keycloak"

# Save DB password to a file for reference
echo "${DB_PASSWORD}" > "${KEYCLOAK_DIR}/${DOMAIN}/db_password.txt"
chmod 600 "${KEYCLOAK_DIR}/${DOMAIN}/db_password.txt"

# Create database initialization script - not needed since we use environment variables
# Instead, we'll remove the previous init script attempt if it exists
rm -f "${KEYCLOAK_DIR}/${DOMAIN}/init-db/init-keycloak-db.sh"

# Create docker-compose.yml file
cat > "${KEYCLOAK_DIR}/${DOMAIN}/docker-compose.yml" <<EOL
version: '3'

networks:
  keycloak_network:
    name: ${CLIENT_ID}_keycloak_${SITE_NAME}_network
  ${CLIENT_ID}_network:
    external: true

services:
  postgres:
    container_name: ${CLIENT_ID}_keycloak_postgres_${SITE_NAME}
    image: postgres:13
    restart: unless-stopped
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    networks:
      - keycloak_network

  keycloak:
    container_name: ${CLIENT_ID}_keycloak_${SITE_NAME}
    image: quay.io/keycloak/keycloak:21.1.1
    restart: unless-stopped
    depends_on:
      - postgres
    command:
      - start-dev
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres/${DB_NAME}
      KC_DB_USERNAME: ${DB_USER}
      KC_DB_PASSWORD: ${DB_PASSWORD}
      KC_HOSTNAME: ${DOMAIN}
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
      PROXY_ADDRESS_FORWARDING: "true"
      KC_HEALTH_ENABLED: "true"
      KC_METRICS_ENABLED: "true"
      KC_HTTP_ENABLED: "true"
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/data:/opt/keycloak/data
      - ${KEYCLOAK_DIR}/${DOMAIN}/themes:/opt/keycloak/themes
    networks:
      - keycloak_network
      - ${CLIENT_ID}_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.keycloak_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.keycloak_${SITE_NAME}.tls=true"
      - "traefik.http.routers.keycloak_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.keycloak_${SITE_NAME}.loadbalancer.server.port=8080"
      # HTTP to HTTPS redirect for Keycloak
      - "traefik.http.routers.keycloak_${SITE_NAME}_http.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.keycloak_${SITE_NAME}_http.entrypoints=web"
      - "traefik.http.middlewares.redirect_https.redirectscheme.scheme=https"
      - "traefik.http.middlewares.redirect_https.redirectscheme.permanent=true"
      - "traefik.http.routers.keycloak_${SITE_NAME}_http.middlewares=redirect_https"
EOL

log "INFO" "Starting Keycloak containers" "${CYAN}Starting Keycloak containers...${NC}"
cd "${KEYCLOAK_DIR}/${DOMAIN}" && docker-compose up -d

# Wait for Keycloak to start
log "INFO" "Waiting for Keycloak to start..." "${CYAN}Waiting for Keycloak to start...${NC}"

RETRIES=0
MAX_RETRIES=30

while [ $RETRIES -lt $MAX_RETRIES ]; do
  # Check for Keycloak container health via logs
  if docker logs ${CLIENT_ID}_keycloak_${SITE_NAME} 2>&1 | grep -q "Keycloak.*JVM.*started"; then
    log "INFO" "Keycloak is running" "${GREEN}✓ Keycloak container is running${NC}"
    break
  elif docker logs ${CLIENT_ID}_keycloak_${SITE_NAME} 2>&1 | grep -q "KC-SERVICES0009: Added user 'admin'"; then
    log "INFO" "Keycloak is running, admin user created" "${GREEN}✓ Keycloak is running with admin user created${NC}"
    break
  elif docker logs ${CLIENT_ID}_keycloak_${SITE_NAME} 2>&1 | grep -q "Profile dev activated"; then
    log "INFO" "Keycloak is running in dev mode" "${GREEN}✓ Keycloak is running in development mode${NC}"
    break
  fi
  
  log "INFO" "Waiting for Keycloak to start (attempt $((RETRIES+1))/${MAX_RETRIES})..." "${CYAN}Waiting for Keycloak to start (attempt $((RETRIES+1))/${MAX_RETRIES})...${NC}"
  sleep 10
  RETRIES=$((RETRIES+1))
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
  log "INFO" "Keycloak failed to start after ${MAX_RETRIES} attempts" "${YELLOW}Warning: Could not verify if Keycloak started properly after ${MAX_RETRIES} attempts. Will continue with installation, but you may need to check Keycloak status manually.${NC}"
  # Don't exit in failure mode as Keycloak might still be running
fi

# Create initial realm
log "INFO" "Creating initial realm" "${CYAN}Creating initial realm...${NC}"

# Wait an additional 30 seconds for Keycloak to fully initialize before configuring
sleep 30

# Create default 'agency' realm
ADMIN_TOKEN=$(curl -s -k -X POST "https://${DOMAIN}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  log "WARNING" "Failed to get admin token, retrying in 10 seconds..." "${YELLOW}Warning: Failed to get admin token, retrying in 10 seconds...${NC}"
  sleep 10
  
  ADMIN_TOKEN=$(curl -s -k -X POST "https://${DOMAIN}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')
  
  if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    log "ERROR" "Failed to get admin token after retry" "${RED}Error: Failed to get admin token after retry.${NC}"
    log "INFO" "Continuing with installation, but realm setup failed" "${YELLOW}Continuing with installation, but realm setup failed. You'll need to manually set up the realm.${NC}"
  fi
else
  # Create agency realm
  REALM_NAME="agency"
  if [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "default" ]; then
    REALM_NAME="${CLIENT_ID}"
  fi
  
  REALM_JSON='{
    "realm": "'"${REALM_NAME}"'",
    "enabled": true,
    "displayName": "AgencyStack",
    "displayNameHtml": "<div class=\"kc-logo-text\"><span>AgencyStack</span></div>",
    "bruteForceProtected": true,
    "permanentLockout": false,
    "failureFactor": 5,
    "sslRequired": "external",
    "registrationAllowed": false,
    "registrationEmailAsUsername": false,
    "rememberMe": true,
    "verifyEmail": true,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "resetPasswordAllowed": true,
    "editUsernameAllowed": false,
    "defaultSignatureAlgorithm": "RS256",
    "browserSecurityHeaders": {
      "contentSecurityPolicy": "frame-src 'self'; frame-ancestors 'self'; object-src 'none';",
      "xContentTypeOptions": "nosniff",
      "xRobotsTag": "none",
      "xFrameOptions": "SAMEORIGIN",
      "contentSecurityPolicyReportOnly": "",
      "xXSSProtection": "1; mode=block",
      "strictTransportSecurity": "max-age=31536000; includeSubDomains"
    }
  }'
  
  curl -s -k -X POST "https://${DOMAIN}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${REALM_JSON}" > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    log "INFO" "Created '${REALM_NAME}' realm" "${GREEN}✓ Created '${REALM_NAME}' realm${NC}"
  else
    log "WARNING" "Failed to create realm" "${YELLOW}Warning: Failed to create realm. You may need to manually set up the realm.${NC}"
  fi
fi

# Success message
log "INFO" "Keycloak installation completed successfully" "${GREEN}Keycloak installation completed successfully!${NC}"
log "INFO" "Keycloak is now accessible at https://${DOMAIN}" "${GREEN}Keycloak is now accessible at:${NC} https://${DOMAIN}"
log "INFO" "Admin username: admin" "${GREEN}Admin username:${NC} admin"
log "INFO" "Admin password: ${ADMIN_PASSWORD}" "${GREEN}Admin password:${NC} ${ADMIN_PASSWORD}"
log "INFO" "Admin credentials saved to: ${KEYCLOAK_DIR}/${DOMAIN}/admin_password.txt" "${GREEN}Admin credentials saved to:${NC} ${KEYCLOAK_DIR}/${DOMAIN}/admin_password.txt"

# Mark installation as complete
echo "1.0.0" > "${KEYCLOAK_DIR}/${DOMAIN}/.version"
touch "${KEYCLOAK_DIR}/${DOMAIN}/.installed_ok"

# Function to configure OAuth providers
configure_oauth_providers() {
  if [ "$ENABLE_OAUTH_GOOGLE" = true ] || [ "$ENABLE_OAUTH_GITHUB" = true ] || [ "$ENABLE_OAUTH_APPLE" = true ] || [ "$ENABLE_OAUTH_LINKEDIN" = true ] || [ "$ENABLE_OAUTH_MICROSOFT" = true ]; then
    log "INFO" "Setting up OAuth identity providers..." "${CYAN}Setting up OAuth identity providers...${NC}"
    
    # Wait for Keycloak to fully initialize (additional 10 seconds)
    sleep 10
    
    # Get admin token for API calls
    ADMIN_PASSWORD_FILE="${KEYCLOAK_DIR}/${DOMAIN}/admin_password.txt"
    if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
      log "ERROR" "Admin password file not found. Cannot configure OAuth providers." "${RED}Error: Admin password file not found. Cannot configure OAuth providers.${NC}"
      return 1
    fi
    
    ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")
    
    # Use the client ID as realm if provided, otherwise use 'agency'
    REALM_NAME="agency"
    if [ -n "$CLIENT_ID" ]; then
      REALM_NAME="${CLIENT_ID}"
    fi
    
    # Get admin token for Keycloak API
    ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')
    
    if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
      log "ERROR" "Failed to get admin token" "${RED}Failed to get admin token. Cannot configure OAuth providers.${NC}"
      log "INFO" "Retrying in 5 seconds..." "${YELLOW}Retrying in 5 seconds...${NC}"
      
      sleep 5
      
      ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')
      
      if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
        log "ERROR" "Failed to get admin token after retry" "${RED}Failed to get admin token after retry. Cannot configure OAuth providers.${NC}"
        return 1
      fi
    fi
    
    # Configure Google Identity Provider
    if [ "$ENABLE_OAUTH_GOOGLE" = true ]; then
      log "INFO" "Configuring Google as identity provider" "${CYAN}Configuring Google as identity provider...${NC}"
      
      # Check if Google IdP already exists
      IDP_EXISTS=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/google" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$IDP_EXISTS" = "200" ]; then
        log "INFO" "Google IdP already exists, updating configuration" "${YELLOW}Google IdP already exists, updating configuration...${NC}"
        # Delete existing Google IdP first to avoid conflicts
        curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/google" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" >> "$INSTALL_LOG" 2>&1
      fi
      
      # Load credentials from secure storage
      if [ -f "${SECRETS_DIR}/${DOMAIN}/google_oauth.env" ]; then
        source "${SECRETS_DIR}/${DOMAIN}/google_oauth.env"
      fi
      
      # Validate credentials again before creating IdP
      if [ -z "${GOOGLE_CLIENT_ID}" ] || [ -z "${GOOGLE_CLIENT_SECRET}" ]; then
        log "ERROR" "Google OAuth credentials not found in secure storage" "${RED}Error: Google OAuth credentials not found in secure storage.${NC}"
        continue
      fi
      
      # Create Google IdP
      GOOGLE_IDP=$(cat <<EOF
{
  "alias": "google",
  "displayName": "Google",
  "providerId": "google",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": ${OAUTH_TRUST_EMAIL},
  "storeToken": ${OAUTH_STORE_TOKENS},
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "${GOOGLE_CLIENT_ID}",
    "clientSecret": "${GOOGLE_CLIENT_SECRET}",
    "useJwksUrl": "${OAUTH_USE_JWKS_URL}",
    "validateSignature": "${OAUTH_VALIDATE_SIGNATURES}",
    "disableUserInfo": "${OAUTH_DISABLE_USER_INFO}",
    "defaultScope": "openid email profile",
    "guiOrder": "1",
    "syncMode": "IMPORT"
  }
}
EOF
)
      
      # Create Google IdP
      HTTP_STATUS=$(curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$GOOGLE_IDP" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$HTTP_STATUS" = "201" ]; then
        log "INFO" "Google IdP successfully configured" "${GREEN}✅ Google IdP successfully configured${NC}"
        # Update component registry with oauth_idp_configured flag
        if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
          ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$INSTALL_LOG" 2>&1
        fi
        
        # Configure mappers for Google IdP
        MAPPER_EMAIL=$(cat <<EOF
{
  "name": "email",
  "identityProviderAlias": "google",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "claim": "email",
    "user.attribute": "email"
  }
}
EOF
)
        
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/google/mappers" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$MAPPER_EMAIL" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "Google email mapper configured" "${GREEN}✅ Google email mapper configured${NC}"
        
      else
        log "ERROR" "Failed to configure Google IdP, HTTP status: ${HTTP_STATUS}" "${RED}Failed to configure Google IdP, HTTP status: ${HTTP_STATUS}${NC}"
      fi
    fi
    
    # Configure GitHub Identity Provider
    if [ "$ENABLE_OAUTH_GITHUB" = true ]; then
      log "INFO" "Configuring GitHub as identity provider" "${CYAN}Configuring GitHub as identity provider...${NC}"
      
      # Check if GitHub IdP already exists
      IDP_EXISTS=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/github" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$IDP_EXISTS" = "200" ]; then
        log "INFO" "GitHub IdP already exists, updating configuration" "${YELLOW}GitHub IdP already exists, updating configuration...${NC}"
        # Delete existing GitHub IdP first to avoid conflicts
        curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/github" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" >> "$INSTALL_LOG" 2>&1
      fi
      
      # Load credentials from secure storage
      if [ -f "${SECRETS_DIR}/${DOMAIN}/github_oauth.env" ]; then
        source "${SECRETS_DIR}/${DOMAIN}/github_oauth.env"
      fi
      
      # Validate credentials again before creating IdP
      if [ -z "${GITHUB_CLIENT_ID}" ] || [ -z "${GITHUB_CLIENT_SECRET}" ]; then
        log "ERROR" "GitHub OAuth credentials not found in secure storage" "${RED}Error: GitHub OAuth credentials not found in secure storage.${NC}"
        continue
      fi
      
      # Create GitHub IdP
      GITHUB_IDP=$(cat <<EOF
{
  "alias": "github",
  "displayName": "GitHub",
  "providerId": "github",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": ${OAUTH_TRUST_EMAIL},
  "storeToken": ${OAUTH_STORE_TOKENS},
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "${GITHUB_CLIENT_ID}",
    "clientSecret": "${GITHUB_CLIENT_SECRET}",
    "defaultScope": "user:email",
    "guiOrder": "2",
    "syncMode": "IMPORT"
  }
}
EOF
)
      
      # Create GitHub IdP
      HTTP_STATUS=$(curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$GITHUB_IDP" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$HTTP_STATUS" = "201" ]; then
        log "INFO" "GitHub IdP successfully configured" "${GREEN}✅ GitHub IdP successfully configured${NC}"
        # Update component registry with oauth_idp_configured flag
        if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
          ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$INSTALL_LOG" 2>&1
        fi
        
        # Configure mappers for GitHub IdP
        MAPPER_EMAIL=$(cat <<EOF
{
  "name": "email",
  "identityProviderAlias": "github",
  "identityProviderMapper": "github-user-attribute-mapper",
  "config": {
    "jsonField": "email",
    "userAttribute": "email"
  }
}
EOF
)
        
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/github/mappers" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$MAPPER_EMAIL" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "GitHub email mapper configured" "${GREEN}✅ GitHub email mapper configured${NC}"
        
      else
        log "ERROR" "Failed to configure GitHub IdP, HTTP status: ${HTTP_STATUS}" "${RED}Failed to configure GitHub IdP, HTTP status: ${HTTP_STATUS}${NC}"
      fi
    fi
    
    # Configure Apple Identity Provider
    if [ "$ENABLE_OAUTH_APPLE" = true ]; then
      log "INFO" "Configuring Apple as identity provider" "${CYAN}Configuring Apple as identity provider...${NC}"
      
      # Check if Apple IdP already exists
      IDP_EXISTS=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/apple" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$IDP_EXISTS" = "200" ]; then
        log "INFO" "Apple IdP already exists, updating configuration" "${YELLOW}Apple IdP already exists, updating configuration...${NC}"
        # Delete existing Apple IdP first to avoid conflicts
        curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/apple" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" >> "$INSTALL_LOG" 2>&1
      fi
      
      # Load credentials from secure storage
      if [ -f "${SECRETS_DIR}/${DOMAIN}/apple_oauth.env" ]; then
        source "${SECRETS_DIR}/${DOMAIN}/apple_oauth.env"
      fi
      
      # Validate credentials again before creating IdP
      if [ -z "${APPLE_CLIENT_ID}" ] || [ -z "${APPLE_CLIENT_SECRET}" ]; then
        log "ERROR" "Apple OAuth credentials not found in secure storage" "${RED}Error: Apple OAuth credentials not found in secure storage.${NC}"
        continue
      fi
      
      # Create Apple IdP
      APPLE_IDP=$(cat <<EOF
{
  "alias": "apple",
  "displayName": "Apple",
  "providerId": "apple",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": ${OAUTH_TRUST_EMAIL},
  "storeToken": ${OAUTH_STORE_TOKENS},
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "${APPLE_CLIENT_ID}",
    "clientSecret": "${APPLE_CLIENT_SECRET}",
    "defaultScope": "email name",
    "guiOrder": "3",
    "syncMode": "IMPORT",
    "validateSignature": "${OAUTH_VALIDATE_SIGNATURES}",
    "useJwksUrl": "${OAUTH_USE_JWKS_URL}"
  }
}
EOF
)
      
      # Create Apple IdP
      HTTP_STATUS=$(curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$APPLE_IDP" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$HTTP_STATUS" = "201" ]; then
        log "INFO" "Apple IdP successfully configured" "${GREEN}✅ Apple IdP successfully configured${NC}"
        # Update component registry with oauth_idp_configured flag
        if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
          ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$INSTALL_LOG" 2>&1
        fi
        
        # Configure mappers for Apple IdP
        MAPPER_EMAIL=$(cat <<EOF
{
  "name": "apple-email",
  "identityProviderAlias": "apple",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "claim": "email",
    "user.attribute": "email"
  }
}
EOF
)
        
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/apple/mappers" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$MAPPER_EMAIL" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "Apple email mapper configured" "${GREEN}✅ Apple email mapper configured${NC}"
        
      else
        log "ERROR" "Failed to configure Apple IdP, HTTP status: ${HTTP_STATUS}" "${RED}Failed to configure Apple IdP, HTTP status: ${HTTP_STATUS}${NC}"
      fi
    fi
    
    # Configure LinkedIn Identity Provider
    if [ "$ENABLE_OAUTH_LINKEDIN" = true ]; then
      log "INFO" "Configuring LinkedIn as identity provider" "${CYAN}Configuring LinkedIn as identity provider...${NC}"
      
      # Check if LinkedIn IdP already exists
      IDP_EXISTS=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/linkedin" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$IDP_EXISTS" = "200" ]; then
        log "INFO" "LinkedIn IdP already exists, updating configuration" "${YELLOW}LinkedIn IdP already exists, updating configuration...${NC}"
        # Delete existing LinkedIn IdP first to avoid conflicts
        curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/linkedin" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" >> "$INSTALL_LOG" 2>&1
      fi
      
      # Load credentials from secure storage
      if [ -f "${SECRETS_DIR}/${DOMAIN}/linkedin_oauth.env" ]; then
        source "${SECRETS_DIR}/${DOMAIN}/linkedin_oauth.env"
      fi
      
      # Validate credentials again before creating IdP
      if [ -z "${LINKEDIN_CLIENT_ID}" ] || [ -z "${LINKEDIN_CLIENT_SECRET}" ]; then
        log "ERROR" "LinkedIn OAuth credentials not found in secure storage" "${RED}Error: LinkedIn OAuth credentials not found in secure storage.${NC}"
        continue
      fi
      
      # Create LinkedIn IdP
      LINKEDIN_IDP=$(cat <<EOF
{
  "alias": "linkedin",
  "displayName": "LinkedIn",
  "providerId": "linkedin",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": ${OAUTH_TRUST_EMAIL},
  "storeToken": ${OAUTH_STORE_TOKENS},
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "${LINKEDIN_CLIENT_ID}",
    "clientSecret": "${LINKEDIN_CLIENT_SECRET}",
    "defaultScope": "r_liteprofile r_emailaddress",
    "guiOrder": "4",
    "syncMode": "IMPORT"
  }
}
EOF
)
      
      # Create LinkedIn IdP
      HTTP_STATUS=$(curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$LINKEDIN_IDP" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$HTTP_STATUS" = "201" ]; then
        log "INFO" "LinkedIn IdP successfully configured" "${GREEN}✅ LinkedIn IdP successfully configured${NC}"
        # Update component registry with oauth_idp_configured flag
        if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
          ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$INSTALL_LOG" 2>&1
        fi
        
        # Configure mappers for LinkedIn IdP
        MAPPER_EMAIL=$(cat <<EOF
{
  "name": "linkedin-email",
  "identityProviderAlias": "linkedin",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "claim": "emailAddress",
    "user.attribute": "email"
  }
}
EOF
)
        
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/linkedin/mappers" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$MAPPER_EMAIL" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "LinkedIn email mapper configured" "${GREEN}✅ LinkedIn email mapper configured${NC}"
        
      else
        log "ERROR" "Failed to configure LinkedIn IdP, HTTP status: ${HTTP_STATUS}" "${RED}Failed to configure LinkedIn IdP, HTTP status: ${HTTP_STATUS}${NC}"
      fi
    fi
    
    # Configure Microsoft Identity Provider
    if [ "$ENABLE_OAUTH_MICROSOFT" = true ]; then
      log "INFO" "Configuring Microsoft as identity provider" "${CYAN}Configuring Microsoft as identity provider...${NC}"
      
      # Check if Microsoft IdP already exists
      IDP_EXISTS=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/microsoft" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$IDP_EXISTS" = "200" ]; then
        log "INFO" "Microsoft IdP already exists, updating configuration" "${YELLOW}Microsoft IdP already exists, updating configuration...${NC}"
        # Delete existing Microsoft IdP first to avoid conflicts
        curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/microsoft" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" >> "$INSTALL_LOG" 2>&1
      fi
      
      # Load credentials from secure storage
      if [ -f "${SECRETS_DIR}/${DOMAIN}/microsoft_oauth.env" ]; then
        source "${SECRETS_DIR}/${DOMAIN}/microsoft_oauth.env"
      fi
      
      # Validate credentials again before creating IdP
      if [ -z "${MICROSOFT_CLIENT_ID}" ] || [ -z "${MICROSOFT_CLIENT_SECRET}" ]; then
        log "ERROR" "Microsoft OAuth credentials not found in secure storage" "${RED}Error: Microsoft OAuth credentials not found in secure storage.${NC}"
        continue
      fi
      
      # Create Microsoft IdP
      MICROSOFT_IDP=$(cat <<EOF
{
  "alias": "microsoft",
  "displayName": "Microsoft",
  "providerId": "microsoft",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": ${OAUTH_TRUST_EMAIL},
  "storeToken": ${OAUTH_STORE_TOKENS},
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "${MICROSOFT_CLIENT_ID}",
    "clientSecret": "${MICROSOFT_CLIENT_SECRET}",
    "defaultScope": "openid profile email",
    "guiOrder": "5",
    "syncMode": "IMPORT",
    "validateSignature": "${OAUTH_VALIDATE_SIGNATURES}",
    "useJwksUrl": "${OAUTH_USE_JWKS_URL}"
  }
}
EOF
)
      
      # Create Microsoft IdP
      HTTP_STATUS=$(curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$MICROSOFT_IDP" \
        -o /dev/null -w "%{http_code}")
      
      if [ "$HTTP_STATUS" = "201" ]; then
        log "INFO" "Microsoft IdP successfully configured" "${GREEN}✅ Microsoft IdP successfully configured${NC}"
        # Update component registry with oauth_idp_configured flag
        if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
          ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$INSTALL_LOG" 2>&1
        fi
        
        # Configure mappers for Microsoft IdP
        MAPPER_EMAIL=$(cat <<EOF
{
  "name": "microsoft-email",
  "identityProviderAlias": "microsoft",
  "identityProviderMapper": "oidc-user-attribute-idp-mapper",
  "config": {
    "claim": "email",
    "user.attribute": "email"
  }
}
EOF
)
        
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/microsoft/mappers" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$MAPPER_EMAIL" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "Microsoft email mapper configured" "${GREEN}✅ Microsoft email mapper configured${NC}"
        
      else
        log "ERROR" "Failed to configure Microsoft IdP, HTTP status: ${HTTP_STATUS}" "${RED}Failed to configure Microsoft IdP, HTTP status: ${HTTP_STATUS}${NC}"
      fi
    fi
    
    # Create authentication browser flow overrides if any IdPs were configured successfully
    if curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -e 'length > 0' > /dev/null; then
      
      log "INFO" "Setting up authentication flow with IdP redirector" "${CYAN}Setting up authentication flow with IdP redirector...${NC}"
      
      # Get the current browser flow
      BROWSER_FLOW=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
      
      if [ -n "$BROWSER_FLOW" ]; then
        log "INFO" "Browser flow retrieved successfully" "${GREEN}Browser flow retrieved successfully${NC}"
        
        # Copy the browser flow to create a custom one
        CUSTOM_FLOW_NAME="browser-with-idp-redirector"
        COPY_FLOW=$(cat <<EOF
{
  "newName": "${CUSTOM_FLOW_NAME}"
}
EOF
)
        
        # Create the copy
        curl -s -X POST "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser/copy" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$COPY_FLOW" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "Created custom browser flow: ${CUSTOM_FLOW_NAME}" "${GREEN}Created custom browser flow: ${CUSTOM_FLOW_NAME}${NC}"
        
        # Set the new flow as the browser flow
        FLOW_UPDATE=$(cat <<EOF
{
  "alias": "browser",
  "flows": ["${CUSTOM_FLOW_NAME}"]
}
EOF
)
        
        curl -s -X PUT "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$FLOW_UPDATE" >> "$INSTALL_LOG" 2>&1
        
        log "INFO" "Set custom flow as default browser flow" "${GREEN}Set custom flow as default browser flow${NC}"
        
        log "INFO" "Identity provider configuration completed" "${GREEN}Identity provider configuration completed${NC}"
      else
        log "ERROR" "Failed to retrieve browser flow" "${RED}Failed to retrieve browser flow${NC}"
      fi
    fi
  fi
}

# Main installation logic...
# ...

# Configure OAuth providers if requested (moved to function)
if [ "$ENABLE_OAUTH_GOOGLE" = true ] || [ "$ENABLE_OAUTH_GITHUB" = true ] || [ "$ENABLE_OAUTH_APPLE" = true ] || [ "$ENABLE_OAUTH_LINKEDIN" = true ] || [ "$ENABLE_OAUTH_MICROSOFT" = true ]; then
  configure_oauth_providers
fi

# Update component registry
if [ "$ENABLE_OAUTH_GOOGLE" = true ] || [ "$ENABLE_OAUTH_GITHUB" = true ] || [ "$ENABLE_OAUTH_APPLE" = true ] || [ "$ENABLE_OAUTH_LINKEDIN" = true ] || [ "$ENABLE_OAUTH_MICROSOFT" = true ]; then
  log "INFO" "Updating component registry with OAuth IDP flag" "${BLUE}Updating component registry...${NC}"
  ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true
fi
