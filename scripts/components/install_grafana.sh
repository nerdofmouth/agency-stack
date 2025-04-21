#!/bin/bash
# install_grafana.sh - Installation script for Grafana
# AgencyStack Team

set -e

# --- BEGIN: Preflight/Prerequisite Check ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$REPO_ROOT/scripts/utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# install_grafana.sh - Install and configure Grafana for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up Grafana with:
# - Default dashboards for system monitoring
# - Integration with Loki for log aggregation (if available)
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
CONFIG_DIR="/opt/agency_stack"
GRAFANA_DIR="${CONFIG_DIR}/grafana"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/grafana.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/grafana.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
GRAFANA_VERSION="latest"
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
SECRET_KEY=$(openssl rand -base64 32)

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Grafana Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures Grafana for monitoring and observability."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for Grafana (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--grafana-version${NC} <ver>   Grafana version (default: latest)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if Grafana is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain grafana.example.com --admin-email admin@example.com --client-id acme"
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
    --grafana-version)
      GRAFANA_VERSION="$2"
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
echo -e "${MAGENTA}${BOLD}AgencyStack Grafana Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Run system validation
if [ -f "${REPO_ROOT}/scripts/utils/validate_system.sh" ]; then
  echo -e "${BLUE}Validating system requirements...${NC}"
  bash "${REPO_ROOT}/scripts/utils/validate_system.sh" || {
    echo -e "${RED}System validation failed. Please fix the issues and try again.${NC}"
    exit 1
  }
