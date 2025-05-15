#!/bin/bash
# install_COMPONENT.sh - Installation script for COMPONENT
#
# This script installs and configures COMPONENT for AgencyStack
# Usage: ./install_COMPONENT.sh [--domain example.com] [--admin-email admin@example.com] [--enable-cloud] [--enable-openai]

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
COMPONENT="component_name"
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT}"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/${COMPONENT}.log"
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
WITH_DEPS=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --enable-openai)
            ENABLE_OPENAI=true
            shift
            ;;
        --use-github)
            USE_GITHUB=true
            shift
            ;;
        --with-deps)
            WITH_DEPS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || true

log_info "Starting ${COMPONENT} installation..."
log_info "Domain: ${DOMAIN}"
log_info "Admin Email: ${ADMIN_EMAIL}"
log_info "Client ID: ${CLIENT_ID}"
log_info "Installation Directory: ${INSTALL_DIR}"

# Check for idempotence - if already installed and not forced, exit
if [[ -d "$INSTALL_DIR" && -f "${INSTALL_DIR}/.installed_ok" && "$FORCE" != "true" ]]; then
    log_info "${COMPONENT} is already installed. Use --force to reinstall."
    exit 0
fi

# Check required commands
check_command docker || {
    log_error "Docker is required but not installed"
    exit 1
}

check_command docker-compose || {
    log_error "Docker Compose is required but not installed"
    exit 1
}

# Create required directories
ensure_directory "$INSTALL_DIR" "750"
ensure_directory "${INSTALL_DIR}/data" "750"
ensure_directory "${INSTALL_DIR}/config" "750"
ensure_directory "${INSTALL_DIR}/backups" "750"

# Install dependencies if requested
if [[ "$WITH_DEPS" == "true" ]]; then
    log_info "Installing dependencies..."
    # Add dependency installation here
fi

# Create configuration files
log_info "Creating configuration files..."

cat > "${INSTALL_DIR}/config/docker-compose.yml" <<EOF
version: '3'

services:
  ${COMPONENT}:
    image: example/${COMPONENT}:latest
    container_name: ${COMPONENT}
    restart: unless-stopped
    environment:
      - DOMAIN=${DOMAIN}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
    volumes:
      - ${INSTALL_DIR}/data:/data
      - ${INSTALL_DIR}/config:/config
    networks:
      - agency-network

networks:
  agency-network:
    external: true
EOF

# Create .env file
cat > "${INSTALL_DIR}/config/.env" <<EOF
DOMAIN=${DOMAIN}
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF

# Pull docker images
log_info "Pulling Docker images..."
cd "${INSTALL_DIR}/config" && docker-compose pull

# Start the service
log_info "Starting ${COMPONENT} services..."
cd "${INSTALL_DIR}/config" && docker-compose up -d

# Wait for service to be ready
log_info "Waiting for ${COMPONENT} to be ready..."
sleep 10

# Check if service is running
if docker ps | grep -q "${COMPONENT}"; then
    log_success "${COMPONENT} is running successfully"
    
    # Mark as installed
    touch "${INSTALL_DIR}/.installed_ok"
    
    # Update component registry
    if command -v "${SCRIPT_DIR}/../utils/update_component_registry.sh" &> /dev/null; then
        "${SCRIPT_DIR}/../utils/update_component_registry.sh" \
            --component="${COMPONENT}" \
            --flag="installed" \
            --value="true"
    fi
    
    log_success "${COMPONENT} installation completed successfully!"
else
    log_error "${COMPONENT} failed to start properly"
    log_info "Check the logs for more information: docker logs ${COMPONENT}"
    exit 1
fi

# Script completed successfully
SCRIPT_SUCCESS=true
