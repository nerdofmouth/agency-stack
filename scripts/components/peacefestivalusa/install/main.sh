#!/bin/bash

# PeaceFestivalUSA Main Installation Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Component Consistency
# - Strict Containerization

set -e

# Script location and common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source common utilities
if [[ -f "${COMPONENTS_DIR}/utils/common.sh" ]]; then
  source "${COMPONENTS_DIR}/utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Log file setup according to Charter conventions
LOG_DIR="/var/log/agency_stack/components"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/peacefestivalusa_wordpress.log"

# Configuration defaults
CLIENT_ID="peacefestivalusa"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_DIR}/traefik"
WORDPRESS_DIR="${INSTALL_DIR}/wordpress"
DOMAIN="${DOMAIN:-localhost}"
FORCE="${FORCE:-false}"
WSL_INTEGRATION="${WSL_INTEGRATION:-false}"
WINDOWS_HOST="${WINDOWS_HOST:-false}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id=*)
      CLIENT_ID="${key#*=}"
      ;;
    --domain=*)
      DOMAIN="${key#*=}"
      ;;
    --force)
      FORCE="true"
      ;;
    --wsl)
      WSL_INTEGRATION="true"
      ;;
    --windows-host)
      WINDOWS_HOST="true"
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id=VALUE   Set client ID (default: peacefestivalusa)"
      echo "  --domain=VALUE      Set domain (default: localhost)"
      echo "  --force             Force reinstallation"
      echo "  --wsl               Enable WSL integration"
      echo "  --windows-host      Configure for Windows host access"
      echo "  --help              Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $key"
      exit 1
      ;;
  esac
  shift
done

log_info "Starting PeaceFestivalUSA WordPress installation"
log_info "Client ID: $CLIENT_ID"
log_info "Domain: $DOMAIN"
log_info "Installation directory: $INSTALL_DIR"

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Source component-specific scripts
log_info "Installing components..."

# 1. Traefik Installation
log_info "Installing Traefik component..."
source "${SCRIPT_DIR}/traefik.sh"

# 2. WordPress Installation 
log_info "Installing WordPress component..."
source "${SCRIPT_DIR}/wordpress.sh"

# 3. Integration
log_info "Integrating components..."
source "${SCRIPT_DIR}/integrate.sh"

# 4. WSL Integration if needed
if [[ "$WSL_INTEGRATION" == "true" ]]; then
  log_info "Performing WSL integration..."
  source "${SCRIPT_DIR}/wsl_integration.sh"
fi

# 5. Windows Host configuration if needed
if [[ "$WINDOWS_HOST" == "true" ]]; then
  log_info "Configuring for Windows host access..."
  source "${SCRIPT_DIR}/windows_host.sh"
fi

# 6. Testing
log_info "Running tests..."
source "${SCRIPT_DIR}/test.sh"

# Completion
log_info "Installation completed successfully."
log_info "WordPress URL: http://${CLIENT_ID}.${DOMAIN}"
log_info "Traefik Dashboard: http://traefik.${CLIENT_ID}.${DOMAIN}"
log_info "Logs available at: $LOG_FILE"
