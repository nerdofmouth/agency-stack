#!/bin/bash
# install_etebase.sh - AgencyStack Etebase Integration
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures Etebase server for encrypted CalDAV/CardDAV
# Part of the AgencyStack Collaboration & Security suite
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

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
ETEBASE_LOG="${COMPONENT_LOG_DIR}/etebase.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
COMPONENT_REGISTRY="${CONFIG_DIR}/config/registry/component_registry.json"
DASHBOARD_DATA="${CONFIG_DIR}/config/dashboard_data.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${CONFIG_DIR}/docker/etebase"

# Etebase Configuration
ETEBASE_VERSION="0.7.0"
CLIENT_ID=""
CLIENT_DIR=""
DOMAIN=""
PORT="8732"
WITH_DEPS=false
FORCE=false
ADMIN_USER=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
SSL=true
ENABLE_MONITORING=true
BACKUP_DIR="${CONFIG_DIR}/backups/etebase"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${ETEBASE_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Etebase Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--domain${NC} <domain>          Domain name for Etebase"
  echo -e "  ${CYAN}--port${NC} <port>              Port for Etebase server (default: 8732)"
  echo -e "  ${CYAN}--admin-user${NC} <username>    Admin username for Etebase"
  echo -e "  ${CYAN}--admin-email${NC} <email>      Admin email for Etebase"
  echo -e "  ${CYAN}--admin-password${NC} <pwd>     Admin password for Etebase (UNSAFE: use only for automation)"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (Docker, Docker Compose, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--no-ssl${NC}                   Disable SSL (not recommended for production)"
  echo -e "  ${CYAN}--disable-monitoring${NC}       Disable monitoring integration"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --client-id client1 --domain etebase.example.com --with-deps"
  echo -e "  $0 --client-id client1 --domain etebase.example.com --admin-user admin --admin-email admin@example.com"
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
  mkdir -p "${CLIENT_DIR}/etebase/data"
  mkdir -p "${CLIENT_DIR}/etebase/config"
  mkdir -p "${CLIENT_DIR}/etebase/logs"
  mkdir -p "${CLIENT_DIR}/etebase/scripts"
  mkdir -p "${CLIENT_DIR}/etebase/backups"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}"
  
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
  if ! command -v docker &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check if Docker Compose is installed
  if ! command -v docker-compose &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check if domain is provided
  if [ -z "$DOMAIN" ]; then
    log "ERROR" "Domain name is required. Please provide a domain name using --domain"
    exit 1
  fi
  
  # All checks passed
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Install Docker if not installed
  if ! command -v docker &> /dev/null; then
    log "INFO" "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $(whoami)
    systemctl enable docker
    systemctl start docker
    log "INFO" "Docker installed successfully"
  else
    log "INFO" "Docker is already installed"
  fi
  
  # Install Docker Compose if not installed
  if ! command -v docker-compose &> /dev/null; then
    log "INFO" "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "INFO" "Docker Compose installed successfully"
  else
    log "INFO" "Docker Compose is already installed"
  fi
  
  log "INFO" "Dependencies installed successfully"
}

# Generate secure passwords
generate_passwords() {
  # Generate admin password if not provided
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -hex 16)
    log "INFO" "Generated random admin password"
  fi
  
  # Generate default admin user if not provided
  if [ -z "$ADMIN_USER" ]; then
    ADMIN_USER="admin"
    log "INFO" "Using default admin username: ${ADMIN_USER}"
  fi
  
  # Generate default admin email if not provided
  if [ -z "$ADMIN_EMAIL" ]; then
    ADMIN_EMAIL="admin@${DOMAIN}"
    log "INFO" "Using default admin email: ${ADMIN_EMAIL}"
  fi
  
  # Generate database password
  DB_PASSWORD=$(openssl rand -hex 16)
  log "INFO" "Generated random database password"
  
  # Generate secret key
  SECRET_KEY=$(openssl rand -hex 32)
  log "INFO" "Generated random secret key"
  
  # Save credentials to a secure file
  CREDENTIALS_FILE="${CLIENT_DIR}/etebase/config/credentials.env"
  
  cat > "$CREDENTIALS_FILE" << EOF
# Etebase Credentials for ${CLIENT_ID}
# Generated on $(date -Iseconds)
# WARNING: This file contains sensitive information and should be kept secure!

