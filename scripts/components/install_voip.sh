#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: voip.sh
# Path: /scripts/components/install_voip.sh
#
        
# install_voip.sh - Install and configure VoIP for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up a complete VoIP solution with:
# - FusionPBX for admin interface
# - FreeSWITCH for call processing
# - PostgreSQL database
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
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
VOIP_DIR="${CONFIG_DIR}/voip"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/voip.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/voip.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
FUSIONPBX_VERSION="latest"
FREESWITCH_VERSION="latest"
DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
VOIP_DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
ENABLE_KEYCLOAK=false
ENFORCE_HTTPS=true

# Source the component_sso_helper.sh if available
if [ -f "${SCRIPT_DIR}/../utils/component_sso_helper.sh" ]; then
  source "${SCRIPT_DIR}/../utils/component_sso_helper.sh"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack VoIP Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures a VoIP system with FusionPBX and FreeSWITCH."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for VoIP (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--fusion-version${NC} <version> FusionPBX version (default: latest)"
  echo -e "  ${BOLD}--fs-version${NC} <version>    FreeSWITCH version (default: latest)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if VoIP is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e "  ${BOLD}--enable-keycloak${NC}         Enable Keycloak SSO integration"
  echo -e "  ${BOLD}--enforce-https${NC}           Enforce HTTPS for VoIP web interface"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain pbx.example.com --admin-email admin@example.com --client-id acme"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  echo -e "  - VoIP requires ports 5060-5061 (SIP) and 16384-32768 (RTP)"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    --verbose)
      VERBOSE=true
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
      shift 2
      ;;
    --fusionpbx-version)
      FUSIONPBX_VERSION="$2"
      shift 2
      ;;
    --freeswitch-version)
      FREESWITCH_VERSION="$2"
      shift 2
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    --enforce-https)
      ENFORCE_HTTPS=true
      shift
      ;;
    *)
      log "ERROR: Unknown option: $key" "${RED}Unknown option: $key${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1

