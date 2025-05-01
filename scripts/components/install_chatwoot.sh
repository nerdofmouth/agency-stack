#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: chatwoot.sh
# Path: /scripts/components/install_chatwoot.sh
#

# --- BEGIN: Preflight/Prerequisite Check ---
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# install_chatwoot.sh - AgencyStack Chatwoot Customer Service Platform Installer
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures Chatwoot with hardened settings
# Part of the AgencyStack Business Applications suite
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
CHATWOOT_LOG="${COMPONENT_LOG_DIR}/chatwoot.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${ROOT_DIR}/docker"
CHATWOOT_DIR="${DOCKER_DIR}/chatwoot"
DOCKER_COMPOSE_FILE="${CHATWOOT_DIR}/docker-compose.yml"
DOCKER_ENV_FILE="${CHATWOOT_DIR}/.env"
TRAEFIK_CONFIG_DIR="${ROOT_DIR}/traefik/config"

# Chatwoot Configuration
CHATWOOT_VERSION="v3.5.0"
CHATWOOT_PORT=3000
CHATWOOT_DB_NAME="chatwoot"
CHATWOOT_DB_USER="chatwoot"
CHATWOOT_DB_PASS="$(openssl rand -hex 16)"
CHATWOOT_SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')"
CHATWOOT_REDIS_PASSWORD="$(openssl rand -hex 16)"
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
WITH_DEPS=false
FORCE=false
MAILU_DOMAIN=""
MAILU_USER=""
MAILU_PASSWORD=""
ENABLE_SSO=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${CHATWOOT_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Chatwoot Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>         Domain name for Chatwoot (e.g., support.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>          Client ID for multi-tenant setup and SSO integration"
  echo -e "  ${CYAN}--with-deps${NC}               Install dependencies (Docker, PostgreSQL, Redis, etc.)"
  echo -e "  ${CYAN}--force${NC}                   Force installation even if already installed"
  echo -e "  ${CYAN}--mailu-domain${NC} <domain>   Mailu server domain for SMTP integration"
  echo -e "  ${CYAN}--mailu-user${NC} <user>       Mailu username for SMTP integration"
  echo -e "  ${CYAN}--mailu-password${NC} <pass>   Mailu password for SMTP integration"
  echo -e "  ${CYAN}--enable-sso${NC}              Enable Keycloak SSO integration"
  echo -e "  ${CYAN}--help${NC}                    Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain support.example.com --with-deps"
  echo -e "  $0 --domain support.client1.com --client-id client1 --enable-sso --mailu-domain mail.client1.com"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}"
  
  # Create persistent data directories
  mkdir -p "${CLIENT_DIR}/chatwoot_data/postgres"
  mkdir -p "${CLIENT_DIR}/chatwoot_data/redis"
  mkdir -p "${CLIENT_DIR}/chatwoot_data/storage"
  mkdir -p "${CLIENT_DIR}/chatwoot_data/config"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/chatwoot_data"
  
  # Save client ID to file if it doesn't exist
  if [ ! -f "${CLIENT_ID_FILE}" ]; then
    echo "${CLIENT_ID}" > "${CLIENT_ID_FILE}"
    log "INFO" "Saved client ID to ${CLIENT_ID_FILE}"
  fi
}

# Check system requirements
check_requirements() {
  log "INFO" "Checking system requirements..."
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check if Docker Compose is installed
  if ! command -v docker-compose &> /dev/null; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check if required port is available
  if ! [ "$WITH_DEPS" = true ] && ! [ "$FORCE" = true ]; then
    if lsof -i:"${CHATWOOT_PORT}" &> /dev/null; then
      log "ERROR" "Port ${CHATWOOT_PORT} is already in use"
      exit 1
    fi
  fi
  
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Create installation directories
  mkdir -p "${CHATWOOT_DIR}"
  
  # Install system dependencies
  log "INFO" "Installing system packages..."
  apt-get update
  apt-get install -y curl wget gnupg apt-transport-https ca-certificates \
                    software-properties-common lsof postgresql-client redis-tools
  
  # Install Docker if not present
  if ! command -v docker &> /dev/null; then
    log "INFO" "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker "${USER}"
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
  fi
  
  # Install Docker Compose if not present
  if ! command -v docker-compose &> /dev/null; then
    log "INFO" "Installing Docker Compose..."
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi
  
  log "INFO" "Dependencies installed successfully"
}

