#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: gitea.sh
# Path: /scripts/components/install_gitea.sh
#
set -e

# --- BEGIN: Preflight/Prerequisite Check ---
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Source common utilities
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Use robust, portable path for helpers
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$REPO_ROOT/scripts/utils/log_helpers.sh"

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