ETEBASE_ADMIN_USER=${ADMIN_USER}
ETEBASE_ADMIN_EMAIL=${ADMIN_EMAIL}
ETEBASE_ADMIN_PASSWORD=${ADMIN_PASSWORD}
ETEBASE_DB_PASSWORD=${DB_PASSWORD}
ETEBASE_SECRET_KEY=${SECRET_KEY}
EOF

  # Set secure permissions
  chmod 600 "$CREDENTIALS_FILE"
  
  log "INFO" "Saved credentials to ${CREDENTIALS_FILE}"
}

# Create Docker Compose configuration
create_docker_config() {
  log "INFO" "Creating Docker Compose configuration..."
  
  # Create Docker directory if it doesn't exist
  mkdir -p "${DOCKER_DIR}"
  
  # Check if Docker Compose file already exists
  if [ -f "${DOCKER_DIR}/docker-compose.yml" ] && [ "$FORCE" = false ]; then
    log "WARN" "Docker Compose file already exists. Use --force to overwrite."
    return
  fi
  
  # Create .env file for Docker Compose
  cat > "${DOCKER_DIR}/.env" << EOF
# Etebase environment variables for ${CLIENT_ID}
# Generated on $(date -Iseconds)

CLIENT_ID=${CLIENT_ID}
DOMAIN=${DOMAIN}
PORT=${PORT}
DATA_DIR=${CLIENT_DIR}/etebase/data
DB_PASSWORD=${DB_PASSWORD}
SECRET_KEY=${SECRET_KEY}
EOF

  # Create Docker Compose file
  cat > "${DOCKER_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  etebase-server:
    image: victorrds/etebase:${ETEBASE_VERSION}
    container_name: etebase-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/etebase/data:/data
    environment:
      - ETEBASE_CREATE_ADMIN_USER=${ADMIN_USER}
      - ETEBASE_CREATE_ADMIN_EMAIL=${ADMIN_EMAIL}
      - ETEBASE_CREATE_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - ETEBASE_EASY_CONFIG_SECRET_KEY=${SECRET_KEY}
      - ETEBASE_DB_ENGINE=sqlite3
      - ETEBASE_TIME_ZONE=UTC
      - ETEBASE_ALLOWED_HOSTS=${DOMAIN},localhost
      - ETEBASE_USE_HTTPS=true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.etebase-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.etebase-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.etebase-${CLIENT_ID}.tls=true"
      - "traefik.http.routers.etebase-${CLIENT_ID}.tls.certResolver=letsencrypt"
      - "traefik.http.services.etebase-${CLIENT_ID}.loadbalancer.server.port=3735"
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.browserXssFilter=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.etebase-security-headers.headers.stsSeconds=31536000"
      - "traefik.http.routers.etebase-${CLIENT_ID}.middlewares=etebase-security-headers"
    ports:
      - "${PORT}:3735"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3735/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - etebase_network

networks:
  etebase_network:
    driver: bridge
    name: etebase_network_${CLIENT_ID}
EOF

  log "INFO" "Created Docker Compose configuration at ${DOCKER_DIR}/docker-compose.yml"
}

# Create Traefik configuration
create_traefik_config() {
  log "INFO" "Creating Traefik configuration..."
  
  # Create Traefik directory if it doesn't exist
  TRAEFIK_DIR="${CONFIG_DIR}/traefik/config/dynamic"
  mkdir -p "${TRAEFIK_DIR}"
  
  # Create Traefik configuration file
  TRAEFIK_CONFIG="${TRAEFIK_DIR}/etebase-${CLIENT_ID}.toml"
  
  # Check if Traefik config already exists
  if [ -f "${TRAEFIK_CONFIG}" ] && [ "$FORCE" = false ]; then
    log "WARN" "Traefik configuration already exists. Use --force to overwrite."
    return
  fi
  
  # Create Traefik configuration
  cat > "${TRAEFIK_CONFIG}" << EOF
# Etebase Traefik configuration for ${CLIENT_ID}
# Generated on $(date -Iseconds)

[http.routers]
  [http.routers.etebase-${CLIENT_ID}]
    rule = "Host(\`${DOMAIN}\`)"
    entryPoints = ["websecure"]
    service = "etebase-${CLIENT_ID}"
    [http.routers.etebase-${CLIENT_ID}.tls]
      certResolver = "letsencrypt"

[http.services]
  [http.services.etebase-${CLIENT_ID}.loadBalancer]
    [[http.services.etebase-${CLIENT_ID}.loadBalancer.servers]]
      url = "http://etebase-${CLIENT_ID}:3735"

[http.middlewares]
  [http.middlewares.etebase-security-headers.headers]
    browserXssFilter = true
    contentTypeNosniff = true
    forceSTSHeader = true
    stsIncludeSubdomains = true
    stsPreload = true
    stsSeconds = 31536000
EOF

  log "INFO" "Created Traefik configuration at ${TRAEFIK_CONFIG}"
}

