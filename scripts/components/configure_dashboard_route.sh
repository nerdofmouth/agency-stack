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

# Paths
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config/dynamic"
DASHBOARD_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard"

# Ensure Traefik dynamic config directory exists
if [ ! -d "$TRAEFIK_CONFIG_DIR" ]; then
  log_error "Traefik dynamic config directory not found: $TRAEFIK_CONFIG_DIR"
  log_info "Please install Traefik first with: make traefik DOMAIN=$DOMAIN"
  exit 1
fi

# Create dashboard routing configuration
log_info "Creating dashboard routing configuration for Traefik..."
cat > "${TRAEFIK_CONFIG_DIR}/dashboard-route.yml" <<EOF
# Dynamic configuration for Dashboard routing
# Auto-generated by configure_dashboard_route.sh
http:
  routers:
    dashboard:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      service: dashboard
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      middlewares:
        - dashboard-strip

  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:${DASHBOARD_PORT}"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
EOF

# Set proper permissions
chmod 644 "${TRAEFIK_CONFIG_DIR}/dashboard-route.yml"

log_success "Dashboard routing configuration created: ${TRAEFIK_CONFIG_DIR}/dashboard-route.yml"
log_info "Dashboard will be accessible at: https://${DOMAIN}/dashboard"

# Ensure Traefik can access the dashboard service
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
