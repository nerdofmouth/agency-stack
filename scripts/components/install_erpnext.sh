#!/bin/bash
# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
        
# install_erpnext.sh - Install and configure ERPNext for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up ERPNext using the official Frappe Docker deployment pattern with:
# - MariaDB database
# - Redis caching
# - Nginx reverse proxy
# - Traefik integration with TLS
# - Keycloak SSO integration (optional)
# - Auto-configured for multi-tenancy
#
# Author: AgencyStack Team
# Version: 2.0.0
# Created: $(date +%Y-%m-%d)

# Variables
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
ENABLE_SSO=false
DOMAIN=""
KEYCLOAK_DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
ADMIN_USER="admin"
DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ERP_DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
ERP_VERSION="v14.0.0"
FRAPPE_DOCKER_REPO="https://github.com/frappe/frappe_docker.git"
FRAPPE_DOCKER_VERSION="main"
FRAPPE_BRANCH="version-14"
FRAPPE_DOCKER_DIR="/tmp/frappe_docker"
MODULES="crm erpnext projects accounting events erpnext_erpnext erpnext_crm website frappe_website"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack ERPNext Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures ERPNext using the official Frappe Docker deployment pattern with:"
  echo -e "  - MariaDB database"
  echo -e "  - Redis caching"
  echo -e "  - Nginx reverse proxy"
  echo -e "  - Traefik integration with TLS"
  echo -e "  - Keycloak SSO integration (optional)"
  echo -e "  - Auto-configured for multi-tenancy"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for ERPNext (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--erp-version${NC} <version>   ERPNext version (default: v14.0.0)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if ERPNext is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--enable-sso${NC}              Enable Keycloak SSO integration (optional)"
  echo -e "  ${BOLD}--keycloak-domain${NC} <domain> Keycloak domain for SSO integration (optional)"
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
    --enable-sso)
      ENABLE_SSO=true
      shift
      ;;
    --keycloak-domain)
      KEYCLOAK_DOMAIN="$2"
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

# Clone Frappe Docker repository
log "INFO: Cloning Frappe Docker repository" "${CYAN}Cloning Frappe Docker repository...${NC}"
git clone --depth 1 --branch "$FRAPPE_BRANCH" "$FRAPPE_DOCKER_REPO" "$FRAPPE_DOCKER_DIR" >> "$INSTALL_LOG" 2>&1
if [ $? -ne 0 ]; then
  log "ERROR: Failed to clone Frappe Docker repository" "${RED}Failed to clone Frappe Docker repository. See log for details.${NC}"
  exit 1
fi

# Create ERPNext Docker Compose file
log "INFO: Creating ERPNext Docker Compose file" "${CYAN}Creating ERPNext Docker Compose file...${NC}"
cat > "${ERPS_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  mariadb:
    image: mariadb:10.6
    container_name: ${MARIADB_CONTAINER}
    restart: unless-stopped
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --skip-character-set-client-handshake
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_USER=frappe
      - MYSQL_PASSWORD=${ERP_DB_PASSWORD}
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/db:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-u", "root", "--password=\${MYSQL_ROOT_PASSWORD}"]
      timeout: 10s
      retries: 5
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "mariadb_${SITE_NAME}"

  redis-cache:
    image: redis:alpine
    container_name: ${REDIS_CONTAINER}_cache
    restart: unless-stopped
    command: redis-server --save "" --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/redis/cache:/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_cache_${SITE_NAME}"

  redis-queue:
    image: redis:alpine
    container_name: ${REDIS_CONTAINER}_queue
    restart: unless-stopped
    command: redis-server --save ""
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/redis/queue:/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_queue_${SITE_NAME}"

  redis-socketio:
    image: redis:alpine
    container_name: ${REDIS_CONTAINER}_socketio
    restart: unless-stopped
    command: redis-server --save ""
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/redis/socketio:/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "redis_socketio_${SITE_NAME}"

  frappe:
    image: frappe/frappe-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_worker
    restart: unless-stopped
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - mariadb
      - redis-cache
      - redis-queue
      - redis-socketio
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "frappe_worker_${SITE_NAME}"

  erpnext:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}
    restart: unless-stopped
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - frappe
      - mariadb
      - redis-cache
      - redis-queue
      - redis-socketio
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "erpnext_worker_${SITE_NAME}"

  socketio:
    image: frappe/frappe-socketio:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_socketio
    restart: unless-stopped
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:ro
    depends_on:
      - redis-socketio
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "socketio_${SITE_NAME}"

  scheduler:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_scheduler
    restart: unless-stopped
    command: bench schedule
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - erpnext
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "scheduler_${SITE_NAME}"

  queue-short:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_queue_short
    restart: unless-stopped
    command: bench worker --queue short
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - erpnext
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "queue_short_${SITE_NAME}"

  queue-long:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_queue_long
    restart: unless-stopped
    command: bench worker --queue long
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - erpnext
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "queue_long_${SITE_NAME}"

  queue-default:
    image: frappe/erpnext-worker:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_queue_default
    restart: unless-stopped
    command: bench worker --queue default
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - DB_HOST=mariadb
      - DB_PORT=3306
      - REDIS_CACHE=redis-cache:6379
      - REDIS_QUEUE=redis-queue:6379
      - REDIS_SOCKETIO=redis-socketio:6379
      - SOCKETIO_PORT=9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/home/frappe/frappe-bench/sites:rw
    depends_on:
      - erpnext
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        tag: "queue_default_${SITE_NAME}"

  nginx:
    image: frappe/erpnext-nginx:${ERP_VERSION}
    container_name: ${ERP_CONTAINER}_nginx
    restart: unless-stopped
    environment:
      - FRAPPE_APP_SITE=${DOMAIN}
      - FRAPPE_PY=erpnext:8000
      - SOCKETIO=socketio:9000
    volumes:
      - ${ERPS_DIR}/${DOMAIN}/sites:/var/www/html/sites:ro
      - ${ERPS_DIR}/${DOMAIN}/logs:/var/log/nginx
    depends_on:
      - erpnext
      - socketio
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SITE_NAME}-erpnext.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${SITE_NAME}-erpnext.entrypoints=websecure"
      - "traefik.http.routers.${SITE_NAME}-erpnext.tls=true"
      - "traefik.http.routers.${SITE_NAME}-erpnext.tls.certresolver=agency-stack-resolver"
      - "traefik.http.services.${SITE_NAME}-erpnext.loadbalancer.server.port=80"
      - "traefik.docker.network=${NETWORK_NAME}"
      - "agency_stack.component=erpnext"
      - "agency_stack.category=business"
      - "agency_stack.description=ERPNext - Open Source ERP"
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
        proxy_pass http://nginx:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Create a sites directory structure
