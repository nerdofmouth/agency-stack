#!/bin/bash
# install_ghost.sh - AgencyStack Ghost Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures Ghost with hardened security
# Part of the AgencyStack Content & Publishing suite
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
GHOST_LOG="${COMPONENT_LOG_DIR}/ghost.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Ghost Configuration
GHOST_VERSION="5.75.1"  # Latest stable version
GHOST_PORT=2368
GHOST_DB_PORT=3306
GHOST_EMAIL_PORT=1025
GHOST_ADMIN_EMAIL=""
GHOST_ADMIN_PASSWORD=$(openssl rand -hex 8)
GHOST_DB_ROOT_PASSWORD=$(openssl rand -hex 16)
GHOST_DB_PASSWORD=$(openssl rand -hex 16)
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
GHOST_CONFIG_DIR="${CONFIG_DIR}/ghost"
DOCKER_COMPOSE_DIR="${GHOST_CONFIG_DIR}/docker"
BLOG_TITLE="AgencyStack Blog"
WITH_DEPS=false
FORCE=false
VERBOSE=false
ADMIN_EMAIL=""

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${GHOST_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Ghost Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Ghost (e.g., blog.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications and login"
  echo -e "  ${CYAN}--blog-title${NC} <title>     Title for the blog (default: 'AgencyStack Blog')"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain blog.example.com --admin-email admin@example.com --with-deps"
  echo -e "  $0 --domain blog.client1.com --client-id client1 --admin-email admin@client1.com --blog-title 'Client 1 Blog' --with-deps"
  echo -e "  $0 --domain blog.client2.com --client-id client2 --admin-email admin@client2.com --force"
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
  mkdir -p "${CLIENT_DIR}/ghost/content"
  mkdir -p "${CLIENT_DIR}/ghost/mysql"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/ghost"
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
      ADMIN_EMAIL="$2"
      GHOST_ADMIN_EMAIL="$2"
      shift 2
      ;;
    --blog-title)
      BLOG_TITLE="$2"
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
if [ -z "$ADMIN_EMAIL" ]; then
  log "ERROR" "Admin email is required. Use --admin-email to specify it."
  show_help
fi

# Set up directories
log "INFO" "Setting up directories for Ghost installation"
setup_client_dir

# Check if Ghost is already installed
GHOST_CONTAINER="${CLIENT_ID}_ghost"
GHOST_DB_CONTAINER="${CLIENT_ID}_ghost_mysql"
GHOST_MAILHOG_CONTAINER="${CLIENT_ID}_ghost_mailhog"
if docker ps -a --format '{{.Names}}' | grep -q "$GHOST_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Ghost container '$GHOST_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Ghost containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Ghost container '$GHOST_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$GHOST_CONTAINER"; then
      log "INFO" "Ghost container is running"
      echo -e "${GREEN}Ghost is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Ghost URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}Ghost Admin: https://${DOMAIN}/ghost${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Ghost container exists but is not running"
      echo -e "${YELLOW}Ghost is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Ghost containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Ghost has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Ghost URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}Ghost Admin: https://${DOMAIN}/ghost${NC}"
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
    image: mysql:8.0
    container_name: ${GHOST_DB_CONTAINER}
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${GHOST_DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=ghost
      - MYSQL_USER=ghost
      - MYSQL_PASSWORD=${GHOST_DB_PASSWORD}
    volumes:
      - ${CLIENT_DIR}/ghost/mysql:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${GHOST_DB_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  mailhog:
    image: mailhog/mailhog:latest
    container_name: ${GHOST_MAILHOG_CONTAINER}
    restart: unless-stopped
    networks:
      - ${NETWORK_NAME}
    ports:
      - "${GHOST_EMAIL_PORT}:8025"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-mailhog.rule=Host(\`mail.${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-mailhog.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-mailhog.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-mailhog.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-mailhog.loadbalancer.server.port=8025"

  ghost:
    image: ghost:${GHOST_VERSION}
    container_name: ${GHOST_CONTAINER}
    restart: unless-stopped
    depends_on:
      - db
      - mailhog
    environment:
      # Ghost environment variables
      - url=https://${DOMAIN}
      - database__client=mysql
      - database__connection__host=${GHOST_DB_CONTAINER}
      - database__connection__user=ghost
      - database__connection__password=${GHOST_DB_PASSWORD}
      - database__connection__database=ghost
      - mail__transport=SMTP
      - mail__options__service=SMTP
      - mail__options__host=${GHOST_MAILHOG_CONTAINER}
      - mail__options__port=1025
      - mail__options__secureConnection=false
      - mail__options__auth__user=
      - mail__options__auth__pass=
      - mail__from=${ADMIN_EMAIL}
      - NODE_ENV=production
    volumes:
      - ${CLIENT_DIR}/ghost/content:/var/lib/ghost/content
    ports:
      - "${GHOST_PORT}:2368"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-ghost.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-ghost.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-ghost.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-ghost.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-ghost.loadbalancer.server.port=2368"
      - "traefik.http.middlewares.${CLIENT_ID}-ghost-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-ghost-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-ghost-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-ghost-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-ghost.middlewares=${CLIENT_ID}-ghost-headers"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:2368/ghost/api/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
GHOST_VERSION=${GHOST_VERSION}
GHOST_PORT=${GHOST_PORT}
GHOST_DB_PORT=${GHOST_DB_PORT}
GHOST_EMAIL_PORT=${GHOST_EMAIL_PORT}
GHOST_ADMIN_EMAIL=${GHOST_ADMIN_EMAIL}
GHOST_ADMIN_PASSWORD=${GHOST_ADMIN_PASSWORD}
GHOST_DB_ROOT_PASSWORD=${GHOST_DB_ROOT_PASSWORD}
GHOST_DB_PASSWORD=${GHOST_DB_PASSWORD}
BLOG_TITLE=${BLOG_TITLE}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/ghost"
cat > "${CONFIG_DIR}/secrets/ghost/${DOMAIN}.env" << EOF
GHOST_URL=https://${DOMAIN}
GHOST_ADMIN_URL=https://${DOMAIN}/ghost
GHOST_ADMIN_EMAIL=${GHOST_ADMIN_EMAIL}
GHOST_ADMIN_PASSWORD=${GHOST_ADMIN_PASSWORD}
GHOST_DB_ROOT_PASSWORD=${GHOST_DB_ROOT_PASSWORD}
GHOST_DB_PASSWORD=${GHOST_DB_PASSWORD}
EOF

# Start Ghost
log "INFO" "Starting Ghost"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Ghost"
  exit 1
}

# Wait for Ghost to be ready
log "INFO" "Waiting for Ghost to be ready"
timeout=180
counter=0
echo -n "Waiting for Ghost to start"
while [ $counter -lt $timeout ]; do
  if curl -s "http://localhost:${GHOST_PORT}/ghost/api/health" | grep -q "success"; then
    break
  fi
  echo -n "."
  sleep 5
  counter=$((counter+5))
done
echo

if [ $counter -ge $timeout ]; then
  log "WARN" "Timed out waiting for Ghost to fully start, but containers are running"
  log "INFO" "You can check the status manually after a few minutes"
else
  log "INFO" "Ghost is now ready"
fi

# Create admin user
log "INFO" "Creating admin user"
if [ $counter -lt $timeout ]; then
  # Wait a bit more to ensure Ghost is fully initialized
  sleep 10
  
  # Use curl to create the admin user
  GHOST_URL="http://localhost:${GHOST_PORT}"
  
  # Check if we can access the setup page
  if curl -s "${GHOST_URL}/ghost/api/admin/setup/" | grep -q "setup"; then
    log "INFO" "Creating admin user with email ${GHOST_ADMIN_EMAIL}"
    
    # Create a temporary file for the curl request
    SETUP_DATA=$(mktemp)
    
    # Create the JSON for the setup request
    cat > "${SETUP_DATA}" << EOF
{
  "setup": [{
    "name": "Ghost Admin",
    "email": "${GHOST_ADMIN_EMAIL}",
    "password": "${GHOST_ADMIN_PASSWORD}",
    "blogTitle": "${BLOG_TITLE}"
  }]
}
EOF
    
    # Send the setup request
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d @"${SETUP_DATA}" \
      "${GHOST_URL}/ghost/api/admin/setup/" > /dev/null
    
    # Clean up
    rm "${SETUP_DATA}"
    
    log "INFO" "Admin user created successfully"
  else
    log "WARN" "Ghost setup page not accessible, admin user may need to be created manually"
  fi
else
  log "WARN" "Ghost didn't start in time, admin user may need to be created manually"
fi

# Update installation records
if ! grep -q "ghost" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "ghost" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${GHOST_PORT}" \
       --arg version "${GHOST_VERSION}" \
       --arg admin_email "${GHOST_ADMIN_EMAIL}" \
       --arg blog_title "${BLOG_TITLE}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.ghost = {
         "name": "Ghost",
         "url": "https://" + $domain,
         "admin_url": "https://" + $domain + "/ghost",
         "port": $port,
         "version": $version,
         "admin_email": $admin_email,
         "blog_title": $blog_title,
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
       '.ghost = {
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
echo -e "${GREEN}${BOLD}✅ Ghost has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Admin URL: https://${DOMAIN}/ghost${NC}"
echo -e "${CYAN}Version: ${GHOST_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Admin Email: ${GHOST_ADMIN_EMAIL}"
echo -e "Admin Password: ${GHOST_ADMIN_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/ghost/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Email:${NC} A mailhog instance has been set up for testing. You can access it at:"
echo -e "${CYAN}https://mail.${DOMAIN}${NC} or ${CYAN}http://localhost:${GHOST_EMAIL_PORT}${NC}"
echo -e "For production use, you should configure a real mail service in Ghost settings."

log "INFO" "Ghost installation completed successfully"
exit 0
