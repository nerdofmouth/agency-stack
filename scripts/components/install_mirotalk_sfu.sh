#!/bin/bash
# install_mirotalk_sfu.sh - Install and configure MiroTalk SFU for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up MiroTalk SFU with:
# - Docker containerization
# - Traefik integration with TLS
# - Multi-tenant awareness
# - AgencyStack dashboard integration
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

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Variables
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
MIROTALK_DIR="${CONFIG_DIR}/mirotalk_sfu"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/mirotalk_sfu.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
ENABLE_CLOUD=false
DOMAIN=""
CLIENT_ID=""
ADMIN_EMAIL=""
TURN_SECRET=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
MIROTALK_VERSION="latest"
MIROTALK_REPO="https://github.com/miroslavpejic85/mirotalk"
ENABLE_METRICS=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack MiroTalk SFU Setup${NC}"
  echo -e "=================================="
  echo -e "This script installs and configures MiroTalk SFU video conferencing platform with:"
  echo -e "  - Docker containerization"
  echo -e "  - Traefik integration with TLS"
  echo -e "  - Multi-tenant awareness"
  echo -e "  - AgencyStack dashboard integration"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>         Primary domain for MiroTalk SFU (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>   Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--admin-email${NC} <email>     Admin email address (required)"
  echo -e "  ${BOLD}--version${NC} <version>       MiroTalk SFU version (default: latest)"
  echo -e "  ${BOLD}--force${NC}                   Force reinstallation even if MiroTalk SFU is already installed"
  echo -e "  ${BOLD}--with-deps${NC}               Automatically install dependencies if missing"
  echo -e "  ${BOLD}--enable-cloud${NC}            Enable cloud dependencies (optional)"
  echo -e "  ${BOLD}--enable-metrics${NC}          Enable Prometheus metrics (optional)"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain video.example.com --admin-email admin@example.com --client-id acme"
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
    --version)
      MIROTALK_VERSION="$2"
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
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-metrics)
      ENABLE_METRICS=true
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
      log_error "Unknown option: $key"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  log_error "--domain is required"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
  log_error "--admin-email is required"
  echo -e "Use --help for usage information"
  exit 1
fi

# Welcome message
log_info "Starting MiroTalk SFU installation for ${DOMAIN}" "${BLUE}Starting MiroTalk SFU installation for ${DOMAIN}...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root or with sudo"
  exit 1
fi

# Create log directories if they don't exist
mkdir -p "${LOG_DIR}"
mkdir -p "${COMPONENTS_LOG_DIR}"
touch "${INSTALL_LOG}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  INSTALL_DIR="${CLIENT_DIR}/mirotalk_sfu/${DOMAIN}"
  MIROTALK_CONTAINER="${CLIENT_ID}_mirotalk_sfu"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  CLIENT_DIR="${CONFIG_DIR}"
  INSTALL_DIR="${CONFIG_DIR}/mirotalk_sfu/${DOMAIN}"
  MIROTALK_CONTAINER="mirotalk_sfu_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if MiroTalk SFU is already installed
