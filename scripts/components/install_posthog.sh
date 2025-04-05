#!/bin/bash
# install_posthog.sh - Install and configure PostHog for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up PostHog analytics platform with:
# - PostgreSQL database
# - ClickHouse for events
# - Redis for caching
# - Zookeeper for coordination
# - Kafka for messaging
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
POSTHOG_DIR="${CONFIG_DIR}/posthog"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/posthog.log"
VERBOSE=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
POSTHOG_VERSION="latest"
SECRET_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack PostHog Setup${NC}"
  echo -e "==========================="
  echo -e "This script installs and configures PostHog analytics platform."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for PostHog (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--posthog-version${NC} <ver>   PostHog version (default: latest)"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain analytics.example.com --admin-email admin@example.com"
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
    --posthog-version)
      POSTHOG_VERSION="$2"
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
echo -e "${MAGENTA}${BOLD}AgencyStack PostHog Setup${NC}"
echo -e "==========================="

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

log "INFO: Starting PostHog installation for $DOMAIN" "${BLUE}Starting PostHog installation for $DOMAIN...${NC}"

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
  POSTHOG_PROJECT_NAME="${CLIENT_ID}_posthog"
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
  POSTHOG_PROJECT_NAME="posthog_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Create PostHog directories
log "INFO: Creating PostHog directories" "${CYAN}Creating PostHog directories...${NC}"
mkdir -p "${POSTHOG_DIR}/${DOMAIN}"
mkdir -p "${POSTHOG_DIR}/${DOMAIN}/data/postgres"
mkdir -p "${POSTHOG_DIR}/${DOMAIN}/data/clickhouse"
mkdir -p "${POSTHOG_DIR}/${DOMAIN}/data/zookeeper"
mkdir -p "${POSTHOG_DIR}/${DOMAIN}/logs"

# Download PostHog docker-compose.yml
log "INFO: Downloading PostHog configuration" "${CYAN}Downloading PostHog configuration...${NC}"
curl -sSL https://raw.githubusercontent.com/PostHog/posthog-docker/master/docker-compose.yml > "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml.template"

if [ $? -ne 0 ]; then
  log "ERROR: Failed to download PostHog configuration" "${RED}Failed to download PostHog configuration. See log for details.${NC}"
  exit 1
fi

# Create .env file for PostHog
log "INFO: Creating PostHog environment configuration" "${CYAN}Creating PostHog environment configuration...${NC}"
cat > "${POSTHOG_DIR}/${DOMAIN}/.env" <<EOF
# PostHog environment configuration
# Generated by AgencyStack installer on $(date +"%Y-%m-%d")

# General
POSTHOG_SECRET=${SECRET_KEY}
SITE_URL=https://${DOMAIN}
DISABLE_SECURE_SSL_REDIRECT=false
IS_BEHIND_PROXY=true

# Database
PGHOST=postgres
PGUSER=posthog
PGPASSWORD=${POSTGRES_PASSWORD}
PGDATABASE=posthog
PGPORT=5432

# Email
EMAIL_HOST=mail.${DOMAIN%.*.*}
EMAIL_PORT=25
EMAIL_HOST_USER=${ADMIN_EMAIL}
DEFAULT_FROM_EMAIL=${ADMIN_EMAIL}

# ClickHouse
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_SECURE=false
CLICKHOUSE_VERIFY=false

# Other services
KAFKA_URL=kafka://kafka:9092
REDIS_URL=redis://redis:6379

# Initial user
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

# Customize docker-compose.yml file with our settings
log "INFO: Customizing PostHog docker-compose.yml" "${CYAN}Customizing PostHog docker-compose.yml...${NC}"
sed -e "s/image: posthog\/posthog:latest/image: posthog\/posthog:${POSTHOG_VERSION}/g" \
    -e "s/\- 8000:8000/\# No direct port mapping with Traefik/g" \
    "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml.template" > "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"

# Add Traefik labels to the web service
log "INFO: Adding Traefik integration" "${CYAN}Adding Traefik integration...${NC}"
sed -i "/web:/,/depends_on:/ s/web:/web:\n    labels:\n      - \"traefik.enable=true\"\n      - \"traefik.http.routers.posthog_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)\"\n      - \"traefik.http.routers.posthog_${SITE_NAME}.entrypoints=websecure\"\n      - \"traefik.http.routers.posthog_${SITE_NAME}.tls.certresolver=myresolver\"\n      - \"traefik.http.routers.posthog_${SITE_NAME}.middlewares=secure-headers@file\"\n      - \"traefik.http.services.posthog_${SITE_NAME}.loadbalancer.server.port=8000\"\n      - \"traefik.docker.network=${NETWORK_NAME}\"/g" "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"