log "INFO: Setting up ERPNext site directory structure" "${CYAN}Setting up ERPNext site directory structure...${NC}"
mkdir -p "${ERPS_DIR}/${DOMAIN}/sites/${DOMAIN}"
mkdir -p "${ERPS_DIR}/${DOMAIN}/sites/assets"

# Create site_config.json
log "INFO: Creating site configuration" "${CYAN}Creating site configuration...${NC}"
cat > "${ERPS_DIR}/${DOMAIN}/sites/${DOMAIN}/site_config.json" <<EOF
{
  "db_name": "erpnext_${SITE_NAME}",
  "db_host": "mariadb",
  "db_port": 3306,
  "db_password": "${ERP_DB_PASSWORD}",
  "redis_cache": "redis-cache:6379",
  "redis_queue": "redis-queue:6379",
  "redis_socketio": "redis-socketio:6379"
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

# Initialize the site with bench commands
log "INFO: Initializing ERPNext site" "${CYAN}Initializing ERPNext site...${NC}"
docker exec -it ${ERP_CONTAINER} bench new-site ${DOMAIN} \
  --mariadb-root-password ${DB_ROOT_PASSWORD} \
  --admin-password ${ADMIN_PASSWORD} \
  --no-mariadb-socket

if [ $? -ne 0 ]; then
  log "ERROR: Failed to initialize ERPNext site" "${RED}Failed to initialize ERPNext site. See log for details.${NC}"
  exit 1
fi

# Install ERPNext app
log "INFO: Installing ERPNext app and modules" "${CYAN}Installing ERPNext app and modules...${NC}"
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} install-app erpnext

# Set site as default
log "INFO: Setting site as default" "${CYAN}Setting site as default...${NC}"
docker exec -it ${ERP_CONTAINER} bench use ${DOMAIN}

# Enable modules
log "INFO: Enabling required modules" "${CYAN}Enabling required modules...${NC}"
for module in $MODULES; do
  log "INFO: Enabling module: $module" "${CYAN}Enabling module: $module...${NC}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} enable-module $module
done

# Set up SMTP for email
if [ -n "$ADMIN_EMAIL" ]; then
  log "INFO: Configuring email settings" "${CYAN}Configuring email settings...${NC}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_server "mail.${DOMAIN%.*.*}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_port "25"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_use_ssl "0"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config mail_login "$ADMIN_EMAIL"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config admin_email "$ADMIN_EMAIL"
fi

