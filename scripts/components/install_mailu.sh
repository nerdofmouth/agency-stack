#!/bin/bash
# install_mailu.sh - Install and configure Mailu email server for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up Mailu, a full-featured mail server with:
# - SMTP and IMAP services
# - Webmail interface (Roundcube)
# - Admin panel
# - Anti-spam and anti-virus filtering
# - DKIM, SPF, and DMARC support
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
INSTALL_LOG="${LOG_DIR}/mailu_install.log"
VERBOSE=false
DOMAIN=""
EMAIL_DOMAIN=""
ADMIN_EMAIL=""
SECRET_KEY=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
INITIAL_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Mailu Email Server Setup${NC}"
  echo -e "========================================"
  echo -e "This script installs and configures Mailu email server with:"
  echo -e "  - SMTP and IMAP services"
  echo -e "  - Webmail interface (Roundcube)"
  echo -e "  - Admin panel"
  echo -e "  - Anti-spam and anti-virus filtering"
  echo -e "  - DKIM, SPF, and DMARC support"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>        Main domain for Mailu admin panel (required)"
  echo -e "  ${BOLD}--email-domain${NC} <domain>  Domain for email addresses (required)" 
  echo -e "  ${BOLD}--admin-email${NC} <email>    Admin email address (required)"
  echo -e "  ${BOLD}--verbose${NC}                Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                   Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain mail.example.com --email-domain example.com --admin-email admin@example.com"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Make sure proper DNS records are configured before running this script"
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
    --email-domain)
      EMAIL_DOMAIN="$2"
      shift
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
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

if [ -z "$EMAIL_DOMAIN" ]; then
  echo -e "${RED}Error: --email-domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: --admin-email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Mailu Email Server Setup${NC}"
echo -e "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
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

log "INFO: Starting Mailu installation" "${BLUE}Starting Mailu installation...${NC}"

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

# Create Mailu directory
log "INFO: Creating Mailu directory" "${CYAN}Creating Mailu directory...${NC}"
mkdir -p "${MAILU_DIR}"
mkdir -p "${MAILU_DIR}/data"
mkdir -p "${MAILU_DIR}/data/mail"
mkdir -p "${MAILU_DIR}/data/webmail"
mkdir -p "${MAILU_DIR}/data/filter"
mkdir -p "${MAILU_DIR}/overrides"

# Create Docker Compose file for Mailu
log "INFO: Creating Mailu Docker Compose file" "${CYAN}Creating Mailu Docker Compose file...${NC}"
cat > "${MAILU_DIR}/docker-compose.yml" <<EOF
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
      - agency-network
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
      - agency-network

  imap:
    image: ${DOCKER_ORG:-mailu}/dovecot:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data/certs:/certs
      - ./overrides/dovecot:/overrides
    networks:
      - agency-network

  smtp:
    image: ${DOCKER_ORG:-mailu}/postfix:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/mail:/mail
      - ./data/certs:/certs
      - ./overrides/postfix:/overrides
    networks:
      - agency-network

  antispam:
    image: ${DOCKER_ORG:-mailu}/rspamd:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/var/lib/rspamd
      - ./data/mail:/mail
      - ./overrides/rspamd:/overrides
    networks:
      - agency-network
    depends_on:
      - antivirus

  antivirus:
    image: ${DOCKER_ORG:-mailu}/clamav:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/filter:/data
    networks:
      - agency-network

  webmail:
    image: ${DOCKER_ORG:-mailu}/roundcube:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/webmail:/data
    networks:
      - agency-network
    depends_on:
      - imap

  webdav:
    image: ${DOCKER_ORG:-mailu}/radicale:${MAILU_VERSION:-1.9}
    restart: always
    env_file: mailu.env
    volumes:
      - ./data/dav:/data
    networks:
      - agency-network

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./data/redis:/data
    networks:
      - agency-network

networks:
  agency-network:
    external: true
EOF

# Create Mailu environment file
log "INFO: Creating Mailu environment file" "${CYAN}Creating Mailu environment file...${NC}"
cat > "${MAILU_DIR}/mailu.env" <<EOF
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
INITIAL_ADMIN_PASSWORD=${INITIAL_ADMIN_PASSWORD}
INITIAL_ADMIN_MODE=update
EOF

# Set permissions
log "INFO: Setting permissions" "${CYAN}Setting permissions...${NC}"
chmod 600 "${MAILU_DIR}/mailu.env"
chown -R root:docker "${MAILU_DIR}/data"
chmod -R 770 "${MAILU_DIR}/data"

# Start Mailu
log "INFO: Starting Mailu" "${CYAN}Starting Mailu...${NC}"
cd "${MAILU_DIR}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start Mailu" "${RED}Failed to start Mailu. See log for details.${NC}"
  exit 1
fi

# DNS Records Information
log "INFO: Generating DNS records information" "${CYAN}Generating DNS records information...${NC}"
cat > "${MAILU_DIR}/dns_records.txt" <<EOF
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
echo -e "${CYAN}Mailu admin panel: https://${DOMAIN}/admin${NC}"
echo -e "${CYAN}Webmail: https://${DOMAIN}/webmail${NC}"
echo -e "${YELLOW}Admin login: admin@${EMAIL_DOMAIN}${NC}"
echo -e "${YELLOW}Initial password: ${INITIAL_ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please change this password immediately!${NC}"
echo -e ""
echo -e "${CYAN}Required DNS records have been saved to:${NC}"
echo -e "${CYAN}${MAILU_DIR}/dns_records.txt${NC}"
echo -e ""
echo -e "${YELLOW}⚠️ You must set up these DNS records for the mail server to function properly!${NC}"
echo -e "${YELLOW}⚠️ DKIM keys will be generated after the first startup and should be added to your DNS records.${NC}"

exit 0
