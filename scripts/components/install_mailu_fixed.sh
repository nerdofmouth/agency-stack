#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: mailu_fixed.sh
# Path: /scripts/components/install_mailu_fixed.sh
#

# Enforce containerization (prevent host contamination)

# AgencyStack Component Installer: Mailu Email Server
# Path: /scripts/components/install_mailu.sh
#
# Installs and configures Mailu, a full-featured mail server solution
# based on Docker containers.

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
INSTALL_LOG="/var/log/agency_stack/components/install_mailu-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $level" >> "$INSTALL_LOG"
  
  if [ -n "${3:-}" ]; then
    echo -e "$3"
  else
    echo -e "[$timestamp] $level"
  fi
}

# Set default values
DOMAIN="${DOMAIN:-mail.example.com}"
EMAIL_DOMAIN="${EMAIL_DOMAIN:-example.com}"
MAILU_DIR="/opt/agency_stack/mailu"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@$EMAIL_DOMAIN}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(openssl rand -base64 12)}"
CLIENT_ID="${CLIENT_ID:-default}"
MAILU_VERSION="2.0"
DOCKER_ORG="ghcr.io/mailu" # Updated Docker organization
MAILU_CONTAINER="mailu"
NETWORK_NAME="agency-network"
FORCE=false
WITH_DEPS=false
VERBOSE=false

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --email-domain)
      EMAIL_DOMAIN="$2"
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
    --client-id)
      CLIENT_ID="$2"
      MAILU_CONTAINER="mailu_${CLIENT_ID}"
      shift 2
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
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --domain DOMAIN       Domain name for Mailu (default: mail.example.com)"
      echo "  --email-domain DOMAIN Email domain (default: example.com)"
      echo "  --admin-email EMAIL   Admin email address (default: admin@EMAIL_DOMAIN)"
      echo "  --admin-password PWD  Admin password (default: random generated)"
      echo "  --client-id ID        Client ID for multi-tenant setup"
      echo "  --force               Force reinstallation if already installed"
      echo "  --with-deps           Install dependencies automatically"
      echo "  --verbose             Show verbose output"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      log "ERROR: Unknown option: $1" "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Welcome message
echo -e "${BLUE}${BOLD}AgencyStack Mailu Email Server Setup${NC}"
echo -e "======================================"

# If client ID is specified, use client-specific paths
if [ "$CLIENT_ID" != "default" ]; then
  MAILU_DIR="${MAILU_DIR}/clients/${CLIENT_ID}"
  NETWORK_NAME="agency-network"

# Check if Mailu is already installed
if docker ps -a --format '{{.Names}}' | grep -q "${MAILU_CONTAINER}_admin"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: Mailu containers already exist, will reinstall because --force was specified" "${YELLOW}⚠️ Mailu containers already exist, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing Mailu containers" "${CYAN}Stopping and removing existing Mailu containers...${NC}"
    cd "${MAILU_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: Mailu containers already exist" "${GREEN}✅ Mailu installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "${MAILU_CONTAINER}_admin"; then
      log "INFO: Mailu containers are running" "${GREEN}✅ Mailu is running${NC}"
      echo -e "${GREEN}Mailu is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/admin/${NC}"
      echo -e "${CYAN}Webmail URL: https://${DOMAIN}/webmail/${NC}"
      exit 0
    else
      log "WARNING: Mailu containers exist but are not running" "${YELLOW}⚠️ Mailu containers exist but are not running${NC}"
      echo -e "${YELLOW}Mailu is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Mailu containers...${NC}"
      cd "${MAILU_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}Mailu has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/admin/${NC}"
      echo -e "${CYAN}Webmail URL: https://${DOMAIN}/webmail/${NC}"
      exit 0
    fi
  fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR: Docker is not installed" "${RED}Docker is not installed. Please install Docker first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker with --with-deps flag" "${CYAN}Installing Docker with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" >> "$INSTALL_LOG" 2>&1
      if [ $? -ne 0 ]; then
        log "ERROR: Failed to install Docker" "${RED}Failed to install Docker. See log for details.${NC}"
        exit 1
      fi
    else
      log "ERROR: Could not find infrastructure installation script" "${RED}Could not find infrastructure installation script.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  log "ERROR: Docker is not running" "${RED}Docker is not running. Please start Docker first.${NC}"
  exit 1

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR: Docker Compose is not installed" "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker Compose with --with-deps flag" "${CYAN}Installing Docker Compose with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" --skip-docker >> "$INSTALL_LOG" 2>&1
      if [ $? -ne 0 ]; then
        log "ERROR: Failed to install Docker Compose" "${RED}Failed to install Docker Compose. See log for details.${NC}"
        exit 1
      fi
    else
      log "ERROR: Could not find infrastructure installation script" "${RED}Could not find infrastructure installation script.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi

