#!/bin/bash
# fix_dashboard_access_standalone.sh - Self-contained fix for dashboard access issues
# 
# This script implements fixes for FQDN access to the dashboard by:
# 1. Allowing HTTP access (bypassing HTTPS redirection)
# 2. Ensuring proper DNS configuration
#
# Author: AgencyStack Team
# Date: 2025-04-10

set -e

# Standalone utilities (no external dependencies)
log_info() {
  echo -e "\033[0;34m[INFO] $1\033[0m"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS] $1\033[0m"
}

log_warning() {
  echo -e "\033[0;33m[WARNING] $1\033[0m"
}

log_error() {
  echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
FIX_DNS="${FIX_DNS:-true}"
ALLOW_HTTP="${ALLOW_HTTP:-true}"
SERVER_IP=$(hostname -I | awk '{print $1}')

# Paths
TRAEFIK_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
TRAEFIK_CONFIG_DIR="${TRAEFIK_DIR}/config"
TRAEFIK_DYNAMIC_DIR="${TRAEFIK_CONFIG_DIR}/dynamic"
DASHBOARD_ROUTE_FILE="${TRAEFIK_DYNAMIC_DIR}/dashboard-route.yml"
TRAEFIK_YML_FILE="${TRAEFIK_CONFIG_DIR}/traefik.yml"

# Parse command-line arguments
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
    --fix-dns)
      FIX_DNS="$2"
      shift 2
      ;;
    --allow-http)
      ALLOW_HTTP="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --domain DOMAIN       Domain to use (default: value from env or localhost)"
      echo "  --client-id ID        Client ID (default: default)"
      echo "  --fix-dns BOOL        Update hosts file (default: true)"
      echo "  --allow-http BOOL     Allow HTTP access (default: true)"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log_info "Starting dashboard access fix..."
log_info "Domain: ${DOMAIN}"
log_info "Client ID: ${CLIENT_ID}"
log_info "Server IP: ${SERVER_IP}"

# Check if Traefik is installed
if [ ! -d "${TRAEFIK_DIR}" ]; then
  log_error "Traefik is not installed at ${TRAEFIK_DIR}"
  exit 1
fi

# Fix 1: Update hosts file if needed
if [ "${FIX_DNS}" == "true" ]; then
  log_info "Checking hosts file configuration..."
  
  # Check if domain exists in hosts file
  if grep -q "${DOMAIN}" /etc/hosts; then
    log_info "Domain ${DOMAIN} found in hosts file"
    
    # Check if it points to the correct IP
    HOSTS_IP=$(grep "${DOMAIN}" /etc/hosts | awk '{print $1}')
    if [ "${HOSTS_IP}" != "${SERVER_IP}" ]; then
      log_warning "Domain ${DOMAIN} points to ${HOSTS_IP} instead of ${SERVER_IP}"
      log_info "Updating hosts file entry..."
      
      # Update the entry
      sed -i "s/^.*${DOMAIN}.*/${SERVER_IP} ${DOMAIN}/" /etc/hosts
      log_success "Updated hosts file: ${DOMAIN} now points to ${SERVER_IP}"
    else
      log_success "Hosts file already has correct entry for ${DOMAIN}"
    fi
  else
    log_warning "Domain ${DOMAIN} not found in hosts file"
    log_info "Adding entry to hosts file..."
    
    # Add the entry
    echo "${SERVER_IP} ${DOMAIN}" >> /etc/hosts
    log_success "Added ${DOMAIN} -> ${SERVER_IP} to hosts file"
  fi
fi

# Fix 2: Update dashboard route to allow HTTP access
if [ "${ALLOW_HTTP}" == "true" ]; then
  log_info "Updating dashboard route configuration to allow HTTP access..."
  
  # Backup the original configuration
  BACKUP_FILE="${DASHBOARD_ROUTE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  cp "${DASHBOARD_ROUTE_FILE}" "${BACKUP_FILE}"
  log_info "Backed up original configuration to ${BACKUP_FILE}"
  
  # Write the new configuration
  cat > "${DASHBOARD_ROUTE_FILE}" <<EOF
http:
  routers:
    # HTTPS Router
    dashboard:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"
      tls: {}
    
    # HTTP Router (no TLS requirement)
    dashboard-http:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard"
      middlewares:
        - "dashboard-strip"

  services:
    dashboard:
      loadBalancer:
        servers:
          - url: "http://dashboard_default:80"

  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes: 
          - "/dashboard"
EOF
  log_success "Updated dashboard route configuration"
fi

# Fix 3: Update Traefik configuration to allow HTTP traffic
if [ "${ALLOW_HTTP}" == "true" ]; then
  log_info "Checking Traefik entrypoints configuration..."
  
  # Check if web entrypoint redirects to HTTPS
  if grep -q "redirections" "${TRAEFIK_YML_FILE}"; then
    log_warning "Traefik is configured to redirect HTTP to HTTPS"
    log_info "Creating modified Traefik configuration..."
    
    # Backup the original configuration
    TRAEFIK_BACKUP="${TRAEFIK_YML_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${TRAEFIK_YML_FILE}" "${TRAEFIK_BACKUP}"
    log_info "Backed up original Traefik configuration to ${TRAEFIK_BACKUP}"
    
    # Modify the configuration to prevent redirection
    sed -i '/redirections/,+3 s/^/#/' "${TRAEFIK_YML_FILE}"
    log_success "Disabled automatic HTTP to HTTPS redirection"
  else
    log_info "Traefik already allows HTTP traffic"
  fi
fi

# Restart Traefik to apply changes
log_info "Restarting Traefik to apply changes..."
cd "${TRAEFIK_DIR}" && docker-compose down && docker-compose up -d
log_success "Traefik restarted successfully"

log_info "Testing dashboard access..."
# Test HTTP access
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}/dashboard")
log_info "HTTP access status: ${HTTP_STATUS}"

# Test HTTPS access
HTTPS_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${DOMAIN}/dashboard")
log_info "HTTPS access status: ${HTTPS_STATUS}"

log_success "Dashboard access fix completed"
log_info ""
log_info "Access instructions:"
log_info "1. HTTP access: http://${DOMAIN}/dashboard"
log_info "2. HTTPS access: https://${DOMAIN}/dashboard (may require security exception)"
log_info "3. Direct access: http://${SERVER_IP}:3001"
log_info ""
log_info "For external access, ensure DNS records are properly configured"
log_info "or add '${SERVER_IP} ${DOMAIN}' to your local hosts file"

exit 0
