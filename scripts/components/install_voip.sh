#!/bin/bash
# install_voip.sh - Install and configure VoIP infrastructure for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up a complete VoIP system with:
# - FusionPBX administrative interface
# - FreeSWITCH VoIP server
# - PostgreSQL database
# - Properly configured SIP and RTP ports
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
VOIP_DIR="${CONFIG_DIR}/voip"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/voip.log"
VERBOSE=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
FREESWITCH_VERSION="1.10"
FUSIONPBX_VERSION="latest"
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
SIP_PORT=5060
SIP_TLS_PORT=5061
RTP_START_PORT=16384
RTP_END_PORT=32768

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack VoIP Setup${NC}"
  echo -e "========================="
  echo -e "This script installs and configures a complete VoIP system with FusionPBX and FreeSWITCH."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>            Primary domain for VoIP server (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>      Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>        Admin email address (required)"
  echo -e "  ${BOLD}--sip-port${NC} <port>            SIP UDP port (default: 5060)"
  echo -e "  ${BOLD}--sip-tls-port${NC} <port>        SIP TLS port (default: 5061)"
  echo -e "  ${BOLD}--rtp-start-port${NC} <port>      RTP starting port (default: 16384)"
  echo -e "  ${BOLD}--rtp-end-port${NC} <port>        RTP ending port (default: 32768)"
  echo -e "  ${BOLD}--freeswitch-version${NC} <ver>   FreeSWITCH version (default: 1.10)"
  echo -e "  ${BOLD}--verbose${NC}                    Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                       Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain voip.example.com --admin-email admin@example.com"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Make sure the specified SIP and RTP ports are allowed in your firewall"
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
    --sip-port)
      SIP_PORT="$2"
      shift
      shift
      ;;
    --sip-tls-port)
      SIP_TLS_PORT="$2"
      shift
      shift
      ;;
    --rtp-start-port)
      RTP_START_PORT="$2"
      shift
      shift
      ;;
    --rtp-end-port)
      RTP_END_PORT="$2"
      shift
      shift
      ;;
    --freeswitch-version)
      FREESWITCH_VERSION="$2"
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

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack VoIP Setup${NC}"
echo -e "========================="

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

log "INFO: Starting VoIP installation for $DOMAIN" "${BLUE}Starting VoIP installation for $DOMAIN...${NC}"

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
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  VOIP_PROJECT_NAME="${CLIENT_ID}_voip"
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
  VOIP_PROJECT_NAME="voip_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Create VoIP directories
log "INFO: Creating VoIP directories" "${CYAN}Creating VoIP directories...${NC}"
mkdir -p "${VOIP_DIR}/${DOMAIN}"
mkdir -p "${VOIP_DIR}/${DOMAIN}/freeswitch"
mkdir -p "${VOIP_DIR}/${DOMAIN}/fusionpbx"
mkdir -p "${VOIP_DIR}/${DOMAIN}/postgres"
mkdir -p "${VOIP_DIR}/${DOMAIN}/logs"
mkdir -p "${VOIP_DIR}/${DOMAIN}/certs"

# Create docker-compose.yml file for VoIP stack
log "INFO: Creating VoIP Docker Compose file" "${CYAN}Creating VoIP Docker Compose file...${NC}"
cat > "${VOIP_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  postgres:
    image: postgres:13-alpine
    container_name: ${VOIP_PROJECT_NAME}_postgres
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
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
    container_name: ${VOIP_PROJECT_NAME}_freeswitch
    restart: unless-stopped
    ports:
      - "${SIP_PORT}:${SIP_PORT}/udp"
      - "${SIP_TLS_PORT}:${SIP_TLS_PORT}/tcp"
      - "${RTP_START_PORT}-${RTP_END_PORT}:${RTP_START_PORT}-${RTP_END_PORT}/udp"
    volumes:
      - ${VOIP_DIR}/${DOMAIN}/freeswitch:/etc/freeswitch
      - ${VOIP_DIR}/${DOMAIN}/logs:/var/log/freeswitch
      - ${VOIP_DIR}/${DOMAIN}/certs:/etc/freeswitch/tls
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=fusionpbx
      - POSTGRES_USER=fusionpbx
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
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
    container_name: ${VOIP_PROJECT_NAME}_fusionpbx
    restart: unless-stopped
    volumes:
      - ${VOIP_DIR}/${DOMAIN}/fusionpbx:/var/www/fusionpbx
      - ${VOIP_DIR}/${DOMAIN}/freeswitch:/etc/freeswitch:ro
      - ${VOIP_DIR}/${DOMAIN}/certs:/etc/nginx/ssl
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=fusionpbx
      - POSTGRES_USER=fusionpbx
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
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
\$db_password = '${POSTGRES_PASSWORD}';

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
ufw allow ${SIP_PORT}/udp
ufw allow ${SIP_TLS_PORT}/tcp

# Allow RTP ports
ufw allow ${RTP_START_PORT}:${RTP_END_PORT}/udp

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
| SIP         | ${SIP_PORT}     | UDP      | Session Initiation Protocol    |
| SIP-TLS     | ${SIP_TLS_PORT} | TCP      | Secure SIP over TLS            |
| RTP         | ${RTP_START_PORT}-${RTP_END_PORT} | UDP | Real-time Transport Protocol |

