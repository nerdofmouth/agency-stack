#!/bin/bash
# AgencyStack One-Line Installer
# A wrapper script that prepares environments for first-run installations
# Following AgencyStack DevOps rules

set -e

# Colors for output
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Setup logging
LOGDIR="/var/log/agency_stack"
mkdir -p "$LOGDIR"
DATE=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOGDIR/one_line_installer-$DATE.log"
touch "$LOGFILE" || { echo "Failed to create log file. Please run with sudo."; exit 1; }

# Banner
echo -e "${MAGENTA}${BOLD}"
echo "   _____                             _____ __             __  "
echo "  /  _  \   ____   ____   ____     / ___// /_____ ______/ /__"
echo " /  /_\  \ / ___\ /    \_/ __ \    \__ \/ __/ __ \/ ___/ //_/"
echo "/    |    / /_/  >   |  \  ___/   ___/ / /_/ /_/ / /__/ ,<   "
echo "\____|__  \___  /|___|  /\___  > /____/\__/\__,_/\___/_/|_|  "
echo "        \/_____/      \/     \/                              "
echo -e "${RESET}"

echo -e "${CYAN}One-Line Installer${RESET}"
echo "By Nerd of Mouth - Deploy Smart. Speak Nerd."
echo "https://stack.nerdofmouth.com"
echo ""
echo "\"The Agency Project: Metal + Meaning.\""
echo ""

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack] [$level] $message" | tee -a "$LOGFILE"
}

echo -e "${CYAN}Logging to: $LOGFILE${RESET}"
log "INFO" "Starting AgencyStack One-Line Installer"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root${RESET}"
  echo "Please run with sudo or as the root user"
  exit 1
fi

# System check
echo -e "${BOLD}Performing system checks...${RESET}"
OS=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
PRETTY_NAME=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')

if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
  echo -e "✓ Detected ${GREEN}$PRETTY_NAME${RESET} - Recommended OS"
else
  echo -e "${YELLOW}⚠️ Detected $PRETTY_NAME - Not officially supported but will attempt installation${RESET}"
fi
log "INFO" "System checks completed"

# Install essential dependencies first
install_essential_dependencies() {
  log "INFO" "Installing essential dependencies"
  echo -e "${BOLD}Installing required dependencies...${RESET}"
  apt-get update
  
  # Install basic utilities required for the Makefile to run
  log "INFO" "Installing basic utilities (curl, git, wget, make, jq, bc)"
  echo -e "${BLUE}Installing basic utilities...${RESET}"
  apt-get install -y curl git wget make jq bc
  
  if ! command -v make &> /dev/null; then
    log "ERROR" "Failed to install make, which is required for installation"
    echo -e "${RED}Failed to install make, which is required for installation${RESET}"
    exit 1
  fi
  
  log "INFO" "Essential dependencies installed successfully"
}

# Setup directory structure
setup_directory_structure() {
  log "INFO" "Setting up required directories"
  echo -e "${BOLD}Setting up required directory structure...${RESET}"
  
  # Create base directories according to AgencyStack DevOps rules
  mkdir -p /opt/agency_stack/clients/default
  mkdir -p /opt/agency_stack/secrets
  mkdir -p /var/log/agency_stack/clients
  mkdir -p /var/log/agency_stack/components
  mkdir -p /var/log/agency_stack/integrations
  
  # If we have the component directory setup utility, use it
  if [ -f "$ROOT_DIR/scripts/utils/setup_component_directories.sh" ]; then
    log "INFO" "Running component directory setup utility"
    echo -e "${BLUE}Setting up component directories using utility script...${RESET}"
    bash "$ROOT_DIR/scripts/utils/setup_component_directories.sh" --force
  else
    log "WARN" "Component directory setup utility not found, continuing with basic setup"
    # Create just the basic component directory
    mkdir -p /opt/agency_stack/components
  fi
  
  log "INFO" "Directory structure set up successfully"
}

# Clone repository if not already present
clone_or_update_repo() {
  if [ -z "$ROOT_DIR" ] || [ ! -d "$ROOT_DIR" ]; then
    log "INFO" "AgencyStack repository not found. Cloning..."
    echo -e "${BOLD}Cloning AgencyStack repository...${RESET}"
    
    git clone https://github.com/nerdofmouth/agency-stack.git /tmp/agency_stack
    ROOT_DIR="/tmp/agency_stack"
    
    log "INFO" "Repository cloned to $ROOT_DIR"
  else
    log "INFO" "Using existing repository at $ROOT_DIR"
  fi
}

# Main installation process
main() {
  # 1. Install essential dependencies
  install_essential_dependencies
  
  # 2. Setup directory structure
  setup_directory_structure
  
  # 3. Clone or identify repository
  clone_or_update_repo
  
  # 4. Run prep-dirs to set up component directories
  echo -e "${BOLD}Running prep-dirs target...${RESET}"
  log "INFO" "Running make prep-dirs"
  
  cd "$ROOT_DIR"
  make prep-dirs || {
    log "WARN" "make prep-dirs encountered issues, continuing anyway"
    echo -e "${YELLOW}prep-dirs encountered issues, continuing...${RESET}"
  }
  
  # 5. Run env-check to validate environment
  echo -e "${BOLD}Running environment check...${RESET}"
  log "INFO" "Running make env-check"
  
  make env-check || {
    log "WARN" "Environment check reported issues"
    echo -e "${YELLOW}Environment check reported issues, these will be fixed during installation${RESET}"
  }
  
  # 6. Display next steps for the user
  echo -e "\n${GREEN}${BOLD}AgencyStack environment prepared successfully!${RESET}"
  echo -e "${CYAN}Ready for component installation.${RESET}"
  echo -e "\nNext steps:"
  echo -e "  ${BOLD}1. Run Docker infrastructure installation:${RESET}"
  echo -e "     cd ${ROOT_DIR}"
  echo -e "     sudo make docker"
  echo -e "     sudo make docker_compose"
  echo -e "\n  ${BOLD}2. Install Traefik and SSL:${RESET}"
  echo -e "     sudo make traefik-ssl"
  echo -e "\n  ${BOLD}3. Add security components:${RESET}"
  echo -e "     sudo make fail2ban"
  echo -e "     sudo make crowdsec"
  echo -e "\n  ${BOLD}4. Check installation status:${RESET}"
  echo -e "     sudo make alpha-check"
  
  log "INFO" "One-line installer completed successfully"
}

# Run the main function
main

exit 0
