#!/bin/bash
# install_erpnext.sh - Install and configure ERPNext for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up ERPNext with:
# - MariaDB database (not MySQL)
# - Redis caching
# - Complete ERP functionality
# - Multi-tenant support
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
ERP_DIR="${CONFIG_DIR}/erpnext"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/erpnext.log"
VERBOSE=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
ERP_VERSION="version-14"
MARIADB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
SITE_NAME=""

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack ERPNext Setup${NC}"
  echo -e "============================"
  echo -e "This script installs and configures ERPNext with MariaDB and Redis."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for ERPNext (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--erp-version${NC} <version>   ERPNext version (default: version-14)"
  echo -e "  ${BOLD}--site-name${NC} <name>        Site name (default: same as domain)"
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
    --site-name)
      SITE_NAME="$2"
      shift
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

# Set site name if not provided
if [ -z "$SITE_NAME" ]; then
  SITE_NAME="$DOMAIN"
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack ERPNext Setup${NC}"
echo -e "============================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$INSTALL_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

log "INFO: Starting ERPNext installation for $DOMAIN" "${BLUE}Starting ERPNext installation for $DOMAIN...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR: Docker is not installed" "${RED}Docker is not installed. Please install Docker first.${NC}"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR: Docker Compose is not installed" "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
  exit 1
fi

# Set up site-specific variables
SITE_NAME_SAFE=${SITE_NAME//./_}
if [ -n "$CLIENT_ID" ]; then
  ERP_PROJECT_NAME="${CLIENT_ID}_erpnext"
  NETWORK_NAME="${CLIENT_ID}_network"
  
  # Check if client-specific network exists, create if it doesn't
  if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
    log "INFO: Creating Docker network $NETWORK_NAME" "${CYAN}Creating Docker network $NETWORK_NAME...${NC}"
    docker network create "$NETWORK_NAME" >> "$INSTALL_LOG" 2>&1
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to create Docker network $NETWORK_NAME" "${RED}Failed to create Docker network $NETWORK_NAME. See log for details.${NC}"
      exit 1
    fi
  fi
else
  ERP_PROJECT_NAME="erpnext_${SITE_NAME_SAFE}"
  NETWORK_NAME="agency-network"
fi

# Create ERPNext directories
log "INFO: Creating ERPNext directories" "${CYAN}Creating ERPNext directories...${NC}"
mkdir -p "${ERP_DIR}/${SITE_NAME}"
mkdir -p "${ERP_DIR}/${SITE_NAME}/config"
mkdir -p "${ERP_DIR}/${SITE_NAME}/data/mariadb"
mkdir -p "${ERP_DIR}/${SITE_NAME}/data/redis"
mkdir -p "${ERP_DIR}/${SITE_NAME}/data/sites"
mkdir -p "${ERP_DIR}/${SITE_NAME}/logs"

# Create ERPNext Docker Compose file
log "INFO: Creating ERPNext Docker Compose file" "${CYAN}Creating ERPNext Docker Compose file...${NC}"
cat > "${ERP_DIR}/${SITE_NAME}/docker-compose.yml" <<EOF
version: '3.7'

services:
  mariadb:
    image: mariadb:10.6
    container_name: ${ERP_PROJECT_NAME}_mariadb
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MARIADB_PASSWORD}
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/mariadb:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "mariadb_${SITE_NAME_SAFE}"

  redis-cache:
    image: redis:alpine
    container_name: ${ERP_PROJECT_NAME}_redis_cache
    restart: unless-stopped
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_cache_${SITE_NAME_SAFE}"

  redis-queue:
    image: redis:alpine
    container_name: ${ERP_PROJECT_NAME}_redis_queue
    restart: unless-stopped
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_queue_${SITE_NAME_SAFE}"

  redis-socketio:
    image: redis:alpine
    container_name: ${ERP_PROJECT_NAME}_redis_socketio
    restart: unless-stopped
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_socketio_${SITE_NAME_SAFE}"

  erpnext-nginx:
    image: frappe/erpnext-nginx:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_nginx
    restart: unless-stopped
    depends_on:
      - erpnext-python
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/var/www/html/sites:rw
      - ${ERP_DIR}/${SITE_NAME}/logs:/var/log
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.erpnext_${SITE_NAME_SAFE}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.erpnext_${SITE_NAME_SAFE}.entrypoints=websecure"
      - "traefik.http.routers.erpnext_${SITE_NAME_SAFE}.tls.certresolver=myresolver"
      - "traefik.http.routers.erpnext_${SITE_NAME_SAFE}.middlewares=secure-headers@file"
      - "traefik.http.services.erpnext_${SITE_NAME_SAFE}.loadbalancer.server.port=80"
      - "traefik.docker.network=${NETWORK_NAME}"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "nginx_${SITE_NAME_SAFE}"

  erpnext-python:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_python
    restart: unless-stopped
    environment:
      - MARIADB_HOST=mariadb
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SITE_NAME=${SITE_NAME}
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
      - ${ERP_DIR}/${SITE_NAME}/logs:/home/frappe/frappe-bench/logs:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "python_${SITE_NAME_SAFE}"

  erpnext-socketio:
    image: frappe/frappe-socketio:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_socketio
    restart: unless-stopped
    depends_on:
      - redis-socketio
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "socketio_${SITE_NAME_SAFE}"

  erpnext-worker-default:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_worker_default
    restart: unless-stopped
    command: worker
    depends_on:
      - redis-queue
      - redis-cache
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "worker_default_${SITE_NAME_SAFE}"

  erpnext-worker-short:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_worker_short
    restart: unless-stopped
    command: worker --queue short
    depends_on:
      - redis-queue
      - redis-cache
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "worker_short_${SITE_NAME_SAFE}"

  erpnext-worker-long:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_worker_long
    restart: unless-stopped
    command: worker --queue long
    depends_on:
      - redis-queue
      - redis-cache
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "worker_long_${SITE_NAME_SAFE}"

  erpnext-scheduler:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_PROJECT_NAME}_scheduler
    restart: unless-stopped
    command: schedule
    depends_on:
      - redis-queue
      - redis-cache
    volumes:
      - ${ERP_DIR}/${SITE_NAME}/data/sites:/home/frappe/frappe-bench/sites:rw
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "scheduler_${SITE_NAME_SAFE}"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create site config file
log "INFO: Creating ERPNext site config" "${CYAN}Creating ERPNext site config...${NC}"
mkdir -p "${ERP_DIR}/${SITE_NAME}/data/sites/common_site_config.json"

