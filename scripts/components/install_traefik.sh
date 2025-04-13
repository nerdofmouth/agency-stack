#!/bin/bash
# install_traefik.sh - Installation script for traefik
#
# This script installs and configures traefik for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@proto001.alpha.nerdofmouth.com}"
HTTP_PORT=80
HTTPS_PORT=443
ENABLE_HTTPS_REDIRECT="${ENABLE_HTTPS_REDIRECT:-true}"
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/traefik.log"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
TRAEFIK_NETWORK_NAME="agency_stack"

# Parse command-line arguments
FORCE=false
WITH_DEPS=false
VERBOSE=false
DRY_RUN=false
SKIP_PORT_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
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
    --skip-port-check)
      SKIP_PORT_CHECK=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --enable-https-redirect)
      ENABLE_HTTPS_REDIRECT="$2"
      shift 2
      ;;
    --use-host-network)
      USE_HOST_NETWORK="$2"
      shift 2
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Configure log file
mkdir -p "${LOG_DIR}"
exec &> >(tee -a "${LOG_FILE}")

# Print script info
log_info "============================================="
log_info "Starting install_traefik.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "============================================="

# Check if ports 80 and 443 are available or if skip check is enabled
check_port_availability() {
  local port=$1
  local process
  
  if ! command -v lsof &> /dev/null; then
    if command -v apt-get &> /dev/null; then
      log_cmd "Installing lsof..."
      apt-get update -q
      apt-get install -y lsof
    elif command -v yum &> /dev/null; then
      log_cmd "Installing lsof..."
      yum install -y lsof
    else
      log_warning "Cannot install lsof, skipping port check"
      return 0
    fi
  fi
  
  # Check if port is in use
  if process=$(lsof -i:"$port" -t 2>/dev/null); then
    local pid=$(echo "$process" | head -n1)
    local command=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
    
    log_warning "Port $port is already in use by process $pid ($command)"
    
    if [[ "$FORCE" == "true" ]]; then
      log_warning "Force flag set, continuing despite port conflict"
      return 0
    else
      log_error "Port $port is not available. Use --force to continue anyway or --skip-port-check to bypass this check."
      log_error "Consider stopping the service using this port: sudo kill $pid"
      return 1
    fi
  else
    log_success "Port $port is available"
    return 0
  fi
}

if [[ "$SKIP_PORT_CHECK" != "true" ]]; then
  log_info "Checking if ports ${HTTP_PORT} and ${HTTPS_PORT} are available..."
  check_port_availability "${HTTP_PORT}" || exit 1
  check_port_availability "${HTTPS_PORT}" || exit 1
else
  log_info "Skipping port availability check"
fi

# Check if Traefik is already installed
if [[ -f "${INSTALL_DIR}/.installed_ok" ]] && [[ "$FORCE" != "true" ]]; then
  log_info "Traefik is already installed in ${INSTALL_DIR}"
  log_info "Use --force to reinstall"
  exit 0
fi

# Start Traefik installation
log_info "Starting traefik installation..."

# Create installation directories
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}" "${CONFIG_DIR}/dynamic" "${DATA_DIR}" "${DATA_DIR}/acme"

# Create Docker network if it doesn't exist
log_cmd "Creating Docker network ${TRAEFIK_NETWORK_NAME}..."
if ! docker network inspect "${TRAEFIK_NETWORK_NAME}" &>/dev/null; then
  docker network create "${TRAEFIK_NETWORK_NAME}"
else
  log_info "Docker network ${TRAEFIK_NETWORK_NAME} already exists"
fi

