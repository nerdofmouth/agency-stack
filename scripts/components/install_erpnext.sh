#!/bin/bash
# install_erpnext.sh - Install and configure ERPNext for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up ERPNext with:
# - MariaDB database
# - Redis caching
# - Nginx reverse proxy
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
ERPS_DIR="${CONFIG_DIR}/erpnext"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/erpnext.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/erpnext.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
ADMIN_USER="admin"
DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ERP_DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
ERP_VERSION="14"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack ERPNext Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures ERPNext with MariaDB and Redis caching."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for ERPNext (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--erp-version${NC} <version>   ERPNext version (default: 14)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if ERPNext is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain erp.example.com --admin-email admin@example.com --client-id acme"
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
    --erp-version)
      ERP_VERSION="$2"
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
echo -e "${MAGENTA}${BOLD}AgencyStack ERPNext Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
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
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERPNext - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERPNext - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting ERPNext installation validation for $DOMAIN" "${BLUE}Starting ERPNext installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  ERP_CONTAINER="${CLIENT_ID}_erpnext"
  MARIADB_CONTAINER="${CLIENT_ID}_erpnext_db"
  REDIS_CONTAINER="${CLIENT_ID}_erpnext_redis"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  ERP_CONTAINER="erpnext_${SITE_NAME}"
  MARIADB_CONTAINER="erpnext_db_${SITE_NAME}"
  REDIS_CONTAINER="erpnext_redis_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if ERPNext is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$ERP_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: ERPNext container '$ERP_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ ERPNext container '$ERP_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing ERPNext containers" "${CYAN}Stopping and removing existing ERPNext containers...${NC}"
    cd "${ERPS_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: ERPNext container '$ERP_CONTAINER' already exists" "${GREEN}✅ ERPNext installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$ERP_CONTAINER"; then
      log "INFO: ERPNext container is running" "${GREEN}✅ ERPNext is running${NC}"
      echo -e "${GREEN}ERPNext is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: ERPNext container exists but is not running" "${YELLOW}⚠️ ERPNext container exists but is not running${NC}"
      echo -e "${YELLOW}ERPNext is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting ERPNext containers...${NC}"
      cd "${ERPS_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}ERPNext has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}${NC}"
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
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. ERPNext may not be accessible without a reverse proxy.${NC}"
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

log "INFO: Starting ERPNext installation for $DOMAIN" "${BLUE}Starting ERPNext installation for $DOMAIN...${NC}"

# Create ERPNext directories
log "INFO: Creating ERPNext directories" "${CYAN}Creating ERPNext directories...${NC}"
mkdir -p "${ERPS_DIR}/${DOMAIN}"
mkdir -p "${ERPS_DIR}/${DOMAIN}/sites"
mkdir -p "${ERPS_DIR}/${DOMAIN}/logs"
mkdir -p "${ERPS_DIR}/${DOMAIN}/db"
mkdir -p "${ERPS_DIR}/${DOMAIN}/redis"
mkdir -p "${ERPS_DIR}/${DOMAIN}/config"

# Create ERPNext Docker Compose file
log "INFO: Creating ERPNext Docker Compose file" "${CYAN}Creating ERPNext Docker Compose file...${NC}"
cat > "${ERPS_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  mariadb:
    image: mariadb:10.6
    container_name: ${MARIADB_CONTAINER}
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=erpnext
      - MYSQL_USER=erpnext
      - MYSQL_PASSWORD=${ERP_DB_PASSWORD}
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/db:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "mariadb_${SITE_NAME}"

  redis:
    image: redis:alpine
    container_name: ${REDIS_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/redis:/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_${SITE_NAME}"

  erpnext:
    image: frappe/erpnext:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}
    restart: unless-stopped
    environment:
      - MYSQL_HOST=mariadb
      - REDIS_CACHE=redis:6379
      - REDIS_QUEUE=redis:6379
      - REDIS_SOCKETIO=redis:6379
      - SITE_NAME=${DOMAIN}
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
      - ${ERPS_DIR}/${DOMAIN}/logs:/home/frappe/frappe-bench/logs:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "erpnext_${SITE_NAME}"

  nginx:
    image: nginx:alpine
    container_name: ${ERP_CONTAINER}_nginx
    restart: unless-stopped
    depends_on:
      - erpnext
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ${ERPS_DIR}/${DOMAIN}/sites:/var/www/html:ro
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "nginx_${SITE_NAME}"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create ERPNext Nginx configuration file
log "INFO: Creating ERPNext Nginx configuration file" "${CYAN}Creating ERPNext Nginx configuration file...${NC}"
cat > "${ERPS_DIR}/${DOMAIN}/config/nginx.conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://erpnext:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Start the ERPNext stack
log "INFO: Starting ERPNext stack" "${CYAN}Starting ERPNext stack...${NC}"
cd "${ERPS_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start ERPNext stack" "${RED}Failed to start ERPNext stack. See log for details.${NC}"
  exit 1
