#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: documenso.sh
# Path: /scripts/components/install_documenso.sh
#
set -e

# --- BEGIN: Preflight/Prerequisite Check ---
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Use robust, portable path for helpers
source "$(dirname "$0")/../utils/log_helpers.sh"

# Source common utilities
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/documenso"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/documenso.log"

log_info "Starting documenso installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

    # Mark component as installed
    mark_installed "documenso" "${COMPONENT_DIR}"
        
log_success "documenso installation completed successfully!"
