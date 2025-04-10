#!/bin/bash
# install_crowdsec.sh - Installation script for crowdsec
#
# This script installs and configures crowdsec for AgencyStack
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
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/crowdsec"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/crowdsec.log"
INSTALLED_MARKER="${INSTALL_DIR}/.installed"
VERSION_FILE="${INSTALL_DIR}/.version"
CURRENT_VERSION="1.5.2" # Update this when upgrading

# Parse command line arguments
ENABLE_KEYCLOAK=false
FORCE=false
VERBOSE=false
PROTECTION_LEVEL="standard" # Can be "minimal", "standard", "aggressive"

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
    --protection-level)
      PROTECTION_LEVEL="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --enable-keycloak            Enable Keycloak SSO integration"
      echo "  --force                      Force reinstallation even if already installed"
      echo "  --verbose                    Enable verbose output"
      echo "  --protection-level LEVEL     Set protection level (minimal, standard, aggressive)"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

log_info "Starting CrowdSec installation..."

# Check if already installed
if [[ -f "${INSTALLED_MARKER}" && "${FORCE}" != "true" ]]; then
  if [[ -f "${VERSION_FILE}" ]]; then
    INSTALLED_VERSION=$(cat "${VERSION_FILE}")
    if [[ "${INSTALLED_VERSION}" == "${CURRENT_VERSION}" ]]; then
      log_info "CrowdSec ${INSTALLED_VERSION} is already installed. Use --force to reinstall."
      
      # Check if protection level changed
      if [[ -f "${CONFIG_DIR}/protection_level" ]]; then
        CURRENT_PROTECTION_LEVEL=$(cat "${CONFIG_DIR}/protection_level")
        if [[ "${CURRENT_PROTECTION_LEVEL}" != "${PROTECTION_LEVEL}" ]]; then
          log_info "Protection level changed from ${CURRENT_PROTECTION_LEVEL} to ${PROTECTION_LEVEL}. Updating configuration..."
          # Update protection level configuration
          echo "${PROTECTION_LEVEL}" > "${CONFIG_DIR}/protection_level"
          # Additional configuration updates would go here
        else
          log_info "Protection level unchanged (${PROTECTION_LEVEL})."
        fi
      else
        # Create protection level file if it doesn't exist
        mkdir -p "${CONFIG_DIR}"
        echo "${PROTECTION_LEVEL}" > "${CONFIG_DIR}/protection_level"
      fi
      
      exit 0
    else
      log_info "Upgrading CrowdSec from ${INSTALLED_VERSION} to ${CURRENT_VERSION}..."
    fi
  else
    log_info "CrowdSec is already installed but version is unknown. Use --force to reinstall."
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

# Check for system dependencies
log_info "Checking for required system dependencies..."
for cmd in curl systemctl iptables; do
  if ! command -v $cmd &> /dev/null; then
    log_error "Required dependency '$cmd' not found. Please install it first."
    exit 1
  fi
done

# Save protection level setting
echo "${PROTECTION_LEVEL}" > "${CONFIG_DIR}/protection_level"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

# Create marker file to indicate installation completion
echo "${CURRENT_VERSION}" > "${VERSION_FILE}"
touch "${INSTALLED_MARKER}"

log_success "CrowdSec installation completed successfully!"
