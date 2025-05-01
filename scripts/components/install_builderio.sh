#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: builderio.sh
# Path: /scripts/components/install_builderio.sh
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

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/builderio"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/builderio.log"
INSTALLED_MARKER="${INSTALL_DIR}/.installed"
VERSION_FILE="${INSTALL_DIR}/.version"
CURRENT_VERSION="1.0.0" # Update this when upgrading

# Parse command line arguments
ENABLE_KEYCLOAK=false
FORCE=false
VERBOSE=false
WITH_DEPS=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --enable-keycloak    Enable Keycloak SSO integration"
      echo "  --force              Force reinstallation even if already installed"
      echo "  --verbose            Enable verbose output"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Normalize FORCE value for robustness
if [[ "${FORCE}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  FORCE=true
  FORCE=false

log_info "Starting builderio installation..."

# Check if already installed
if [[ -f "${INSTALLED_MARKER}" && "${FORCE}" != "true" ]]; then
  if [[ -f "${VERSION_FILE}" ]]; then
    INSTALLED_VERSION=$(cat "${VERSION_FILE}")
    if [[ "${INSTALLED_VERSION}" == "${CURRENT_VERSION}" ]]; then
      log_info "builderio ${INSTALLED_VERSION} is already installed. Use --force to reinstall."
      exit 0
    else
      log_info "Upgrading builderio from ${INSTALLED_VERSION} to ${CURRENT_VERSION}..."
    fi
  else
    log_info "builderio is already installed but version is unknown. Use --force to reinstall."
    echo "${CURRENT_VERSION}" > "${VERSION_FILE}"
    exit 0
  fi

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

# Create marker file to indicate installation completion
echo "${CURRENT_VERSION}" > "${VERSION_FILE}"
touch "${INSTALLED_MARKER}"

log_success "builderio installation completed successfully!"
