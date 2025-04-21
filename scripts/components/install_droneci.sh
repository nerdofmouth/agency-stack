#!/bin/bash
# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# --- BEGIN: Preflight/Prerequisite Check ---
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# install_droneci.sh - AgencyStack Drone CI Integration
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures Drone CI with hardened settings
# Part of the AgencyStack DevOps suite
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
DRONECI_LOG="${COMPONENT_LOG_DIR}/droneci.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${ROOT_DIR}/docker"
DRONECI_DIR="${DOCKER_DIR}/droneci"
DOCKER_COMPOSE_FILE="${DRONECI_DIR}/docker-compose.yml"
DOCKER_ENV_FILE="${DRONECI_DIR}/.env"
TRAEFIK_CONFIG_DIR="${ROOT_DIR}/traefik/config"

# Drone CI Configuration
DRONE_VERSION="2.16.0"
DRONE_RUNNER_VERSION="1.8.0"
DRONE_SERVER_PORT=3001
DRONE_RPC_PORT=3002
DRONE_RUNNER_PORT=3003
DRONE_RPC_SECRET=""
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
WITH_DEPS=false
FORCE=false
ENABLE_GITEA=false
ENABLE_SSO=false
GITEA_DOMAIN=""
GITEA_CLIENT_ID=""
GITEA_CLIENT_SECRET=""
MAILU_DOMAIN=""
MAILU_USER=""
MAILU_PASSWORD=""

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${DRONECI_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Drone CI Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>          Domain name for Drone CI (e.g., ci.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (Docker, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--enable-gitea${NC}             Enable Gitea integration"
  echo -e "  ${CYAN}--gitea-domain${NC} <domain>    Gitea server domain (required if --enable-gitea is used)"
  echo -e "  ${CYAN}--gitea-client-id${NC} <id>     Gitea OAuth client ID (required if --enable-gitea is used)"
  echo -e "  ${CYAN}--gitea-client-secret${NC} <s>  Gitea OAuth client secret (required if --enable-gitea is used)"
  echo -e "  ${CYAN}--enable-sso${NC}               Enable Keycloak SSO integration"
  echo -e "  ${CYAN}--mailu-domain${NC} <domain>    Mailu server domain for SMTP integration"
  echo -e "  ${CYAN}--mailu-user${NC} <user>        Mailu username for SMTP integration"
  echo -e "  ${CYAN}--mailu-password${NC} <pass>    Mailu password for SMTP integration"
  echo -e "  ${CYAN}--drone-rpc-secret${NC} <secret> Specify the RPC secret (generated if not provided)"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain ci.example.com --with-deps"
  echo -e "  $0 --domain ci.client1.com --client-id client1 --enable-gitea --gitea-domain git.client1.com"
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
  mkdir -p "${CLIENT_DIR}/droneci_data/server"
  mkdir -p "${CLIENT_DIR}/droneci_data/runner"
  mkdir -p "${CLIENT_DIR}/droneci_data/config"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/droneci_data"
  
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
  
  # Check if required ports are available
  if ! [ "$WITH_DEPS" = true ] && ! [ "$FORCE" = true ]; then
    if lsof -i:"${DRONE_SERVER_PORT}" &> /dev/null; then
      log "ERROR" "Port ${DRONE_SERVER_PORT} is already in use"
      exit 1
    fi
    if lsof -i:"${DRONE_RPC_PORT}" &> /dev/null; then
      log "ERROR" "Port ${DRONE_RPC_PORT} is already in use"
      exit 1
    fi
    if lsof -i:"${DRONE_RUNNER_PORT}" &> /dev/null; then
      log "ERROR" "Port ${DRONE_RUNNER_PORT} is already in use"
      exit 1
    fi
  fi
  
  # Check Gitea integration requirements
  if [ "$ENABLE_GITEA" = true ]; then
    if [ -z "$GITEA_DOMAIN" ]; then
      log "ERROR" "Gitea domain is required when --enable-gitea is specified"
      exit 1
    fi
    if [ -z "$GITEA_CLIENT_ID" ]; then
      log "ERROR" "Gitea client ID is required when --enable-gitea is specified"
      exit 1
    fi
    if [ -z "$GITEA_CLIENT_SECRET" ]; then
      log "ERROR" "Gitea client secret is required when --enable-gitea is specified"
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
  mkdir -p "${DRONECI_DIR}"
  
  # Install system dependencies
  log "INFO" "Installing system packages..."
  apt-get update
  apt-get install -y curl wget gnupg apt-transport-https ca-certificates \
                    software-properties-common lsof
  
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

# Generate RPC secret if not provided
generate_rpc_secret() {
  if [ -z "$DRONE_RPC_SECRET" ]; then
    DRONE_RPC_SECRET=$(openssl rand -hex 16)
    log "INFO" "Generated Drone RPC secret"
  else
    log "INFO" "Using provided Drone RPC secret"
  fi
}

# Create Docker Compose configuration
create_docker_compose() {
  log "INFO" "Creating Docker Compose configuration..."
  
  mkdir -p "${DRONECI_DIR}"
  
  cat > "${DOCKER_COMPOSE_FILE}" << EOF
version: '3'

services:
  drone-server:
    image: drone/drone:${DRONE_VERSION}
    container_name: drone-server-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - drone-redis
    volumes:
      - ${CLIENT_DIR}/droneci_data/server:/data
    env_file:
      - ${DOCKER_ENV_FILE}
    environment:
      - DRONE_SERVER_PORT=:${DRONE_SERVER_PORT}
      - DRONE_SERVER_HOST=${DOMAIN}
      - DRONE_SERVER_PROTO=https
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
    networks:
      - droneci_network
      - traefik_network
    ports:
      - "${DRONE_SERVER_PORT}:${DRONE_SERVER_PORT}"
      - "${DRONE_RPC_PORT}:${DRONE_RPC_PORT}"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:${DRONE_SERVER_PORT}/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.drone-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.drone-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.drone-${CLIENT_ID}.tls=true"
      - "traefik.http.routers.drone-${CLIENT_ID}.tls.certresolver=letsencrypt"
      - "traefik.http.services.drone-${CLIENT_ID}.loadbalancer.server.port=${DRONE_SERVER_PORT}"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.drone-${CLIENT_ID}-security.headers.stsPreload=true"
      - "traefik.http.routers.drone-${CLIENT_ID}.middlewares=drone-${CLIENT_ID}-security"

  drone-runner:
    image: drone/drone-runner-docker:${DRONE_RUNNER_VERSION}
    container_name: drone-runner-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - drone-server
    volumes:
      - ${CLIENT_DIR}/droneci_data/runner:/data
      - /var/run/docker.sock:/var/run/docker.sock
    env_file:
      - ${DOCKER_ENV_FILE}
    environment:
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_RPC_HOST=${DOMAIN}
      - DRONE_RPC_PROTO=https
      - DRONE_RUNNER_NAME=drone-runner-${CLIENT_ID}
      - DRONE_RUNNER_CAPACITY=2
    networks:
      - droneci_network
    ports:
      - "${DRONE_RUNNER_PORT}:3000"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3

  drone-redis:
    image: redis:6-alpine
    container_name: drone-redis-${CLIENT_ID}
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - ${CLIENT_DIR}/droneci_data/redis:/data
    networks:
      - droneci_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  droneci_network:
    driver: bridge
  traefik_network:
    external: true
    name: traefik-network
EOF

  log "INFO" "Docker Compose configuration created successfully"
}

# Create environment configuration file
create_env_file() {
  log "INFO" "Creating environment configuration..."
  
  mkdir -p "${DRONECI_DIR}"

  # Create base environment file
  cat > "${DOCKER_ENV_FILE}" << EOF
# Drone CI Configuration
DRONE_SERVER_HOST=${DOMAIN}
DRONE_SERVER_PROTO=https
DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
DRONE_RPC_PORT=${DRONE_RPC_PORT}
DRONE_DATABASE_DRIVER=sqlite3
DRONE_DATABASE_DATASOURCE=/data/database.sqlite
DRONE_SERVER_PORT=:${DRONE_SERVER_PORT}

# User management
DRONE_USER_CREATE=username:admin,admin:true

# Logging
DRONE_LOGS_DEBUG=false
DRONE_LOGS_TRACE=false
DRONE_LOGS_COLOR=true
DRONE_LOGS_PRETTY=true
DRONE_LOGS_TEXT=true

# TLS Configuration
DRONE_TLS_AUTOCERT=false

# SMTP Configuration
DRONE_SMTP_HOST=${MAILU_DOMAIN}
DRONE_SMTP_PORT=587
DRONE_SMTP_USERNAME=${MAILU_USER}
DRONE_SMTP_PASSWORD=${MAILU_PASSWORD}
DRONE_SMTP_FROM=${MAILU_USER}
DRONE_SMTP_SKIP_VERIFY=false

# Security Settings
DRONE_USER_FILTER=
DRONE_REPOSITORY_FILTER=
DRONE_COOKIE_TIMEOUT=720h
DRONE_COOKIE_SECRET=$(openssl rand -hex 16)

# Runner Configuration
DRONE_RUNNER_CAPACITY=2
DRONE_RUNNER_NAME=drone-runner-${CLIENT_ID}
EOF

  # Add Gitea integration if enabled
  if [ "$ENABLE_GITEA" = true ]; then
    cat >> "${DOCKER_ENV_FILE}" << EOF

# Gitea Integration
DRONE_GITEA=true
DRONE_GITEA_SERVER=https://${GITEA_DOMAIN}
DRONE_GITEA_CLIENT_ID=${GITEA_CLIENT_ID}
DRONE_GITEA_CLIENT_SECRET=${GITEA_CLIENT_SECRET}
EOF
  fi

  # Add Keycloak SSO integration if enabled
  if [ "$ENABLE_SSO" = true ]; then
    cat >> "${DOCKER_ENV_FILE}" << EOF

# Keycloak SSO Integration
DRONE_KEYCLOAK=true
DRONE_KEYCLOAK_REALM=${CLIENT_ID}
DRONE_KEYCLOAK_CLIENT_ID=droneci
DRONE_KEYCLOAK_SERVER=https://keycloak.${DOMAIN/ci./}/auth
EOF
  fi

  log "INFO" "Environment configuration created successfully"
}

# Setup Traefik configuration
setup_traefik() {
  log "INFO" "Setting up Traefik configuration..."
  
  # Ensure the Traefik config directory exists
  mkdir -p "${TRAEFIK_CONFIG_DIR}/dynamic"
  
  # Create Drone CI Traefik configuration
  cat > "${TRAEFIK_CONFIG_DIR}/dynamic/droneci-${CLIENT_ID}.toml" << EOF
[http.routers.drone-${CLIENT_ID}]
  rule = "Host(\`${DOMAIN}\`)"
  entrypoints = ["websecure"]
  service = "drone-${CLIENT_ID}"
  middlewares = ["drone-${CLIENT_ID}-security"]
  [http.routers.drone-${CLIENT_ID}.tls]
    certResolver = "letsencrypt"

[http.services.drone-${CLIENT_ID}.loadBalancer]
  [[http.services.drone-${CLIENT_ID}.loadBalancer.servers]]
    url = "http://drone-server-${CLIENT_ID}:${DRONE_SERVER_PORT}"

[http.middlewares.drone-${CLIENT_ID}-security.headers]
  stsSeconds = 31536000
  browserXssFilter = true
  contentTypeNosniff = true
  forceSTSHeader = true
  stsIncludeSubdomains = true
  stsPreload = true
  frameDeny = false
  [http.middlewares.drone-${CLIENT_ID}-security.headers.customResponseHeaders]
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
  mkdir -p "${CLIENT_DIR}/droneci_data/config/sso"
  
  # Create a note file with instructions for completing SSO setup
  cat > "${CLIENT_DIR}/droneci_data/config/sso/keycloak-setup-instructions.txt" << EOF
Keycloak SSO Integration Instructions for Drone CI

To complete the SSO integration, perform these steps in your Keycloak instance:

1. Create a new client in the ${CLIENT_ID} realm:
   - Client ID: droneci
   - Client Protocol: openid-connect
   - Access Type: confidential
   - Valid Redirect URIs: https://${DOMAIN}/login
   - Web Origins: https://${DOMAIN}

2. Once created, go to the Credentials tab and copy the Secret

3. Update the .env file with the correct configuration:
   - Edit ${DOCKER_ENV_FILE}
   - Add/update DRONE_KEYCLOAK_CLIENT_SECRET with your actual secret

4. Create Mapper for user attributes (if not present):
   - Add mappers for email, name, and preferred_username if they don't exist

5. Restart Drone CI services:
   - Run: make droneci-restart

For more information, see the Drone CI documentation on OIDC SSO integration.
EOF

  log "INFO" "SSO integration setup completed"
}

# Setup Gitea integration
setup_gitea() {
  if [ "$ENABLE_GITEA" = false ]; then
    log "INFO" "Skipping Gitea integration setup (--enable-gitea not specified)"
    return
  fi
  
  log "INFO" "Setting up Gitea integration..."
  
  # Create directory for Gitea integration configuration
  mkdir -p "${CLIENT_DIR}/droneci_data/config/gitea"
  
  # Create a note file with instructions for completing Gitea integration
  cat > "${CLIENT_DIR}/droneci_data/config/gitea/gitea-setup-instructions.txt" << EOF
Gitea Integration Instructions for Drone CI

The Drone CI instance is configured to authenticate with Gitea at https://${GITEA_DOMAIN}

If you haven't already set up the OAuth application in Gitea, follow these steps:

1. Login to Gitea as an administrator
2. Go to Site Administration > Applications
3. Create a new OAuth2 application:
   - Name: Drone CI
   - Redirect URI: https://${DOMAIN}/login
   - Client ID: ${GITEA_CLIENT_ID} (or create a new one)
   - Client Secret: ${GITEA_CLIENT_SECRET} (or create a new one)

4. If you created new credentials, update the .env file:
   - Edit ${DOCKER_ENV_FILE}
   - Update DRONE_GITEA_CLIENT_ID and DRONE_GITEA_CLIENT_SECRET

5. Restart Drone CI services:
   - Run: make droneci-restart

For more information, see the Drone CI documentation on Gitea integration.
EOF

  log "INFO" "Gitea integration setup completed"
}

# Setup monitoring hooks
setup_monitoring() {
  log "INFO" "Setting up monitoring hooks..."
  
  # Create monitoring configuration for Drone CI
  mkdir -p "${ROOT_DIR}/monitoring/config/components"
  
  # Create Prometheus configuration for scraping Drone CI metrics
  cat > "${ROOT_DIR}/monitoring/config/components/droneci-${CLIENT_ID}.yml" << EOF
- job_name: 'drone-server-${CLIENT_ID}'
  scrape_interval: 30s
  metrics_path: '/metrics'
  static_configs:
    - targets: ['drone-server-${CLIENT_ID}:${DRONE_SERVER_PORT}']
      labels:
        instance: 'drone-server'
        component: 'devops'
        client_id: '${CLIENT_ID}'

- job_name: 'drone-runner-${CLIENT_ID}'
  scrape_interval: 30s
  metrics_path: '/metrics'
  static_configs:
    - targets: ['drone-runner-${CLIENT_ID}:3000']
      labels:
        instance: 'drone-runner'
        component: 'devops'
        client_id: '${CLIENT_ID}'
EOF

  # Create monitoring check script
  mkdir -p "${ROOT_DIR}/monitoring/scripts"
  
  cat > "${ROOT_DIR}/monitoring/scripts/check_droneci-${CLIENT_ID}.sh" << EOF
#!/bin/bash
# Drone CI monitoring check script for ${CLIENT_ID}

# Check if Drone Server is responding
curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/healthz" | grep -q "200"
exit \$?
EOF
  
  chmod +x "${ROOT_DIR}/monitoring/scripts/check_droneci-${CLIENT_ID}.sh"
  
  # Create Loki logging configuration
  mkdir -p "${ROOT_DIR}/monitoring/loki/config"
  
  cat > "${ROOT_DIR}/monitoring/loki/config/droneci-${CLIENT_ID}.yml" << EOF
scrape_configs:
  - job_name: drone-${CLIENT_ID}-logs
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(drone-server-${CLIENT_ID}|drone-runner-${CLIENT_ID})$'
        action: keep
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: container
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: logstream
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: service
EOF

  log "INFO" "Monitoring hooks set up successfully"
}

# Register Drone CI component with AgencyStack
register_component() {
  log "INFO" "Registering Drone CI component with AgencyStack..."
  
  # Ensure config directory exists
  mkdir -p "${CONFIG_DIR}"
  
  # Add to installed components
  if ! grep -q "droneci" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
    echo "droneci" >> "${INSTALLED_COMPONENTS}"
    log "INFO" "Added Drone CI to installed components list"
  fi
  
  # Update dashboard data
  if [ -f "${DASHBOARD_DATA}" ]; then
    # Check if Drone CI entry already exists
    if ! grep -q '"component": "droneci"' "${DASHBOARD_DATA}"; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      jq --argjson new_component '{
        "component": "droneci",
        "name": "Drone CI",
        "description": "Continuous Integration and Delivery platform",
        "category": "DevOps",
        "url": "https://'"${DOMAIN}"'",
        "adminUrl": "https://'"${DOMAIN}"'/account/repos",
        "version": "'"${DRONE_VERSION}"'",
        "installDate": "'"$(date -Iseconds)"'",
        "status": "active",
        "icon": "activity",
        "clientId": "'"${CLIENT_ID}"'"
      }' '.components += [$new_component]' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
      log "INFO" "Updated dashboard data with Drone CI component"
    else
      log "INFO" "Drone CI already exists in dashboard data"
    fi
  else
    # Create a new dashboard data file
    cat > "${DASHBOARD_DATA}" << EOF
{
  "components": [
    {
      "component": "droneci",
      "name": "Drone CI",
      "description": "Continuous Integration and Delivery platform",
      "category": "DevOps",
      "url": "https://${DOMAIN}",
      "adminUrl": "https://${DOMAIN}/account/repos",
      "version": "${DRONE_VERSION}",
      "installDate": "$(date -Iseconds)",
      "status": "active",
      "icon": "activity",
      "clientId": "${CLIENT_ID}"
    }
  ]
}
EOF
    log "INFO" "Created new dashboard data file with Drone CI component"
  fi
  
  # Update integration status
  if [ -f "${INTEGRATION_STATUS}" ]; then
    # Check if Drone CI entry already exists
    if ! grep -q '"component": "droneci"' "${INTEGRATION_STATUS}"; then
      # Create a temporary file with the new integration status
      TEMP_FILE=$(mktemp)
      jq --argjson new_status '{
        "component": "droneci",
        "clientId": "'"${CLIENT_ID}"'",
        "integrations": {
          "monitoring": true,
          "auth": '"${ENABLE_SSO}"',
          "mail": true,
          "gitea": '"${ENABLE_GITEA}"'
        },
        "lastChecked": "'"$(date -Iseconds)"'"
      }' '.status += [$new_status]' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
      log "INFO" "Updated integration status with Drone CI component"
    else
      log "INFO" "Drone CI already exists in integration status"
    fi
  else
    # Create a new integration status file
    cat > "${INTEGRATION_STATUS}" << EOF
{
  "status": [
    {
      "component": "droneci",
      "clientId": "${CLIENT_ID}",
      "integrations": {
        "monitoring": true,
        "auth": ${ENABLE_SSO},
        "mail": true,
        "gitea": ${ENABLE_GITEA}
      },
      "lastChecked": "$(date -Iseconds)"
    }
  ]
}
EOF
    log "INFO" "Created new integration status file with Drone CI component"
  fi
  
  log "INFO" "Drone CI component registered successfully"
}

# Register component in component registry
register_component_registry() {
  log "INFO" "Registering Drone CI in the component registry..."
  
  local REGISTRY_DIR="${CONFIG_DIR}/registry"
  local REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
  
  mkdir -p "${REGISTRY_DIR}"
  
  if [ -f "${REGISTRY_FILE}" ]; then
    # Check if Drone CI entry already exists
    if ! jq -e '.components.devops.droneci' "${REGISTRY_FILE}" > /dev/null 2>&1; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      
      jq --arg version "${DRONE_VERSION}" '.components.devops.droneci = {
        "name": "Drone CI",
        "category": "DevOps",
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
        "description": "Continuous Integration and Delivery platform",
        "ports": {
          "web": '"${DRONE_SERVER_PORT}"',
          "rpc": '"${DRONE_RPC_PORT}"',
          "runner": '"${DRONE_RUNNER_PORT}"'
        }
      }' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      # Update the timestamp
      TEMP_FILE=$(mktemp)
      jq --arg ts "$(date -Iseconds)" '.last_updated = $ts' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      log "INFO" "Added Drone CI to component registry"
    else
      log "INFO" "Drone CI already exists in component registry"
    fi
  else
    log "WARN" "Component registry not found, skipping registration"
  fi
}

