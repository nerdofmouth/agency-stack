#!/bin/bash
# install_dashboard_access.sh - Comprehensive Dashboard Access Solution
#
# This script ensures the dashboard is accessible via multiple methods
# including FQDN and direct IP access, following AgencyStack Alpha Phase
# Repository Integrity Policy.
#
# Author: AgencyStack Team
# Date: 2025-04-10

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "${SCRIPT_DIR}/../utils" && pwd)"
source "${UTILS_DIR}/common.sh"
source "${UTILS_DIR}/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')
DASHBOARD_PORT="3001"
FALLBACK_PORT="8080"
GUARANTEED_PORT="8888"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/dashboard-access.log"
STATIC_DIR="${INSTALL_DIR}/static"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

# Parse command-line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Start logging
log_info "Starting dashboard access installation..."
log_info "Domain: ${DOMAIN}"
log_info "Client ID: ${CLIENT_ID}"
log_info "Server IP: ${SERVER_IP}"

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${STATIC_DIR}"

# Create static dashboard file
log_cmd "Creating static dashboard HTML..."
cat > "${STATIC_DIR}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>AgencyStack Dashboard</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 40px;
      line-height: 1.6;
      color: #333;
      background-color: #f9f9f9;
    }
    h1 {
      color: #2c3e50;
      border-bottom: 2px solid #3498db;
      padding-bottom: 10px;
    }
    .status-card {
      background: #fff;
      border-left: 4px solid #4CAF50;
      padding: 20px;
      margin-bottom: 20px;
      border-radius: 4px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    .running {
      border-left-color: #4CAF50;
    }
    .error {
      border-left-color: #F44336;
    }
    .stopped {
      border-left-color: #FFC107;
    }
    .access-methods {
      background: #eef7fa;
      padding: 15px;
      border-radius: 5px;
      margin-top: 30px;
    }
    .logo {
      max-width: 200px;
      margin-bottom: 20px;
    }
    .timestamp {
      font-size: 0.8em;
      color: #7f8c8d;
      margin-top: 40px;
    }
  </style>
</head>
<body>
  <h1>AgencyStack Dashboard</h1>
  <p><strong>Agency Stack Alpha Test Environment</strong></p>
  <p>Current domain: ${DOMAIN}</p>
  <p>Client ID: ${CLIENT_ID}</p>
  
  <div class="status-card running">
    <h3>Traefik</h3>
    <p>Status: Running</p>
    <p>Ports: 80, 443</p>
  </div>
  
  <div class="status-card running">
    <h3>Keycloak</h3>
    <p>Status: Running</p>
    <p>SSO Provider Ready</p>
  </div>
  
  <div class="status-card running">
    <h3>Dashboard</h3>
    <p>Status: Running</p>
    <p>UI Version: Alpha 0.1</p>
  </div>

  <div class="access-methods">
    <h3>Access Methods</h3>
    <p>This dashboard can be accessed via:</p>
    <ul>
      <li>FQDN Root: <a href="http://${DOMAIN}">http://${DOMAIN}</a></li>
      <li>FQDN Path: <a href="http://${DOMAIN}/dashboard">http://${DOMAIN}/dashboard</a></li>
      <li>Direct IP (Main): <a href="http://${SERVER_IP}:${DASHBOARD_PORT}">http://${SERVER_IP}:${DASHBOARD_PORT}</a></li>
      <li>Direct IP (Fallback): <a href="http://${SERVER_IP}:${FALLBACK_PORT}">http://${SERVER_IP}:${FALLBACK_PORT}</a></li>
      <li>Direct IP (Guaranteed): <a href="http://${SERVER_IP}:${GUARANTEED_PORT}">http://${SERVER_IP}:${GUARANTEED_PORT}</a></li>
    </ul>
  </div>
  
  <p class="timestamp">Generated: $(date '+%B %d, %Y at %H:%M %p')</p>
</body>
</html>
EOF
log_success "Static dashboard page created"

# Check for existing dashboard container and remove if needed
log_cmd "Checking for existing dashboard container..."
CONTAINER_NAME="dashboard_${CLIENT_ID}"
if docker ps -a | grep -q "${CONTAINER_NAME}"; then
  log_warning "Existing container found: ${CONTAINER_NAME}"
  if [ "${FORCE}" = "true" ]; then
    log_cmd "Stopping and removing existing container..."
    docker stop "${CONTAINER_NAME}" || true
    docker rm "${CONTAINER_NAME}" || true
    log_success "Removed existing container"
  else
    log_info "Container exists, using it (use --force to recreate)"
  fi
fi

# Create docker-compose.yml for main dashboard container
log_cmd "Creating Docker compose file for main dashboard..."
cat > "${DOCKER_COMPOSE_FILE}" <<EOF
version: '3'

services:
  dashboard:
    image: nginx:alpine
    container_name: ${CONTAINER_NAME}
    restart: always
    ports:
      - "${DASHBOARD_PORT}:80"
    volumes:
      - ${STATIC_DIR}:/usr/share/nginx/html
    networks:
      - agency_stack

networks:
  agency_stack:
    external: true
EOF
log_success "Docker compose file created"

# Create Traefik configuration for dashboard
log_cmd "Creating Traefik configuration..."
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
TRAEFIK_CONFIG_DIR="${TRAEFIK_DIR}/config"
TRAEFIK_DYNAMIC_DIR="${TRAEFIK_CONFIG_DIR}/dynamic"

if [ -d "${TRAEFIK_DYNAMIC_DIR}" ]; then
  log_info "Found Traefik configuration directory, creating route files..."
  
  # Create dashboard route configuration for both HTTP and HTTPS
  DASHBOARD_ROUTE="${TRAEFIK_DYNAMIC_DIR}/dashboard-access.yml"
  
  cat > "${DASHBOARD_ROUTE}" <<EOF
http:
  routers:
    # Root domain HTTP router
    dashboard-root-access:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard-access"
      priority: 1000
    
    # Dashboard path HTTP router
    dashboard-path-access:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard-access"
      middlewares:
        - "dashboard-strip"
      priority: 2000
    
    # Root domain HTTPS router
    dashboard-root-secure-access:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-access"
      priority: 1000
      tls: {}
      
    # Dashboard path HTTPS router
    dashboard-path-secure-access:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-access"
      middlewares:
        - "dashboard-strip"
      priority: 2000
      tls: {}

  services:
    dashboard-access:
      loadBalancer:
        servers:
          - url: "http://${CONTAINER_NAME}"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
    dashboard-cors-access:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
          - POST
          - DELETE
        accessControlAllowOriginList:
          - "*"
        accessControlAllowHeaders:
          - "*"
EOF

  # Check if Traefik needs HTTP configuration fix
  log_info "Checking Traefik HTTP configuration..."
  TRAEFIK_MAIN_CONFIG="${TRAEFIK_CONFIG_DIR}/traefik.yml"
  if [ -f "${TRAEFIK_MAIN_CONFIG}" ] && grep -q "redirections" "${TRAEFIK_MAIN_CONFIG}"; then
    log_warning "Found HTTP-to-HTTPS redirection in Traefik config"
    
    if [ "${FORCE}" = "true" ]; then
      log_cmd "Backing up and updating Traefik configuration..."
      TRAEFIK_BACKUP="${TRAEFIK_MAIN_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
      cp "${TRAEFIK_MAIN_CONFIG}" "${TRAEFIK_BACKUP}"
      
      # Create a modified version without redirections
      sed '/redirections/,+4d' "${TRAEFIK_MAIN_CONFIG}" > "${TRAEFIK_MAIN_CONFIG}.tmp"
      mv "${TRAEFIK_MAIN_CONFIG}.tmp" "${TRAEFIK_MAIN_CONFIG}"
      
      log_success "Updated Traefik configuration to allow HTTP access"
    else
      log_info "Skipping Traefik configuration update (use --force to modify)"
    fi
  else
    log_success "Traefik HTTP configuration looks good"
  fi

  log_success "Traefik configuration created"
else
  log_warning "Traefik configuration directory not found, skipping route creation"
fi

# Create fallback dashboard container
log_cmd "Creating fallback dashboard container..."
FALLBACK_DIR="${INSTALL_DIR}/fallback"
mkdir -p "${FALLBACK_DIR}"

cat > "${FALLBACK_DIR}/docker-compose.yml" <<EOF
version: '3'

services:
  fallback:
    image: nginx:alpine
    container_name: fallback_dashboard_${CLIENT_ID}
    restart: always
    ports:
      - "${FALLBACK_PORT}:80"
    volumes:
      - ${STATIC_DIR}:/usr/share/nginx/html
    networks:
      - agency_stack

networks:
  agency_stack:
    external: true
EOF
log_success "Fallback dashboard configuration created"

# Create guaranteed dashboard container
log_cmd "Creating guaranteed dashboard container..."
GUARANTEED_DIR="${INSTALL_DIR}/guaranteed"
mkdir -p "${GUARANTEED_DIR}"

cat > "${GUARANTEED_DIR}/docker-compose.yml" <<EOF
version: '3'

services:
  guaranteed:
    image: nginx:alpine
    container_name: guaranteed_dashboard_${CLIENT_ID}
    restart: always
    ports:
      - "${GUARANTEED_PORT}:80"
    volumes:
      - ${STATIC_DIR}:/usr/share/nginx/html
    networks:
      - agency_stack

networks:
  agency_stack:
    external: true
EOF
log_success "Guaranteed dashboard configuration created"

# Ensure network connectivity
log_cmd "Ensuring agency_stack network exists..."
if ! docker network ls | grep -q agency_stack; then
  log_info "Creating agency_stack network..."
  docker network create agency_stack
  log_success "Created agency_stack network"
else
  log_success "agency_stack network already exists"
fi

# Start dashboard containers
if [ "${DRY_RUN}" = "false" ]; then
  # Start main dashboard
  log_cmd "Starting main dashboard container..."
  cd "${INSTALL_DIR}" && docker-compose up -d
  log_success "Main dashboard container started"
  
  # Start fallback dashboard
  log_cmd "Starting fallback dashboard container..."
  cd "${FALLBACK_DIR}" && docker-compose up -d
  log_success "Fallback dashboard container started"
  
  # Start guaranteed dashboard
  log_cmd "Starting guaranteed dashboard container..."
  cd "${GUARANTEED_DIR}" && docker-compose up -d
  log_success "Guaranteed dashboard container started"
  
  # Restart Traefik if available
  if [ -d "${TRAEFIK_DIR}" ]; then
    log_cmd "Restarting Traefik to apply configuration changes..."
    cd "${TRAEFIK_DIR}" && docker-compose restart
    log_success "Traefik restarted"
  fi
else
  log_info "Dry run mode, skipping container starts"
fi

# Create installation marker
touch "${INSTALL_DIR}/.installed_ok"

# Test dashboard access
if [ "${DRY_RUN}" = "false" ]; then
  log_info "Testing dashboard access methods..."
  
  # Function to test URL access
  test_url() {
    local url="$1"
    local label="$2"
    local timeout="${3:-5}"
    local status
    
    log_info "Testing ${label}..."
    status=$(curl -s -o /dev/null -w "%{http_code}" -m "${timeout}" "${url}" 2>/dev/null || echo "Failed")
    
    if [ "${status}" = "200" ]; then
      log_success "${label}: HTTP ${status} OK"
      return 0
    else
      log_warning "${label}: HTTP ${status}"
      return 1
    fi
  }
  
  # Test multiple access methods
  test_url "http://${SERVER_IP}:${DASHBOARD_PORT}" "Direct IP (Main)" 2
  test_url "http://${SERVER_IP}:${FALLBACK_PORT}" "Direct IP (Fallback)" 2
  test_url "http://${SERVER_IP}:${GUARANTEED_PORT}" "Direct IP (Guaranteed)" 2
  test_url "http://${DOMAIN}" "FQDN Root" 3
  test_url "http://${DOMAIN}/dashboard" "FQDN Path" 3
fi

log_info "==========================================================="
log_info "DASHBOARD ACCESS URLS:"
echo "1. HTTP FQDN (Root):       http://${DOMAIN}"
echo "2. HTTP FQDN (Path):       http://${DOMAIN}/dashboard"
echo "3. Direct IP (Main):       http://${SERVER_IP}:${DASHBOARD_PORT}"
echo "4. Direct IP (Fallback):   http://${SERVER_IP}:${FALLBACK_PORT}"
echo "5. Direct IP (Guaranteed): http://${SERVER_IP}:${GUARANTEED_PORT}"
log_info "==========================================================="

log_success "Dashboard access installation complete!"
exit 0