if docker ps -a --format '{{.Names}}' | grep -q "${MIROTALK_CONTAINER}"; then
  if [ "$FORCE" = true ]; then
    log_warning "MiroTalk SFU container '${MIROTALK_CONTAINER}' already exists, will reinstall because --force was specified"
    
    # Stop and remove existing containers
    log_info "Stopping and removing existing MiroTalk SFU containers"
    cd "${INSTALL_DIR}" && docker-compose down 2>/dev/null || true
  else
    log_info "MiroTalk SFU container '${MIROTALK_CONTAINER}' already exists"
    log_info "To reinstall, use --force flag"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "${MIROTALK_CONTAINER}"; then
      log_success "MiroTalk SFU is running"
      echo -e "${GREEN}MiroTalk SFU is already installed and running for ${DOMAIN}${NC}"
      echo -e "${CYAN}URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log_warning "MiroTalk SFU container exists but is not running"
      echo -e "${YELLOW}MiroTalk SFU is installed but not running for ${DOMAIN}${NC}"
      echo -e "${CYAN}Starting MiroTalk SFU containers...${NC}"
      cd "${INSTALL_DIR}" && docker-compose up -d
      log_success "MiroTalk SFU has been started for ${DOMAIN}"
      echo -e "${GREEN}MiroTalk SFU has been started for ${DOMAIN}${NC}"
      echo -e "${CYAN}URL: https://${DOMAIN}${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log_error "Docker is not installed"
  
  if [ "$WITH_DEPS" = true ]; then
    log_info "Installing Docker with --with-deps flag"
    
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log_error "Failed to install Docker"
        exit 1
      }
    else
      log_error "Cannot find install_infrastructure.sh script"
      exit 1
    fi
  else
    log_info "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  log_error "Docker is not running"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log_error "Docker Compose is not installed"
  
  if [ "$WITH_DEPS" = true ]; then
    log_info "Installing Docker Compose with --with-deps flag"
    
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log_error "Failed to install Docker Compose"
        exit 1
      }
    else
      log_error "Cannot find install_infrastructure.sh script"
      exit 1
    fi
  else
    log_info "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if network exists, create if it doesn't
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log_info "Creating Docker network $NETWORK_NAME"
  docker network create "$NETWORK_NAME" >> "$INSTALL_LOG" 2>&1
  
  if [ $? -ne 0 ]; then
    log_error "Failed to create Docker network $NETWORK_NAME"
    exit 1
  fi
else
  log_success "Docker network $NETWORK_NAME already exists"
fi

# Check for Traefik
if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
  log_warning "Traefik container not found. MiroTalk SFU may not be accessible without a reverse proxy."
  
  if [ "$WITH_DEPS" = true ]; then
    log_info "Installing security infrastructure with --with-deps flag"
    
    if [ -f "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$ADMIN_EMAIL" || {
        log_error "Failed to install security infrastructure"
      }
    else
      log_error "Cannot find install_security_infrastructure.sh script"
    fi
  else
    log_info "Use --with-deps to automatically install dependencies"
  fi
else
  log_success "Traefik container found"
fi

log_info "Starting MiroTalk SFU installation for $DOMAIN"

# Create MiroTalk SFU directories
log_info "Creating MiroTalk SFU directories"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/config"
mkdir -p "${INSTALL_DIR}/data"
mkdir -p "${INSTALL_DIR}/logs"

# Generate config file
log_info "Generating MiroTalk SFU configuration"

# Create .env file
cat > "${INSTALL_DIR}/.env" <<EOF
# MiroTalk SFU Settings
MEDIASOUP_LISTEN_IP=0.0.0.0
MEDIASOUP_ANNOUNCED_IP=
NODE_ENV=production
SERVER_PORT=3000
PROTOCOL=https
HTTPS=true
CORS_ALLOW_ORIGIN=*
API_KEY_SECRET=${TURN_SECRET}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${TURN_SECRET}
WEBRTC_STATS_ENABLED=true
WEBRTC_STATS_INTERVAL_MS=10000
UI_OFF=false
TRUSTING_TURN_ON=false
TURN_ENABLED=false
$(if [ "$ENABLE_CLOUD" = true ]; then
echo "TURN_URLS=turn:numb.viagenie.ca
TURN_USERNAME=webrtc@live.com
TURN_PASSWORD=muazkh"
else
echo "TURN_URLS=turn:localhost:3478?transport=tcp
TURN_USERNAME=mirotalk
TURN_PASSWORD=${TURN_SECRET}"
fi)
RECORDING_ENABLED=false
$(if [ "$ENABLE_METRICS" = true ]; then
echo "PROMETHEUS_ENABLED=true
PROMETHEUS_PORT=3001
PROMETHEUS_AUTH_TOKEN=${TURN_SECRET}"
fi)
EOF

# Create Docker Compose file
log_info "Creating MiroTalk SFU Docker Compose file"
cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
  mirotalk-sfu:
    image: mirotalk/sfu:${MIROTALK_VERSION}
    container_name: ${MIROTALK_CONTAINER}
    restart: unless-stopped
    env_file: .env
    volumes:
      - ${INSTALL_DIR}/data:/app/data
      - ${INSTALL_DIR}/logs:/app/logs
      - ${INSTALL_DIR}/config:/app/config
    networks:
      - ${NETWORK_NAME}
    ports:
      - 0.0.0.0:3000:3000
      $(if [ "$ENABLE_METRICS" = true ]; then echo "      - 0.0.0.0:3001:3001"; fi)
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SITE_NAME}-mirotalk.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${SITE_NAME}-mirotalk.entrypoints=websecure"
      - "traefik.http.routers.${SITE_NAME}-mirotalk.tls=true"
      - "traefik.http.routers.${SITE_NAME}-mirotalk.tls.certresolver=agency-stack-resolver"
      - "traefik.http.services.${SITE_NAME}-mirotalk.loadbalancer.server.port=3000"
      - "traefik.docker.network=${NETWORK_NAME}"
      - "agency_stack.component=mirotalk_sfu"
      - "agency_stack.category=communications"
      - "agency_stack.description=MiroTalk SFU - Secure video conferencing"
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 5
        window: 60s

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Start the MiroTalk SFU stack
log_info "Starting MiroTalk SFU stack"
cd "${INSTALL_DIR}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log_error "Failed to start MiroTalk SFU stack"
  exit 1