# Configure Keycloak SSO integration if enabled
if [ "$ENABLE_SSO" = true ]; then
  if [ -z "$KEYCLOAK_DOMAIN" ]; then
    log "WARNING: Keycloak SSO enabled but no domain specified" "${YELLOW}⚠️ Keycloak SSO enabled but no domain specified. Using auth.${DOMAIN}${NC}"
    KEYCLOAK_DOMAIN="auth.${DOMAIN}"
  fi
  
  log "INFO: Installing OAuth provider app" "${CYAN}Installing OAuth provider app...${NC}"
  docker exec -it ${ERP_CONTAINER} bench get-app --branch master https://github.com/frappe/oauth_provider
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} install-app oauth_provider
  
  log "INFO: Configuring Keycloak SSO" "${CYAN}Configuring Keycloak SSO...${NC}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config oauth_keycloak_enabled true
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config oauth_keycloak_url "https://${KEYCLOAK_DOMAIN}/auth"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config oauth_keycloak_realm "erpnext"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config oauth_keycloak_client_id "erpnext"
  
  # Register with Keycloak if available
  if docker ps --format '{{.Names}}' | grep -q "keycloak"; then
    log "INFO: Registering with Keycloak" "${CYAN}Registering with Keycloak...${NC}"
    if [ -f "${ROOT_DIR}/scripts/utils/register_with_keycloak.sh" ]; then
      bash "${ROOT_DIR}/scripts/utils/register_with_keycloak.sh" \
        --client-name "erpnext" \
        --client-id "erpnext" \
        --redirect-uri "https://${DOMAIN}/api/method/oauth_provider.login_oauth" \
        --keycloak-domain "${KEYCLOAK_DOMAIN}" \
        --roles "user,admin,manager" \
        --site-domain "${DOMAIN}" \
        --description "ERPNext ERP System"
    else
      log "WARNING: register_with_keycloak.sh not found" "${YELLOW}⚠️ Could not register with Keycloak: register_with_keycloak.sh not found${NC}"
    fi
  else
    log "WARNING: Keycloak container not found" "${YELLOW}⚠️ Could not register with Keycloak: container not found${NC}"
  fi
  
  log "INFO: Please manually complete SSO setup in Keycloak" "${YELLOW}Please complete SSO setup manually in Keycloak${NC}"
  echo -e "${YELLOW}Manual steps for Keycloak SSO configuration:${NC}"
  echo -e "1. Log into Keycloak admin at https://${KEYCLOAK_DOMAIN}/auth/admin/"
  echo -e "2. Create a client for ERPNext with client ID 'erpnext'"
  echo -e "3. Set Valid Redirect URIs to https://${DOMAIN}/api/method/oauth_provider.login_oauth"
  echo -e "4. Configure client roles and mappers as needed"
fi

# Configure the system
log "INFO: Configuring ERPNext system settings" "${CYAN}Configuring ERPNext system settings...${NC}"
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config enable_scheduler 1
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config enable_telemetry 0
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config enable_two_factor_auth 0
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config auto_update 0
docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config disable_system_update_notification 1

# Set up prometheus metrics endpoint if available
if [ -d "/opt/agency_stack/prometheus" ]; then
  log "INFO: Setting up Prometheus metrics endpoint" "${CYAN}Setting up Prometheus metrics endpoint...${NC}"
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config enable_metrics true
  docker exec -it ${ERP_CONTAINER} bench --site ${DOMAIN} set-config metrics_port 8000
  
  # Add ERPNext to Prometheus targets
  if [ -f "/opt/agency_stack/prometheus/prometheus.yml" ]; then
    log "INFO: Adding ERPNext to Prometheus targets" "${CYAN}Adding ERPNext to Prometheus targets...${NC}"
    TEMP_FILE=$(mktemp)
    sed "/static_configs:/a\\
    - targets: ['${DOMAIN}:8000']\\
      labels:\\
        instance: 'erpnext-${DOMAIN}'\\
        service: 'erpnext'
" "/opt/agency_stack/prometheus/prometheus.yml" > "$TEMP_FILE"
    cp "$TEMP_FILE" "/opt/agency_stack/prometheus/prometheus.yml"
    rm "$TEMP_FILE"
    
    # Reload Prometheus if running
    if docker ps --format '{{.Names}}' | grep -q "prometheus"; then
      log "INFO: Reloading Prometheus configuration" "${CYAN}Reloading Prometheus configuration...${NC}"
      docker exec prometheus curl -X POST http://localhost:9090/-/reload
    fi
  fi
fi

# Restart the services
log "INFO: Restarting ERPNext services" "${CYAN}Restarting ERPNext services...${NC}"
cd "${ERPS_DIR}/${DOMAIN}" && docker-compose restart

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
log "INFO: Registering ERPNext in component registry" "${CYAN}Registering ERPNext in component registry...${NC}"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"

