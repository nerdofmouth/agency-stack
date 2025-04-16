#!/bin/bash
# DroneCI Upgrade Script v2.25.0
# AgencyStack Component: droneci

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Component configuration
COMPONENT_NAME="droneci"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"

# Default parameters
DOMAIN=""
ADMIN_EMAIL=""
CLIENT_ID="default"
ENABLE_CLOUD=false
ENABLE_KEYCLOAK=true
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_GITEA=true

# Initialize logging
log_start "${LOG_FILE}" "DroneCI upgrade to v2.25.0 started"

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
    --enable-gitea)
      ENABLE_GITEA=true
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
      echo "Usage: $0 --domain <domain> --admin-email <email> [--client-id <id>] [--enable-cloud] [--enable-keycloak] [--enable-gitea] [--force] [--with-deps] [--verbose]"
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
fi

# Set installation directory
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/droneci"

# Verify current installation
if [ ! -f "${INSTALL_DIR}/.installed" ]; then
    log_error "${LOG_FILE}" "DroneCI not installed, cannot upgrade"
    exit 1
fi

# Check current version
CURRENT_VERSION=$(grep -o "DRONE_VERSION=.*" "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
if [ "$CURRENT_VERSION" == "2.25.0" ] && [ "$FORCE" != "true" ]; then
    log_info "${LOG_FILE}" "DroneCI already at v2.25.0, skipping upgrade"
    exit 0
fi

log_info "${LOG_FILE}" "Upgrading DroneCI from ${CURRENT_VERSION} to v2.25.0"

# Stop existing service
log_info "${LOG_FILE}" "Stopping DroneCI service"
cd "${INSTALL_DIR}"
docker-compose down

# Backup current data
log_info "${LOG_FILE}" "Creating backup"
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "${BACKUP_DIR}"
cp -r "${INSTALL_DIR}"/* "${BACKUP_DIR}"/

# Check for existing runner configuration
RUNNER_VERSION="1.8.0"
if grep -q "DRONE_RUNNER_VERSION" "${INSTALL_DIR}/.env"; then
    RUNNER_VERSION=$(grep -o "DRONE_RUNNER_VERSION=.*" "${INSTALL_DIR}/.env" | cut -d= -f2 | tr -d '"')
    # Update runner to latest compatible version
    RUNNER_VERSION="2.0.0"
fi

# Update environment file
log_info "${LOG_FILE}" "Updating configuration"
sed -i 's/DRONE_VERSION=.*/DRONE_VERSION="2.25.0"/' "${INSTALL_DIR}/.env"
sed -i "s/DRONE_RUNNER_VERSION=.*/DRONE_RUNNER_VERSION=\"${RUNNER_VERSION}\"/" "${INSTALL_DIR}/.env"

# Update docker-compose.yml for version changes
sed -i 's|image: drone/drone:.*|image: drone/drone:2.25.0|g' "${INSTALL_DIR}/docker-compose.yml"
sed -i "s|image: drone/drone-runner-docker:.*|image: drone/drone-runner-docker:${RUNNER_VERSION}|g" "${INSTALL_DIR}/docker-compose.yml"

# Add new environment variables for v2.25.0
if ! grep -q "DRONE_STARLARK_ENABLED" "${INSTALL_DIR}/.env"; then
    echo "DRONE_STARLARK_ENABLED=true" >> "${INSTALL_DIR}/.env"
fi

if ! grep -q "DRONE_VALIDATE_PLUGIN_SKIP" "${INSTALL_DIR}/.env"; then
    echo "DRONE_VALIDATE_PLUGIN_SKIP=true" >> "${INSTALL_DIR}/.env"
fi

# Keycloak SSO integration
if [ "$ENABLE_KEYCLOAK" == "true" ]; then
    log_info "${LOG_FILE}" "Configuring Keycloak SSO integration"
    
    # Check if Keycloak is available
    KEYCLOAK_STATUS=$(systemctl is-active keycloak.service 2>/dev/null || echo "inactive")
    if [ "$KEYCLOAK_STATUS" != "active" ]; then
        log_warning "${LOG_FILE}" "Keycloak service not active. SSO integration may not work correctly."
    fi
    
    # Update OAuth configuration for v2.25.0
    if grep -q "DRONE_GITHUB_CLIENT_ID" "${INSTALL_DIR}/.env"; then
        log_info "${LOG_FILE}" "Updating OAuth settings for Keycloak"
        sed -i '/DRONE_GITHUB_/d' "${INSTALL_DIR}/.env"
        
        # Add Keycloak OAuth settings
        cat << EOF >> "${INSTALL_DIR}/.env"
# Keycloak OAuth Configuration
DRONE_KEYCLOAK_SERVER=https://keycloak.${DOMAIN}/auth
DRONE_KEYCLOAK_CLIENT_ID=droneci
DRONE_KEYCLOAK_CLIENT_SECRET=droneci-secret
DRONE_KEYCLOAK_REALM=${CLIENT_ID}
EOF
    fi
fi

# Gitea integration if enabled
if [ "$ENABLE_GITEA" == "true" ]; then
    log_info "${LOG_FILE}" "Configuring Gitea integration"
    
    # Check if Gitea env vars are present; if not, add them
    if ! grep -q "DRONE_GITEA_SERVER" "${INSTALL_DIR}/.env"; then
        cat << EOF >> "${INSTALL_DIR}/.env"
# Gitea Integration
DRONE_GITEA_SERVER=https://gitea.${DOMAIN}
DRONE_GIT_ALWAYS_AUTH=true
EOF
    fi
    
    # Update to latest Gitea integration features
    sed -i '/DRONE_GITEA_/d' "${INSTALL_DIR}/.env"
    cat << EOF >> "${INSTALL_DIR}/.env"
# Updated Gitea Integration for v2.25.0
DRONE_GITEA_SERVER=https://gitea.${DOMAIN}
DRONE_GITEA_CLIENT_ID=droneci
DRONE_GITEA_CLIENT_SECRET=droneci-secret
DRONE_GIT_ALWAYS_AUTH=true
DRONE_GITEA_SKIP_VERIFY=false
EOF
fi

# Pull updated images
log_info "${LOG_FILE}" "Pulling new images"
docker-compose pull

# Start upgraded service
log_info "${LOG_FILE}" "Starting upgraded service"
docker-compose up -d

# Verify upgrade
sleep 10 # Wait for services to stabilize
CONTAINER_STATUS=$(docker ps -a --filter "name=droneci-server-${CLIENT_ID}" --format "{{.Status}}" | grep -i "up" || echo "")
if [ -n "$CONTAINER_STATUS" ]; then
    # Update version marker
    echo "2.25.0" > "${INSTALL_DIR}/.version"
    
    # Update component registry
    log_info "${LOG_FILE}" "Updating component registry"
    COMPONENT_REGISTRY="/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json"
    jq '.components.infrastructure.droneci.version = "2.25.0"' "$COMPONENT_REGISTRY" > "${COMPONENT_REGISTRY}.tmp" && \
    mv "${COMPONENT_REGISTRY}.tmp" "$COMPONENT_REGISTRY"
    
    log_success "${LOG_FILE}" "DroneCI upgraded successfully to v2.25.0"
    
    # Notify about re-adding repositories
    log_info "${LOG_FILE}" "NOTE: You may need to re-sync repositories in the DroneCI UI after this upgrade."
    log_info "${LOG_FILE}" "Access the DroneCI dashboard at: https://drone.${DOMAIN}"
else
    log_error "${LOG_FILE}" "Upgrade failed: container is not running"
    log_info "${LOG_FILE}" "Attempting rollback from backup..."
    docker-compose down
    rm -rf "${INSTALL_DIR}"
    cp -r "${BACKUP_DIR}"/* "${INSTALL_DIR}"/
    cd "${INSTALL_DIR}"
    docker-compose up -d
    log_warning "${LOG_FILE}" "Rollback completed. Previous version restored."
    exit 1
fi