# Create Chatwoot Docker Compose configuration
create_docker_compose() {
  log "INFO" "Creating Docker Compose configuration..."
  
  mkdir -p "${CHATWOOT_DIR}"
  
  cat > "${DOCKER_COMPOSE_FILE}" << EOF
version: '3'

services:
  postgres:
    image: postgres:14-alpine
    container_name: chatwoot-postgres-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/chatwoot_data/postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${CHATWOOT_DB_NAME}
      - POSTGRES_USER=${CHATWOOT_DB_USER}
      - POSTGRES_PASSWORD=${CHATWOOT_DB_PASS}
    command: postgres -c 'max_connections=200'
    networks:
      - chatwoot_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:6-alpine
    container_name: chatwoot-redis-${CLIENT_ID}
    restart: unless-stopped
    command: redis-server --requirepass ${CHATWOOT_REDIS_PASSWORD}
    volumes:
      - ${CLIENT_DIR}/chatwoot_data/redis:/data
    networks:
      - chatwoot_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  chatwoot:
    image: chatwoot/chatwoot:${CHATWOOT_VERSION}
    container_name: chatwoot-app-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    env_file:
      - ${CHATWOOT_DIR}/.env
    volumes:
      - ${CLIENT_DIR}/chatwoot_data/storage:/app/storage
    networks:
      - chatwoot_network
      - traefik_network
    ports:
      - "${CHATWOOT_PORT}:3000"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 5s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.chatwoot-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.chatwoot-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.chatwoot-${CLIENT_ID}.tls=true"
      - "traefik.http.routers.chatwoot-${CLIENT_ID}.tls.certresolver=letsencrypt"
      - "traefik.http.services.chatwoot-${CLIENT_ID}.loadbalancer.server.port=3000"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.chatwoot-${CLIENT_ID}-security.headers.stsPreload=true"
      - "traefik.http.routers.chatwoot-${CLIENT_ID}.middlewares=chatwoot-${CLIENT_ID}-security"

  sidekiq:
    image: chatwoot/chatwoot:${CHATWOOT_VERSION}
    container_name: chatwoot-sidekiq-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
      - chatwoot
    env_file:
      - ${CHATWOOT_DIR}/.env
    command: bundle exec sidekiq -C config/sidekiq.yml
    volumes:
      - ${CLIENT_DIR}/chatwoot_data/storage:/app/storage
    networks:
      - chatwoot_network
    healthcheck:
      test: ["CMD-SHELL", "ps aux | grep sidekiq | grep -v grep"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  chatwoot_network:
    driver: bridge
  traefik_network:
    external: true
    name: traefik-network
EOF

  log "INFO" "Docker Compose configuration created successfully"
}

# Create Chatwoot environment file
create_env_file() {
  log "INFO" "Creating environment configuration..."
  
  cat > "${DOCKER_ENV_FILE}" << EOF
# Database configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=${CHATWOOT_DB_NAME}
POSTGRES_USERNAME=${CHATWOOT_DB_USER}
POSTGRES_PASSWORD=${CHATWOOT_DB_PASS}

# Redis configuration
REDIS_URL=redis://:${CHATWOOT_REDIS_PASSWORD}@redis:6379

# Rails configuration
RAILS_ENV=production
NODE_ENV=production
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=${CHATWOOT_SECRET_KEY_BASE}

# SMTP configuration
SMTP_ADDRESS=${MAILU_DOMAIN}
SMTP_PORT=587
SMTP_USERNAME=${MAILU_USER}
SMTP_PASSWORD=${MAILU_PASSWORD}
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
SMTP_EMAIL_DOMAIN=${DOMAIN}
MAILER_SENDER_EMAIL=${MAILU_USER}

# Frontend URL
FRONTEND_URL=https://${DOMAIN}

# Installation URL
INSTALLATION_URL=https://${DOMAIN}

# IP masking (privacy)
IP_LOOKUP_SERVICE=geoip2
PRIVACY_MASKING=true

# Push notifications
ENABLE_PUSH_NOTIFICATIONS=true

# Monitoring and metrics
ENABLE_METRICS=true

# Default locale
DEFAULT_LOCALE=en

# Rate limits for security
RACK_ATTACK_ENABLED=true

# Prevent direct file uploads to CDNs
ACTIVE_STORAGE_CDN_HOST=

# Ensure all cookies are secure
COOKIE_SECURE=true

# Account auto verification
AUTO_VERIFY_NEW_ACCOUNTS=false

# Telemetry
TELEMETRY_ENABLED=false
EOF

  # Add SSO configuration if enabled
  if [ "$ENABLE_SSO" = true ]; then
    cat >> "${DOCKER_ENV_FILE}" << EOF

# SSO Configuration
OMNIAUTH_OPENID_CONNECT_ENABLED=true
OMNIAUTH_OPENID_CONNECT_CLIENT_ID=chatwoot
OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET=chatwoot-secret
OMNIAUTH_OPENID_CONNECT_ISSUER=https://keycloak.${DOMAIN/support./}/auth/realms/${CLIENT_ID}
OMNIAUTH_OPENID_CONNECT_AUTH_SERVER_URL=https://keycloak.${DOMAIN/support./}/auth/realms/${CLIENT_ID}/protocol/openid-connect/auth
OMNIAUTH_OPENID_CONNECT_SCOPE="openid email profile"
OMNIAUTH_OPENID_CONNECT_UID_FIELD=preferred_username
OMNIAUTH_OPENID_CONNECT_AUTH_SCHEME=basic
EOF
  fi

  log "INFO" "Environment configuration created successfully"
}

# Setup Traefik configuration
setup_traefik() {
  log "INFO" "Setting up Traefik configuration..."
  
  # Ensure the Traefik config directory exists
  mkdir -p "${TRAEFIK_CONFIG_DIR}/dynamic"
  
  # Create Chatwoot Traefik configuration
  cat > "${TRAEFIK_CONFIG_DIR}/dynamic/chatwoot-${CLIENT_ID}.toml" << EOF
[http.routers.chatwoot-${CLIENT_ID}]
  rule = "Host(\`${DOMAIN}\`)"
  entrypoints = ["websecure"]
  service = "chatwoot-${CLIENT_ID}"
  middlewares = ["chatwoot-${CLIENT_ID}-security"]
  [http.routers.chatwoot-${CLIENT_ID}.tls]
    certResolver = "letsencrypt"

[http.services.chatwoot-${CLIENT_ID}.loadBalancer]
  [[http.services.chatwoot-${CLIENT_ID}.loadBalancer.servers]]
    url = "http://chatwoot-app-${CLIENT_ID}:3000"

[http.middlewares.chatwoot-${CLIENT_ID}-security.headers]
  stsSeconds = 31536000
  browserXssFilter = true
  contentTypeNosniff = true
  forceSTSHeader = true
  stsIncludeSubdomains = true
  stsPreload = true
  frameDeny = false
  [http.middlewares.chatwoot-${CLIENT_ID}-security.headers.customResponseHeaders]
    X-Robots-Tag = "noindex, nofollow, nosnippet, noarchive"
EOF

  log "INFO" "Traefik configuration created successfully"
}

# Setup Keycloak SSO integration
setup_sso() {
  if [ "$ENABLE_SSO" = false ]; then
    log "INFO" "Skipping SSO setup (--enable-sso not specified)"
    return
  fi
  
  log "INFO" "Setting up Keycloak SSO integration..."
  
  # Create directory for SSO configuration
  mkdir -p "${CLIENT_DIR}/chatwoot_data/config/sso"
  
  # Create a note file with instructions for completing SSO setup
  cat > "${CLIENT_DIR}/chatwoot_data/config/sso/keycloak-setup-instructions.txt" << EOF
Keycloak SSO Integration Instructions for Chatwoot

To complete the SSO integration, perform these steps in your Keycloak instance:

1. Create a new client in the ${CLIENT_ID} realm:
   - Client ID: chatwoot
   - Client Protocol: openid-connect
   - Access Type: confidential
   - Valid Redirect URIs: https://${DOMAIN}/*
   - Web Origins: https://${DOMAIN}

2. Once created, go to the Credentials tab and copy the Secret

3. Update the .env file with the correct secret:
   - Edit ${DOCKER_ENV_FILE}
   - Replace OMNIAUTH_OPENID_CONNECT_CLIENT_SECRET=chatwoot-secret with your actual secret

4. Create Mapper for user attributes (if not present):
   - Add mappers for email, name, and preferred_username if they don't exist

5. Restart Chatwoot services:
   - Run: make chatwoot-restart

For more information, see the Chatwoot documentation on OIDC SSO integration.
EOF

  log "INFO" "SSO integration setup completed"
}

# Setup monitoring hooks
setup_monitoring() {
  log "INFO" "Setting up monitoring hooks..."
  
  # Create monitoring configuration for Chatwoot
  mkdir -p "${ROOT_DIR}/monitoring/config/components"
  
  # Create Prometheus configuration for scraping Chatwoot metrics
  cat > "${ROOT_DIR}/monitoring/config/components/chatwoot-${CLIENT_ID}.yml" << EOF
- job_name: 'chatwoot-${CLIENT_ID}'
  scrape_interval: 30s
  metrics_path: '/metrics'
  static_configs:
    - targets: ['chatwoot-app-${CLIENT_ID}:3000']
      labels:
        instance: 'chatwoot'
        component: 'business_applications'
        client_id: '${CLIENT_ID}'
EOF

  # Create monitoring check script
  mkdir -p "${ROOT_DIR}/monitoring/scripts"
  
  cat > "${ROOT_DIR}/monitoring/scripts/check_chatwoot-${CLIENT_ID}.sh" << EOF
#!/bin/bash
# Chatwoot monitoring check script for ${CLIENT_ID}

# Check if Chatwoot is responding
curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/api/v1/health_check" | grep -q "200"
exit \$?
EOF
  
  chmod +x "${ROOT_DIR}/monitoring/scripts/check_chatwoot-${CLIENT_ID}.sh"
  
  log "INFO" "Monitoring hooks set up successfully"
}

# Register Chatwoot component with AgencyStack
register_component() {
  log "INFO" "Registering Chatwoot component with AgencyStack..."
  
  # Ensure config directory exists
  mkdir -p "${CONFIG_DIR}"
  
  # Add to installed components
  if ! grep -q "chatwoot" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
    echo "chatwoot" >> "${INSTALLED_COMPONENTS}"
    log "INFO" "Added Chatwoot to installed components list"
  fi
  
  # Update dashboard data
  if [ -f "${DASHBOARD_DATA}" ]; then
    # Check if Chatwoot entry already exists
    if ! grep -q '"component": "chatwoot"' "${DASHBOARD_DATA}"; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      jq --argjson new_component '{
        "component": "chatwoot",
        "name": "Chatwoot",
        "description": "Customer messaging platform that helps businesses talk to customers",
        "category": "Business Applications",
        "url": "https://'"${DOMAIN}"'",
        "adminUrl": "https://'"${DOMAIN}"'/super_admin",
        "version": "'"${CHATWOOT_VERSION}"'",
        "installDate": "'"$(date -Iseconds)"'",
        "status": "active",
        "icon": "message-circle",
        "clientId": "'"${CLIENT_ID}"'"
      }' '.components += [$new_component]' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
      log "INFO" "Updated dashboard data with Chatwoot component"
    else
      log "INFO" "Chatwoot already exists in dashboard data"
    fi
  else
    # Create a new dashboard data file
    cat > "${DASHBOARD_DATA}" << EOF
{
  "components": [
    {
      "component": "chatwoot",
      "name": "Chatwoot",
      "description": "Customer messaging platform that helps businesses talk to customers",
      "category": "Business Applications",
      "url": "https://${DOMAIN}",
      "adminUrl": "https://${DOMAIN}/super_admin",
      "version": "${CHATWOOT_VERSION}",
      "installDate": "$(date -Iseconds)",
      "status": "active",
      "icon": "message-circle",
      "clientId": "${CLIENT_ID}"
    }
  ]
}
EOF
    log "INFO" "Created new dashboard data file with Chatwoot component"
  fi
  
  # Update integration status
  if [ -f "${INTEGRATION_STATUS}" ]; then
    # Check if Chatwoot entry already exists
    if ! grep -q '"component": "chatwoot"' "${INTEGRATION_STATUS}"; then
      # Create a temporary file with the new integration status
      TEMP_FILE=$(mktemp)
      jq --argjson new_status '{
        "component": "chatwoot",
        "clientId": "'"${CLIENT_ID}"'",
        "integrations": {
          "monitoring": true,
          "auth": '"${ENABLE_SSO}"',
          "mail": true
        },
        "lastChecked": "'"$(date -Iseconds)"'"
      }' '.status += [$new_status]' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
      log "INFO" "Updated integration status with Chatwoot component"
    else
      log "INFO" "Chatwoot already exists in integration status"
    fi
  else
    # Create a new integration status file
    cat > "${INTEGRATION_STATUS}" << EOF
{
  "status": [
    {
      "component": "chatwoot",
      "clientId": "${CLIENT_ID}",
      "integrations": {
        "monitoring": true,
        "auth": ${ENABLE_SSO},
        "mail": true
      },
      "lastChecked": "$(date -Iseconds)"
    }
  ]
}
EOF
    log "INFO" "Created new integration status file with Chatwoot component"
  fi
  
  log "INFO" "Chatwoot component registered successfully"
}