if [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: --admin-email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack VoIP Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1

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
  echo "$(date +"%Y-%m-%d %H:%M:%S") - VoIP - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - VoIP - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting VoIP installation validation for $DOMAIN" "${BLUE}Starting VoIP installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  FUSIONPBX_CONTAINER="${CLIENT_ID}_fusionpbx"
  FREESWITCH_CONTAINER="${CLIENT_ID}_freeswitch"
  POSTGRES_CONTAINER="${CLIENT_ID}_voip_postgres"
  NETWORK_NAME="${CLIENT_ID}_network"
  FUSIONPBX_CONTAINER="fusionpbx_${SITE_NAME}"
  FREESWITCH_CONTAINER="freeswitch_${SITE_NAME}"
  POSTGRES_CONTAINER="voip_postgres_${SITE_NAME}"
  NETWORK_NAME="agency-network"

# Check if VoIP is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$FUSIONPBX_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: VoIP container '$FUSIONPBX_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ VoIP container '$FUSIONPBX_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing VoIP containers" "${CYAN}Stopping and removing existing VoIP containers...${NC}"
    cd "${VOIP_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: VoIP container '$FUSIONPBX_CONTAINER' already exists" "${GREEN}✅ VoIP installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$FUSIONPBX_CONTAINER"; then
      log "INFO: VoIP container is running" "${GREEN}✅ VoIP is running${NC}"
      echo -e "${GREEN}VoIP is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: VoIP container exists but is not running" "${YELLOW}⚠️ VoIP container exists but is not running${NC}"
      echo -e "${YELLOW}VoIP is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting VoIP containers...${NC}"
      cd "${VOIP_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}VoIP has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}${NC}"
      exit 0
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
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. VoIP web administration may not be accessible without a reverse proxy.${NC}"
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
  log "INFO: Traefik container found" "${GREEN}✅ Traefik container found${NC}"

# Check if ports are available
log "INFO: Checking for port availability" "${CYAN}Checking for port availability...${NC}"
for port in 5060 5061 5080 16384; do
  if netstat -tuln | grep -q ":$port "; then
    log "WARNING: Port $port is already in use" "${YELLOW}⚠️ Port $port is already in use. This may cause conflicts with the VoIP system.${NC}"
  fi
done

log "INFO: Starting VoIP installation for $DOMAIN" "${BLUE}Starting VoIP installation for $DOMAIN...${NC}"

# Create VoIP directories
log "INFO: Creating VoIP directories" "${CYAN}Creating VoIP directories...${NC}"
mkdir -p "${VOIP_DIR}/${DOMAIN}"
mkdir -p "${VOIP_DIR}/${DOMAIN}/freeswitch"
mkdir -p "${VOIP_DIR}/${DOMAIN}/fusionpbx"
mkdir -p "${VOIP_DIR}/${DOMAIN}/postgres"
mkdir -p "${VOIP_DIR}/${DOMAIN}/logs"

# Create docker-compose.yml file for VoIP stack
log "INFO: Creating VoIP Docker Compose file" "${CYAN}Creating VoIP Docker Compose file...${NC}"
cat > "${VOIP_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  postgres:
    image: postgres:13-alpine
    container_name: ${POSTGRES_CONTAINER}
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${DB_ROOT_PASSWORD}
      POSTGRES_USER: fusionpbx
      POSTGRES_DB: fusionpbx
    volumes:
      - ${VOIP_DIR}/${DOMAIN}/postgres:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "postgres_${SITE_NAME}"

  freeswitch:
    image: signalwire/freeswitch:${FREESWITCH_VERSION}
    container_name: ${FREESWITCH_CONTAINER}
    restart: unless-stopped
    ports:
      - "5060:5060/udp"
      - "5061:5061/tcp"
      - "5080:5080/tcp"
      - "16384-32768:16384-32768/udp"
    volumes:
      - ${VOIP_DIR}/${DOMAIN}/freeswitch:/etc/freeswitch
      - ${VOIP_DIR}/${DOMAIN}/logs:/var/log/freeswitch
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=fusionpbx
      - POSTGRES_USER=fusionpbx
      - POSTGRES_PASSWORD=${VOIP_DB_PASSWORD}
      - DOMAIN_NAME=${DOMAIN}
    networks:
      - ${NETWORK_NAME}
    cap_add:
      - SYS_NICE
      - NET_ADMIN
    depends_on:
      - postgres
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "freeswitch_${SITE_NAME}"

  fusionpbx:
    image: sareu/fusionpbx:${FUSIONPBX_VERSION}
    container_name: ${FUSIONPBX_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${VOIP_DIR}/${DOMAIN}/fusionpbx:/var/www/fusionpbx
      - ${VOIP_DIR}/${DOMAIN}/freeswitch:/etc/freeswitch:ro
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=fusionpbx
      - POSTGRES_USER=fusionpbx
      - POSTGRES_PASSWORD=${VOIP_DB_PASSWORD}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - DOMAIN_NAME=${DOMAIN}
      - FREESWITCH_HOST=freeswitch
      - INITIAL_SETUP=true
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - postgres
      - freeswitch
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fusionpbx_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.fusionpbx_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.fusionpbx_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.routers.fusionpbx_${SITE_NAME}.middlewares=secure-headers@file"
      - "traefik.http.services.fusionpbx_${SITE_NAME}.loadbalancer.server.port=80"
      - "traefik.docker.network=${NETWORK_NAME}"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "fusionpbx_${SITE_NAME}"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create FusionPBX configuration
log "INFO: Creating FusionPBX configuration" "${CYAN}Creating FusionPBX configuration...${NC}"
mkdir -p "${VOIP_DIR}/${DOMAIN}/fusionpbx/resources/config"
cat > "${VOIP_DIR}/${DOMAIN}/fusionpbx/resources/config/config.php" <<EOF
<?php
/*
 FusionPBX
 Version: MPL 1.1

 The contents of this file are subject to the Mozilla Public License Version
 1.1 (the "License"); you may not use this file except in compliance with
 the License. You may obtain a copy of the License at
 http://www.mozilla.org/MPL/

 Software distributed under the License is distributed on an "AS IS" basis,
 WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 for the specific language governing rights and limitations under the
 License.

 The Original Code is FusionPBX

 The Initial Developer of the Original Code is
 Mark J Crane <markjcrane@fusionpbx.com>
 Portions created by the Initial Developer are Copyright (C) 2008-2020
 the Initial Developer. All Rights Reserved.

 Contributor(s):
 Mark J Crane <markjcrane@fusionpbx.com>
*/

//-----------------------------------------------------
// settings:
//-----------------------------------------------------

// Database Settings
\$db_type = 'pgsql'; // mysql, pgsql, sqlite
\$db_host = 'postgres';
\$db_port = '5432';
\$db_name = 'fusionpbx';
\$db_username = 'fusionpbx';
\$db_password = '${VOIP_DB_PASSWORD}';

// Show errors
\$show_debug = false;

// Additional Settings
\$setting['debug']['enabled'] = 'false';
\$setting['email']['method'] = 'smtp';
\$setting['email']['smtp_host'] = 'mail.${DOMAIN%.*.*}';
\$setting['email']['smtp_port'] = '25';
\$setting['email']['smtp_auth'] = 'true';
\$setting['email']['smtp_username'] = '${ADMIN_EMAIL}';
\$setting['email']['smtp_password'] = ''; // Set this manually for security
\$setting['email']['smtp_secure'] = 'tls';
\$setting['email']['smtp_from'] = '${ADMIN_EMAIL}';
\$setting['email']['smtp_from_name'] = 'FusionPBX VoIP';

// Domain Settings
\$domain_name = '${DOMAIN}';
\$domain_count = 0;
\$domain_array[0]['domain_uuid'] = '60c41750-6ad6-465d-b844-21030c2e2732';
\$domain_array[0]['domain_name'] = \$domain_name;

?>
EOF

# Create firewall configuration script
log "INFO: Creating firewall configuration script" "${CYAN}Creating firewall configuration script...${NC}"
cat > "${VOIP_DIR}/${DOMAIN}/setup_firewall.sh" <<EOF
#!/bin/bash
# VoIP Firewall Configuration Script
# This script configures the firewall to allow VoIP traffic

# Allow SIP ports
ufw allow 5060/udp
ufw allow 5061/tcp

# Allow RTP ports
ufw allow 16384:32768/udp

# Reload firewall
ufw reload

echo "Firewall rules added for VoIP"
EOF

chmod +x "${VOIP_DIR}/${DOMAIN}/setup_firewall.sh"

# Create a ports documentation file
log "INFO: Creating ports documentation" "${CYAN}Creating ports documentation...${NC}"
mkdir -p "${ROOT_DIR}/docs/pages"
if [ -f "${ROOT_DIR}/docs/pages/ports.md" ]; then
  # Append to existing ports documentation
  cat >> "${ROOT_DIR}/docs/pages/ports.md" <<EOF

## VoIP Configuration for ${DOMAIN}

| Service     | Port            | Protocol | Purpose                        |
|-------------|-----------------|----------|--------------------------------|
| SIP         | 5060            | UDP      | Session Initiation Protocol    |
| SIP-TLS     | 5061            | TCP      | Secure SIP over TLS            |
| RTP         | 16384-32768     | UDP      | Real-time Transport Protocol |

These ports must be open in your firewall for proper VoIP functionality.
EOF
  # Create new ports documentation
  cat > "${ROOT_DIR}/docs/pages/ports.md" <<EOF
# AgencyStack Port Configuration

This document outlines the ports used by various services in the AgencyStack.

## VoIP Configuration for ${DOMAIN}

| Service     | Port            | Protocol | Purpose                        |
|-------------|-----------------|----------|--------------------------------|
| SIP         | 5060            | UDP      | Session Initiation Protocol    |
| SIP-TLS     | 5061            | TCP      | Secure SIP over TLS            |
| RTP         | 16384-32768     | UDP      | Real-time Transport Protocol |

These ports must be open in your firewall for proper VoIP functionality.
EOF

# Start the VoIP stack
log "INFO: Starting VoIP stack" "${CYAN}Starting VoIP stack...${NC}"
cd "${VOIP_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start VoIP stack" "${RED}Failed to start VoIP stack. See log for details.${NC}"
  exit 1

# Wait for services to start
log "INFO: Waiting for VoIP services to start (this may take a few minutes)" "${YELLOW}Waiting for VoIP services to start (this may take a few minutes)...${NC}"
sleep 60

# Configure firewall
log "INFO: Configuring firewall for VoIP" "${CYAN}Configuring firewall for VoIP...${NC}"
if command -v ufw &> /dev/null; then
  bash "${VOIP_DIR}/${DOMAIN}/setup_firewall.sh" >> "$INSTALL_LOG" 2>&1
  log "INFO: Firewall configured for VoIP" "${GREEN}Firewall configured for VoIP${NC}"
  log "WARNING: UFW not installed, firewall not configured" "${YELLOW}UFW not installed, please configure your firewall manually${NC}"
  log "WARNING: VoIP requires SIP ports (5060/udp, 5061/tcp) and RTP ports (16384-32768/udp)" "${YELLOW}VoIP requires SIP ports (5060/udp, 5061/tcp) and RTP ports (16384-32768/udp)${NC}"

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/voip"
chmod 700 "${CONFIG_DIR}/secrets/voip"

cat > "${CONFIG_DIR}/secrets/voip/${DOMAIN}.env" <<EOF
# VoIP Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

FUSIONPBX_URL=https://${DOMAIN}/
FUSIONPBX_ADMIN_USER=admin
FUSIONPBX_ADMIN_PASSWORD=${ADMIN_PASSWORD}
FUSIONPBX_ADMIN_EMAIL=${ADMIN_EMAIL}

POSTGRES_PASSWORD=${VOIP_DB_PASSWORD}

# SIP Server Details
SIP_SERVER=${DOMAIN}
SIP_PORT=5060
SIP_TLS_PORT=5061
RTP_PORTS=16384-32768

# Docker project
VOIP_PROJECT_NAME=${FUSIONPBX_CONTAINER}
EOF

chmod 600 "${CONFIG_DIR}/secrets/voip/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering VoIP in components registry" "${CYAN}Registering VoIP in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/voip"
  
  cat > "${CONFIG_DIR}/components/voip/${DOMAIN}.json" <<EOF
{
  "component": "voip",
  "version": "${FREESWITCH_VERSION}",
  "fusionpbx_version": "${FUSIONPBX_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active",
  "ports": {
    "sip": 5060,
    "sip_tls": 5061,
    "rtp_start": 16384,
    "rtp_end": 32768
  }
}
EOF

# Integrate with dashboard if available
log "INFO: Checking for dashboard integration" "${CYAN}Checking for dashboard integration...${NC}"
if [ -f "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" ]; then
  log "INFO: Updating dashboard with VoIP information" "${CYAN}Updating dashboard with VoIP information...${NC}"
  bash "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" "voip" "${DOMAIN}" "active"
  log "INFO: Dashboard integration script not found, skipping" "${YELLOW}Dashboard integration script not found, skipping${NC}"

# Update installed_components.txt
if [ -f "${CONFIG_DIR}/installed_components.txt" ]; then
  if ! grep -q "voip|${DOMAIN}" "${CONFIG_DIR}/installed_components.txt"; then
    echo "voip|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
    log "INFO: Updated installed components list" "${CYAN}Updated installed components list${NC}"
  fi
  echo "component|domain|install_date|status" > "${CONFIG_DIR}/installed_components.txt"
  echo "voip|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
  log "INFO: Created installed components list" "${CYAN}Created installed components list${NC}"

# Display completion information
log "INFO: VoIP installation completed successfully" "${GREEN}VoIP installation completed successfully!${NC}"
log "INFO: FusionPBX is now accessible at https://${DOMAIN}" "${GREEN}FusionPBX is now accessible at:${NC} https://${DOMAIN}"
log "INFO: Admin username: admin" "${GREEN}Admin username:${NC} admin"
log "INFO: Admin password: ${ADMIN_PASSWORD}" "${GREEN}Admin password:${NC} ${ADMIN_PASSWORD}"

# Configure Keycloak SSO integration if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  log "INFO: Configuring Keycloak SSO integration for VoIP" "${CYAN}Configuring Keycloak SSO integration for VoIP...${NC}"
  
  # Check if component_sso_helper.sh is available and the enable_component_sso function exists
  if type enable_component_sso &>/dev/null; then
    # Get redirect URIs for VoIP
    VOIP_REDIRECT_URIS='["https://'"${DOMAIN}"'/*", "https://pbx.'"${DOMAIN}"'/*", "https://voip.'"${DOMAIN}"'/*"]'
    
    # Enable SSO for VoIP
    if enable_component_sso "voip" "${DOMAIN}" "${VOIP_REDIRECT_URIS}" "voip" "agency_stack"; then
      log "INFO: Successfully enabled Keycloak SSO for VoIP" "${GREEN}Successfully enabled Keycloak SSO for VoIP${NC}"
      
      # Create a Docker volume for the FusionPBX authentication integration
      log "INFO: Setting up FusionPBX SSO integration files" "${CYAN}Setting up FusionPBX SSO integration files...${NC}"
      
      # Create SSO configuration directory
      mkdir -p "${VOIP_DIR}/${DOMAIN}/sso"
      
      # Create the SSO integration script
      cat > "${VOIP_DIR}/${DOMAIN}/sso/keycloak_config.php" <<EOF
<?php
// FusionPBX Keycloak SSO Integration
// This file is auto-generated by install_voip.sh

// Keycloak Configuration
\$keycloak_config = [
    'realm' => 'agency_stack',
    'auth-server-url' => 'https://${DOMAIN}/auth',
    'ssl-required' => 'external',
    'resource' => 'voip',
    'public-client' => false,
    'confidential-port' => 0,
    'redirect_uri' => 'https://${DOMAIN}/oauth2callback.php'
];

// Include this file in the FusionPBX configuration to enable SSO
?>
EOF
      
      # Create a marker file for the SSO configuration
      touch "${VOIP_DIR}/${DOMAIN}/sso/.sso_configured"
      
      # Update the component registry for VoIP with SSO configuration status
      if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
        log "INFO: Updating component registry with SSO status" "${CYAN}Updating component registry with SSO status...${NC}"
        bash "${ROOT_DIR}/scripts/utils/update_component_registry.sh" --component "voip" --sso true --sso_configured true
      fi
      
      log "INFO: SSO integration completed for VoIP" "${GREEN}SSO integration completed for VoIP${NC}"
    else
      log "WARNING: Failed to enable Keycloak SSO for VoIP" "${YELLOW}Failed to enable Keycloak SSO for VoIP${NC}"
    fi
  else
    log "WARNING: component_sso_helper.sh not found or not properly sourced" "${YELLOW}Keycloak SSO integration helper not available${NC}"
    log "INFO: Manual SSO configuration will be required" "${CYAN}Manual SSO configuration will be required${NC}"
  fi

# Update component registry
if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
  log "INFO: Updating component registry" "${CYAN}Updating component registry...${NC}"
  
  REGISTRY_ARGS=(
    "--component" "voip"
    "--installed" "true"
    "--monitoring" "true"
    "--traefik_tls" "true"
  )
  
  if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
    REGISTRY_ARGS+=(
      "--sso" "true"
      "--sso_configured" "true"
    )
  fi
  
  bash "${ROOT_DIR}/scripts/utils/update_component_registry.sh" "${REGISTRY_ARGS[@]}"

log "INFO: Installation complete" "${GREEN}Installation complete!${NC}"

# Final connection and usage information
echo -e ""
echo -e "${CYAN}Connection Details:${NC}"
echo -e "${CYAN}SIP Server: ${DOMAIN}${NC}"
echo -e "${CYAN}SIP Port (UDP): 5060${NC}"
echo -e "${CYAN}SIP-TLS Port: 5061${NC}"
echo -e "${CYAN}RTP Ports: 16384-32768${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/voip/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}NOTE: For VoIP to work properly, ensure the following:${NC}"
echo -e "${YELLOW}1. SIP and RTP ports are open in your firewall${NC}"
echo -e "${YELLOW}2. Your domain has proper DNS records pointing to this server${NC}"
echo -e "${YELLOW}3. If using external VoIP providers, configure them in FusionPBX${NC}"

exit 0