cat > "${ERP_DIR}/${SITE_NAME}/data/sites/common_site_config.json" <<EOF
{
  "db_host": "mariadb",
  "redis_cache": "redis-cache:6379",
  "redis_queue": "redis-queue:6379",
  "redis_socketio": "redis-socketio:6379",
  "socketio_port": 9000,
  "webserver_port": 8000,
  "serve_default_site": true,
  "auto_update": false,
  "encryption_key": "$(openssl rand -base64 32)",
  "admin_password": "${ADMIN_PASSWORD}",
  "root_password": "${MARIADB_PASSWORD}"
}
EOF

# Start the ERPNext stack
log "INFO: Starting ERPNext stack" "${CYAN}Starting ERPNext stack...${NC}"
cd "${ERP_DIR}/${SITE_NAME}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start ERPNext stack" "${RED}Failed to start ERPNext stack. See log for details.${NC}"
  exit 1
fi

log "INFO: Waiting for ERPNext containers to initialize" "${YELLOW}Waiting for ERPNext containers to initialize...${NC}"
sleep 30

# Create a new site
log "INFO: Creating new ERPNext site" "${CYAN}Creating new ERPNext site...${NC}"
docker exec -it ${ERP_PROJECT_NAME}_python bench new-site ${SITE_NAME} \
  --mariadb-root-password ${MARIADB_PASSWORD} \
  --admin-password ${ADMIN_PASSWORD} \
  --install-app erpnext \
  --no-mariadb-socket

if [ $? -ne 0 ]; then
  log "ERROR: Failed to create ERPNext site" "${RED}Failed to create ERPNext site. See log for details.${NC}"
  exit 1
fi

# Set site as default
log "INFO: Setting site as default" "${CYAN}Setting site as default...${NC}"
docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config serve_default_site true

# Set up SMTP for email
if [ -n "$ADMIN_EMAIL" ]; then
  log "INFO: Configuring email settings" "${CYAN}Configuring email settings...${NC}"
  docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config mail_server "mail.${DOMAIN%.*.*}"
  docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config mail_port "25"
  docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config mail_use_ssl "0"
  docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config mail_login "$ADMIN_EMAIL"
  docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config admin_email "$ADMIN_EMAIL"
fi

# Configure the system
log "INFO: Configuring ERPNext system settings" "${CYAN}Configuring ERPNext system settings...${NC}"
docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config enable_two_factor_auth 0
docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config auto_update 0
docker exec -it ${ERP_PROJECT_NAME}_python bench --site ${SITE_NAME} set-config disable_system_update_notification 1

# Restart the services
log "INFO: Restarting ERPNext services" "${CYAN}Restarting ERPNext services...${NC}"
cd "${ERP_DIR}/${SITE_NAME}" && docker-compose restart erpnext-nginx erpnext-python

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/erpnext"
chmod 700 "${CONFIG_DIR}/secrets/erpnext"

cat > "${CONFIG_DIR}/secrets/erpnext/${SITE_NAME}.env" <<EOF
# ERPNext Credentials for ${SITE_NAME}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

ERP_URL=https://${DOMAIN}/
ERP_ADMIN_USER=Administrator
ERP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
ERP_ADMIN_EMAIL=${ADMIN_EMAIL}

MARIADB_ROOT_PASSWORD=${MARIADB_PASSWORD}

# Docker project
ERP_PROJECT_NAME=${ERP_PROJECT_NAME}
EOF

chmod 600 "${CONFIG_DIR}/secrets/erpnext/${SITE_NAME}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering ERPNext in components registry" "${CYAN}Registering ERPNext in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/erpnext"
  
  cat > "${CONFIG_DIR}/components/erpnext/${SITE_NAME}.json" <<EOF
{
  "component": "erpnext",
  "version": "${ERP_VERSION}",
  "domain": "${DOMAIN}",
  "site_name": "${SITE_NAME}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
fi

# Final message
log "INFO: ERPNext installation completed successfully" "${GREEN}${BOLD}✅ ERPNext installed successfully!${NC}"
echo -e "${CYAN}ERPNext URL: https://${DOMAIN}/${NC}"
echo -e "${YELLOW}Admin Username: Administrator${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/erpnext/${SITE_NAME}.env${NC}"
echo -e ""
echo -e "${YELLOW}Note: Initial ERPNext setup may still be in progress.${NC}"
echo -e "${YELLOW}If you encounter any issues, wait 5-10 minutes and try again.${NC}"

exit 0