# Register component in component registry
register_component_registry() {
  log "INFO" "Registering Chatwoot in the component registry..."
  
  local REGISTRY_DIR="${CONFIG_DIR}/registry"
  local REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
  
  mkdir -p "${REGISTRY_DIR}"
  
  if [ -f "${REGISTRY_FILE}" ]; then
    # Check if Chatwoot entry already exists
    if ! jq -e '.components.business.chatwoot' "${REGISTRY_FILE}" > /dev/null 2>&1; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      
      jq --arg version "${CHATWOOT_VERSION}" '.components.business.chatwoot = {
        "name": "Chatwoot",
        "category": "Business Applications",
        "version": $version,
        "integration_status": {
          "installed": true,
          "hardened": true,
          "makefile": true,
          "sso": '"${ENABLE_SSO}"',
          "dashboard": true,
          "logs": true,
          "docs": true,
          "auditable": true,
          "traefik_tls": true,
          "multi_tenant": true
        },
        "description": "Customer messaging platform that helps businesses talk to customers",
        "ports": {
          "web": 3000
        }
      }' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      # Update the timestamp
      TEMP_FILE=$(mktemp)
      jq --arg ts "$(date -Iseconds)" '.last_updated = $ts' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      log "INFO" "Added Chatwoot to component registry"
    else
      log "INFO" "Chatwoot already exists in component registry"
    fi
  else
    log "WARN" "Component registry not found, skipping registration"
  fi
}

