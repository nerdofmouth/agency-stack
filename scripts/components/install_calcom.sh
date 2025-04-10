#!/bin/bash
# install_calcom.sh - Installation script for calcom
#
# This script installs and configures calcom for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/calcom"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/calcom.log"
INSTALLED_MARKER="${INSTALL_DIR}/.installed"
VERSION_FILE="${INSTALL_DIR}/.version"
CURRENT_VERSION="2.7.11" # Update this when upgrading

# Parse command line arguments
ENABLE_KEYCLOAK=false
FORCE=false
VERBOSE=false
WITH_DEPS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --enable-keycloak    Enable Keycloak SSO integration"
      echo "  --force              Force reinstallation even if already installed"
      echo "  --verbose            Enable verbose output"
      echo "  --with-deps          Install dependencies (PostgreSQL, Redis)"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log_info "Starting Cal.com installation..."

# Check if already installed
if [[ -f "${INSTALLED_MARKER}" && "${FORCE}" != "true" ]]; then
  if [[ -f "${VERSION_FILE}" ]]; then
    INSTALLED_VERSION=$(cat "${VERSION_FILE}")
    if [[ "${INSTALLED_VERSION}" == "${CURRENT_VERSION}" ]]; then
      log_info "Cal.com ${INSTALLED_VERSION} is already installed. Use --force to reinstall."
      exit 0
    else
      log_info "Upgrading Cal.com from ${INSTALLED_VERSION} to ${CURRENT_VERSION}..."
    fi
  else
    log_info "Cal.com is already installed but version is unknown. Use --force to reinstall."
    echo "${CURRENT_VERSION}" > "${VERSION_FILE}"
    exit 0
  fi
fi

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

# Check dependencies
if [[ "${WITH_DEPS}" == "true" ]]; then
  log_info "Checking for PostgreSQL..."
  if ! command -v psql &> /dev/null; then
    log_cmd "Installing PostgreSQL..."
    # Add PostgreSQL installation commands here
  else
    log_info "PostgreSQL already installed."
  fi
  
  log_info "Checking for Redis..."
  if ! command -v redis-cli &> /dev/null; then
    log_cmd "Installing Redis..."
    # Add Redis installation commands here
  else
    log_info "Redis already installed."
  fi
fi

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

# Create marker file to indicate installation completion
echo "${CURRENT_VERSION}" > "${VERSION_FILE}"
touch "${INSTALLED_MARKER}"

log_success "Cal.com installation completed successfully!"
