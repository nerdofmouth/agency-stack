#!/bin/bash
# Listmonk Upgrade Script v4.1.0
# AgencyStack Component: listmonk

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Component configuration
COMPONENT_NAME="listmonk"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID:-default}/${COMPONENT_NAME}"

# Initialize logging
log_start "${LOG_FILE}" "Listmonk upgrade to v4.1.0 started"

# Verify current installation
if [ ! -f "${INSTALL_DIR}/.installed" ]; then
    log_error "${LOG_FILE}" "Listmonk not installed, cannot upgrade"
    exit 1
fi

# Check current version
CURRENT_VERSION=$(docker inspect --format='{{.Config.Image}}' listmonk | cut -d: -f2)
if [ "$CURRENT_VERSION" == "v4.1.0" ]; then
    log_info "${LOG_FILE}" "Listmonk already at v4.1.0, skipping upgrade"
    exit 0
fi

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
sed -i 's|listmonk/listmonk:.*|listmonk/listmonk:v4.1.0|g' docker-compose.yml

# Pull new image
log_info "${LOG_FILE}" "Pulling new image"
docker-compose pull

# Start upgraded service
log_info "${LOG_FILE}" "Starting upgraded service"
docker-compose up -d

# Run database migration
log_info "${LOG_FILE}" "Running database migration"
docker-compose exec -T listmonk ./listmonk --upgrade

# Verify upgrade
sleep 10 # Wait for services to stabilize
if docker-compose ps | grep -q "Up"; then
    log_info "${LOG_FILE}" "Listmonk upgraded to v4.1.0 successfully"
    echo "4.1.0" > "${INSTALL_DIR}/.version"
else
    log_error "${LOG_FILE}" "Upgrade failed"
    exit 1
fi