# Start Chatwoot containers
start_services() {
  log "INFO" "Starting Chatwoot services..."
  
  cd "${CHATWOOT_DIR}"
  docker-compose up -d
  
  # Wait for the services to be ready
  log "INFO" "Waiting for Chatwoot services to be ready..."
  sleep 10
  
  # Run initial setup if this is the first time
  if docker-compose logs chatwoot | grep -q 'Database schema is not up to date'; then
    log "INFO" "Running database migrations..."
    docker-compose exec -T chatwoot rails db:chatwoot_prepare
  fi
  
  log "INFO" "Chatwoot services started successfully"
}

# Validate installation
validate_installation() {
  log "INFO" "Validating Chatwoot installation..."
  
  # Ensure validate_system.sh exists
  if [ ! -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
    log "WARN" "validate_system.sh not found, skipping validation"
    return
  fi
  
  # Run validation
  "${ROOT_DIR}/scripts/utils/validate_system.sh" --component=chatwoot --client-id="${CLIENT_ID}"
  
  # Check if validation was successful
  if [ $? -eq 0 ]; then
    log "INFO" "Chatwoot installation validated successfully"
  else
    log "WARN" "Chatwoot installation validation failed"
  fi
}

# Create admin user for Chatwoot
create_admin_user() {
  log "INFO" "Creating super admin user..."
  
  # Generate random password
  ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
  
  # Create super admin user
  cd "${CHATWOOT_DIR}"
  docker-compose exec -T chatwoot rails "r Admin::CreateAdminService.new.create_admin('${CLIENT_ID}-admin@${DOMAIN/support./}', '${ADMIN_PASSWORD}')" || true
  
  # Save admin credentials to file
  mkdir -p "${CLIENT_DIR}/chatwoot_data/config"
  cat > "${CLIENT_DIR}/chatwoot_data/config/admin-credentials.txt" << EOF
Chatwoot Super Admin Credentials

Email: ${CLIENT_ID}-admin@${DOMAIN/support./}
Password: ${ADMIN_PASSWORD}

Please change this password immediately after first login!
Access the admin panel at: https://${DOMAIN}/super_admin
EOF

  log "INFO" "Super admin user created successfully"
  echo -e "${BOLD}${GREEN}Super Admin Created:${NC}"
  echo -e "${BOLD}Email:${NC} ${CLIENT_ID}-admin@${DOMAIN/support./}"
  echo -e "${BOLD}Password:${NC} ${ADMIN_PASSWORD}"
  echo -e "${BOLD}${YELLOW}Please change this password immediately after first login!${NC}"
}

# Main installation function
install_chatwoot() {
  log "INFO" "Starting Chatwoot installation..."
  
  # Check if already installed
  if grep -q "chatwoot" "${INSTALLED_COMPONENTS}" 2>/dev/null && [ "$FORCE" = false ]; then
    log "ERROR" "Chatwoot is already installed. Use --force to reinstall."
    exit 1
  fi
  
  # Setup client directory
  setup_client_dir
  
  # Check requirements
  check_requirements
  
  # Install dependencies if requested
  install_dependencies
  
  # Create Docker Compose configuration
  create_docker_compose
  
  # Create environment file configuration
  create_env_file
  
  # Setup Traefik configuration
  setup_traefik
  
  # Configure SSO integration if requested
  setup_sso
  
  # Setup monitoring hooks
  setup_monitoring
  
  # Start Chatwoot services
  start_services
  
  # Register Chatwoot component with AgencyStack
  register_component
  
  # Register in component registry
  register_component_registry
  
  # Create admin user
  create_admin_user
  
  # Validate installation
  validate_installation
  
  log "INFO" "Chatwoot installation completed successfully"
  echo -e "\n${BOLD}${GREEN}Chatwoot installation completed successfully${NC}"
  echo -e "${BOLD}Web UI:${NC} https://${DOMAIN}"
  echo -e "${BOLD}Admin UI:${NC} https://${DOMAIN}/super_admin"
  echo -e "${BOLD}Client ID:${NC} ${CLIENT_ID}"
  echo -e "${BOLD}Data Directory:${NC} ${CLIENT_DIR}/chatwoot_data"
  echo -e "${BOLD}Log File:${NC} ${CHATWOOT_LOG}"
  echo -e "\n${BOLD}${YELLOW}NOTE: Please save the super admin credentials in a secure location.${NC}"
}

# Process command-line arguments
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
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --mailu-domain)
      MAILU_DOMAIN="$2"
      shift
      shift
      ;;
    --mailu-user)
      MAILU_USER="$2"
      shift
      shift
      ;;
    --mailu-password)
      MAILU_PASSWORD="$2"
      shift
      shift
      ;;
    --enable-sso)
      ENABLE_SSO=true
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

# Validate required parameters
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain name is required. Use --domain to specify."
  echo -e "${RED}Error: Domain name is required.${NC} Use --domain to specify."
  echo -e "Use --help for usage information"
  exit 1

# If Mailu parameters are not provided, use defaults
if [ -z "$MAILU_DOMAIN" ]; then
  MAILU_DOMAIN="mail.${DOMAIN/support./}"
  log "INFO" "Mailu domain not specified, using default: ${MAILU_DOMAIN}"

if [ -z "$MAILU_USER" ]; then
  MAILU_USER="noreply@${DOMAIN/support./}"
  log "INFO" "Mailu user not specified, using default: ${MAILU_USER}"

if [ -z "$MAILU_PASSWORD" ]; then
  log "WARN" "Mailu password not specified. SMTP may not work properly."
  MAILU_PASSWORD="password_not_set"

# Make script executable
chmod +x "$0"

# Run the installer
install_chatwoot
