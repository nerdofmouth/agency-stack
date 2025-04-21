#!/bin/bash
# install_focalboard.sh - Installation script for focalboard
#
# This script installs and configures focalboard for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Use robust, portable path for helpers
source "$(dirname "$0")/../utils/log_helpers.sh"

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/focalboard"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/focalboard.log"

log_info "Starting focalboard installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

    # Mark component as installed
    mark_installed "focalboard" "${COMPONENT_DIR}"
        
log_success "focalboard installation completed successfully!"
