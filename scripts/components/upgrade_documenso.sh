#!/bin/bash
# Documenso Upgrade Script v1.4.2
# AgencyStack Component: documenso

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Component configuration
COMPONENT_NAME="documenso"
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

# Initialize logging
log_start "${LOG_FILE}" "Documenso upgrade to v1.4.2 started"

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
fi

# Set installation directory
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT_NAME}"

# Verify current installation
if [ ! -f "${INSTALL_DIR}/.installed" ]; then
    log_error "${LOG_FILE}" "Documenso not installed, cannot upgrade"
    exit 1
fi

# Check current version
CURRENT_VERSION=$(grep -o '"version": ".*"' "${INSTALL_DIR}/package.json" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
if [ "$CURRENT_VERSION" == "1.4.2" ] && [ "$FORCE" != "true" ]; then
    log_info "${LOG_FILE}" "Documenso already at v1.4.2, skipping upgrade"
    exit 0
fi

log_info "${LOG_FILE}" "Upgrading Documenso from ${CURRENT_VERSION} to v1.4.2"

# Stop existing service
log_info "${LOG_FILE}" "Stopping Documenso service"
cd "${INSTALL_DIR}"
docker-compose down || log_warning "${LOG_FILE}" "Service may not be running"

# Backup current data
log_info "${LOG_FILE}" "Creating backup"
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "${BACKUP_DIR}"
cp -r "${INSTALL_DIR}"/* "${BACKUP_DIR}"/

# Update to the latest version
log_info "${LOG_FILE}" "Updating to v1.4.2"
git checkout main
git pull
git checkout tags/v1.4.2

# Update dependencies
log_info "${LOG_FILE}" "Updating dependencies"
npm ci

# Run database migrations
log_info "${LOG_FILE}" "Running database migrations"
npx prisma migrate deploy

# Rebuild the application
log_info "${LOG_FILE}" "Rebuilding application"
npm run build

# Keycloak integration if enabled
if [ "$ENABLE_KEYCLOAK" == "true" ]; then
    log_info "${LOG_FILE}" "Configuring Keycloak SSO integration"
    
    # Check if Keycloak is available
    KEYCLOAK_STATUS=$(systemctl is-active keycloak.service 2>/dev/null || echo "inactive")
    if [ "$KEYCLOAK_STATUS" != "active" ]; then
        log_warning "${LOG_FILE}" "Keycloak service not active. SSO integration may not work correctly."
    fi
    
    # Update Keycloak configuration in .env
    log_info "${LOG_FILE}" "Updating SSO configuration"
    sed -i 's/^NEXTAUTH_PROVIDER=.*/NEXTAUTH_PROVIDER=keycloak/' .env
    
    # Add or update Keycloak config if not present
    if ! grep -q "^KEYCLOAK_CLIENT_ID" .env; then
        cat << EOF >> .env

# Keycloak SSO Configuration
KEYCLOAK_CLIENT_ID=documenso
KEYCLOAK_CLIENT_SECRET=documenso-secret
KEYCLOAK_ISSUER=https://keycloak.${DOMAIN}/realms/${CLIENT_ID}
EOF
    fi
fi

# Update connection strings for multi-tenant support
if grep -q "multi_tenant: true" "/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json"; then
    log_info "${LOG_FILE}" "Configuring multi-tenant support"
    sed -i "s/^DATABASE_URL=.*/DATABASE_URL=postgresql:\/\/documenso:documenso@postgres-${CLIENT_ID}:5432\/documenso-${CLIENT_ID}/" .env
fi

# Restart the application
log_info "${LOG_FILE}" "Starting upgraded service"
docker-compose up -d

# Verify upgrade
sleep 10 # Wait for services to stabilize
CONTAINER_STATUS=$(docker ps -a --filter "name=documenso-app-${CLIENT_ID}" --format "{{.Status}}" | grep -i "up" || echo "")
if [ -n "$CONTAINER_STATUS" ]; then
    # Update version marker
    echo "1.4.2" > "${INSTALL_DIR}/.version"
    
    # Update component registry
    log_info "${LOG_FILE}" "Updating component registry"
    COMPONENT_REGISTRY="/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json"
    jq '.components.business.documenso.version = "1.4.2"' "$COMPONENT_REGISTRY" > "${COMPONENT_REGISTRY}.tmp" && \
    mv "${COMPONENT_REGISTRY}.tmp" "$COMPONENT_REGISTRY"
    
    log_success "${LOG_FILE}" "Documenso upgraded successfully to v1.4.2"
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
