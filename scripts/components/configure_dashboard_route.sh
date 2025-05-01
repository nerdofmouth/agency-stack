#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: configure_dashboard_route.sh
# Path: /scripts/components/configure_dashboard_route.sh
#
set -e

# Source common utilities
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT="3001"  # Updated to match install_dashboard.sh port
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"  # Default to host network mode for better compatibility
ENABLE_KEYCLOAK="${ENABLE_KEYCLOAK:-false}"
ENFORCE_HTTPS="${ENFORCE_HTTPS:-false}"

# Process command line arguments
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
    --use-host-network)
      USE_HOST_NETWORK="$2"
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
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log_info "Starting configure_dashboard_route.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "NETWORK MODE: ${USE_HOST_NETWORK}"
log_info "ENABLE_KEYCLOAK: ${ENABLE_KEYCLOAK}"
log_info "ENFORCE_HTTPS: ${ENFORCE_HTTPS}"

# Paths
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic"
DASHBOARD_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard"
TRAEFIK_DYNAMIC_CONFIG_DIR="${TRAEFIK_CONFIG_DIR}"

# Ensure Traefik dynamic config directory exists
if [ ! -d "$TRAEFIK_CONFIG_DIR" ]; then
  log_error "Traefik dynamic config directory not found: $TRAEFIK_CONFIG_DIR"
  log_info "Please install Traefik first with: make traefik DOMAIN=$DOMAIN"
  exit 1

# Ensure Traefik is on the agency_stack network
if ! docker network inspect agency_stack 2>/dev/null | grep -q "traefik_demo"; then
  log_info "Adding Traefik to the agency_stack network..."
  docker network connect agency_stack traefik_demo || {
    log_warning "Failed to connect Traefik to agency_stack network, creating connection manually"
    # Try alternative approach if needed
  }

# Configure Traefik to route traffic to the dashboard container
# When containerized, the dashboard is on the agency_stack Docker network

log_info "Creating dashboard routing configuration for Traefik..."

# Create dynamic config directory if it doesn't exist
mkdir -p "${TRAEFIK_DYNAMIC_CONFIG_DIR}"

# Create the dashboard route configuration
cat > "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
http:
  routers:
    # HTTP - Root domain router
    dashboard-root-http:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      priority: 10000
EOF

# Add HTTPS enforcement middleware if enabled
if [[ "${ENFORCE_HTTPS}" == "true" ]]; then
  cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
      middlewares:
        - "https-redirect"
EOF

cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
    
    # HTTP - Dashboard path router
    dashboard-path-http:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
EOF

# Add middlewares for dashboard path HTTP router
cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
      middlewares:
EOF

# Add middlewares based on configuration
middleware_list=()
middleware_list+=("dashboard-strip")

if [[ "${ENFORCE_HTTPS}" == "true" ]]; then
  middleware_list+=("https-redirect")

# Join the middleware list with commas
middleware_string=$(IFS=,; echo "${middleware_list[*]}")

cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
        - "${middleware_string}"
      priority: 10100
    
    # HTTPS - Root domain router
    dashboard-root-https:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
EOF

# Add Keycloak authentication middleware if enabled for HTTPS root router
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
      middlewares:
        - "keycloak-auth"
EOF

cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
      priority: 10000
      tls: {}
    
    # HTTPS - Dashboard path router
    dashboard-path-https:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
EOF

# Add middlewares for dashboard path HTTPS router
cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
      middlewares:
EOF

# Reset and rebuild middleware list for HTTPS path router
middleware_list=()
middleware_list+=("dashboard-strip")

if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  middleware_list+=("keycloak-auth")

# Join the middleware list with commas
middleware_string=$(IFS=,; echo "${middleware_list[*]}")

cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
        - "${middleware_string}"
      priority: 10100
      tls: {}
  
  # Define the dashboard service and middleware
  services:
    dashboard-service:
      loadBalancer:
        servers:
EOF

# Determine the right URL format based on network mode
if [[ "${USE_HOST_NETWORK}" == "true" ]]; then
  log_info "Using localhost URL for host network mode"
  # When using host network mode, Traefik can access the dashboard via localhost
  echo "          - url: \"http://localhost:${DASHBOARD_PORT}\"" >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml"
  log_info "Using host IP URL for bridge network mode"
  # When using bridge network mode, Traefik needs to access the dashboard via host IP
  HOST_IP=$(hostname -I | awk '{print $1}')
  echo "          - url: \"http://${HOST_IP}:${DASHBOARD_PORT}\"" >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml"

# Continue with the rest of the configuration
cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
  
  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes:
          - "/dashboard"
EOF

if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
    keycloak-auth:
      forwardAuth:
        address: "http://keycloak:8080/auth/realms/agencystack/protocol/openid-connect/auth"
        trustForwardHeader: true
EOF

if [[ "${ENFORCE_HTTPS}" == "true" ]]; then
  cat >> "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
    https-redirect:
      redirectScheme:
        scheme: "https"
EOF

log_success "Dashboard routing configuration created: ${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml"
log_info "Dashboard access URLs:"
log_info "HTTP FQDN (Root):       http://${DOMAIN}"
log_info "HTTP FQDN (Path):       http://${DOMAIN}/dashboard"
log_info "HTTPS FQDN (Root):      https://${DOMAIN} (if TLS is configured)"
log_info "HTTPS FQDN (Path):      https://${DOMAIN}/dashboard (if TLS is configured)"

# Verify the dashboard is accessible
log_info "Verifying dashboard is accessible from Traefik..."
if ! curl -s http://127.0.0.1:${DASHBOARD_PORT} > /dev/null; then
  log_warning "Dashboard service doesn't appear to be responding on port ${DASHBOARD_PORT}"
  log_info "Checking dashboard service status..."
  
  # Find PM2 installation and check dashboard status
  if command -v pm2 &> /dev/null; then
    PM2_CMD="pm2"
  elif [ -f "${DASHBOARD_DIR}/node/bin/pm2" ]; then
    PM2_CMD="${DASHBOARD_DIR}/node/bin/pm2"
  else
    log_error "PM2 not found. Cannot check dashboard service status."
    exit 1
  fi
  
  if $PM2_CMD list | grep -q "agencystack-dashboard"; then
    log_info "Dashboard service is running with PM2. Checking port configuration..."
    
    # Update PORT in ecosystem.config.js if needed
    sed -i "s/PORT: [0-9]*/PORT: ${DASHBOARD_PORT}/" "${DASHBOARD_DIR}/ecosystem.config.js"
    log_info "Restarting dashboard service with correct port..."
    $PM2_CMD restart agencystack-dashboard || true
  else
    log_error "Dashboard service not found in PM2. Please reinstall the dashboard with: make dashboard DOMAIN=$DOMAIN"
    exit 1
  fi

log_success "Dashboard routing configuration completed"
exit 0