# Create monitoring script
create_monitoring_script() {
  if [ "$ENABLE_MONITORING" = false ]; then
    log "INFO" "Monitoring integration disabled. Skipping monitoring script creation."
    return
  fi
  
  log "INFO" "Creating monitoring script..."
  
  # Create monitoring directory if it doesn't exist
  MONITORING_DIR="${CONFIG_DIR}/monitoring/scripts"
  mkdir -p "${MONITORING_DIR}"
  
  # Create monitoring script
  MONITORING_SCRIPT="${MONITORING_DIR}/check_etebase-${CLIENT_ID}.sh"
  
  cat > "${MONITORING_SCRIPT}" << 'EOF'
#!/bin/bash
# Etebase Monitoring Script

# Configuration
CLIENT_ID="${1:-default}"
CONTAINER_NAME="etebase-${CLIENT_ID}"
DASHBOARD_DATA="/opt/agency_stack/config/dashboard_data.json"
CREDENTIALS_FILE="/opt/agency_stack/clients/${CLIENT_ID}/etebase/config/credentials.env"

# Function to update dashboard data
update_dashboard() {
  local status="$1"
  local health="$2"
  local sync_time="$3"
  local client_count="$4"
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for dashboard updates"
    exit 1
  fi
  
  # Ensure dashboard data directory exists
  mkdir -p "$(dirname "$DASHBOARD_DATA")"
  
  # Create dashboard data if it doesn't exist
  if [ ! -f "$DASHBOARD_DATA" ]; then
    echo '{"components":{}}' > "$DASHBOARD_DATA"
  fi
  
  # Check if the collaboration section exists
  if ! jq -e '.components.collaboration' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.collaboration = {}' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create the etebase entry if it doesn't exist
  if ! jq -e '.components.collaboration.etebase' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.collaboration.etebase = {
      "name": "Etebase",
      "description": "Encrypted CalDAV and CardDAV server",
      "version": "0.7.0",
      "icon": "calendar",
      "status": {
        "running": false,
        "health": "unknown",
        "last_sync": null,
        "client_connections": 0
      },
      "client_data": {}
    }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create the client data entry if it doesn't exist
  if ! jq -e ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\"" "$DASHBOARD_DATA" &> /dev/null; then
    jq ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\" = {
      \"running\": false,
      \"health\": \"unknown\",
      \"last_sync\": null,
      \"client_connections\": 0
    }" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the client data
  jq ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\".running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\".health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\".client_connections = ${client_count}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$sync_time" ]; then
    jq ".components.collaboration.etebase.client_data.\"${CLIENT_ID}\".last_sync = \"${sync_time}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the main status (use the last client's status)
  jq ".components.collaboration.etebase.status.running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.collaboration.etebase.status.health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.collaboration.etebase.status.client_connections = ${client_count}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$sync_time" ]; then
    jq ".components.collaboration.etebase.status.last_sync = \"${sync_time}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
}

# Check if container is running
RUNNING="false"
HEALTH="unknown"
SYNC_TIME=""
CLIENT_COUNT=0

