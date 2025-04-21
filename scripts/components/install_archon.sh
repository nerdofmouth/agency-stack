#!/bin/bash
# Archon Installation Script
# AgencyStack Component: archon

set -euo pipefail

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Component configuration
COMPONENT_NAME="archon"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID:-default}/${COMPONENT_NAME}"

# Initialize logging
log_start "${LOG_FILE}" "Archon installation started"

# Check for existing installation
if [ -f "${INSTALL_DIR}/.installed" ]; then
    log_info "${LOG_FILE}" "Archon already installed, skipping"
    exit 0
fi

# Create installation directory
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    log_info "${LOG_FILE}" "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $SUDO_USER
fi

# Pull Archon Docker image
log_info "${LOG_FILE}" "Pulling Archon Docker image"
docker pull archon/archon:latest

# Create Docker compose file
log_info "${LOG_FILE}" "Creating Docker compose configuration"
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  archon:
    image: archon/archon:latest
    container_name: archon
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    environment:
      - ARCHON_ENV=production
      - ARCHON_SECRET_KEY=${RANDOM_SECRET}
EOF

# Start Archon service
log_info "${LOG_FILE}" "Starting Archon service"
docker-compose up -d

# Mark installation complete
touch "${INSTALL_DIR}/.installed"

log_success "${LOG_FILE}" "Archon installed successfully"
