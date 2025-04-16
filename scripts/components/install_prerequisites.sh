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

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"
AGENCY_CORE_DIR="${AGENCY_SCRIPTS_DIR}/core"

# Ensure log directory exists
mkdir -p "${AGENCY_LOG_DIR}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
INSTALL_LOG="${AGENCY_LOG_DIR}/prerequisites-${TIMESTAMP}.log"
touch "${INSTALL_LOG}" || { echo "Failed to create log file. Please run with sudo."; exit 1; }

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [Prerequisites] [$level] $message" | tee -a "${INSTALL_LOG}"
  
  # Also log to main install log if it exists
  if [ -f "${AGENCY_LOG_DIR}/install.log" ]; then
    echo -e "[$timestamp] [Prerequisites] [$level] $message" >> "${AGENCY_LOG_DIR}/install.log"
  fi
  
  if [ -n "${3:-}" ]; then
    echo -e "$3" | tee -a "${INSTALL_LOG}"
    if [ -f "${AGENCY_LOG_DIR}/install.log" ]; then
      echo -e "$3" >> "${AGENCY_LOG_DIR}/install.log"
    fi
  fi
}

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

# Check if we are running as root
if [ "$(id -u)" -ne 0 ]; then
  log "ERROR" "This script must be run as root" "${RED}Error: This script must be run as root${NC}"
  echo -e "Please run with sudo or as root user."
  exit 1
fi

# Create required directories with absolute paths
create_directories() {
  log "INFO" "Creating required directories" "${BLUE}Creating required directories...${NC}"
  
  # Create standard AgencyStack directories
  mkdir -p "${AGENCY_ROOT}/clients/default"
  mkdir -p "${AGENCY_ROOT}/secrets"
  mkdir -p "${AGENCY_ROOT}/clients/default/config"
  mkdir -p "${AGENCY_ROOT}/clients/default/data"
  mkdir -p "${AGENCY_LOG_DIR}/clients"
  mkdir -p "${AGENCY_LOG_DIR}/components"
  mkdir -p "${AGENCY_LOG_DIR}/integrations"
  
  log "INFO" "Directory structure setup complete" "${GREEN}Directory structure setup complete${NC}"
  return 0
}

# Make sure we have basic system packages
install_system_packages() {
  log "INFO" "Installing essential system packages" "${BLUE}Installing essential system packages...${NC}"
  
  # Ensure non-interactive apt
  export DEBIAN_FRONTEND=noninteractive
  
  # Update package lists
  apt-get update -qq || {
    log "ERROR" "Failed to update package lists" "${RED}Failed to update package lists${NC}"
    return 1
  }
  
  # Install essential packages
  log "INFO" "Installing required packages" "${BLUE}Installing required packages...${NC}"
  apt-get install -y -qq \
    curl wget git make jq bc \
    openssl unzip procps htop \
    apt-transport-https ca-certificates \
    gnupg lsb-release python3 python3-pip \
    software-properties-common \
    vim zsh net-tools dnsutils \
    || {
      log "ERROR" "Failed to install essential packages" "${RED}Failed to install essential packages${NC}"
      return 1
    }
  
  log "INFO" "Essential packages installed successfully" "${GREEN}Essential packages installed successfully${NC}"
  return 0
}

# Configure log rotation for AgencyStack
setup_log_rotation() {
  log "INFO" "Setting up log rotation" "${BLUE}Setting up log rotation...${NC}"
  
  # Create logrotate configuration if it doesn't exist
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
  log "INFO" "Testing log rotation configuration" "${BLUE}Testing log rotation configuration...${NC}"
  logrotate -d /etc/logrotate.d/agency_stack
  
  log "INFO" "Log rotation has been configured" "${GREEN}✅ Log rotation has been configured${NC}"
  echo "Logs will be rotated daily and kept for 14 days"
  echo "Configuration: /etc/logrotate.d/agency_stack"
  return 0
}

# Configure basic firewall
setup_firewall() {
  log "INFO" "Setting up basic firewall" "${BLUE}Setting up basic firewall...${NC}"
  
  # Check if UFW is installed, if not install it
  if ! command -v ufw &> /dev/null; then
    log "INFO" "Installing UFW firewall" "${BLUE}Installing UFW firewall...${NC}"
    apt-get install -y -qq ufw || {
      log "WARN" "Failed to install UFW, skipping firewall setup" "${YELLOW}Failed to install UFW, skipping firewall setup${NC}"
      return 0
    }
  fi
  
  # Only configure if UFW is not already active
  if ! ufw status | grep -q "Status: active"; then
    log "INFO" "Configuring firewall rules" "${BLUE}Configuring firewall rules...${NC}"
    
    # Default policy
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall without prompting
    echo "y" | ufw enable
    
    log "INFO" "Firewall configured and enabled" "${GREEN}✅ Firewall configured and enabled${NC}"
  else
    log "INFO" "Firewall already configured" "${YELLOW}Firewall already active, skipping configuration${NC}"
  fi
  
  return 0
}

# Function to check if core infrastructure script exists and use it
check_core_infrastructure() {
  if [ -f "${AGENCY_CORE_DIR}/install_infrastructure.sh" ]; then
    log "INFO" "Found core infrastructure script" "${CYAN}Found core infrastructure script, using it for additional setup...${NC}"
    return 0
  else
    log "INFO" "Core infrastructure script not found" "${YELLOW}Core infrastructure script not found, using fallback implementation${NC}"
    return 1
  fi
}

# Main installation function
install_prerequisites() {
  # Check if prerequisites have already been installed
  if [ -f "${AGENCY_ROOT}/.prerequisites_ok" ]; then
    log "INFO" "Prerequisites already installed" "${GREEN}Prerequisites already installed, skipping...${NC}"
    return 0
  fi

  log "INFO" "Starting prerequisites installation" "${BLUE}Installing system prerequisites...${NC}"
  
  # Create required directories
  create_directories
  
  # Install system packages
  install_system_packages
  
  # Set up log rotation
  setup_log_rotation
  
  # Set up basic firewall
  setup_firewall
  
  # If the core infrastructure script exists, use it for additional setup
  if check_core_infrastructure; then
    log "INFO" "Running core infrastructure script" "${CYAN}Running core infrastructure script...${NC}"
    
    # Try to run with --prerequisites-only first, then fallback to no arguments if it fails
    if ! bash "${AGENCY_CORE_DIR}/install_infrastructure.sh" --prerequisites-only 2>/dev/null; then
      log "INFO" "Trying core infrastructure script with no arguments" "${YELLOW}--prerequisites-only option not recognized, trying without arguments...${NC}"
      bash "${AGENCY_CORE_DIR}/install_infrastructure.sh" || {
        log "WARN" "Core infrastructure script returned non-zero, continuing with basic setup" "${YELLOW}Core script returned non-zero, continuing with basic setup${NC}"
      }
    fi
  fi
  
  # Create marker file indicating successful prerequisites installation
  touch "${AGENCY_ROOT}/.prerequisites_ok"
  
  log "INFO" "Prerequisites installation completed" "${GREEN}✅ System prerequisites installed successfully${NC}"
  return 0
}

# Run installation
install_prerequisites
EXIT_CODE=$?

# Return exit code
exit $EXIT_CODE
