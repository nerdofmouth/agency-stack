#!/bin/bash
# fix_traefik_network_mode.sh - Properly configure Traefik docker network mode
# Following the AgencyStack Alpha Phase Repository Integrity Policy
# This script updates the Docker Compose configuration to properly use host network mode

set -e

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "${SCRIPT_DIR}/../utils" && pwd)"
if [[ -f "${UTILS_DIR}/common.sh" ]]; then
  source "${UTILS_DIR}/common.sh"
fi

# Fallback logging functions if common.sh is not available
if ! command -v log_info &> /dev/null; then
  log_info() { echo "[INFO] $1"; }
  log_error() { echo "[ERROR] $1" >&2; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1" >&2; }
fi

# Default values
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
DASHBOARD_PORT="3001"
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"
DASHBOARD_FIX="${DASHBOARD_FIX:-true}"
FORCE_RECREATE="${FORCE_RECREATE:-true}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --dashboard-port)
      DASHBOARD_PORT="$2"
      shift 2
      ;;
    --use-host-network)
      USE_HOST_NETWORK="$2"
      shift 2
      ;;
    --dashboard-fix)
      DASHBOARD_FIX="$2"
      shift 2
      ;;
    --force-recreate)
      FORCE_RECREATE="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id CLIENT_ID       Client ID (default: default)"
      echo "  --dashboard-port PORT       Dashboard port (default: 3001)"
      echo "  --use-host-network BOOL     Use host network mode (default: true)"
      echo "  --dashboard-fix BOOL        Fix dashboard routes (default: true)"
      echo "  --force-recreate BOOL       Force recreation of containers (default: true)"
      echo "  --help                      Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if Traefik directory exists
if [[ ! -d "${TRAEFIK_DIR}" ]]; then
  log_error "Traefik directory not found at ${TRAEFIK_DIR}"
  exit 1
fi

# Backup docker-compose.yml
DOCKER_COMPOSE_FILE="${TRAEFIK_DIR}/docker-compose.yml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

log_info "Creating backup of docker-compose.yml"
cp "${DOCKER_COMPOSE_FILE}" "${DOCKER_COMPOSE_FILE}${BACKUP_SUFFIX}"

# Get host machine IP visible to Docker containers
HOST_IP=$(hostname -I | awk '{print $1}')
log_info "Host IP: ${HOST_IP}"

# Create a new docker-compose.yml with appropriate network settings
log_info "Creating new docker-compose.yml with appropriate network configuration"

# Create the updated docker-compose.yml
cat > "${DOCKER_COMPOSE_FILE}" <<EOL
version: '3'

services:
  traefik:
    image: traefik:v2.9
    container_name: traefik_default
    restart: always
    security_opt:
      - no-new-privileges:true
EOL

# Add network configuration based on the selected mode
if [[ "${USE_HOST_NETWORK}" == "true" ]]; then
  log_info "Configuring Traefik to use host network mode"
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    network_mode: "host"
EOL
else
  log_info "Configuring Traefik to use bridge network mode with port mapping"
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    networks:
      - agency_stack
    ports:
      - "80:80"
      - "443:443"
EOL
fi

# Add the rest of the configuration
cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/agency_stack/clients/${CLIENT_ID}/traefik/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - /opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic:/etc/traefik/dynamic:ro
      - /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/acme:/etc/traefik/acme
      - /opt/agency_stack/clients/${CLIENT_ID}/traefik/data/logs:/etc/traefik/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(\`proto001.alpha.nerdofmouth.com\`) && PathPrefix(\`/dashboard\`, \`/api\`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.tls=true"
EOL

# Add networks section if not using host network
if [[ "${USE_HOST_NETWORK}" != "true" ]]; then
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL

networks:
  agency_stack:
    external: true
EOL
fi

# Fix dashboard route configuration if requested
if [[ "${DASHBOARD_FIX}" == "true" ]]; then
  DASHBOARD_ROUTE="${TRAEFIK_DIR}/config/dynamic/dashboard-route.yml"
  
  if [[ -f "${DASHBOARD_ROUTE}" ]]; then
    log_info "Creating backup of dashboard route configuration"
    cp "${DASHBOARD_ROUTE}" "${DASHBOARD_ROUTE}${BACKUP_SUFFIX}"
    
    # Update the dashboard route based on network mode
    if [[ "${USE_HOST_NETWORK}" == "true" ]]; then
      log_info "Updating dashboard route for host network mode"
      sed -i "s|http://[0-9.]\+:${DASHBOARD_PORT}|http://localhost:${DASHBOARD_PORT}|g" "${DASHBOARD_ROUTE}"
    else
      log_info "Updating dashboard route for bridge network mode"
      sed -i "s|http://localhost:${DASHBOARD_PORT}|http://${HOST_IP}:${DASHBOARD_PORT}|g" "${DASHBOARD_ROUTE}"
    fi
  else
    log_warning "Dashboard route configuration not found at ${DASHBOARD_ROUTE}"
  fi
fi

# Restart Traefik with the new configuration
log_info "Restarting Traefik with the new network configuration"
cd "${TRAEFIK_DIR}"

if [[ "${FORCE_RECREATE}" == "true" ]]; then
  log_info "Forcing recreation of Traefik container"
  docker-compose down
  docker-compose up -d
else
  docker-compose restart
fi

log_success "Traefik network configuration updated successfully"
log_info "To restore the original configuration, use: ${DOCKER_COMPOSE_FILE}${BACKUP_SUFFIX}"

# Verify dashboard accessibility
log_info "Waiting for Traefik to start up..."
sleep 5

# Test if dashboard is accessible
log_info "Testing dashboard access..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost" | grep -q "2[0-9][0-9]\|3[0-9][0-9]"; then
  log_success "Dashboard is accessible through Traefik!"
else
  log_warning "Dashboard may not be accessible yet. Please check manually:"
  log_info "  - http://proto001.alpha.nerdofmouth.com"
  log_info "  - http://proto001.alpha.nerdofmouth.com/dashboard"
  log_info "  - http://localhost:3001 (direct access)"
fi
