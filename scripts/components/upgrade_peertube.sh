#!/bin/bash
# PeerTube Upgrade Script
# AgencyStack Component: peertube

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Component configuration
COMPONENT_NAME="peertube"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID:-default}/${COMPONENT_NAME}"

# Initialize logging
log_start "${LOG_FILE}" "PeerTube upgrade to v7.0 started"

# Verify current installation
if [ ! -f "${INSTALL_DIR}/.installed" ]; then
    log_error "${LOG_FILE}" "PeerTube not installed, cannot upgrade"
    exit 1
fi

# Check current version
CURRENT_VERSION=$(docker inspect --format='{{.Config.Image}}' peertube | cut -d: -f2)
if [ "$CURRENT_VERSION" == "production-bookworm-v7.0" ]; then
    log_info "${LOG_FILE}" "PeerTube already at v7.0, skipping upgrade"
    exit 0
fi

# Stop existing service
log_info "${LOG_FILE}" "Stopping PeerTube service"
cd "${INSTALL_DIR}"
docker-compose down

# Backup current data
log_info "${LOG_FILE}" "Creating backup"
BACKUP_DIR="${INSTALL_DIR}_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "${BACKUP_DIR}"
cp -r "${INSTALL_DIR}"/* "${BACKUP_DIR}"/

# Update docker-compose file
log_info "${LOG_FILE}" "Updating configuration"
sed -i 's|chocobozzz/peertube:production-bookworm.*|chocobozzz/peertube:production-bookworm-v7.0|g' docker-compose.yml

# Pull new image
log_info "${LOG_FILE}" "Pulling new PeerTube image"
docker-compose pull

# Start upgraded service
log_info "${LOG_FILE}" "Starting upgraded PeerTube service"
docker-compose up -d

# Run post-upgrade checks
log_info "${LOG_FILE}" "Running post-upgrade checks"
sleep 30 # Wait for services to initialize
if docker ps -f name=peertube | grep -q peertube; then
    log_success "${LOG_FILE}" "PeerTube upgraded to v7.0 successfully"
else
    log_error "${LOG_FILE}" "PeerTube upgrade failed"
    # Attempt rollback
    log_info "${LOG_FILE}" "Attempting rollback"
    docker-compose down
    rm -rf "${INSTALL_DIR}"/*
    cp -r "${BACKUP_DIR}"/* "${INSTALL_DIR}"/
    docker-compose up -d
    exit 1
fi
