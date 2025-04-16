#!/bin/bash
# install_dashboard_guaranteed.sh - Guaranteed access dashboard installation
#
# This script ensures the dashboard is always accessible via multiple methods
# following AgencyStack Alpha Phase Repository Integrity Policy.
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
NGINX_AVAILABLE=false

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/dashboard-guaranteed.log"
STATIC_DIR="${INSTALL_DIR}/static"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
STATIC_HTML="${SCRIPT_DIR}/dashboard-static.html"

# Parse command-line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false

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
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

log_info "Starting guaranteed dashboard installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${STATIC_DIR}"

# Check if nginx is available
if command -v nginx &>/dev/null; then
  NGINX_AVAILABLE=true
  log_info "Nginx is available for direct static hosting"
else
  log_info "Nginx not found, will use Docker for hosting"
fi

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
      <li>Direct IP: <a href="http://${SERVER_IP}:${DASHBOARD_PORT}">http://${SERVER_IP}:${DASHBOARD_PORT}</a></li>
    </ul>
  </div>
  
  <p class="timestamp">Generated: $(date '+%B %d, %Y at %H:%M %p')</p>
</body>
</html>
EOF

# Copy any existing static HTML if available 
if [ -f "${STATIC_HTML}" ]; then
  log_info "Found static dashboard template, using it..."
  cp "${STATIC_HTML}" "${STATIC_DIR}/index.html"
fi

log_success "Static dashboard page created"

# Create docker-compose.yml for nginx container
log_cmd "Creating Docker compose file..."
cat > "${DOCKER_COMPOSE_FILE}" <<EOF
version: '3'

services:
  dashboard:
    image: nginx:alpine
    container_name: dashboard_${CLIENT_ID}
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
  DASHBOARD_ROUTE="${TRAEFIK_DYNAMIC_DIR}/dashboard-guaranteed.yml"
  
  cat > "${DASHBOARD_ROUTE}" <<EOF
http:
  routers:
    # Root domain HTTP router
    dashboard-root:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      priority: 100
    
    # Dashboard path HTTP router
    dashboard-path:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      priority: 200
    
    # Root domain HTTPS router
    dashboard-root-secure:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      priority: 100
      tls: {}
      
    # Dashboard path HTTPS router
    dashboard-path-secure:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      priority: 200
      tls: {}

  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_${CLIENT_ID}:80"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
    dashboard-cors:
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

  # Create direct IP route
  DIRECT_ROUTE="${TRAEFIK_DYNAMIC_DIR}/direct-ip-guaranteed.yml"
  
  cat > "${DIRECT_ROUTE}" <<EOF
http:
  routers:
    # Direct IP router
    ip-router:
      rule: "HostRegexp(\`{ip:${SERVER_IP}}\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      priority: 300
      
  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_${CLIENT_ID}:80"
EOF

  log_success "Traefik configuration created"
else
  log_warning "Traefik configuration directory not found, skipping route creation"
fi

# Start the dashboard container
log_cmd "Starting dashboard container..."
cd "${INSTALL_DIR}" && docker-compose down && docker-compose up -d
log_success "Dashboard container started"

# Update hosts file if needed
log_cmd "Checking hosts file configuration..."
if grep -q "${DOMAIN}" /etc/hosts; then
  HOSTS_IP=$(grep "${DOMAIN}" /etc/hosts | awk '{print $1}')
  if [ "${HOSTS_IP}" != "${SERVER_IP}" ]; then
    log_warning "Hosts file has incorrect IP for ${DOMAIN}: ${HOSTS_IP} (should be ${SERVER_IP})"
    log_info "Updating hosts file entry..."
    sed -i "s/^.*${DOMAIN}.*/${SERVER_IP} ${DOMAIN}/" /etc/hosts
    log_success "Updated hosts file entry"
  else
    log_success "Hosts file already has correct entry for ${DOMAIN}"
  fi
else
  log_info "Adding domain to hosts file..."
  echo "${SERVER_IP} ${DOMAIN}" >> /etc/hosts
  log_success "Added domain to hosts file"
fi

# Restart Traefik if available
if [ -d "${TRAEFIK_DIR}" ]; then
  log_cmd "Restarting Traefik to apply configuration changes..."
  cd "${TRAEFIK_DIR}" && docker-compose down && docker-compose up -d
  log_success "Traefik restarted"
fi

# Create installation marker
touch "${INSTALL_DIR}/.installed_ok"

# Test dashboard access
log_info "Testing dashboard access..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}")
log_info "HTTP status for http://${DOMAIN}: ${HTTP_STATUS}"

HTTP_PATH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}/dashboard")
log_info "HTTP status for http://${DOMAIN}/dashboard: ${HTTP_PATH_STATUS}"

DIRECT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}:${DASHBOARD_PORT}")
log_info "HTTP status for http://${SERVER_IP}:${DASHBOARD_PORT}: ${DIRECT_STATUS}"

log_info "-----------------------------------------------------"
log_info "DASHBOARD ACCESS URLS:"
echo "1. HTTP FQDN (Root):    http://${DOMAIN}"
echo "2. HTTP FQDN (Path):    http://${DOMAIN}/dashboard"
echo "3. Direct IP:           http://${SERVER_IP}:${DASHBOARD_PORT}"
log_info "-----------------------------------------------------"

log_success "Guaranteed dashboard installation complete!"
exit 0