# Check if network exists, create if it doesn't
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO: Creating Docker network $NETWORK_NAME" "${CYAN}Creating Docker network $NETWORK_NAME...${NC}"
  docker network create "$NETWORK_NAME" >> "$INSTALL_LOG" 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to create Docker network $NETWORK_NAME" "${RED}Failed to create Docker network $NETWORK_NAME. See log for details.${NC}"
    exit 1
  fi
  log "INFO: Docker network $NETWORK_NAME already exists" "${GREEN}✅ Docker network $NETWORK_NAME already exists${NC}"

# Check for Traefik
if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. Mailu may not be accessible without a reverse proxy.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing security infrastructure with --with-deps flag" "${CYAN}Installing security infrastructure with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" >> "$INSTALL_LOG" 2>&1
      if [ $? -ne 0 ]; then
        log "WARNING: Failed to install security infrastructure" "${YELLOW}⚠️ Failed to install security infrastructure. Continuing without Traefik.${NC}"
      fi
    else
      log "WARNING: Could not find security infrastructure installation script" "${YELLOW}⚠️ Could not find security infrastructure installation script. Continuing without Traefik.${NC}"
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
  fi

# Check for port availability
log "INFO: Checking for port availability" "${CYAN}Checking for port availability...${NC}"
for port in 25 465 587 993; do
  if netstat -tuln | grep -q ":$port "; then
    log "WARNING: Port $port is already in use" "${YELLOW}⚠️ Port $port is already in use. Mailu might not work correctly.${NC}"
  fi
done

# Start installation
log "INFO: Starting Mailu installation for $DOMAIN" "${CYAN}Starting Mailu installation for $DOMAIN...${NC}"

# Create Mailu directories
log "INFO: Creating Mailu directories" "${CYAN}Creating Mailu directories...${NC}"
mkdir -p "${MAILU_DIR}/${DOMAIN}/data/mail" 2>/dev/null || true
mkdir -p "${MAILU_DIR}/${DOMAIN}/data/certs" 2>/dev/null || true
mkdir -p "${MAILU_DIR}/${DOMAIN}/overrides/nginx" 2>/dev/null || true

# Create Mailu environment file
log "INFO: Creating Mailu environment file" "${CYAN}Creating Mailu environment file...${NC}"
cat > "${MAILU_DIR}/${DOMAIN}/mailu.env" <<EOF
# Mailu main configuration file
#
# This file is auto-generated by the AgencyStack installer.
# For more information on specific settings, visit:
# https://mailu.io/2.0/configuration.html

# Common configuration
SECRET_KEY=$(openssl rand -hex 16)
DOMAIN=${DOMAIN}
HOSTNAMES=${DOMAIN}
SUBNET=192.168.203.0/24
POSTMASTER=${ADMIN_EMAIL}

# TLS configuration
TLS_FLAVOR=cert
TRAEFIK_VERSION=2

# Mail settings
AUTH_RATELIMIT_IP=60/hour
DISABLE_STATISTICS=True
MESSAGE_SIZE_LIMIT=50000000

# Services
ADMIN=true
WEBMAIL=roundcube
ANTISPAM=true
ANTIVIRUS=true
WEBDAV=true

# Admin account for the webmail and admin interface
INITIAL_ADMIN_ACCOUNT=${ADMIN_EMAIL%@*}
INITIAL_ADMIN_DOMAIN=${EMAIL_DOMAIN}
INITIAL_ADMIN_PW=${ADMIN_PASSWORD}
INITIAL_ADMIN_MODE=update
EOF

