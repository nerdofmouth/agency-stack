#!/bin/bash
# install_focalboard.sh - AgencyStack Focalboard Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures Focalboard with hardened security
# Part of the AgencyStack Collaboration & Productivity suite
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
FOCALBOARD_LOG="${COMPONENT_LOG_DIR}/focalboard.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Focalboard Configuration
FOCALBOARD_VERSION="7.10.3"  # Latest stable version
FOCALBOARD_PORT=8000
FOCALBOARD_DB_PORT=5432
FOCALBOARD_ADMIN_EMAIL=""
FOCALBOARD_ADMIN_USERNAME="admin"
FOCALBOARD_ADMIN_PASSWORD=$(openssl rand -hex 8)
FOCALBOARD_DB_PASSWORD=$(openssl rand -hex 16)
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
FOCALBOARD_CONFIG_DIR="${CONFIG_DIR}/focalboard"
DOCKER_COMPOSE_DIR="${FOCALBOARD_CONFIG_DIR}/docker"
WITH_DEPS=false
FORCE=false
VERBOSE=false
SSO=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${FOCALBOARD_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Focalboard Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Focalboard (e.g., board.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications and login"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain board.example.com --admin-email admin@example.com --with-deps"
  echo -e "  $0 --domain board.client1.com --client-id client1 --admin-email admin@client1.com --with-deps"
  echo -e "  $0 --domain board.client2.com --client-id client2 --admin-email admin@client2.com --force"
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
  mkdir -p "${CLIENT_DIR}/focalboard/config"
  mkdir -p "${CLIENT_DIR}/focalboard/data"
  mkdir -p "${CLIENT_DIR}/focalboard/postgres"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/focalboard"
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --admin-email)
      FOCALBOARD_ADMIN_EMAIL="$2"
      shift 2
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log "ERROR" "Unknown parameter passed: $1"
      show_help
      ;;
  esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain is required. Use --domain to specify it."
  show_help
fi

# Check if admin email is provided
if [ -z "$FOCALBOARD_ADMIN_EMAIL" ]; then
  log "ERROR" "Admin email is required. Use --admin-email to specify it."
  show_help
fi

# Set up directories
log "INFO" "Setting up directories for Focalboard installation"
setup_client_dir

# Check if Focalboard is already installed
FOCALBOARD_CONTAINER="${CLIENT_ID}_focalboard"
FOCALBOARD_DB_CONTAINER="${CLIENT_ID}_focalboard_postgres"
if docker ps -a --format '{{.Names}}' | grep -q "$FOCALBOARD_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Focalboard container '$FOCALBOARD_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Focalboard containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Focalboard container '$FOCALBOARD_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$FOCALBOARD_CONTAINER"; then
      log "INFO" "Focalboard container is running"
      echo -e "${GREEN}Focalboard is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Focalboard URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Focalboard container exists but is not running"
      echo -e "${YELLOW}Focalboard is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Focalboard containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Focalboard has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Focalboard URL: https://${DOMAIN}${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR" "Docker is not installed. Please install Docker first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker.sh" || {
        log "ERROR" "Failed to install Docker. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker.sh script. Please install Docker manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR" "Docker Compose is not installed. Please install Docker Compose first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker Compose with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker_compose.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker_compose.sh" || {
        log "ERROR" "Failed to install Docker Compose. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker_compose.sh script. Please install Docker Compose manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Create Docker network if it doesn't exist
NETWORK_NAME="${CLIENT_ID}_network"
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO" "Creating Docker network $NETWORK_NAME"
  docker network create "$NETWORK_NAME" || {
    log "ERROR" "Failed to create Docker network $NETWORK_NAME."
    exit 1
  }
fi

# Create Focalboard config file
log "INFO" "Creating Focalboard configuration"
mkdir -p "${CLIENT_DIR}/focalboard/config"
cat > "${CLIENT_DIR}/focalboard/config/config.json" << EOF
{
  "serverRoot": "https://${DOMAIN}",
  "port": 8000,
  "dbtype": "postgres",
  "dbconfig": "postgres://focalboard:${FOCALBOARD_DB_PASSWORD}@${FOCALBOARD_DB_CONTAINER}:5432/focalboard?sslmode=disable",
  "postgres_dbconfig": "postgres://focalboard:${FOCALBOARD_DB_PASSWORD}@${FOCALBOARD_DB_CONTAINER}:5432/focalboard?sslmode=disable",
  "useSSL": false,
  "webpath": "./pack",
  "filespath": "/data/files",
  "telemetry": false,
  "session_expire_time": 2592000,
  "session_refresh_time": 18000,
  "localOnly": false,
  "enableLocalMode": false,
  "localModeSocketLocation": "/var/tmp/focalboard_local.socket",
  "enablePublicSharedBoards": true,
  "featureFlags": {},
  "enableDataRetention": true,
  "dataRetentionDays": 365
}
EOF

# Create Docker Compose file
log "INFO" "Creating Docker Compose configuration"
cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  postgres:
    image: postgres:13
    container_name: ${FOCALBOARD_DB_CONTAINER}
    restart: unless-stopped
    environment:
      - POSTGRES_DB=focalboard
      - POSTGRES_USER=focalboard
      - POSTGRES_PASSWORD=${FOCALBOARD_DB_PASSWORD}
    volumes:
      - ${CLIENT_DIR}/focalboard/postgres:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U focalboard"]
      interval: 10s
      timeout: 5s
      retries: 5

  focalboard:
    image: mattermost/focalboard:${FOCALBOARD_VERSION}
    container_name: ${FOCALBOARD_CONTAINER}
    restart: unless-stopped
    depends_on:
      - postgres
    volumes:
      - ${CLIENT_DIR}/focalboard/config:/config
      - ${CLIENT_DIR}/focalboard/data:/data
    environment:
      - CONFIG_FILE=/config/config.json
      - VIRTUAL_HOST=${DOMAIN}
      - VIRTUAL_PORT=8000
      - FOCALBOARD_ADMIN_USERNAME=${FOCALBOARD_ADMIN_USERNAME}
      - FOCALBOARD_ADMIN_EMAIL=${FOCALBOARD_ADMIN_EMAIL}
      - FOCALBOARD_ADMIN_PASSWORD=${FOCALBOARD_ADMIN_PASSWORD}
    ports:
      - "${FOCALBOARD_PORT}:8000"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-focalboard.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-focalboard.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-focalboard.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-focalboard.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-focalboard.loadbalancer.server.port=8000"
      - "traefik.http.middlewares.${CLIENT_ID}-focalboard-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-focalboard-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-focalboard-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-focalboard-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-focalboard.middlewares=${CLIENT_ID}-focalboard-headers"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8000/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 10s

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
FOCALBOARD_VERSION=${FOCALBOARD_VERSION}
FOCALBOARD_PORT=${FOCALBOARD_PORT}
FOCALBOARD_DB_PORT=${FOCALBOARD_DB_PORT}
FOCALBOARD_ADMIN_EMAIL=${FOCALBOARD_ADMIN_EMAIL}
FOCALBOARD_ADMIN_USERNAME=${FOCALBOARD_ADMIN_USERNAME}
FOCALBOARD_ADMIN_PASSWORD=${FOCALBOARD_ADMIN_PASSWORD}
FOCALBOARD_DB_PASSWORD=${FOCALBOARD_DB_PASSWORD}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/focalboard"
cat > "${CONFIG_DIR}/secrets/focalboard/${DOMAIN}.env" << EOF
FOCALBOARD_URL=https://${DOMAIN}
FOCALBOARD_ADMIN_EMAIL=${FOCALBOARD_ADMIN_EMAIL}
FOCALBOARD_ADMIN_USERNAME=${FOCALBOARD_ADMIN_USERNAME}
FOCALBOARD_ADMIN_PASSWORD=${FOCALBOARD_ADMIN_PASSWORD}
FOCALBOARD_DB_PASSWORD=${FOCALBOARD_DB_PASSWORD}
EOF

# Start Focalboard
log "INFO" "Starting Focalboard"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Focalboard"
  exit 1
}

# Wait for Focalboard to be ready
log "INFO" "Waiting for Focalboard to be ready"
timeout=120
counter=0
echo -n "Waiting for Focalboard to start"
while [ $counter -lt $timeout ]; do
  if curl -s "http://localhost:${FOCALBOARD_PORT}/api/v1/health" | grep -q "ok"; then
    break
  fi
  echo -n "."
  sleep 2
  counter=$((counter+2))
done
echo

if [ $counter -ge $timeout ]; then
  log "WARN" "Timed out waiting for Focalboard to fully start, but containers are running"
  log "INFO" "You can check the status manually after a few minutes"
else
  log "INFO" "Focalboard is now ready"
fi

# Update installation records
if ! grep -q "focalboard" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "focalboard" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${FOCALBOARD_PORT}" \
       --arg version "${FOCALBOARD_VERSION}" \
       --arg admin_email "${FOCALBOARD_ADMIN_EMAIL}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.focalboard = {
         "name": "Focalboard",
         "url": "https://" + $domain,
         "port": $port,
         "version": $version,
         "admin_email": $admin_email,
         "status": "running",
         "last_updated": $timestamp
       }' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
       
    # Replace original file with updated data
    mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
  else
    log "WARN" "jq is not installed. Skipping dashboard data update."
  fi
fi

# Update integration status
if [ -f "${INTEGRATION_STATUS}" ]; then
  if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    
    jq --arg domain "${DOMAIN}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.focalboard = {
         "integrated": true,
         "domain": $domain,
         "last_updated": $timestamp
       }' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
       
    mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
  else
    log "WARN" "jq is not installed. Skipping integration status update."
  fi
fi

# Display completion message
echo -e "${GREEN}${BOLD}✅ Focalboard has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Port: ${FOCALBOARD_PORT}${NC}"
echo -e "${CYAN}Version: ${FOCALBOARD_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Admin Username: ${FOCALBOARD_ADMIN_USERNAME}"
echo -e "Admin Email: ${FOCALBOARD_ADMIN_EMAIL}"
echo -e "Admin Password: ${FOCALBOARD_ADMIN_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/focalboard/${DOMAIN}.env${NC}"

log "INFO" "Focalboard installation completed successfully"
exit 0
