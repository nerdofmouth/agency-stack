#!/bin/bash
# install_mailu.sh - Install and configure Mailu email server for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up a Mailu email server with:
# - SMTP/IMAP/POP3 services
# - Web administration interface
# - Webmail (Roundcube)
# - Anti-spam and anti-virus protection
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
MAILU_DIR="${CONFIG_DIR}/mailu"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/mailu.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/mailu.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
EMAIL_DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
SECRET_KEY=$(openssl rand -base64 32)
MAILU_VERSION="1.9"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Mailu Email Server Setup${NC}"
  echo -e "======================================"
  echo -e "This script installs and configures a Mailu email server with webmail and administration interface."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for Mailu server (required)"
  echo -e "  ${BOLD}--email-domain${NC} <domain>   Domain for email addresses (defaults to --domain)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--mailu-version${NC} <version> Mailu version (default: 1.9)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if Mailu is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain mail.example.com --email-domain example.com --admin-email admin@example.com --client-id acme"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  echo -e "  - Make sure DNS records for mail server are properly configured"
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
    --email-domain)
      EMAIL_DOMAIN="$2"
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
    --mailu-version)
      MAILU_VERSION="$2"
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

# Set email domain if not provided
if [ -z "$EMAIL_DOMAIN" ]; then
  EMAIL_DOMAIN="$DOMAIN"
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Mailu Email Server Setup${NC}"
echo -e "======================================"

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
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Mailu - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Mailu - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting Mailu installation validation for $DOMAIN" "${BLUE}Starting Mailu installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  MAILU_CONTAINER="${CLIENT_ID}_mailu"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  MAILU_CONTAINER="mailu_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

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
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
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
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. Mailu may not be accessible without a reverse proxy.${NC}"
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

# Check if ports are available
log "INFO: Checking for port availability" "${CYAN}Checking for port availability...${NC}"
for port in 25 465 587 143 993 110 995; do
  if netstat -tuln | grep -q ":$port "; then
    log "WARNING: Port $port is already in use" "${YELLOW}⚠️ Port $port is already in use. This may cause conflicts with Mailu.${NC}"
  fi
done

log "INFO: Starting Mailu installation for $DOMAIN" "${BLUE}Starting Mailu installation for $DOMAIN...${NC}"

# Create Mailu directories
log "INFO: Creating Mailu directories" "${CYAN}Creating Mailu directories...${NC}"
mkdir -p "${MAILU_DIR}/${DOMAIN}"
mkdir -p "${MAILU_DIR}/${DOMAIN}/data"
mkdir -p "${MAILU_DIR}/${DOMAIN}/mail"
mkdir -p "${MAILU_DIR}/${DOMAIN}/certs"
mkdir -p "${MAILU_DIR}/${DOMAIN}/overrides"
mkdir -p "${MAILU_DIR}/${DOMAIN}/logs"

# Create Mailu environment file
log "INFO: Creating Mailu environment file" "${CYAN}Creating Mailu environment file...${NC}"
cat > "${MAILU_DIR}/${DOMAIN}/mailu.env" <<EOF
# Mailu main configuration file
#
# This file is autogenerated by the AgencyStack installer
# For a complete reference of configuration options, see
# https://mailu.io/1.9/configuration.html

# Common configuration
SECRET_KEY=${SECRET_KEY}
DOMAIN=${EMAIL_DOMAIN}
HOSTNAMES=${DOMAIN}
POSTMASTER=${ADMIN_EMAIL}
TLS_FLAVOR=cert

# Authentication
CREDENTIAL_ROUNDS=12
AUTH_RATELIMIT=10/minute;1000/hour
DISABLE_STATISTICS=False

# Components
ADMIN=true
FRONT=true
WEBMAIL=true
WEBDAV=true
ANTISPAM=true
ANTIVIRUS=true

# Mail settings
RECIPIENT_DELIMITER=+
DMARC_RUA=postmaster
DMARC_RUF=postmaster
WELCOME=true
WELCOME_SUBJECT=Welcome to your new email account
WELCOME_BODY=Welcome to your new email account, sent by an AgencyStack server