# Create Docker Compose file for Mailu
log "INFO: Creating Mailu Docker Compose file" "${CYAN}Creating Mailu Docker Compose file...${NC}"
cat > "${MAILU_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  front:
    image: ${DOCKER_ORG}/nginx:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    logging:
      driver: json-file
    ports:
      - "25:25"    # SMTP
      - "465:465"  # SMTPS
      - "587:587"  # Submission
      - "993:993"  # IMAPS
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/certs:/certs
      - ./overrides/nginx:/overrides
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - webmail
      - admin
      - imap
      - antispam
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailu.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.mailu.entrypoints=websecure"
      - "traefik.http.routers.mailu.tls.certresolver=myresolver"
      - "traefik.http.routers.mailu.middlewares=secure-headers@file"
      - "traefik.http.services.mailu.loadbalancer.server.port=80"

  admin:
    image: ${DOCKER_ORG}/admin:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data:/data
      - ./data/mail:/mail
    depends_on:
      - redis
    networks:
      - ${NETWORK_NAME}

  imap:
    image: ${DOCKER_ORG}/dovecot:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data:/data
      - ./overrides/dovecot:/overrides
    networks:
      - ${NETWORK_NAME}

  smtp:
    image: ${DOCKER_ORG}/postfix:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data:/data
      - ./overrides/postfix:/overrides
    networks:
      - ${NETWORK_NAME}

  antispam:
    image: ${DOCKER_ORG}/rspamd:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/var/lib/rspamd
      - ./data:/data
      - ./overrides/rspamd:/overrides
    networks:
      - ${NETWORK_NAME}

  antivirus:
    image: ${DOCKER_ORG}/clamav:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/data
      - ./overrides/clamav:/overrides
    networks:
      - ${NETWORK_NAME}

  webmail:
    image: ${DOCKER_ORG}/roundcube:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/webmail:/data
      - ./overrides/roundcube:/overrides
    depends_on:
      - imap
    networks:
      - ${NETWORK_NAME}

  webdav:
    image: ${DOCKER_ORG}/radicale:${MAILU_VERSION:-2.0}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/webdav:/data
      - ./overrides/radicale:/overrides
    networks:
      - ${NETWORK_NAME}

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./data/redis:/data
    networks:
      - ${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Set permissions
log "INFO: Setting permissions" "${CYAN}Setting permissions...${NC}"
chmod 600 "${MAILU_DIR}/${DOMAIN}/mailu.env"
chown -R root:docker "${MAILU_DIR}/${DOMAIN}/data"
chmod -R 770 "${MAILU_DIR}/${DOMAIN}/data"

# Start Mailu
log "INFO: Starting Mailu" "${CYAN}Starting Mailu...${NC}"
cd "${MAILU_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start Mailu" "${RED}Failed to start Mailu. See log for details.${NC}"
  exit 1

# Wait for Mailu to start
log "INFO: Waiting for Mailu to start" "${CYAN}Waiting for Mailu to start...${NC}"
count=0
max_attempts=10
while [ $count -lt $max_attempts ]; do
  if docker ps | grep -q "${MAILU_CONTAINER}_admin"; then
    log "SUCCESS: Mailu has been started successfully" "${GREEN}✅ Mailu has been started successfully${NC}"
    break
  fi
  count=$((count+1))
  log "INFO: Waiting for Mailu to start (attempt $count/$max_attempts)" "${CYAN}Waiting for Mailu to start (attempt $count/$max_attempts)...${NC}"
  sleep 5
done

# Finish install message
log "SUCCESS: Mailu installation completed" "${GREEN}✅ Mailu installation completed${NC}"
echo -e "${GREEN}Mailu has been installed successfully for $DOMAIN${NC}"
echo -e "${CYAN}Admin URL: https://${DOMAIN}/admin/${NC}"
echo -e "${CYAN}Admin username: ${ADMIN_EMAIL%@*}@${EMAIL_DOMAIN}${NC}"
if [ "$ADMIN_PASSWORD" = "$(openssl rand -base64 12)" ]; then
  echo -e "${CYAN}Admin password: $ADMIN_PASSWORD (randomly generated)${NC}"
  echo -e "${YELLOW}Make sure to save this password!${NC}"
  echo -e "${CYAN}Admin password: (as provided)${NC}"
echo -e "${CYAN}Webmail URL: https://${DOMAIN}/webmail/${NC}"
echo -e "${YELLOW}Note: It might take a few minutes for all services to fully start.${NC}"

# Mark installation complete
echo "DOMAIN=$DOMAIN" > "${MAILU_DIR}/${DOMAIN}/.installed_ok"
echo "ADMIN_EMAIL=$ADMIN_EMAIL" >> "${MAILU_DIR}/${DOMAIN}/.installed_ok"
echo "INSTALL_DATE=$(date)" >> "${MAILU_DIR}/${DOMAIN}/.installed_ok"

exit 0
