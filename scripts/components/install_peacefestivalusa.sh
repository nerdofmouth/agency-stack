#!/bin/bash

# PeaceFestivalUSA Installation Wrapper
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Idempotency & Automation
# - Component Consistency
# - Strict Containerization

set -e

# Script location and common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${COMPONENTS_DIR}/.." && pwd)"

# Source common utilities
if [[ -f "${COMPONENTS_DIR}/utils/common.sh" ]]; then
  source "${COMPONENTS_DIR}/utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Configuration defaults
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost"
FORCE="false"
WSL_INTEGRATION="false"
WINDOWS_HOST="false"

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
      # Auto-enable WSL integration if windows-host is specified
      WSL_INTEGRATION="true"
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --client-id=VALUE   Set client ID (default: peacefestivalusa)"
      echo "  --domain=VALUE      Set domain (default: localhost)"
      echo "  --force             Force reinstallation"
      echo "  --wsl               Enable WSL integration"
      echo "  --windows-host      Configure for Windows host access (implies --wsl)"
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

# Auto-detect WSL environment if not specified
if [[ "$WSL_INTEGRATION" == "false" ]]; then
  if grep -q Microsoft /proc/version; then
    echo "WSL environment detected, enabling WSL integration"
    WSL_INTEGRATION="true"
  fi
fi

# Set component directory
PEACEFESTIVALUSA_DIR="${SCRIPT_DIR}/peacefestivalusa"

# Check if component directory exists
if [[ ! -d "${PEACEFESTIVALUSA_DIR}/install" ]]; then
  echo "ERROR: PeaceFestivalUSA installation scripts not found at ${PEACEFESTIVALUSA_DIR}/install"
  exit 1
fi

# Execute main installation script
export CLIENT_ID DOMAIN FORCE WSL_INTEGRATION WINDOWS_HOST
cd "${PEACEFESTIVALUSA_DIR}/install" && bash ./main.sh

echo "Installation completed successfully!"

# If Windows host access was enabled, display browser access instructions
if [[ "$WINDOWS_HOST" == "true" ]]; then
  echo ""
  echo "===== Windows Browser Access Instructions ====="
  echo "To access from your Windows browser:"
  echo ""
  echo "1. Add these entries to your Windows hosts file:"
  echo "   127.0.0.1 ${CLIENT_ID}.${DOMAIN}"
  echo "   127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN}"
  echo ""
  echo "2. Then open these URLs in your Windows browser:"
  echo "   WordPress: http://${CLIENT_ID}.${DOMAIN}"
  echo "   Traefik Dashboard: http://traefik.${CLIENT_ID}.${DOMAIN}"
  echo ""
  echo "For detailed instructions and troubleshooting:"
  echo "/opt/agency_stack/clients/${CLIENT_ID}/windows_browser_access.md"
fi