# Advanced settings
PASSWORD_SCHEME=PBKDF2
LOG_LEVEL=INFO
SUBNET=192.168.203.0/24
POD_ADDRESS_RANGE=none

# Admin user
INITIAL_ADMIN_ACCOUNT=admin
INITIAL_ADMIN_DOMAIN=${EMAIL_DOMAIN}
INITIAL_ADMIN_PASSWORD=${ADMIN_PASSWORD}
INITIAL_ADMIN_MODE=update
EOF

# Create Docker Compose file for Mailu
log "INFO: Creating Mailu Docker Compose file" "${CYAN}Creating Mailu Docker Compose file...${NC}"
cat > "${MAILU_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  front:
    image: ${DOCKER_ORG:-mailu}/nginx:${MAILU_VERSION:-1.9}
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
    image: ${DOCKER_ORG:-mailu}/admin:${MAILU_VERSION:-1.9}
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
    image: ${DOCKER_ORG:-mailu}/dovecot:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data/certs:/certs
      - ./overrides/dovecot:/overrides
    networks:
      - ${NETWORK_NAME}

  smtp:
    image: ${DOCKER_ORG:-mailu}/postfix:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data/certs:/certs
      - ./overrides/postfix:/overrides
    networks:
      - ${NETWORK_NAME}

  antispam:
    image: ${DOCKER_ORG:-mailu}/rspamd:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/var/lib/rspamd
      - ./data/mail:/mail
      - ./overrides/rspamd:/overrides
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - antivirus

  antivirus:
    image: ${DOCKER_ORG:-mailu}/clamav:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/data
    networks:
      - ${NETWORK_NAME}

  webmail:
    image: ${DOCKER_ORG:-mailu}/roundcube:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/webmail:/data
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - imap

  webdav:
    image: ${DOCKER_ORG:-mailu}/radicale:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/dav:/data
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
fi

# DNS Records Information
log "INFO: Generating DNS records information" "${CYAN}Generating DNS records information...${NC}"
cat > "${MAILU_DIR}/${DOMAIN}/dns_records.txt" <<EOF
# DNS Records for Mailu (${EMAIL_DOMAIN})
# Please add these records to your DNS zone

# MX Record
${EMAIL_DOMAIN}. 3600 IN MX 10 ${DOMAIN}.

# SPF Record
${EMAIL_DOMAIN}. 3600 IN TXT "v=spf1 mx a:${DOMAIN} -all"

# DKIM - This will be generated after first start
# Check /data/dkim folder after first start

# DMARC Record
_dmarc.${EMAIL_DOMAIN}. 3600 IN TXT "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:${ADMIN_EMAIL}; ruf=mailto:${ADMIN_EMAIL}; fo=1"

# Autodiscover for Outlook
autodiscover.${EMAIL_DOMAIN}. 3600 IN CNAME ${DOMAIN}.
_autodiscover._tcp.${EMAIL_DOMAIN}. 3600 IN SRV 0 0 443 ${DOMAIN}.

# Autoconfig for Thunderbird
autoconfig.${EMAIL_DOMAIN}. 3600 IN CNAME ${DOMAIN}.
EOF

# Final message
log "INFO: Mailu installation completed successfully" "${GREEN}${BOLD}✅ Mailu email server installation completed successfully!${NC}"
echo -e "${CYAN}Mailu admin panel: https://${DOMAIN}/admin/${NC}"
echo -e "${CYAN}Webmail: https://${DOMAIN}/webmail/${NC}"
echo -e "${YELLOW}Admin login: admin@${EMAIL_DOMAIN}${NC}"
echo -e "${YELLOW}Initial password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please change this password immediately!${NC}"
echo -e ""
echo -e "${CYAN}Required DNS records have been saved to:${NC}"
echo -e "${CYAN}${MAILU_DIR}/${DOMAIN}/dns_records.txt${NC}"
echo -e ""
echo -e "${YELLOW}⚠️ You must set up these DNS records for the mail server to function properly!${NC}"
echo -e "${YELLOW}⚠️ DKIM keys will be generated after the first startup and should be added to your DNS records.${NC}"

exit 0