# Create Traefik configuration files
create_traefik_yml() {
  log_info "Creating Traefik configuration files..."
  
  # Create base directories
  mkdir -p "${CONFIG_DIR}/dynamic"
  mkdir -p "${DATA_DIR}/acme"
  mkdir -p "${DATA_DIR}/logs"

  # Create traefik.yml
  cat > "${CONFIG_DIR}/traefik.yml" <<EOL
# Traefik configuration for AgencyStack
# Auto-generated by install_traefik.sh

global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: INFO
  filePath: /etc/traefik/logs/traefik.log

api:
  dashboard: true
  insecure: false

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${TRAEFIK_NETWORK_NAME}"
  file:
    directory: /etc/traefik/dynamic
    watch: true

entryPoints:
  web:
    address: ":${HTTP_PORT}"
EOL

  # Add HTTP to HTTPS redirection only if requested
  if [[ "${ENABLE_HTTPS_REDIRECT}" == "true" ]]; then
    cat >> "${CONFIG_DIR}/traefik.yml" <<EOL
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
EOL
  fi

  cat >> "${CONFIG_DIR}/traefik.yml" <<EOL
  websecure:
    address: ":${HTTPS_PORT}"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: "${ADMIN_EMAIL}"
      storage: /etc/traefik/acme/acme.json
      httpChallenge:
        entryPoint: web
EOL
}

create_traefik_yml

# Create dynamic configuration
mkdir -p "${CONFIG_DIR}/dynamic"
cat > "${CONFIG_DIR}/dynamic/dashboard.yml" <<EOL
http:
  routers:
    dashboard:
      rule: "Host(\`${DOMAIN}\`) && (PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`))"
      service: "api@internal"
      entrypoints:
        - "websecure"
      middlewares:
        - "auth"
      tls: {}

  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:$$apr1$$qzOrVK3m$$uUYSj0U1NIIaQBUZFRQcn1"
EOL

# Create docker-compose.yml
log_cmd "Creating Traefik docker-compose.yml..."
log_info "Network mode: ${USE_HOST_NETWORK}"
cat > "${DOCKER_COMPOSE_FILE}" <<EOL
version: '3'

services:
  traefik:
    image: traefik:v2.9
    container_name: traefik_${CLIENT_ID}
    restart: always
    security_opt:
      - no-new-privileges:true
EOL

# Add network configuration based on the selected mode
if [[ "${USE_HOST_NETWORK}" == "true" ]]; then
  log_info "Configuring Traefik to use host network mode for improved container-to-host communication"
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    network_mode: "host"
EOL
else
  log_info "Configuring Traefik to use bridge network mode with port mapping"
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    networks:
      - ${TRAEFIK_NETWORK_NAME}
    ports:
      - "${HTTP_PORT}:${HTTP_PORT}"
      - "${HTTPS_PORT}:${HTTPS_PORT}"
EOL
fi

# Add the rest of the configuration
cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${CONFIG_DIR}/dynamic:/etc/traefik/dynamic:ro
      - ${DATA_DIR}/acme:/etc/traefik/acme
      - ${DATA_DIR}/logs:/etc/traefik/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`, \`/api\`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.tls=true"
EOL

# Add networks section if not using host network
if [[ "${USE_HOST_NETWORK}" != "true" ]]; then
  cat >> "${DOCKER_COMPOSE_FILE}" <<EOL
      
networks:
  ${TRAEFIK_NETWORK_NAME}:
    external: true
EOL
fi

# Start Traefik
log_cmd "Starting Traefik..."
if [[ "$DRY_RUN" != "true" ]]; then
  cd "${INSTALL_DIR}" && docker-compose up -d
  
  # Check if Traefik is running
  if docker ps | grep -q "traefik_${CLIENT_ID}"; then
    log_success "Traefik is running"
    
    # Create installed marker
    touch "${INSTALL_DIR}/.installed_ok"
    echo "v2.9" > "${INSTALL_DIR}/.version"
    
    # Verify port access
    log_info "Verifying port access..."
    timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/${HTTP_PORT}" &>/dev/null && log_success "HTTP port ${HTTP_PORT} is accessible" || log_warning "HTTP port ${HTTP_PORT} is not accessible"
    timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/${HTTPS_PORT}" &>/dev/null && log_success "HTTPS port ${HTTPS_PORT} is accessible" || log_warning "HTTPS port ${HTTPS_PORT} is not accessible"
    
    # Final output
    log_success "traefik installation completed successfully!"
    log_info "Traefik Dashboard: https://${DOMAIN}/dashboard/"
  else
    log_error "Traefik is not running, check logs for errors"
    exit 1
  fi
else
  log_info "DRY RUN: Would start Traefik container"
  log_success "traefik installation completed successfully (dry run)!"
fi

log_success "Script completed successfully"