fi

log "INFO: Waiting for ERPNext containers to initialize" "${YELLOW}Waiting for ERPNext containers to initialize...${NC}"
sleep 30

# Create a new site
log "INFO: Creating new ERPNext site" "${CYAN}Creating new ERPNext site...${NC}"
docker exec -it ${ERP_CONTAINER} bench new-site ${DOMAIN} \
  --mariadb-root-password ${DB_ROOT_PASSWORD} \
  --admin-password ${ADMIN_PASSWORD} \
  --install-app erpnext \
  --no-mariadb-socket

if [ $? -ne 0 ]; then
  log "ERROR: Failed to create ERPNext site" "${RED}Failed to create ERPNext site. See log for details.${NC}"
  exit 1
fi

# Set site as default
log "INFO: Setting site as default" "${CYAN}Setting site as default...${NC}"
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config serve_default_site true

# Set up SMTP for email
if [ -n "$ADMIN_EMAIL" ]; then
  log "INFO: Configuring email settings" "${CYAN}Configuring email settings...${NC}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_server "mail.${DOMAIN%.*.*}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_port "25"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_use_ssl "0"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_login "$ADMIN_EMAIL"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config admin_email "$ADMIN_EMAIL"
fi

# Configure the system
log "INFO: Configuring ERPNext system settings" "${CYAN}Configuring ERPNext system settings...${NC}"
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config enable_two_factor_auth 0
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config auto_update 0
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config disable_system_update_notification 1

# Restart the services
log "INFO: Restarting ERPNext services" "${CYAN}Restarting ERPNext services...${NC}"
cd "${ERPS_DIR}/${DOMAIN}" && docker-compose restart erpnext nginx

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/erpnext"
chmod 700 "${CONFIG_DIR}/secrets/erpnext"

cat > "${CONFIG_DIR}/secrets/erpnext/${DOMAIN}.env" <<EOF
# ERPNext Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

ERP_URL=https://${DOMAIN}/
ERP_ADMIN_USER=Administrator
ERP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
ERP_ADMIN_EMAIL=${ADMIN_EMAIL}

MARIADB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
ERP_DB_PASSWORD=${ERP_DB_PASSWORD}

# Docker project
ERP_CONTAINER=${ERP_CONTAINER}
MARIADB_CONTAINER=${MARIADB_CONTAINER}
REDIS_CONTAINER=${REDIS_CONTAINER}
EOF

chmod 600 "${CONFIG_DIR}/secrets/erpnext/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering ERPNext in components registry" "${CYAN}Registering ERPNext in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/erpnext"
  
  cat > "${CONFIG_DIR}/components/erpnext/${DOMAIN}.json" <<EOF
{
  "component": "erpnext",
  "version": "${ERP_VERSION}",
  "domain": "${DOMAIN}",
  "site_name": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
fi

# Final message
log "INFO: ERPNext installation completed successfully" "${GREEN}${BOLD}✅ ERPNext installed successfully!${NC}"
echo -e "${CYAN}ERPNext URL: https://${DOMAIN}${NC}"
echo -e "${YELLOW}Admin Username: Administrator${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/erpnext/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Note: Initial ERPNext setup may still be in progress.${NC}"
echo -e "${YELLOW}If you encounter any issues, wait 5-10 minutes and try again.${NC}"

exit 0
