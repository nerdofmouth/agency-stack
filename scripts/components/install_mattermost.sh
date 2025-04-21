#!/bin/bash
# install_mattermost.sh - Installation script for mattermost
#
# This script installs and configures mattermost for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname \"$0\")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Use robust, portable path for helpers
source "$(dirname "$0")/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/mattermost"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/mattermost.log"

log_info "Starting mattermost installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

log_success "mattermost installation completed successfully!"
