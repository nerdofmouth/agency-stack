#!/bin/bash
# install_infrastructure.sh - Core infrastructure setup for AgencyStack
# https://stack.nerdofmouth.com
#
# This script installs and configures the core infrastructure components:
# - System prerequisites (utilities, libraries)
# - Docker Engine
# - Docker Compose
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
INSTALL_LOG="${LOG_DIR}/install.log"
VERBOSE=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Infrastructure Setup${NC}"
  echo -e "======================================"
  echo -e "This script installs and configures the core infrastructure components for AgencyStack:"
  echo -e "  - System prerequisites (utilities, libraries)"
  echo -e "  - Docker Engine"
  echo -e "  - Docker Compose"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--verbose${NC}          Show detailed output during installation"
  echo -e "  ${BOLD}--skip-docker${NC}      Skip Docker installation (use if already installed)"
  echo -e "  ${BOLD}--skip-compose${NC}     Skip Docker Compose installation"
  echo -e "  ${BOLD}--help${NC}             Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --verbose"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script requires root privileges for installation"
  echo -e "  - Log file is saved to: ${INSTALL_LOG}"
  exit 0
}

# Parse arguments
SKIP_DOCKER=false
SKIP_COMPOSE=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --skip-docker)
      SKIP_DOCKER=true
      shift
      ;;
    --skip-compose)
      SKIP_COMPOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Infrastructure Setup${NC}"
echo -e "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

log "INFO: Starting AgencyStack infrastructure installation" "${BLUE}Starting installation...${NC}"

#######################
# SYSTEM PREREQUISITES
#######################

log "INFO: Installing system prerequisites" "${BLUE}Installing system prerequisites...${NC}"

# Update package lists
log "INFO: Updating package lists" "${CYAN}Updating package lists...${NC}"
apt-get update >> "$INSTALL_LOG" 2>&1
if [ $? -ne 0 ]; then
  log "ERROR: Failed to update package lists" "${RED}Failed to update package lists. See log for details.${NC}"
  exit 1
fi

# Install essential packages
log "INFO: Installing essential packages" "${CYAN}Installing essential packages...${NC}"
PACKAGES="apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release jq git unzip wget"
apt-get install -y $PACKAGES >> "$INSTALL_LOG" 2>&1
if [ $? -ne 0 ]; then
  log "ERROR: Failed to install essential packages" "${RED}Failed to install essential packages. See log for details.${NC}"
  exit 1
fi

log "INFO: Successfully installed system prerequisites" "${GREEN}✅ System prerequisites installed successfully${NC}"

#######################
# DOCKER INSTALLATION
#######################

if [ "$SKIP_DOCKER" = false ]; then
  log "INFO: Installing Docker Engine" "${BLUE}Installing Docker Engine...${NC}"
  
  # Check if Docker is already installed
  if command -v docker &> /dev/null; then
    log "INFO: Docker is already installed" "${YELLOW}Docker is already installed. Skipping installation.${NC}"
    # Show Docker version
    DOCKER_VERSION=$(docker --version)
    log "INFO: $DOCKER_VERSION" "${CYAN}$DOCKER_VERSION${NC}"
  else
    # Add Docker's official GPG key
    log "INFO: Adding Docker GPG key" "${CYAN}Adding Docker GPG key...${NC}"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the Docker repository
    log "INFO: Setting up Docker repository" "${CYAN}Setting up Docker repository...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package lists again
    log "INFO: Updating package lists" "${CYAN}Updating package lists...${NC}"
    apt-get update >> "$INSTALL_LOG" 2>&1
    
    # Install Docker Engine
    log "INFO: Installing Docker Engine, containerd, and Docker CLI" "${CYAN}Installing Docker Engine...${NC}"
    apt-get install -y docker-ce docker-ce-cli containerd.io >> "$INSTALL_LOG" 2>&1
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to install Docker" "${RED}Failed to install Docker. See log for details.${NC}"
      exit 1
    fi
    
    # Enable and start Docker service
    log "INFO: Enabling and starting Docker service" "${CYAN}Enabling and starting Docker service...${NC}"
    systemctl enable docker >> "$INSTALL_LOG" 2>&1
    systemctl start docker >> "$INSTALL_LOG" 2>&1
    
    # Verify Docker installation
    log "INFO: Verifying Docker installation" "${CYAN}Verifying Docker installation...${NC}"
    if ! docker run --rm hello-world >> "$INSTALL_LOG" 2>&1; then
      log "ERROR: Docker verification failed" "${RED}Docker verification failed. See log for details.${NC}"
      exit 1
    fi
    
    # Add current user to the docker group
    if [ -n "$SUDO_USER" ]; then
      log "INFO: Adding user $SUDO_USER to the docker group" "${CYAN}Adding user $SUDO_USER to the docker group...${NC}"
      usermod -aG docker "$SUDO_USER"
      log "INFO: User added to docker group. You may need to log out and back in for this to take effect." "${YELLOW}You may need to log out and back in for group changes to take effect.${NC}"
    fi
  fi
  
  log "INFO: Docker installation completed" "${GREEN}✅ Docker installed successfully${NC}"
