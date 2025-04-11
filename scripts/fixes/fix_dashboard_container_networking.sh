#!/bin/bash
# fix_dashboard_container_networking.sh - Fix networking between Traefik and Dashboard
# Following the AgencyStack Alpha Phase Repository Integrity Policy
# This script updates the dashboard route to use host.docker.internal or host IP instead of localhost

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
fi

# Default values
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
DASHBOARD_PORT="3001"
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
DASHBOARD_ROUTE="${TRAEFIK_CONFIG_DIR}/dynamic/dashboard-route.yml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --dashboard-port)
      DASHBOARD_PORT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id CLIENT_ID       Client ID (default: default)"
      echo "  --domain DOMAIN             Domain name (default: proto001.alpha.nerdofmouth.com)"
      echo "  --dashboard-port PORT       Dashboard port (default: 3001)"
      echo "  --help                      Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if dashboard route exists
if [[ ! -f "${DASHBOARD_ROUTE}" ]]; then
  log_error "Dashboard route configuration not found at ${DASHBOARD_ROUTE}"
  exit 1
fi

# Get host machine IP visible to Docker containers
HOST_IP=$(hostname -I | awk '{print $1}')
log_info "Host IP: ${HOST_IP}"

# Backup original configuration
log_info "Creating backup of dashboard route configuration"
cp "${DASHBOARD_ROUTE}" "${DASHBOARD_ROUTE}${BACKUP_SUFFIX}"

# Update the dashboard route configuration to use host IP instead of localhost
log_info "Updating dashboard route to use host IP instead of localhost"
sed -i "s|http://localhost:${DASHBOARD_PORT}|http://${HOST_IP}:${DASHBOARD_PORT}|g" "${DASHBOARD_ROUTE}"

# For Docker Desktop on Mac/Windows, host.docker.internal is also an option
if grep -q "host.docker.internal" "${DASHBOARD_ROUTE}"; then
  log_info "Using host.docker.internal for Docker Desktop compatibility"
else
  log_info "Using direct IP address: ${HOST_IP}"
fi

# Restart Traefik to apply changes
log_info "Restarting Traefik to apply configuration changes"
cd "/opt/agency_stack/clients/${CLIENT_ID}/traefik" && docker-compose restart

log_success "Dashboard route updated to use host IP. Container networking issue should be resolved."
log_info "To restore the original configuration, use: ${DASHBOARD_ROUTE}${BACKUP_SUFFIX}"

# Verify connectivity from Traefik container
log_info "Verifying connectivity from Traefik container to dashboard service..."
sleep 3 # Give Traefik time to restart

if docker exec traefik_default wget -O- --timeout=5 "http://${HOST_IP}:${DASHBOARD_PORT}" >/dev/null 2>&1; then
  log_success "Connectivity test successful! Traefik can now reach the dashboard service."
else
  log_warning "Connectivity test failed. Please check firewall settings and network configuration."
  log_info "Trying direct HTTP access to verify dashboard service is running..."
  
  if curl -s "http://${HOST_IP}:${DASHBOARD_PORT}" >/dev/null; then
    log_success "Dashboard service is running and accessible directly."
    log_warning "Traefik container may have network isolation issues."
  else
    log_error "Dashboard service is not accessible directly. Please check if it's running."
  fi
fi
