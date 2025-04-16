#!/bin/bash
# fix_docker_network_access.sh - Fix Docker network to allow container access to host services
# Following the AgencyStack Alpha Phase Repository Integrity Policy
# This script configures Docker to allow containers to access host services via special DNS or network mode

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
FORCE_RECREATE=false

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
    --force-recreate)
      FORCE_RECREATE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id CLIENT_ID       Client ID (default: default)"
      echo "  --dashboard-port PORT       Dashboard port (default: 3001)"
      echo "  --force-recreate            Force recreation of Traefik container"
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

# Get host machine IP visible to Docker containers
HOST_IP=$(hostname -I | awk '{print $1}')
log_info "Host IP: ${HOST_IP}"

# Backup and update docker-compose.yml to add host network mode
DOCKER_COMPOSE_FILE="${TRAEFIK_DIR}/docker-compose.yml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

log_info "Creating backup of docker-compose.yml"
cp "${DOCKER_COMPOSE_FILE}" "${DOCKER_COMPOSE_FILE}${BACKUP_SUFFIX}"

# Modify docker-compose.yml to use host network
log_info "Updating docker-compose.yml to use host network mode"
sed -i 's/^\(\s*\)ports:/\1network_mode: "host"\n\1# ports:/' "${DOCKER_COMPOSE_FILE}"
sed -i 's/^\(\s*\)- .*:80/\1# - 80:80/' "${DOCKER_COMPOSE_FILE}"
sed -i 's/^\(\s*\)- .*:443/\1# - 443:443/' "${DOCKER_COMPOSE_FILE}"

# Backup and update dashboard-route.yml as well
DASHBOARD_ROUTE="${TRAEFIK_DIR}/config/dynamic/dashboard-route.yml"
if [[ -f "${DASHBOARD_ROUTE}" ]]; then
  log_info "Creating backup of dashboard-route.yml"
  cp "${DASHBOARD_ROUTE}" "${DASHBOARD_ROUTE}${BACKUP_SUFFIX}"
  
  # Update to use localhost instead of host IP since we're using host network mode
  log_info "Updating dashboard route to use localhost (host network mode)"
  sed -i "s|http://${HOST_IP}:${DASHBOARD_PORT}|http://localhost:${DASHBOARD_PORT}|g" "${DASHBOARD_ROUTE}"
  sed -i "s|http://[0-9.]\+:${DASHBOARD_PORT}|http://localhost:${DASHBOARD_PORT}|g" "${DASHBOARD_ROUTE}"
fi

# Recreate and restart Traefik container
log_info "Restarting Traefik with host network mode"
cd "${TRAEFIK_DIR}"

if [[ "${FORCE_RECREATE}" == "true" ]]; then
  log_info "Forcing recreation of Traefik container"
  docker-compose down
  docker-compose up -d
else
  docker-compose restart
fi

log_success "Traefik container now uses host network mode. This should resolve the network isolation issues."
log_info "To restore the original configuration, use:"
log_info "  - Docker Compose: ${DOCKER_COMPOSE_FILE}${BACKUP_SUFFIX}"
log_info "  - Dashboard Route: ${DASHBOARD_ROUTE}${BACKUP_SUFFIX}"

# Verify dashboard is now accessible through Traefik
log_info "Giving Traefik time to start up..."
sleep 5

# Test if we can access the dashboard directly through Traefik
log_info "Testing dashboard access through Traefik..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${HOST_IP}" || echo "Connection failed")

if [[ "${HTTP_STATUS}" == "200" ]] || [[ "${HTTP_STATUS}" == "301" ]] || [[ "${HTTP_STATUS}" == "302" ]]; then
  log_success "Dashboard is accessible through Traefik! HTTP Status: ${HTTP_STATUS}"
else
  log_warning "Dashboard may not be accessible through Traefik. HTTP Status: ${HTTP_STATUS}"
  log_info "Please check these URLs manually:"
  log_info "- http://proto001.alpha.nerdofmouth.com"
  log_info "- http://proto001.alpha.nerdofmouth.com/dashboard"
fi