# Add volume path configurations
log "INFO: Customizing volume paths" "${CYAN}Customizing volume paths...${NC}"
sed -i "s|pgdata|${POSTHOG_DIR}/${DOMAIN}/data/postgres|g" "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"
sed -i "s|clickhouse-data|${POSTHOG_DIR}/${DOMAIN}/data/clickhouse|g" "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"
sed -i "s|zookeeper-datalog|${POSTHOG_DIR}/${DOMAIN}/data/zookeeper/datalog|g" "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"
sed -i "s|zookeeper-data|${POSTHOG_DIR}/${DOMAIN}/data/zookeeper/data|g" "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml"

# Add network configuration
log "INFO: Adding network configuration" "${CYAN}Adding network configuration...${NC}"
cat >> "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml" <<EOF

networks:
  default:
    external:
      name: ${NETWORK_NAME}
EOF

# Start the PostHog stack
log "INFO: Starting PostHog stack" "${CYAN}Starting PostHog stack...${NC}"
cd "${POSTHOG_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start PostHog stack" "${RED}Failed to start PostHog stack. See log for details.${NC}"
  exit 1
fi

# Wait for PostHog to start
log "INFO: Waiting for PostHog to start (this may take a few minutes)" "${YELLOW}Waiting for PostHog to start (this may take a few minutes)...${NC}"
log "INFO: Initial setup may take up to 5-10 minutes" "${YELLOW}Initial setup may take up to 5-10 minutes...${NC}"

# Check service health (this can take several minutes for initial setup)
for i in {1..30}; do
  if docker-compose -f "${POSTHOG_DIR}/${DOMAIN}/docker-compose.yml" ps | grep -q "posthog_web.*Up"; then
    log "INFO: PostHog web service is up" "${GREEN}PostHog web service is up${NC}"
    break
  fi
  log "INFO: Waiting for services to be ready... ($i/30)" "${YELLOW}Waiting for services to be ready... ($i/30)${NC}"
  sleep 10
done

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/posthog"
chmod 700 "${CONFIG_DIR}/secrets/posthog"

cat > "${CONFIG_DIR}/secrets/posthog/${DOMAIN}.env" <<EOF
# PostHog Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

POSTHOG_URL=https://${DOMAIN}/
POSTHOG_ADMIN_USER="staff_user@${DOMAIN}"
POSTHOG_ADMIN_PASSWORD=${ADMIN_PASSWORD}
POSTHOG_ADMIN_EMAIL=${ADMIN_EMAIL}

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
SECRET_KEY=${SECRET_KEY}

# Docker project
POSTHOG_PROJECT_NAME=${POSTHOG_PROJECT_NAME}
EOF

chmod 600 "${CONFIG_DIR}/secrets/posthog/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering PostHog in components registry" "${CYAN}Registering PostHog in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/posthog"
  
  cat > "${CONFIG_DIR}/components/posthog/${DOMAIN}.json" <<EOF
{
  "component": "posthog",
  "version": "${POSTHOG_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
fi

# Integrate with dashboard if available
log "INFO: Checking for dashboard integration" "${CYAN}Checking for dashboard integration...${NC}"
if [ -f "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" ]; then
  log "INFO: Updating dashboard with PostHog information" "${CYAN}Updating dashboard with PostHog information...${NC}"
  bash "${ROOT_DIR}/scripts/dashboard/update_dashboard_data.sh" "posthog" "${DOMAIN}" "active"
else
  log "INFO: Dashboard integration script not found, skipping" "${YELLOW}Dashboard integration script not found, skipping${NC}"
fi

# Update installed_components.txt
if [ -f "${CONFIG_DIR}/installed_components.txt" ]; then
  if ! grep -q "posthog|${DOMAIN}" "${CONFIG_DIR}/installed_components.txt"; then
    echo "posthog|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
    log "INFO: Updated installed components list" "${CYAN}Updated installed components list${NC}"
  fi
else
  echo "component|domain|install_date|status" > "${CONFIG_DIR}/installed_components.txt"
  echo "posthog|${DOMAIN}|$(date +"%Y-%m-%d")|active" >> "${CONFIG_DIR}/installed_components.txt"
  log "INFO: Created installed components list" "${CYAN}Created installed components list${NC}"
fi

# Final message
log "INFO: PostHog installation completed successfully" "${GREEN}${BOLD}✅ PostHog installed successfully!${NC}"
echo -e "${CYAN}PostHog URL: https://${DOMAIN}/${NC}"
echo -e "${YELLOW}Admin Email: ${ADMIN_EMAIL}${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/posthog/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Note: PostHog initial setup might still be in progress.${NC}"
echo -e "${YELLOW}If the interface is not fully available, please wait 5-10 minutes.${NC}"
echo -e "${CYAN}To complete PostHog setup, create a new project and configure your tracking.${NC}"

exit 0