fi

log_info "Waiting for MiroTalk SFU container to initialize"
sleep 10

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "${MIROTALK_CONTAINER}"; then
  log_error "MiroTalk SFU container failed to start"
  docker logs "${MIROTALK_CONTAINER}" >> "${INSTALL_LOG}" 2>&1
  exit 1
fi

# Store credentials in a secure location
log_info "Storing credentials"
mkdir -p "${CONFIG_DIR}/secrets/mirotalk_sfu"
chmod 700 "${CONFIG_DIR}/secrets/mirotalk_sfu"

cat > "${CONFIG_DIR}/secrets/mirotalk_sfu/${DOMAIN}.env" <<EOF
# MiroTalk SFU Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

MIROTALK_URL=https://${DOMAIN}/
MIROTALK_ADMIN_EMAIL=${ADMIN_EMAIL}
MIROTALK_ADMIN_PASSWORD=${TURN_SECRET}
MIROTALK_API_KEY_SECRET=${TURN_SECRET}

# Docker project
MIROTALK_CONTAINER=${MIROTALK_CONTAINER}
EOF

chmod 600 "${CONFIG_DIR}/secrets/mirotalk_sfu/${DOMAIN}.env"

# Register the installation in component registry
log_info "Registering MiroTalk SFU in component registry"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"

if [ -f "$REGISTRY_FILE" ]; then
  # Extract the components array from the registry
  components=$(jq '.components' "$REGISTRY_FILE")
  
  # Check if mirotalk_sfu component exists
  if echo "$components" | jq -e '.[] | select(.name == "mirotalk_sfu")' > /dev/null; then
    # Update the existing component
    jq --arg domain "$DOMAIN" \
       --arg version "$MIROTALK_VERSION" \
       --arg client_id "$CLIENT_ID" \
       --arg metrics "$([ "$ENABLE_METRICS" = true ] && echo "true" || echo "false")" \
       '.components = (.components | map(if .name == "mirotalk_sfu" then 
         .flags.installed = true | 
         .flags.monitoring = ($metrics == "true") | 
         .flags.multi_tenant = true |
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
       --arg version "$MIROTALK_VERSION" \
       --arg client_id "$CLIENT_ID" \
       --arg metrics "$([ "$ENABLE_METRICS" = true ] && echo "true" || echo "false")" \
       '.components += [{
         "name": "mirotalk_sfu",
         "category": "communications",
         "description": "Self-hosted video conferencing (SFU) for privacy-respecting collaboration.",
         "flags": {
           "installed": true,
           "makefile": true,
           "docs": true,
           "hardened": true,
           "monitoring": ($metrics == "true"),
           "multi_tenant": true,
           "sso": false
         },
         "ports": [3000, 3001],
         "metadata": {
           "version": $version,
           "domains": [$domain],
           "client_ids": [$client_id]
         }
       }]' "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
  fi
  
  # Replace the registry file with the updated version
  mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
  chmod 644 "$REGISTRY_FILE"
  
  log_success "Updated component registry"