else
  echo -e "${YELLOW}Warning: System validation script not found. Proceeding without validation.${NC}"
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
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Grafana - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Grafana - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting Grafana installation validation for $DOMAIN" "${BLUE}Starting Grafana installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  GRAFANA_CONTAINER="${CLIENT_ID}_grafana"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  GRAFANA_CONTAINER="grafana_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if Grafana is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$GRAFANA_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: Grafana container '$GRAFANA_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ Grafana container '$GRAFANA_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing Grafana containers" "${CYAN}Stopping and removing existing Grafana containers...${NC}"
    cd "${GRAFANA_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: Grafana container '$GRAFANA_CONTAINER' already exists" "${GREEN}✅ Grafana installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$GRAFANA_CONTAINER"; then
      log "INFO: Grafana container is running" "${GREEN}✅ Grafana is running${NC}"
      echo -e "${GREEN}Grafana is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: Grafana container exists but is not running" "${YELLOW}⚠️ Grafana container exists but is not running${NC}"
      echo -e "${YELLOW}Grafana is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Grafana containers...${NC}"
      cd "${GRAFANA_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}Grafana has been started for $DOMAIN${NC}"
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
    if [ -f "${REPO_ROOT}/scripts/core/install_infrastructure.sh" ]; then
      bash "${REPO_ROOT}/scripts/core/install_infrastructure.sh" || {
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
    if [ -f "${REPO_ROOT}/scripts/core/install_infrastructure.sh" ]; then
      bash "${REPO_ROOT}/scripts/core/install_infrastructure.sh" || {
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
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. Grafana may not be accessible without a reverse proxy.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing security infrastructure with --with-deps flag" "${CYAN}Installing security infrastructure with --with-deps flag...${NC}"
    if [ -f "${REPO_ROOT}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${REPO_ROOT}/scripts/core/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$ADMIN_EMAIL" || {
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

# Check for Loki
log "INFO: Checking for Loki" "${CYAN}Checking for Loki integration...${NC}"
if docker ps --format '{{.Names}}' | grep -q "loki"; then
  log "INFO: Loki container found, will configure integration" "${GREEN}✅ Loki found, will configure integration${NC}"
  HAS_LOKI=true
else
  log "INFO: Loki container not found, skipping integration" "${YELLOW}⚠️ Loki not found, skipping log aggregation setup${NC}"
  HAS_LOKI=false
fi

log "INFO: Starting Grafana installation for $DOMAIN" "${BLUE}Starting Grafana installation for $DOMAIN...${NC}"

# Create Grafana directories
log "INFO: Creating Grafana directories" "${CYAN}Creating Grafana directories...${NC}"
mkdir -p "${GRAFANA_DIR}/${DOMAIN}"
mkdir -p "${GRAFANA_DIR}/${DOMAIN}/data"
mkdir -p "${GRAFANA_DIR}/${DOMAIN}/provisioning/datasources"
mkdir -p "${GRAFANA_DIR}/${DOMAIN}/provisioning/dashboards"
mkdir -p "${GRAFANA_DIR}/${DOMAIN}/dashboards"

# Create Grafana configuration
log "INFO: Creating Grafana configuration" "${CYAN}Creating Grafana configuration...${NC}"
cat > "${GRAFANA_DIR}/${DOMAIN}/grafana.ini" <<EOF
[server]
domain = ${DOMAIN}
root_url = https://${DOMAIN}
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = ${ADMIN_PASSWORD}
secret_key = ${SECRET_KEY}

[users]
allow_sign_up = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[smtp]
enabled = true
host = mail.${DOMAIN/.[^.]*$/.local}:25
user = 
password = 
from_address = grafana@${DOMAIN}
from_name = Grafana

[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/home.json
EOF

# Create Docker Compose file
log "INFO: Creating Docker Compose file" "${CYAN}Creating Docker Compose file...${NC}"
cat > "${GRAFANA_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  grafana:
    image: grafana/grafana:${GRAFANA_VERSION}
    container_name: ${GRAFANA_CONTAINER}
    restart: unless-stopped
    user: "472"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_DOMAIN=${DOMAIN}
      - GF_SERVER_ROOT_URL=https://${DOMAIN}
    volumes:
      - ${GRAFANA_DIR}/${DOMAIN}/data:/var/lib/grafana
      - ${GRAFANA_DIR}/${DOMAIN}/grafana.ini:/etc/grafana/grafana.ini
      - ${GRAFANA_DIR}/${DOMAIN}/provisioning:/etc/grafana/provisioning
      - ${GRAFANA_DIR}/${DOMAIN}/dashboards:/var/lib/grafana/dashboards
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.grafana_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.grafana_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.grafana_${SITE_NAME}.loadbalancer.server.port=3000"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.stsPreload=true"
      - "traefik.http.middlewares.grafana_${SITE_NAME}_security.headers.stsSeconds=31536000"
      - "traefik.http.routers.grafana_${SITE_NAME}.middlewares=grafana_${SITE_NAME}_security"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create default datasource provisioning
log "INFO: Creating default datasource provisioning" "${CYAN}Creating default datasource provisioning...${NC}"

# Configure Loki datasource if available
if [ "$HAS_LOKI" = true ]; then
  cat > "${GRAFANA_DIR}/${DOMAIN}/provisioning/datasources/loki.yaml" <<EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    version: 1
EOF
  integration_log "INFO: Configured Loki datasource" 
fi

# Create dashboard provisioning
log "INFO: Creating dashboard provisioning" "${CYAN}Creating dashboard provisioning...${NC}"
cat > "${GRAFANA_DIR}/${DOMAIN}/provisioning/dashboards/default.yaml" <<EOF
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
EOF

# Create default home dashboard
log "INFO: Creating default home dashboard" "${CYAN}Creating default home dashboard...${NC}"
cat > "${GRAFANA_DIR}/${DOMAIN}/dashboards/home.json" <<EOF
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.5.3",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Welcome to AgencyStack Monitoring",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "datasource": null,
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 9
      },
      "id": 4,
      "options": {
        "content": "# Welcome to AgencyStack Monitoring\n\nThis is your Grafana instance, which will provide monitoring and observability for your AgencyStack installation.\n\n## Getting Started\n\n1. Add your system metrics using Prometheus, Loki, or other data sources\n2. Import dashboards for your specific components\n3. Set up alerts for critical conditions\n\n## Documentation\n\nFor more information, visit [Grafana Documentation](https://grafana.com/docs/)",
        "mode": "markdown"
      },
      "pluginVersion": "7.5.3",
      "title": "Documentation",
      "type": "text"
    }
  ],
  "schemaVersion": 27,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Home",
  "uid": "home",
  "version": 1
}
EOF

# Start Grafana
log "INFO: Starting Grafana" "${CYAN}Starting Grafana...${NC}"
cd "${GRAFANA_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start Grafana" "${RED}Failed to start Grafana. See log for details.${NC}"
  exit 1
fi

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/grafana"
chmod 700 "${CONFIG_DIR}/secrets/grafana"

cat > "${CONFIG_DIR}/secrets/grafana/${DOMAIN}.env" <<EOF
# Grafana Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${ADMIN_PASSWORD}
GRAFANA_ADMIN_EMAIL=${ADMIN_EMAIL}
GRAFANA_SECRET_KEY=${SECRET_KEY}

# Docker project
GRAFANA_CONTAINER=${GRAFANA_CONTAINER}
EOF

chmod 600 "${CONFIG_DIR}/secrets/grafana/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering Grafana in components registry" "${CYAN}Registering Grafana in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/grafana"
  
  cat > "${CONFIG_DIR}/components/grafana/${DOMAIN}.json" <<EOF
{
  "component": "grafana",
  "version": "${GRAFANA_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
else
  log "WARNING: Components registry not found" "${YELLOW}Components registry not found, skipping registration${NC}"
fi

# Add to installed_components.txt
INSTALLED_COMPONENTS_FILE="${CONFIG_DIR}/installed_components.txt"
log "INFO: Adding to installed components" "${CYAN}Adding to installed components...${NC}"

# Create file if it doesn't exist
if [ ! -f "$INSTALLED_COMPONENTS_FILE" ]; then
  echo "component|domain|version|status" > "$INSTALLED_COMPONENTS_FILE"
fi

# Check if component is already in the file
if grep -q "grafana|${DOMAIN}|" "$INSTALLED_COMPONENTS_FILE"; then
  # Update the entry
  sed -i "s|grafana|${DOMAIN}|.*|grafana|${DOMAIN}|${GRAFANA_VERSION}|active|" "$INSTALLED_COMPONENTS_FILE"
else
  # Add new entry
  echo "grafana|${DOMAIN}|${GRAFANA_VERSION}|active" >> "$INSTALLED_COMPONENTS_FILE"
fi

# Update dashboard status
if [ -f "${CONFIG_DIR}/dashboard/status.json" ]; then
  log "INFO: Updating dashboard status" "${CYAN}Updating dashboard status...${NC}"
  # This is a placeholder for dashboard status update logic
  # In a real implementation, this would modify the dashboard status JSON
  # to include information about the Grafana installation
else
  log "WARNING: Dashboard status file not found" "${YELLOW}Dashboard status file not found, skipping update${NC}"
fi

# Final message
log "INFO: Grafana installation completed successfully" "${GREEN}${BOLD}✅ Grafana installed successfully!${NC}"
echo -e "${CYAN}Grafana URL: https://${DOMAIN}${NC}"
echo -e "${YELLOW}Admin Username: admin${NC}"
echo -e "${YELLOW}Admin Password: ${ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/grafana/${DOMAIN}.env${NC}"

# Check for Loki integration
if [ "$HAS_LOKI" = true ]; then
  echo -e "${GREEN}✅ Loki integration configured for log aggregation${NC}"
else
  echo -e "${YELLOW}⚠️ Loki not installed. For complete monitoring, install Loki with:${NC}"
  echo -e "${CYAN}   make install-loki DOMAIN=loki.${DOMAIN}${NC}"
fi

exit 0
