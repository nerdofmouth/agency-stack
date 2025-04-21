#!/bin/bash
# install_loki.sh - Install and configure Grafana Loki for log aggregation in AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up Loki with:
# - Persistent storage for logs
# - Integration with Grafana
# - Docker log driver configuration
# - Retention policies
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

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
LOKI_DIR="${CONFIG_DIR}/loki"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/loki.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/loki.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID=""
LOKI_VERSION="latest"
GRAFANA_DOMAIN=""
RETENTION_DAYS=30

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Loki Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures Grafana Loki for log aggregation and storage."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>           Domain for Loki (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>     Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--grafana-domain${NC} <domain>   Grafana domain for integration (optional)"
  echo -e "  ${BOLD}--retention${NC} <days>          Log retention in days (default: 30)"
  echo -e "  ${BOLD}--loki-version${NC} <version>    Loki version (default: latest)"
  echo -e "  ${BOLD}--force${NC}                     Force reinstallation even if Loki is already installed"
  echo -e "  ${BOLD}--with-deps${NC}                 Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                   Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                      Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain logs.example.com --grafana-domain grafana.example.com --retention 60"
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
    --grafana-domain)
      GRAFANA_DOMAIN="$2"
      shift
      shift
      ;;
    --retention)
      RETENTION_DAYS="$2"
      shift
      shift
      ;;
    --loki-version)
      LOKI_VERSION="$2"
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

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Loki Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Run system validation
if [ -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
  echo -e "${BLUE}Validating system requirements...${NC}"
  bash "${ROOT_DIR}/scripts/utils/validate_system.sh" || {
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
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Loki - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - Loki - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting Loki installation validation for $DOMAIN" "${BLUE}Starting Loki installation validation for $DOMAIN...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  LOKI_CONTAINER="${CLIENT_ID}_loki"
  PROMTAIL_CONTAINER="${CLIENT_ID}_promtail"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  LOKI_CONTAINER="loki_${SITE_NAME}"
  PROMTAIL_CONTAINER="promtail_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if Loki is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$LOKI_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: Loki container '$LOKI_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ Loki container '$LOKI_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing Loki containers" "${CYAN}Stopping and removing existing Loki containers...${NC}"
    cd "${LOKI_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: Loki container '$LOKI_CONTAINER' already exists" "${GREEN}✅ Loki installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$LOKI_CONTAINER"; then
      log "INFO: Loki container is running" "${GREEN}✅ Loki is running${NC}"
      echo -e "${GREEN}Loki is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: Loki container exists but is not running" "${YELLOW}⚠️ Loki container exists but is not running${NC}"
      echo -e "${YELLOW}Loki is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Loki containers...${NC}"
      cd "${LOKI_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}Loki has been started for $DOMAIN${NC}"
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
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. Loki may not be accessible without a reverse proxy.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing security infrastructure with --with-deps flag" "${CYAN}Installing security infrastructure with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" --domain "$DOMAIN" || {
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

log "INFO: Starting Loki installation for $DOMAIN" "${BLUE}Starting Loki installation for $DOMAIN...${NC}"

# Create Loki directories
log "INFO: Creating Loki directories" "${CYAN}Creating Loki directories...${NC}"
mkdir -p "${LOKI_DIR}/${DOMAIN}"
mkdir -p "${LOKI_DIR}/${DOMAIN}/loki-data"
mkdir -p "${LOKI_DIR}/${DOMAIN}/promtail-data"
mkdir -p "${LOKI_DIR}/${DOMAIN}/config"

# Create Loki config
log "INFO: Creating Loki configuration" "${CYAN}Creating Loki configuration...${NC}"
cat > "${LOKI_DIR}/${DOMAIN}/config/loki-config.yaml" <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: ${RETENTION_DAYS}d
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 6

analytics:
  reporting_enabled: false
EOF

# Create Promtail config
log "INFO: Creating Promtail configuration" "${CYAN}Creating Promtail configuration...${NC}"
cat > "${LOKI_DIR}/${DOMAIN}/config/promtail-config.yaml" <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker 
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
        filters:
          - name: label
            values: ["logging=loki"]
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'logstream'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'
  
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
  
  - job_name: agency_stack
    static_configs:
      - targets:
          - localhost
        labels:
          job: agency_stack
          __path__: /var/log/agency_stack/**/*log
EOF

# Create Docker Compose file
log "INFO: Creating Docker Compose file" "${CYAN}Creating Docker Compose file...${NC}"
cat > "${LOKI_DIR}/${DOMAIN}/docker-compose.yml" <<EOF
version: '3.7'

services:
  loki:
    image: grafana/loki:${LOKI_VERSION}
    container_name: ${LOKI_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${LOKI_DIR}/${DOMAIN}/config/loki-config.yaml:/etc/loki/local-config.yaml
      - ${LOKI_DIR}/${DOMAIN}/loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.loki_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.loki_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.loki_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.loki_${SITE_NAME}.loadbalancer.server.port=3100"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.stsPreload=true"
      - "traefik.http.middlewares.loki_${SITE_NAME}_security.headers.stsSeconds=31536000"
      - "traefik.http.routers.loki_${SITE_NAME}.middlewares=loki_${SITE_NAME}_security"
      - "logging=loki"

  promtail:
    image: grafana/promtail:${LOKI_VERSION}
    container_name: ${PROMTAIL_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${LOKI_DIR}/${DOMAIN}/config/promtail-config.yaml:/etc/promtail/config.yml
      - /var/log:/var/log
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - loki
    labels:
      - "logging=loki"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create Grafana datasource if Grafana domain is specified
if [ -n "$GRAFANA_DOMAIN" ]; then
  log "INFO: Creating Grafana datasource configuration" "${CYAN}Creating Grafana datasource configuration...${NC}"
  
  # Find Grafana provisioning directory
  GRAFANA_PROVISIONING_DIR=""
  if [ -d "${CONFIG_DIR}/grafana/${GRAFANA_DOMAIN}/provisioning" ]; then
    GRAFANA_PROVISIONING_DIR="${CONFIG_DIR}/grafana/${GRAFANA_DOMAIN}/provisioning"
  elif [ -n "$CLIENT_ID" ] && [ -d "${CONFIG_DIR}/clients/${CLIENT_ID}/grafana/provisioning" ]; then
    GRAFANA_PROVISIONING_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}/grafana/provisioning"
  fi
  
  if [ -n "$GRAFANA_PROVISIONING_DIR" ]; then
    # Create datasources directory if it doesn't exist
    mkdir -p "${GRAFANA_PROVISIONING_DIR}/datasources"
    
    # Create datasource configuration
    cat > "${GRAFANA_PROVISIONING_DIR}/datasources/loki.yaml" <<EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://${LOKI_CONTAINER}:3100
    version: 1
    editable: true
    isDefault: false
    jsonData:
      maxLines: 1000
EOF
    
    log "INFO: Created Grafana datasource configuration" "${GREEN}✅ Created Grafana datasource configuration${NC}"
    integration_log "INFO: Created Loki datasource for Grafana at ${GRAFANA_DOMAIN}"
    
    # Create default dashboard directory if it doesn't exist
    mkdir -p "${GRAFANA_PROVISIONING_DIR}/dashboards"
    
    # Create dashboard provider configuration if it doesn't exist
    if [ ! -f "${GRAFANA_PROVISIONING_DIR}/dashboards/provider.yaml" ]; then
      cat > "${GRAFANA_PROVISIONING_DIR}/dashboards/provider.yaml" <<EOF
apiVersion: 1

providers:
  - name: 'AgencyStack'
    orgId: 1
    folder: 'AgencyStack'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
EOF
    fi
    
    # Restart Grafana to pick up the new datasource
    GRAFANA_CONTAINER_NAME=""
    if [ -n "$CLIENT_ID" ]; then
      GRAFANA_CONTAINER_NAME="${CLIENT_ID}_grafana"
    else
      GRAFANA_CONTAINER_NAME="grafana_${GRAFANA_DOMAIN//./_}"
    fi
    
    if docker ps -a --format '{{.Names}}' | grep -q "$GRAFANA_CONTAINER_NAME"; then
      log "INFO: Restarting Grafana to apply datasource configuration" "${CYAN}Restarting Grafana to apply datasource configuration...${NC}"
      docker restart "$GRAFANA_CONTAINER_NAME" >> "$INSTALL_LOG" 2>&1
      integration_log "INFO: Restarted Grafana to apply Loki datasource"
    fi
  else
    log "WARNING: Grafana provisioning directory not found" "${YELLOW}⚠️ Grafana provisioning directory not found, skipping datasource creation${NC}"
    log "INFO: You will need to manually configure Loki datasource in Grafana" "${CYAN}You will need to manually configure Loki datasource in Grafana${NC}"
  fi
else
  log "INFO: Grafana domain not specified, skipping datasource creation" "${CYAN}Grafana domain not specified, skipping datasource creation${NC}"
  log "INFO: You will need to manually configure Loki datasource in Grafana" "${CYAN}You will need to manually configure Loki datasource in Grafana${NC}"
fi

# Start Loki
log "INFO: Starting Loki" "${CYAN}Starting Loki...${NC}"
cd "${LOKI_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start Loki" "${RED}Failed to start Loki. See log for details.${NC}"
  exit 1
fi

# Configure Docker daemon to use Loki log driver
log "INFO: Checking Docker log driver configuration" "${CYAN}Checking Docker log driver configuration...${NC}"

# Create /etc/docker/daemon.json if it doesn't exist
if [ ! -f "/etc/docker/daemon.json" ]; then
  log "INFO: Creating Docker daemon configuration" "${CYAN}Creating Docker daemon configuration...${NC}"
  cat > "/etc/docker/daemon.json" <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
fi

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering Loki in components registry" "${CYAN}Registering Loki in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/loki"
  
  cat > "${CONFIG_DIR}/components/loki/${DOMAIN}.json" <<EOF
{
  "component": "loki",
  "version": "${LOKI_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active",
  "retention_days": ${RETENTION_DAYS}
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
if grep -q "loki|${DOMAIN}|" "$INSTALLED_COMPONENTS_FILE"; then
  # Update the entry
  sed -i "s|loki|${DOMAIN}|.*|loki|${DOMAIN}|${LOKI_VERSION}|active|" "$INSTALLED_COMPONENTS_FILE"
else
  # Add new entry
  echo "loki|${DOMAIN}|${LOKI_VERSION}|active" >> "$INSTALLED_COMPONENTS_FILE"
fi

# Update dashboard status
if [ -f "${CONFIG_DIR}/dashboard/status.json" ]; then
  log "INFO: Updating dashboard status" "${CYAN}Updating dashboard status...${NC}"
  # This is a placeholder for dashboard status update logic
else
  log "WARNING: Dashboard status file not found" "${YELLOW}Dashboard status file not found, skipping update${NC}"
fi

# Add integration information for other components
log "INFO: Creating integration information" "${CYAN}Creating integration information...${NC}"
mkdir -p "${CONFIG_DIR}/integrations/loki"

cat > "${CONFIG_DIR}/integrations/loki/info.json" <<EOF
{
  "loki_url": "http://${LOKI_CONTAINER}:3100",
  "public_url": "https://${DOMAIN}",
  "integration_date": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "retention_days": ${RETENTION_DAYS}
}
EOF

integration_log "INFO: Created integration information at ${CONFIG_DIR}/integrations/loki/info.json"

# Final message
log "INFO: Loki installation completed successfully" "${GREEN}${BOLD}✅ Loki installed successfully!${NC}"
echo -e "${CYAN}Loki API URL: https://${DOMAIN}${NC}"
echo -e ""
echo -e "${YELLOW}Integration Information:${NC}"
echo -e "${CYAN}To send logs to Loki, containers should be labeled with:${NC}"
echo -e "${CYAN}  logging=loki${NC}"
echo -e ""
if [ -n "$GRAFANA_DOMAIN" ]; then
  echo -e "${CYAN}Loki is integrated with Grafana at https://${GRAFANA_DOMAIN}${NC}"
  echo -e "${CYAN}Log into Grafana to explore your logs${NC}"
else
  echo -e "${CYAN}To integrate with Grafana, add a Loki datasource with URL:${NC}"
  echo -e "${CYAN}  http://${LOKI_CONTAINER}:3100${NC}"
fi
echo -e ""
echo -e "${CYAN}Log retention is set to ${RETENTION_DAYS} days${NC}"

exit 0
