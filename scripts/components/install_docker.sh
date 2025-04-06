#!/bin/bash
# install_docker.sh - AgencyStack Docker Component Installer
# Installs and configures Docker for AgencyStack
# v0.1.0-alpha

# Exit on error
set -e

# Colors for output
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
NC="\033[0m" # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack/components"
DOCKER_CONFIG_DIR="${CONFIG_DIR}/docker"

# Log file
LOG_FILE="${LOG_DIR}/docker.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"

# -----------------------------------------------------------------------------
# Function Definitions
# -----------------------------------------------------------------------------

log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" | tee -a "${LOG_FILE}"
    if [ -n "$2" ]; then
        echo -e "$2"
    fi
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force                    Force reinstallation even if Docker is already installed"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${DOCKER_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/docker" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${DOCKER_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/docker" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_docker_installed() {
    if command -v docker &>/dev/null; then
        if [ "$FORCE" = false ]; then
            log "Docker is already installed. Use --force to reinstall."
            echo -e "${GREEN}Docker is already installed.${NC}"
            echo "To force reinstallation, use the --force flag."
            echo "Current Docker version: $(docker --version)"
            return 0
        else
            log "Docker is already installed but --force flag is set. Proceeding with reinstallation."
            echo -e "${YELLOW}Docker is already installed but will be reinstalled due to --force flag.${NC}"
            return 1
        fi
    else
        return 1
    fi
}

install_dependencies() {
    log "Installing dependencies..."
    echo -e "${CYAN}Installing dependencies...${NC}"
    
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common
}

install_docker() {
    log "Installing Docker..."
    echo -e "${CYAN}Installing Docker...${NC}"
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure Docker daemon
    configure_docker
    
    # Test Docker installation
    docker --version
    log "Docker installed successfully: $(docker --version)"
    echo -e "${GREEN}Docker installed successfully: $(docker --version)${NC}"
}

configure_docker() {
    log "Configuring Docker..."
    echo -e "${CYAN}Configuring Docker...${NC}"
    
    # Create daemon.json configuration file
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "live-restore": true,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "metrics-addr": "127.0.0.1:9323",
  "experimental": false
}
EOF
    
    # Create client-specific configuration
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/docker"
    cp /etc/docker/daemon.json "${CONFIG_DIR}/clients/${CLIENT_ID}/docker/daemon.json"
    
    # Restart Docker to apply configuration
    systemctl restart docker
    
    log "Docker configured successfully"
    echo -e "${GREEN}Docker configured successfully${NC}"
}

setup_security() {
    log "Setting up Docker security..."
    echo -e "${CYAN}Setting up Docker security...${NC}"
    
    # Add current user to docker group to avoid using sudo
    usermod -aG docker "$(whoami)" 2>/dev/null || true
    
    log "Docker security setup completed"
    echo -e "${GREEN}Docker security setup completed${NC}"
    echo -e "${YELLOW}NOTE: You may need to log out and back in for group changes to take effect${NC}"
}

register_component() {
    log "Registering Docker component..."
    echo -e "${CYAN}Registering Docker component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry"
    cat > "${CONFIG_DIR}/registry/docker.json" << EOF
{
  "name": "Docker",
  "version": "$(docker --version | cut -d ' ' -f 3 | tr -d ',')",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${DOCKER_CONFIG_DIR}",
  "log_file": "${LOG_FILE}",
  "client_id": "${CLIENT_ID}",
  "domain": "${DOMAIN}"
}
EOF
    
    log "Docker component registered"
    echo -e "${GREEN}Docker component registered${NC}"
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

# Process command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo -e "${MAGENTA}${BOLD}🐳 Installing Docker for AgencyStack...${NC}"
log "Starting Docker installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if Docker is already installed
if check_docker_installed; then
    # Docker is already installed and --force is not set
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install and configure Docker
install_dependencies
install_docker
setup_security
register_component

log "Docker installation completed successfully"
echo -e "${GREEN}${BOLD}✅ Docker installation completed successfully${NC}"
echo -e "You can check Docker status with: ${CYAN}make docker-status${NC}"