if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
  RUNNING="true"
  
  # Check container health status
  HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null)
  
  case $HEALTH_STATUS in
    "healthy")
      HEALTH="healthy"
      ;;
    "unhealthy")
      HEALTH="error"
      ;;
    "starting")
      HEALTH="starting"
      ;;
    *)
      HEALTH="unknown"
      ;;
  esac
  
  # Try to get client connections count (if container is running)
  CLIENT_COUNT=$(docker logs $CONTAINER_NAME 2>&1 | grep -c "Client connected" || echo 0)
  
  # Get last sync time (approximate from logs)
  SYNC_TIME=$(docker logs $CONTAINER_NAME 2>&1 | grep "Sync completed" | tail -1 | awk '{print $1 " " $2}')
  
  # If no sync time found, use container start time
  if [ -z "$SYNC_TIME" ]; then
    SYNC_TIME=$(docker inspect --format='{{.State.StartedAt}}' $CONTAINER_NAME | cut -d'.' -f1 | sed 's/T/ /')
  fi
else
  HEALTH="stopped"
  RUNNING="false"
fi

# Update dashboard
update_dashboard "$RUNNING" "$HEALTH" "$SYNC_TIME" "$CLIENT_COUNT"

# Output status
echo "Etebase status for client '${CLIENT_ID}':"
echo "- Running: $RUNNING"
echo "- Health: $HEALTH"
echo "- Last activity: ${SYNC_TIME:-Unknown}"
echo "- Client connections: $CLIENT_COUNT"

exit 0
EOF

  # Make monitoring script executable
  chmod +x "${MONITORING_SCRIPT}"
  
  log "INFO" "Created monitoring script at ${MONITORING_SCRIPT}"
  
  # Create cron job for monitoring
  CRON_DIR="/etc/cron.d"
  if [ -d "$CRON_DIR" ]; then
    CRON_FILE="${CRON_DIR}/etebase-${CLIENT_ID}-monitor"
    echo "*/5 * * * * root ${MONITORING_SCRIPT} ${CLIENT_ID} > /dev/null 2>&1" > "$CRON_FILE"
    log "INFO" "Created cron job for monitoring at ${CRON_FILE}"
  else
    log "WARN" "Cron directory not found. Could not create monitoring cron job."
  fi
}

# Create backup script
create_backup_script() {
  log "INFO" "Creating backup script..."
  
  # Create backup directory
  mkdir -p "${BACKUP_DIR}"
  
  # Create backup script
  BACKUP_SCRIPT="${CLIENT_DIR}/etebase/scripts/backup.sh"
  
  cat > "${BACKUP_SCRIPT}" << 'EOF'
#!/bin/bash
# Etebase Backup Script

# Configuration
CLIENT_ID="${1:-default}"
BACKUP_DIR="${2:-/opt/agency_stack/backups/etebase}"
DATE=$(date +%Y%m%d-%H%M%S)
DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}/etebase/data"
CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/etebase/config"
BACKUP_FILE="${BACKUP_DIR}/etebase-${CLIENT_ID}-${DATE}.tar.gz"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Check if Etebase server is running
if docker ps -q -f name="etebase-${CLIENT_ID}" | grep -q .; then
  echo "Etebase server is running. Creating a hot backup..."
  
  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  
  # Copy data files to temporary directory
  cp -a "${DATA_DIR}/." "${TEMP_DIR}/"
  cp -a "${CONFIG_DIR}/." "${TEMP_DIR}/config/"
  
  # Create the backup archive
  tar -czf "${BACKUP_FILE}" -C "${TEMP_DIR}" .
  
  # Clean up temporary directory
  rm -rf "${TEMP_DIR}"
else
  echo "Etebase server is not running. Creating a cold backup..."
  
  # Create the backup archive directly
  tar -czf "${BACKUP_FILE}" -C "${DATA_DIR}/.." "data" -C "${CONFIG_DIR}/.." "config"
fi

# Check if backup was successful
if [ -f "${BACKUP_FILE}" ]; then
  echo "Backup completed successfully: ${BACKUP_FILE}"
  
  # Create a symlink to the latest backup
  ln -sf "${BACKUP_FILE}" "${BACKUP_DIR}/etebase-${CLIENT_ID}-latest.tar.gz"
  
  # Remove old backups (keep last 7)
  ls -1t "${BACKUP_DIR}"/etebase-${CLIENT_ID}-*.tar.gz | tail -n +8 | xargs -r rm
  
  exit 0
else
  echo "Backup failed"
  exit 1
