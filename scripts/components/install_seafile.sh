#!/bin/bash
# install_seafile.sh - AgencyStack Seafile Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures Seafile with hardened security
# Part of the AgencyStack Storage & Documents suite
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
SEAFILE_LOG="${COMPONENT_LOG_DIR}/seafile.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Seafile Configuration
SEAFILE_VERSION="10.0.1"  # Latest stable version
SEAFILE_PORT=8000
SEAFILE_DB_PORT=3306
SEAFILE_MEMCACHED_PORT=11211
SEAFILE_ADMIN_EMAIL=""
SEAFILE_ADMIN_PASSWORD=$(openssl rand -hex 8)
SEAFILE_DB_ROOT_PASSWORD=$(openssl rand -hex 16)
SEAFILE_DB_PASSWORD=$(openssl rand -hex 16)
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
SEAFILE_CONFIG_DIR="${CONFIG_DIR}/seafile"
DOCKER_COMPOSE_DIR="${SEAFILE_CONFIG_DIR}/docker"
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
  echo "[$timestamp] [$level] $message" >> "${SEAFILE_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Seafile Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Seafile (e.g., files.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications and login"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain files.example.com --admin-email admin@example.com --with-deps"
  echo -e "  $0 --domain files.client1.com --client-id client1 --admin-email admin@client1.com --with-deps"
  echo -e "  $0 --domain files.client2.com --client-id client2 --admin-email admin@client2.com --force"
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
  mkdir -p "${CLIENT_DIR}/seafile/conf"
  mkdir -p "${CLIENT_DIR}/seafile/seafile-data"
  mkdir -p "${CLIENT_DIR}/seafile/logs"
  mkdir -p "${CLIENT_DIR}/seafile/mysql"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/seafile"
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
      SEAFILE_ADMIN_EMAIL="$2"
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
if [ -z "$SEAFILE_ADMIN_EMAIL" ]; then
  log "ERROR" "Admin email is required. Use --admin-email to specify it."
  show_help
fi

# Set up directories
log "INFO" "Setting up directories for Seafile installation"
setup_client_dir

# Check if Seafile is already installed
SEAFILE_CONTAINER="${CLIENT_ID}_seafile"
SEAFILE_DB_CONTAINER="${CLIENT_ID}_seafile_mysql"
SEAFILE_MEMCACHED_CONTAINER="${CLIENT_ID}_seafile_memcached"
if docker ps -a --format '{{.Names}}' | grep -q "$SEAFILE_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Seafile container '$SEAFILE_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Seafile containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Seafile container '$SEAFILE_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$SEAFILE_CONTAINER"; then
      log "INFO" "Seafile container is running"
      echo -e "${GREEN}Seafile is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Seafile URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Seafile container exists but is not running"
      echo -e "${YELLOW}Seafile is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Seafile containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Seafile has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Seafile URL: https://${DOMAIN}${NC}"
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

# Create Docker Compose file
log "INFO" "Creating Docker Compose configuration"
cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  db:
    image: mariadb:10.6
    container_name: ${SEAFILE_DB_CONTAINER}
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${SEAFILE_DB_ROOT_PASSWORD}
      - MYSQL_LOG_CONSOLE=true
    volumes:
      - ${CLIENT_DIR}/seafile/mysql:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${SEAFILE_DB_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  memcached:
    image: memcached:1.6
    container_name: ${SEAFILE_MEMCACHED_CONTAINER}
    restart: unless-stopped
    entrypoint: memcached -m 256
    networks:
      - ${NETWORK_NAME}

  seafile:
    image: seafileltd/seafile-mc:${SEAFILE_VERSION}
    container_name: ${SEAFILE_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/seafile/conf:/shared/seafile/conf
      - ${CLIENT_DIR}/seafile/seafile-data:/shared/seafile/seafile-data
      - ${CLIENT_DIR}/seafile/logs:/shared/seafile/logs
    environment:
      - DB_HOST=${SEAFILE_DB_CONTAINER}
      - DB_ROOT_PASSWD=${SEAFILE_DB_ROOT_PASSWORD}
      - TIME_ZONE=UTC
      - SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
      - SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
      - SEAFILE_SERVER_HOSTNAME=${DOMAIN}
      - SEAFILE_SERVER_LETSENCRYPT=false  # We'll use Traefik for SSL
    ports:
      - "${SEAFILE_PORT}:80"
    depends_on:
      - db
      - memcached
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-seafile.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-seafile.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-seafile.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-seafile.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-seafile.loadbalancer.server.port=80"
      - "traefik.http.middlewares.${CLIENT_ID}-seafile-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-seafile-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-seafile-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-seafile-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-seafile.middlewares=${CLIENT_ID}-seafile-headers"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
SEAFILE_VERSION=${SEAFILE_VERSION}
SEAFILE_PORT=${SEAFILE_PORT}
SEAFILE_DB_PORT=${SEAFILE_DB_PORT}
SEAFILE_MEMCACHED_PORT=${SEAFILE_MEMCACHED_PORT}
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
SEAFILE_DB_ROOT_PASSWORD=${SEAFILE_DB_ROOT_PASSWORD}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/seafile"
cat > "${CONFIG_DIR}/secrets/seafile/${DOMAIN}.env" << EOF
SEAFILE_URL=https://${DOMAIN}
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
SEAFILE_DB_ROOT_PASSWORD=${SEAFILE_DB_ROOT_PASSWORD}
EOF

# Start Seafile
log "INFO" "Starting Seafile"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Seafile"
  exit 1
}

# Wait for Seafile to be ready (this can take a few minutes)
log "INFO" "Waiting for Seafile to be ready (this might take a few minutes)"
timeout=300  # Seafile can take a while to initialize
counter=0
echo -n "Waiting for Seafile to start"
while [ $counter -lt $timeout ]; do
  if docker logs ${SEAFILE_CONTAINER} 2>&1 | grep -q "Seahub is started"; then
    break
  fi
  echo -n "."
  sleep 5
  counter=$((counter+5))
done
echo

if [ $counter -ge $timeout ]; then
  log "WARN" "Timed out waiting for Seafile to fully start, but containers are running"
  log "INFO" "You can check the status manually after a few minutes"
else
  log "INFO" "Seafile is now ready"
fi

# Update installation records
if ! grep -q "seafile" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "seafile" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${SEAFILE_PORT}" \
       --arg version "${SEAFILE_VERSION}" \
       --arg admin_email "${SEAFILE_ADMIN_EMAIL}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.seafile = {
         "name": "Seafile",
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
       '.seafile = {
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
echo -e "${GREEN}${BOLD}✅ Seafile has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Port: ${SEAFILE_PORT}${NC}"
echo -e "${CYAN}Version: ${SEAFILE_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Admin Email: ${SEAFILE_ADMIN_EMAIL}"
echo -e "Admin Password: ${SEAFILE_ADMIN_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/seafile/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Note:${NC} Seafile may take a few minutes to fully initialize. If you can't access it immediately,"
echo -e "wait a few minutes and then try again."

log "INFO" "Seafile installation completed successfully"
exit 0