if [ -f "$REGISTRY_FILE" ]; then
  # Extract the components array from the registry
  components=$(jq '.components' "$REGISTRY_FILE")
  
  # Check if erpnext component exists
  if echo "$components" | jq -e '.[] | select(.name == "erpnext")' > /dev/null; then
    # Update the existing component
    jq --arg domain "$DOMAIN" \
       --arg version "$ERP_VERSION" \
       --arg client_id "$CLIENT_ID" \
       --arg sso "$([ "$ENABLE_SSO" = true ] && echo "true" || echo "false")" \
       '.components = (.components | map(if .name == "erpnext" then 
         .flags.installed = true | 
         .flags.sso = ($sso == "true") | 
         .flags.multi_tenant = true | 
         .flags.monitoring = true |
         .flags.makefile = true |
         .flags.docs = true |
         .flags.hardened = true |
         .metadata.domains += [$domain] |
         .metadata.client_ids += [$client_id] |
         .metadata.version = $version
         else . end))' "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
  else
    # Add a new component
    jq --arg domain "$DOMAIN" \
       --arg version "$ERP_VERSION" \
       --arg client_id "$CLIENT_ID" \
       --arg sso "$([ "$ENABLE_SSO" = true ] && echo "true" || echo "false")" \
       '.components += [{
         "name": "erpnext",
         "category": "business",
         "description": "ERPNext is a Frappe-powered open-source ERP platform for CRM, accounting, projects, events, and more.",
         "flags": {
           "installed": true,
           "makefile": true,
           "docs": true,
           "hardened": true,
           "monitoring": true,
           "multi_tenant": true,
           "sso": ($sso == "true")
         },
         "ports": [8000, 9000, 3306],
         "metadata": {
           "version": $version,
           "domains": [$domain],
           "client_ids": [$client_id],
           "modules": ["crm", "projects", "accounting", "events"]
         }
       }]' "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
  fi
  
  # Replace the registry file with the updated version
  mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
  chmod 644 "$REGISTRY_FILE"
  
  log "SUCCESS: Updated component registry" "${GREEN}✅ Updated component registry${NC}"
else
  log "WARNING: Component registry file not found" "${YELLOW}⚠️ Component registry file not found at ${REGISTRY_FILE}${NC}"
  
  # Create directory if it doesn't exist
  mkdir -p "${CONFIG_DIR}/registry"
  
  # Create a new registry file
  cat > "$REGISTRY_FILE" <<EOF
{
  "components": [
    {
      "name": "erpnext",
      "category": "business",
      "description": "ERPNext is a Frappe-powered open-source ERP platform for CRM, accounting, projects, events, and more.",
      "flags": {
        "installed": true,
        "makefile": true,
        "docs": true,
        "hardened": true,
        "monitoring": true,
        "multi_tenant": true,
        "sso": $([ "$ENABLE_SSO" = true ] && echo "true" || echo "false")
      },
      "ports": [8000, 9000, 3306],
      "metadata": {
        "version": "${ERP_VERSION}",
        "domains": ["${DOMAIN}"],
        "client_ids": ["${CLIENT_ID}"],
        "modules": ["crm", "projects", "accounting", "events"]
      }
    }
  ]
}
EOF
  
  chmod 644 "$REGISTRY_FILE"
  log "SUCCESS: Created new component registry" "${GREEN}✅ Created new component registry${NC}"
fi

# Record installation in dashboard data if available
DASHBOARD_DATA="${CONFIG_DIR}/dashboard/data/dashboard_data.json"
if [ -f "$DASHBOARD_DATA" ]; then
  log "INFO: Recording installation in dashboard data" "${CYAN}Recording installation in dashboard data...${NC}"
  
  jq --arg domain "$DOMAIN" \
     --arg client_id "$CLIENT_ID" \
     --arg version "$ERP_VERSION" \
     --arg date "$(date +"%Y-%m-%d %H:%M:%S")" \
     '.erp = {
       "installed": true,
       "domain": $domain,
       "client_id": $client_id,
       "version": $version,
       "installed_at": $date,
       "modules": ["crm", "projects", "accounting", "events"]
     }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp"
  
  mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  chmod 644 "$DASHBOARD_DATA"
  
  log "SUCCESS: Updated dashboard data" "${GREEN}✅ Updated dashboard data${NC}"
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
echo -e "${CYAN}Enabled Modules:${NC}"
echo -e "- CRM"
echo -e "- Projects"
echo -e "- Accounting"
echo -e "- Events"
if [ "$ENABLE_SSO" = true ]; then
  echo -e "- Keycloak SSO Integration"
fi
echo -e ""
echo -e "${YELLOW}Note: Initial ERPNext setup may still be in progress.${NC}"
echo -e "${YELLOW}If you encounter any issues, wait 5-10 minutes and try again.${NC}"
echo -e "${YELLOW}For more information, see: /docs/pages/components/erpnext.md${NC}"

exit 0