# Start Drone CI containers
start_services() {
  log "INFO" "Starting Drone CI services..."
  
  cd "${DRONECI_DIR}"
  docker-compose up -d
  
  # Wait for services to be ready
  log "INFO" "Waiting for Drone CI services to be ready..."
  sleep 10
  
  log "INFO" "Drone CI services started successfully"
}

# Validate installation
validate_installation() {
  log "INFO" "Validating Drone CI installation..."
  
  # Ensure validate_system.sh exists
  if [ ! -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
    log "WARN" "validate_system.sh not found, skipping validation"
    return
  fi
  
  # Run validation
  "${ROOT_DIR}/scripts/utils/validate_system.sh" --component=droneci --client-id="${CLIENT_ID}"
  
  # Check if validation was successful
  if [ $? -eq 0 ]; then
    log "INFO" "Drone CI installation validated successfully"
  else
    log "WARN" "Drone CI installation validation failed"
  fi
}

# Create backup script
create_backup_script() {
  log "INFO" "Creating backup script..."
  
  mkdir -p "${CLIENT_DIR}/droneci_data/scripts"
  
  cat > "${CLIENT_DIR}/droneci_data/scripts/backup.sh" << EOF
#!/bin/bash
# Drone CI backup script for client ${CLIENT_ID}

BACKUP_DIR="\${1:-/opt/agency_stack/backups/droneci}"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
CLIENT_ID="${CLIENT_ID}"
CLIENT_DIR="${CLIENT_DIR}"

# Create backup directory
mkdir -p "\${BACKUP_DIR}"

# Backup Drone Server data
echo "Backing up Drone Server data..."
tar -czf "\${BACKUP_DIR}/drone-server-\${CLIENT_ID}-\${TIMESTAMP}.tar.gz" -C "${CLIENT_DIR}/droneci_data" server

# Backup Runner data if needed
echo "Backing up Drone Runner data..."
tar -czf "\${BACKUP_DIR}/drone-runner-\${CLIENT_ID}-\${TIMESTAMP}.tar.gz" -C "${CLIENT_DIR}/droneci_data" runner

# Backup configs
echo "Backing up Drone CI configuration..."
cp "${DOCKER_ENV_FILE}" "\${BACKUP_DIR}/drone-env-\${CLIENT_ID}-\${TIMESTAMP}.env"
cp "${DOCKER_COMPOSE_FILE}" "\${BACKUP_DIR}/drone-compose-\${CLIENT_ID}-\${TIMESTAMP}.yml"

echo "Backup completed successfully:"
echo "\${BACKUP_DIR}/drone-server-\${CLIENT_ID}-\${TIMESTAMP}.tar.gz"
echo "\${BACKUP_DIR}/drone-runner-\${CLIENT_ID}-\${TIMESTAMP}.tar.gz"
echo "\${BACKUP_DIR}/drone-env-\${CLIENT_ID}-\${TIMESTAMP}.env"
echo "\${BACKUP_DIR}/drone-compose-\${CLIENT_ID}-\${TIMESTAMP}.yml"
EOF

  chmod +x "${CLIENT_DIR}/droneci_data/scripts/backup.sh"
  
  log "INFO" "Backup script created successfully"
}

# Main installation function
install_droneci() {
  log "INFO" "Starting Drone CI installation..."
  
  # Check if already installed
  if grep -q "droneci" "${INSTALLED_COMPONENTS}" 2>/dev/null && [ "$FORCE" = false ]; then
    log "ERROR" "Drone CI is already installed. Use --force to reinstall."
    exit 1
  fi
  
  # Generate RPC secret if not provided
  generate_rpc_secret
  
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
  
  # Configure Gitea integration if requested
  setup_gitea
  
  # Setup monitoring hooks
  setup_monitoring
  
  # Create backup script
  create_backup_script
  
  # Start Drone CI services
  start_services
  
  # Register Drone CI component with AgencyStack
  register_component
  
  # Register in component registry
  register_component_registry
  
  # Validate installation
  validate_installation
  
  log "INFO" "Drone CI installation completed successfully"
  echo -e "\n${BOLD}${GREEN}Drone CI installation completed successfully${NC}"
  echo -e "${BOLD}Web UI:${NC} https://${DOMAIN}"
  echo -e "${BOLD}Client ID:${NC} ${CLIENT_ID}"
  echo -e "${BOLD}Data Directory:${NC} ${CLIENT_DIR}/droneci_data"
  echo -e "${BOLD}Log File:${NC} ${DRONECI_LOG}"
  
  # Show Gitea integration information if enabled
  if [ "$ENABLE_GITEA" = true ]; then
    echo -e "\n${BOLD}${YELLOW}Gitea Integration:${NC}"
    echo -e "Gitea Server: https://${GITEA_DOMAIN}"
    echo -e "Please review ${CLIENT_DIR}/droneci_data/config/gitea/gitea-setup-instructions.txt for completing setup"
  fi
  
  # Show SSO integration information if enabled
  if [ "$ENABLE_SSO" = true ]; then
    echo -e "\n${BOLD}${YELLOW}Keycloak SSO Integration:${NC}"
    echo -e "Please review ${CLIENT_DIR}/droneci_data/config/sso/keycloak-setup-instructions.txt for completing setup"
  fi
  
  # Show RPC secret for runner setup
  echo -e "\n${BOLD}${YELLOW}Drone RPC Secret (save in a secure location):${NC}"
  echo -e "${DRONE_RPC_SECRET}"
  
  echo -e "\n${BOLD}${YELLOW}NOTE: For security reasons, please change the admin password after first login.${NC}"
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
    --enable-gitea)
      ENABLE_GITEA=true
      shift
      ;;
    --gitea-domain)
      GITEA_DOMAIN="$2"
      shift
      shift
      ;;
    --gitea-client-id)
      GITEA_CLIENT_ID="$2"
      shift
      shift
      ;;
    --gitea-client-secret)
      GITEA_CLIENT_SECRET="$2"
      shift
      shift
      ;;
    --enable-sso)
      ENABLE_SSO=true
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
    --drone-rpc-secret)
      DRONE_RPC_SECRET="$2"
      shift
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
fi

# If Mailu parameters are not provided, use defaults
if [ -z "$MAILU_DOMAIN" ]; then
  MAILU_DOMAIN="mail.${DOMAIN/ci./}"
  log "INFO" "Mailu domain not specified, using default: ${MAILU_DOMAIN}"
fi

if [ -z "$MAILU_USER" ]; then
  MAILU_USER="droneci@${DOMAIN/ci./}"
  log "INFO" "Mailu user not specified, using default: ${MAILU_USER}"
fi

if [ -z "$MAILU_PASSWORD" ]; then
  log "WARN" "Mailu password not specified. SMTP may not work properly."
  MAILU_PASSWORD="password_not_set"
fi

# Make script executable
chmod +x "$0"

# Run the installer
install_droneci