fi

#######################
# DOCKER COMPOSE INSTALLATION
#######################

if [ "$SKIP_COMPOSE" = false ]; then
  log "INFO: Installing Docker Compose" "${BLUE}Installing Docker Compose...${NC}"
  
  # Check if Docker Compose is already installed
  if command -v docker-compose &> /dev/null; then
    log "INFO: Docker Compose is already installed" "${YELLOW}Docker Compose is already installed. Skipping installation.${NC}"
    # Show Docker Compose version
    COMPOSE_VERSION=$(docker-compose --version)
    log "INFO: $COMPOSE_VERSION" "${CYAN}$COMPOSE_VERSION${NC}"
  else
    # Install Docker Compose v2
    log "INFO: Installing Docker Compose v2" "${CYAN}Installing Docker Compose v2...${NC}"
    
    # The compose plugin is included in recent Docker Desktop and Docker Engine packages
    # But we'll ensure it's installed separately for compatibility
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
    log "INFO: Latest Docker Compose version: $LATEST_COMPOSE_VERSION" "${CYAN}Latest Docker Compose version: $LATEST_COMPOSE_VERSION${NC}"
    
    # Download Docker Compose
    log "INFO: Downloading Docker Compose" "${CYAN}Downloading Docker Compose...${NC}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    
    # Make it executable
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    # Create symlink for backward compatibility
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    
    # Verify Docker Compose installation
    log "INFO: Verifying Docker Compose installation" "${CYAN}Verifying Docker Compose installation...${NC}"
    if ! docker-compose version >> "$INSTALL_LOG" 2>&1; then
      log "ERROR: Docker Compose verification failed" "${RED}Docker Compose verification failed. See log for details.${NC}"
      exit 1
    fi
  fi
  
  log "INFO: Docker Compose installation completed" "${GREEN}✅ Docker Compose installed successfully${NC}"
fi

# Create Docker network for AgencyStack if it doesn't exist
log "INFO: Creating Docker network for AgencyStack" "${BLUE}Creating Docker network for AgencyStack...${NC}"
if ! docker network inspect agency-network &> /dev/null; then
  docker network create agency-network >> "$INSTALL_LOG" 2>&1
  log "INFO: Created Docker network: agency-network" "${GREEN}✅ Created Docker network: agency-network${NC}"
else
  log "INFO: Docker network agency-network already exists" "${YELLOW}Docker network agency-network already exists${NC}"
fi

# Final message
log "INFO: Infrastructure installation completed successfully" "${GREEN}${BOLD}✅ AgencyStack infrastructure installation completed successfully!${NC}"
echo -e "${CYAN}You can now proceed with installing individual components.${NC}"

exit 0