These ports must be open in your firewall for proper VoIP functionality.
EOF
else
  # Create new ports documentation
  cat > "${ROOT_DIR}/docs/pages/ports.md" <<EOF
# AgencyStack Port Configuration

This document outlines the ports used by various services in the AgencyStack.

## VoIP Configuration for ${DOMAIN}

| Service     | Port            | Protocol | Purpose                        |
|-------------|-----------------|----------|--------------------------------|
| SIP         | ${SIP_PORT}     | UDP      | Session Initiation Protocol    |
| SIP-TLS     | ${SIP_TLS_PORT} | TCP      | Secure SIP over TLS            |
| RTP         | ${RTP_START_PORT}-${RTP_END_PORT} | UDP | Real-time Transport Protocol |

These ports must be open in your firewall for proper VoIP functionality.
EOF
fi

# Start the VoIP stack
log "INFO: Starting VoIP stack" "${CYAN}Starting VoIP stack...${NC}"
cd "${VOIP_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start VoIP stack" "${RED}Failed to start VoIP stack. See log for details.${NC}"
  exit 1
fi

# Wait for services to start
log "INFO: Waiting for VoIP services to start (this may take a few minutes)" "${YELLOW}Waiting for VoIP services to start (this may take a few minutes)...${NC}"
sleep 60

# Configure firewall
log "INFO: Configuring firewall for VoIP" "${CYAN}Configuring firewall for VoIP...${NC}"
if command -v ufw &> /dev/null; then
  bash "${VOIP_DIR}/${DOMAIN}/setup_firewall.sh" >> "$INSTALL_LOG" 2>&1
  log "INFO: Firewall configured for VoIP" "${GREEN}Firewall configured for VoIP${NC}"
else
  log "WARNING: UFW not installed, firewall not configured" "${YELLOW}UFW not installed, please configure your firewall manually${NC}"
  log "WARNING: VoIP requires SIP ports ($SIP_PORT/udp, $SIP_TLS_PORT/tcp) and RTP ports ($RTP_START_PORT-$RTP_END_PORT/udp)" "${YELLOW}VoIP requires SIP ports ($SIP_PORT/udp, $SIP_TLS_PORT/tcp) and RTP ports ($RTP_START_PORT-$RTP_END_PORT/udp)${NC}"
fi

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

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# SIP Server Details
SIP_SERVER=${DOMAIN}
SIP_PORT=${SIP_PORT}
SIP_TLS_PORT=${SIP_TLS_PORT}
RTP_PORTS=${RTP_START_PORT}-${RTP_END_PORT}

# Docker project
VOIP_PROJECT_NAME=${VOIP_PROJECT_NAME}
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
    "sip": ${SIP_PORT},
    "sip_tls": ${SIP_TLS_PORT},
    "rtp_start": ${RTP_START_PORT},
    "rtp_end": ${RTP_END_PORT}
  }
}
EOF
fi

# Integrate with dashboard if available
log "INFO: Checking for dashboard integration" "${CYAN}Checking for dashboard integration...${NC}"
if [ -f "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" ]; then
  log "INFO: Updating dashboard with VoIP information" "${CYAN}Updating dashboard with VoIP information...${NC}"
  bash "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" "voip" "${DOMAIN}" "active"
else
  log "INFO: Dashboard integration script not found, skipping" "${YELLOW}Dashboard integration script not found, skipping${NC}"
fi

# Update installed_components.txt
if [ -f "${CONFIG_DIR}/installed_components.txt" ]; then
  if ! grep -q "voip|${DOMAIN}" "${CONFIG_DIR}/installed_components.txt"; then
    echo "voip|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
    log "INFO: Updated installed components list" "${CYAN}Updated installed components list${NC}"
  fi
else
  echo "component|domain|install_date|status" > "${CONFIG_DIR}/installed_components.txt"
  echo "voip|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
  log "INFO: Created installed components list" "${CYAN}Created installed components list${NC}"
fi

# Final message
log "INFO: VoIP installation completed successfully" "${GREEN}${BOLD}✅ VoIP system installed successfully!${NC}"
echo -e "${CYAN}FusionPBX Admin URL: https://${DOMAIN}/${NC}"
echo -e "${YELLOW}Admin Username: admin${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}SIP Server: ${DOMAIN}${NC}"
echo -e "${CYAN}SIP Port (UDP): ${SIP_PORT}${NC}"
echo -e "${CYAN}SIP-TLS Port: ${SIP_TLS_PORT}${NC}"
echo -e "${CYAN}RTP Ports: ${RTP_START_PORT}-${RTP_END_PORT}${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/voip/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}NOTE: For VoIP to work properly, ensure the following:${NC}"
echo -e "${YELLOW}1. SIP and RTP ports are open in your firewall${NC}"
echo -e "${YELLOW}2. Your domain has proper DNS records pointing to this server${NC}"
echo -e "${YELLOW}3. If using external VoIP providers, configure them in FusionPBX${NC}"

exit 0
