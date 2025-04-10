#!/bin/bash
# This script creates a Traefik dynamic configuration file to route traffic to the dashboard
# Following the repository-first approach in the AgencyStack Alpha Phase Repository Integrity Policy

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT="3000"  # Default Next.js port

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
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log_info "Starting configure_dashboard_route.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"

# Paths
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic"
DASHBOARD_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard"
TRAEFIK_DYNAMIC_CONFIG_DIR="${TRAEFIK_CONFIG_DIR}"

# Ensure Traefik dynamic config directory exists
if [ ! -d "$TRAEFIK_CONFIG_DIR" ]; then
  log_error "Traefik dynamic config directory not found: $TRAEFIK_CONFIG_DIR"
  log_info "Please install Traefik first with: make traefik DOMAIN=$DOMAIN"
  exit 1
fi

# Configure Traefik to route traffic to the dashboard container
# When containerized, the dashboard is on the agency_stack Docker network

log_info "Creating dashboard routing configuration for Traefik..."

# Create dynamic config directory if it doesn't exist
mkdir -p "${TRAEFIK_DYNAMIC_CONFIG_DIR}"

# Create the dashboard route configuration
cat > "${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml" <<EOF
http:
  routers:
    dashboard:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      tls: {}

  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_${CLIENT_ID}:3000"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
EOF

log_success "Dashboard routing configuration created: ${TRAEFIK_DYNAMIC_CONFIG_DIR}/dashboard-route.yml"
log_info "Dashboard will be accessible at: https://${DOMAIN}/dashboard"

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
fi

log_success "Dashboard routing configuration completed"
exit 0
