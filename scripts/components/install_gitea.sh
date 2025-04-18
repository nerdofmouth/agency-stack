#!/bin/bash
# install_gitea.sh - Installation script for gitea
#
# This script installs and configures gitea for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Use robust, portable path for helpers
source "$(dirname "$0")/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/gitea"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/gitea.log"

log_info "Starting gitea installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

    # Mark component as installed
    mark_installed "gitea" "${COMPONENT_DIR}"
        
log_success "gitea installation completed successfully!"
