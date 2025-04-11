#!/bin/bash
# disable_https_redirect.sh - Temporarily disable HTTPS redirection for testing environments
# Following the AgencyStack Alpha Phase Repository Integrity Policy
# This script creates a new Traefik configuration that allows direct HTTP access

set -e

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "${SCRIPT_DIR}/../utils" && pwd)"
if [[ -f "${UTILS_DIR}/common.sh" ]]; then
  source "${UTILS_DIR}/common.sh"
fi

# Fallback logging functions if common.sh is not available
if ! command -v log_info &> /dev/null; then
  log_info() { echo "[INFO] $1"; }
  log_error() { echo "[ERROR] $1" >&2; }
  log_success() { echo "[SUCCESS] $1"; }
fi

# Default values
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
TRAEFIK_YML="${TRAEFIK_CONFIG_DIR}/traefik.yml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id CLIENT_ID   Client ID (default: default)"
      echo "  --help                  Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if Traefik configuration exists
if [[ ! -f "${TRAEFIK_YML}" ]]; then
  log_error "Traefik configuration not found at ${TRAEFIK_YML}"
  exit 1
fi

# Backup original configuration
log_info "Creating backup of Traefik configuration"
cp "${TRAEFIK_YML}" "${TRAEFIK_YML}${BACKUP_SUFFIX}"

# Create new configuration without HTTP to HTTPS redirection
log_info "Updating Traefik configuration to disable HTTP to HTTPS redirection"

# Extract and modify configuration
MODIFIED_CONFIG=$(cat "${TRAEFIK_YML}" | sed '/redirections/,/scheme: https/d')

# Write modified configuration
echo "${MODIFIED_CONFIG}" > "${TRAEFIK_YML}"

# Restart Traefik to apply changes
log_info "Restarting Traefik to apply configuration changes"
cd "/opt/agency_stack/clients/${CLIENT_ID}/traefik" && docker-compose restart

log_success "HTTPS redirection disabled. HTTP access should now work directly."
log_info "To restore the original configuration, use: ${TRAEFIK_YML}${BACKUP_SUFFIX}"
