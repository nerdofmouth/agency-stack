#!/bin/bash
# AgencyStack Component Installer: System Prerequisites
# Path: /scripts/components/install_prerequisites.sh
#
# Installs and configures basic system dependencies required
# by all other AgencyStack components.
#
# This follows the standard AgencyStack component structure
# and delegates to core infrastructure scripts as needed.

# Set strict error handling
set -euo pipefail

# Script location and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")/core"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source common utilities
if [ -f "$UTILS_DIR/common.sh" ]; then
  source "$UTILS_DIR/common.sh"
else
  # Fallback logging if common.sh isn't available
  log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] [Prerequisites] [$level] $message"
    
    if [ -n "${3:-}" ]; then
      echo -e "$3"
    fi
  }
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Display banner
echo -e "${BLUE}${BOLD}"
echo -e "╭───────────────────────────────────────────────────╮"
echo -e "│                                                   │"
echo -e "│  AgencyStack Prerequisites Component Installer    │"
echo -e "│                                                   │"
echo -e "╰───────────────────────────────────────────────────╯"
echo -e "${NC}"

# Main installation function
install_prerequisites() {
  log "INFO" "Starting prerequisites installation" "${BLUE}Installing system prerequisites...${NC}"
  
  # Create required directories
  mkdir -p /opt/agency_stack/clients/default
  mkdir -p /opt/agency_stack/secrets
  mkdir -p /var/log/agency_stack/clients
  mkdir -p /var/log/agency_stack/components
  
  # If the core infrastructure script exists, use it
  if [ -f "$CORE_DIR/install_infrastructure.sh" ]; then
    log "INFO" "Delegating to core infrastructure script" "${CYAN}Using core infrastructure script...${NC}"
    bash "$CORE_DIR/install_infrastructure.sh" --prerequisites-only
    
    # Check status
    if [ $? -eq 0 ]; then
      log "INFO" "Prerequisites installation completed successfully" "${GREEN}✅ Prerequisites installation successful${NC}"
      return 0
    else
      log "ERROR" "Prerequisites installation failed" "${RED}❌ Prerequisites installation failed${NC}"
      return 1
    fi
  else
    # Fallback installation if the core script isn't available
    log "WARN" "Core infrastructure script not found, using fallback installation" "${YELLOW}Core script not found, using fallback installation...${NC}"
    
    # Update package lists
    log "INFO" "Updating package lists" "${BLUE}Updating package lists...${NC}"
    apt-get update -qq || {
      log "ERROR" "Failed to update package lists" "${RED}Failed to update package lists${NC}"
      return 1
    }
    
    # Install essential packages
    log "INFO" "Installing essential packages" "${BLUE}Installing essential packages...${NC}"
    apt-get install -y -qq \
      curl wget git make jq bc \
      openssl unzip procps htop \
      apt-transport-https ca-certificates \
      software-properties-common gnupg lsb-release \
      || {
        log "ERROR" "Failed to install essential packages" "${RED}Failed to install essential packages${NC}"
        return 1
      }
    
    # Set up log rotation
    log "INFO" "Setting up log rotation" "${BLUE}Setting up log rotation...${NC}"
    if [ ! -f "/etc/logrotate.d/agency_stack" ]; then
      cat > /etc/logrotate.d/agency_stack << 'EOF'
/var/log/agency_stack/*.log {
  daily
  rotate 14
  compress
  delaycompress
  notifempty
  create 0640 root root
  missingok
}
EOF
      log "INFO" "Created log rotation configuration" "${GREEN}✅ Log rotation configuration created${NC}"
    else
      log "INFO" "Log rotation configuration already exists" "${YELLOW}Log rotation configuration already exists${NC}"
    fi
    
    # Verify logrotate config (in debug mode to prevent actual rotation)
    logrotate -d /etc/logrotate.d/agency_stack
    
    log "INFO" "Prerequisites installation completed" "${GREEN}✅ System prerequisites installed successfully${NC}"
  fi
  
  return 0
}

# Run installation
install_prerequisites

exit $?