fi
EOF

  # Make backup script executable
  chmod +x "${BACKUP_SCRIPT}"
  
  log "INFO" "Created backup script at ${BACKUP_SCRIPT}"
  
  # Create restore script
  RESTORE_SCRIPT="${CLIENT_DIR}/etebase/scripts/restore.sh"
  
  cat > "${RESTORE_SCRIPT}" << 'EOF'
#!/bin/bash
# Etebase Restore Script

# Configuration
CLIENT_ID="${1:-default}"
BACKUP_FILE="${2}"
DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}/etebase/data"
CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/etebase/config"

# Check if backup file is provided
if [ -z "${BACKUP_FILE}" ]; then
  echo "Error: No backup file specified"
  echo "Usage: $0 <client_id> <backup_file>"
  exit 1
fi

# Check if backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

# Check if Etebase server is running
if docker ps -q -f name="etebase-${CLIENT_ID}" | grep -q .; then
  echo "Etebase server is running. Stopping server before restore..."
  
  # Stop the server
  cd /opt/agency_stack/docker/etebase && docker-compose down
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)

# Extract backup to temporary directory
echo "Extracting backup file..."
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Move data to the data directory
echo "Restoring data..."
rm -rf "${DATA_DIR}"/*
mkdir -p "${DATA_DIR}"
cp -a "${TEMP_DIR}/"* "${DATA_DIR}/"

# Move config to the config directory
if [ -d "${TEMP_DIR}/config" ]; then
  echo "Restoring configuration..."
  mkdir -p "${CONFIG_DIR}"
  cp -a "${TEMP_DIR}/config/." "${CONFIG_DIR}/"
fi

# Clean up temporary directory
rm -rf "${TEMP_DIR}"

# Start the server
echo "Starting Etebase server..."
cd /opt/agency_stack/docker/etebase && docker-compose up -d

echo "Restore completed successfully"
exit 0
EOF

  # Make restore script executable
  chmod +x "${RESTORE_SCRIPT}"
  
  log "INFO" "Created restore script at ${RESTORE_SCRIPT}"
}

# Deploy Etebase
deploy_etebase() {
  log "INFO" "Deploying Etebase..."
  
  # Navigate to Docker directory
  cd "${DOCKER_DIR}"
  
  # Start containers
  docker-compose up -d
  
  # Wait for container to start
  log "INFO" "Waiting for Etebase container to start..."
  sleep 10
  
  # Check if container is running
  if docker ps -q -f name="etebase-${CLIENT_ID}" | grep -q .; then
    log "INFO" "Etebase container started successfully"
    
    # Create initial backup
    log "INFO" "Creating initial backup..."
    ${CLIENT_DIR}/etebase/scripts/backup.sh "${CLIENT_ID}" "${BACKUP_DIR}"
    
    # Update dashboard data
    if [ "$ENABLE_MONITORING" = true ] && [ -f "${CONFIG_DIR}/monitoring/scripts/check_etebase-${CLIENT_ID}.sh" ]; then
      log "INFO" "Updating dashboard data..."
      ${CONFIG_DIR}/monitoring/scripts/check_etebase-${CLIENT_ID}.sh "${CLIENT_ID}"
    fi
  else
    log "ERROR" "Failed to start Etebase container"
    docker-compose logs
    exit 1
  fi
}

# Update component registry
update_registry() {
  log "INFO" "Updating component registry..."
  
  # Update installed components list
  if ! grep -q "etebase" "$INSTALLED_COMPONENTS" 2>/dev/null; then
    mkdir -p "$(dirname "$INSTALLED_COMPONENTS")"
    echo "etebase" >> "$INSTALLED_COMPONENTS"
    log "INFO" "Added etebase to installed components list"
  fi
  
  # Check if registry file exists
  if [ ! -f "$COMPONENT_REGISTRY" ]; then
    mkdir -p "$(dirname "$COMPONENT_REGISTRY")"
    echo '{"components":{}}' > "$COMPONENT_REGISTRY"
    log "INFO" "Created component registry file"
  fi
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log "WARN" "jq is not installed. Skipping registry update."
    return
  fi
  
  # Create temporary file for JSON manipulation
  TEMP_FILE=$(mktemp)
  
  # Check if collaboration section exists
  if ! jq -e '.components.collaboration' "$COMPONENT_REGISTRY" &> /dev/null; then
    jq '.components.collaboration = {}' "$COMPONENT_REGISTRY" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  fi
  
  # Add or update etebase entry
  jq '.components.collaboration.etebase = {
    "component_id": "etebase",
    "name": "Etebase",
    "category": "Collaboration",
    "version": "v0.7.0",
    "integration_status": {
      "installed": true,
      "hardened": true,
      "makefile": true,
      "sso": false,
      "dashboard": true,
      "logs": true,
      "docs": true,
      "auditable": true,
      "traefik_tls": true,
      "multi_tenant": true,
      "monitoring": true
    },
    "description": "Encrypted self-hosted CalDAV and CardDAV server for private calendar, contact, and task sync.",
    "ports": {
      "http": '${PORT}'
    }
  }' "$COMPONENT_REGISTRY" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  
  log "INFO" "Updated component registry with etebase entry"
}

# Print summary and usage instructions
print_summary() {
  echo
  echo -e "${BOLD}${GREEN}=== Etebase Installation Complete ===${NC}"
  echo
  echo -e "${BOLD}Configuration Details:${NC}"
  echo -e "  ${CYAN}Client ID:${NC}        ${CLIENT_ID}"
  echo -e "  ${CYAN}Domain:${NC}           ${DOMAIN}"
  echo -e "  ${CYAN}Port:${NC}             ${PORT}"
  echo -e "  ${CYAN}Admin User:${NC}       ${ADMIN_USER}"
  echo -e "  ${CYAN}Admin Email:${NC}      ${ADMIN_EMAIL}"
  echo -e "  ${CYAN}Data Directory:${NC}   ${CLIENT_DIR}/etebase/data"
  echo
  echo -e "${BOLD}Access Information:${NC}"
  echo -e "  ${CYAN}Web Admin:${NC}        https://${DOMAIN}"
  echo -e "  ${CYAN}CalDAV URL:${NC}       https://${DOMAIN}/dav/"
  echo -e "  ${CYAN}CardDAV URL:${NC}      https://${DOMAIN}/dav/"
  echo
  echo -e "${BOLD}Client Configuration:${NC}"
  echo -e "  ${CYAN}For Thunderbird:${NC}"
  echo -e "    1. Go to Calendar > New Calendar > On the Network"
  echo -e "    2. Select CalDAV"
  echo -e "    3. Enter: https://${DOMAIN}/dav/"
  echo -e "    4. For Contacts, use the same URL"
  echo
  echo -e "  ${CYAN}For Mobile (DAVx⁵):${NC}"
  echo -e "    1. Add new account"
  echo -e "    2. Select CalDAV/CardDAV"
  echo -e "    3. Enter base URL: https://${DOMAIN}/dav/"
  echo -e "    4. Enter your username and password"
  echo
  echo -e "${BOLD}${YELLOW}Important:${NC} Admin credentials are stored in:"
  echo -e "  ${GREEN}${CLIENT_DIR}/etebase/config/credentials.env${NC}"
  echo
  echo -e "${BOLD}${GREEN}For more information, see the documentation at:${NC}"
  echo -e "  ${CYAN}https://stack.nerdofmouth.com/docs/components/etebase.html${NC}"
  echo
}

# Main function
main() {
  # Process command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client-id)
        CLIENT_ID="$2"
        shift 2
        ;;
      --domain)
        DOMAIN="$2"
        shift 2
        ;;
      --port)
        PORT="$2"
        shift 2
        ;;
      --admin-user)
        ADMIN_USER="$2"
        shift 2
        ;;
      --admin-email)
        ADMIN_EMAIL="$2"
        shift 2
        ;;
      --admin-password)
        ADMIN_PASSWORD="$2"
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
      --no-ssl)
        SSL=false
        shift
        ;;
      --disable-monitoring)
        ENABLE_MONITORING=false
        shift
        ;;
      --help)
        show_help
        ;;
      *)
        log "ERROR" "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Log the start of installation
  log "INFO" "Starting Etebase installation..."
  
  # Run installation steps
  setup_client_dir
  check_requirements
  install_dependencies
  generate_passwords
  create_docker_config
  create_traefik_config
  create_monitoring_script
  create_backup_script
  deploy_etebase
  update_registry
  
  # Print summary
  print_summary
  
  # Log completion
  log "INFO" "Etebase installation completed successfully"
}

# Execute main function
main "$@"
