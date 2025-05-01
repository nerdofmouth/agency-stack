#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: upgrade_listmonk.sh
# Path: /scripts/components/upgrade_listmonk.sh
#
set -euo pipefail

# Source common utilities

# Component configuration
COMPONENT_NAME="listmonk"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID:-default}/${COMPONENT_NAME}"

# Default parameters
DOMAIN=""
ADMIN_EMAIL=""
CLIENT_ID="default"
ENABLE_CLOUD=false
ENABLE_KEYCLOAK=true
FORCE=false
WITH_DEPS=false
VERBOSE=false

# Initialize logging
log_start "${LOG_FILE}" "Listmonk upgrade to v4.1.0 started"

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
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
    --help)
      echo "Usage: $0 --domain <domain> --admin-email <email> [--client-id <id>] [--enable-cloud] [--enable-keycloak] [--force] [--with-deps] [--verbose]"
      exit 0
      ;;
    *)
      log_error "${LOG_FILE}" "Unknown parameter: $key"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$DOMAIN" ] || [ -z "$ADMIN_EMAIL" ]; then
  log_error "${LOG_FILE}" "Missing required parameters. Use --help for usage."
  exit 1

# Update install directory with client ID
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT_NAME}"

# Verify current installation
if [ ! -f "${INSTALL_DIR}/.installed" ]; then
    log_error "${LOG_FILE}" "Listmonk not installed, cannot upgrade"
    exit 1

# Check current version
CURRENT_VERSION=$(docker inspect --format='{{.Config.Image}}' listmonk-app-${CLIENT_ID} 2>/dev/null | grep -o 'v[0-9.]*' || echo "unknown")
if [ "$CURRENT_VERSION" == "v4.1.0" ] && [ "$FORCE" != "true" ]; then
    log_info "${LOG_FILE}" "Listmonk already at v4.1.0, skipping upgrade"
    exit 0

log_info "${LOG_FILE}" "Upgrading Listmonk from ${CURRENT_VERSION} to v4.1.0"

# Stop existing service
log_info "${LOG_FILE}" "Stopping Listmonk service"
cd "${INSTALL_DIR}"
docker-compose down

# Backup current data
log_info "${LOG_FILE}" "Creating backup"
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "${BACKUP_DIR}"
cp -r "${INSTALL_DIR}"/* "${BACKUP_DIR}"/

# Update docker-compose file
log_info "${LOG_FILE}" "Updating configuration files"
sed -i 's|listmonk/listmonk:.*|listmonk/listmonk:v4.1.0|g' docker-compose.yml

# Update config for v4.1.0 compatibility
if [ -f "${INSTALL_DIR}/config.toml" ]; then
    log_info "${LOG_FILE}" "Updating configuration for v4.1.0"
    # Add new config options for v4.1.0
    if ! grep -q "\[privacy\]" "${INSTALL_DIR}/config.toml"; then
        cat << EOF >> "${INSTALL_DIR}/config.toml"

# New privacy settings in v4.1.0
[privacy]
    individual_tracking = false
    allow_blocklist = true
    allow_export = true
    allow_wipe = true
EOF
    fi

# Pull new image
log_info "${LOG_FILE}" "Pulling new image"
docker-compose pull

# Keycloak integration if enabled
if [ "$ENABLE_KEYCLOAK" == "true" ]; then
    log_info "${LOG_FILE}" "Configuring Keycloak SSO integration"
    
    # Check if Keycloak is available
    KEYCLOAK_STATUS=$(systemctl is-active keycloak.service 2>/dev/null || echo "inactive")
    if [ "$KEYCLOAK_STATUS" != "active" ]; then
        log_warning "${LOG_FILE}" "Keycloak service not active. SSO integration may not work correctly."
    fi
    
    # Update SSO configuration for v4.1.0
    sed -i '/auth.provider/s/none/oidc/' "${INSTALL_DIR}/config.toml"
    
    # Add or update OIDC configuration
    if ! grep -q "\[auth.oidc\]" "${INSTALL_DIR}/config.toml"; then
        cat << EOF >> "${INSTALL_DIR}/config.toml"

[auth.oidc]
    name = "Keycloak"
    discover_url = "https://keycloak.${DOMAIN}/realms/${CLIENT_ID}/protocol/openid-connect/auth"
    client_id = "listmonk"
    client_secret = "listmonk-secret"  # Replace with actual secret from Keycloak
    scope = ["openid", "profile", "email"]
    email_claim = "email"
    name_claim = "name"
EOF
    fi

# Start upgraded service
log_info "${LOG_FILE}" "Starting upgraded service"
docker-compose up -d

# Run database migration
log_info "${LOG_FILE}" "Running database migration"
sleep 10 # Wait for container to stabilize
docker-compose exec -T listmonk ./listmonk --upgrade

# Verify upgrade
CONTAINER_STATUS=$(docker ps -a --filter "name=listmonk-app-${CLIENT_ID}" --format "{{.Status}}" | grep -i "up" || echo "")
if [ -n "$CONTAINER_STATUS" ]; then
    # Update version marker
    echo "4.1.0" > "${INSTALL_DIR}/.version"
    
    # Update component registry
    log_info "${LOG_FILE}" "Updating component registry"
    COMPONENT_REGISTRY="/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json"
    jq '.components.communication.listmonk.version = "4.1.0"' "$COMPONENT_REGISTRY" > "${COMPONENT_REGISTRY}.tmp" && \
    mv "${COMPONENT_REGISTRY}.tmp" "$COMPONENT_REGISTRY"
    
    log_success "${LOG_FILE}" "Listmonk upgraded successfully to v4.1.0"
    log_error "${LOG_FILE}" "Upgrade failed: container is not running"
    log_info "${LOG_FILE}" "Attempting rollback from backup..."
    docker-compose down
    rm -rf "${INSTALL_DIR}"
    cp -r "${BACKUP_DIR}"/* "${INSTALL_DIR}"/
    cd "${INSTALL_DIR}"
    docker-compose up -d
    log_warning "${LOG_FILE}" "Rollback completed. Previous version restored."
    exit 1