else
  log_warning "Component registry file not found at ${REGISTRY_FILE}"
  
  # Create directory if it doesn't exist
  mkdir -p "${CONFIG_DIR}/registry"
  
  # Create a new registry file
  cat > "$REGISTRY_FILE" <<EOF
{
  "components": [
    {
      "name": "mirotalk_sfu",
      "category": "communications",
      "description": "Self-hosted video conferencing (SFU) for privacy-respecting collaboration.",
      "flags": {
        "installed": true,
        "makefile": true,
        "docs": true,
        "hardened": true,
        "monitoring": $([ "$ENABLE_METRICS" = true ] && echo "true" || echo "false"),
        "multi_tenant": true,
        "sso": false
      },
      "ports": [3000, 3001],
      "metadata": {
        "version": "${MIROTALK_VERSION}",
        "domains": ["${DOMAIN}"],
        "client_ids": ["${CLIENT_ID}"]
      }
    }
  ]
}
EOF
  
  chmod 644 "$REGISTRY_FILE"
  log_success "Created new component registry"
fi

# Register in the dashboard if available
DASHBOARD_DATA="${CONFIG_DIR}/dashboard/data/dashboard_data.json"
if [ -f "$DASHBOARD_DATA" ]; then
  log_info "Recording installation in dashboard data"
  
  jq --arg domain "$DOMAIN" \
     --arg client_id "$CLIENT_ID" \
     --arg version "$MIROTALK_VERSION" \
     --arg date "$(date +"%Y-%m-%d %H:%M:%S")" \
     '.video_conferencing = {
       "installed": true,
       "type": "mirotalk_sfu",
       "domain": $domain,
       "client_id": $client_id,
       "version": $version,
       "installed_at": $date
     }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp"
  
  mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  chmod 644 "$DASHBOARD_DATA"
  
  log_success "Updated dashboard data"
fi

# Configure Prometheus metrics if enabled
if [ "$ENABLE_METRICS" = true ] && [ -d "/opt/agency_stack/prometheus" ]; then
  log_info "Setting up Prometheus metrics integration"

  # Add MiroTalk SFU to Prometheus targets
  if [ -f "/opt/agency_stack/prometheus/prometheus.yml" ]; then
    log_info "Adding MiroTalk SFU to Prometheus targets"
    TEMP_FILE=$(mktemp)
    sed "/static_configs:/a\\
    - targets: ['${DOMAIN}:3001']\\
      labels:\\
        instance: 'mirotalk-${DOMAIN}'\\
        service: 'mirotalk_sfu'
" "/opt/agency_stack/prometheus/prometheus.yml" > "$TEMP_FILE"
    cp "$TEMP_FILE" "/opt/agency_stack/prometheus/prometheus.yml"
    rm "$TEMP_FILE"
    
    # Reload Prometheus if running
    if docker ps --format '{{.Names}}' | grep -q "prometheus"; then
      log_info "Reloading Prometheus configuration"
      docker exec prometheus curl -X POST http://localhost:9090/-/reload
    fi
  fi
fi

# Final message
log_success "MiroTalk SFU installation completed successfully"
echo -e "${CYAN}MiroTalk SFU URL: https://${DOMAIN}${NC}"
echo -e "${YELLOW}Admin Email: ${ADMIN_EMAIL}${NC}"
echo -e "${YELLOW}Admin Password: ${TURN_SECRET}${NC}"
echo -e "${YELLOW}IMPORTANT: Save these credentials securely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/mirotalk_sfu/${DOMAIN}.env${NC}"
echo -e ""
if [ "$ENABLE_METRICS" = true ]; then
  echo -e "${CYAN}Metrics URL: https://${DOMAIN}:3001/metrics${NC}"
  echo -e "${YELLOW}Metrics Auth Token: ${TURN_SECRET}${NC}"
  echo -e ""
fi
echo -e "${YELLOW}Note: Initial MiroTalk SFU setup may still be in progress.${NC}"
echo -e "${YELLOW}If you encounter any issues, wait a few minutes and try again.${NC}"
echo -e "${YELLOW}For more information, see: /docs/pages/components/mirotalk_sfu.md${NC}"

exit 0
