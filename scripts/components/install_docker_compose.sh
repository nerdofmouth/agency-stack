#!/bin/bash
# install_docker_compose.sh - AgencyStack Docker Compose Component Installer
# Installs and configures Docker Compose for AgencyStack
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
COMPOSE_CONFIG_DIR="${CONFIG_DIR}/docker_compose"

# Log file
LOG_FILE="${LOG_DIR}/docker_compose.log"

# Default values
FORCE=false
CLIENT_ID="default"
DOMAIN="localhost"
COMPOSE_VERSION="v2.21.0"  # Default version

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
    echo "  --force                    Force reinstallation even if Docker Compose is already installed"
    echo "  --client-id <id>           Set client ID (default: default)"
    echo "  --domain <domain>          Set domain name (default: localhost)"
    echo "  --compose-version <ver>    Set Docker Compose version (default: ${COMPOSE_VERSION})"
    echo "  --help                     Show this help message"
    exit 1
}

ensure_dirs() {
    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${COMPOSE_CONFIG_DIR}" 2>/dev/null || true
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/docker_compose" 2>/dev/null || true
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Create log file if it doesn't exist
    touch "${LOG_FILE}" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${COMPOSE_CONFIG_DIR}" 2>/dev/null || true
    chmod 755 "${CONFIG_DIR}/clients/${CLIENT_ID}/docker_compose" 2>/dev/null || true
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 644 "${LOG_FILE}" 2>/dev/null || true
}

check_docker_installed() {
    if ! command -v docker &>/dev/null; then
        log "ERROR: Docker is not installed. Please install Docker first." "${RED}ERROR: Docker is not installed. Please install Docker first.${NC}"
        echo "Run: make docker"
        exit 1
    fi
}

check_compose_installed() {
    if docker compose version &>/dev/null || command -v docker-compose &>/dev/null; then
        if [ "$FORCE" = false ]; then
            EXISTING_VERSION=""
            if docker compose version &>/dev/null; then
                EXISTING_VERSION=$(docker compose version --short)
                log "Docker Compose plugin is already installed (${EXISTING_VERSION})."
            elif command -v docker-compose &>/dev/null; then
                EXISTING_VERSION=$(docker-compose --version | cut -d ' ' -f 3 | tr -d ',')
                log "Standalone Docker Compose is already installed (${EXISTING_VERSION})."
            fi
            
            echo -e "${GREEN}Docker Compose is already installed (${EXISTING_VERSION}).${NC}"
            echo "To force reinstallation, use the --force flag."
            return 0
        else
            log "Docker Compose is already installed but --force flag is set. Proceeding with reinstallation."
            echo -e "${YELLOW}Docker Compose is already installed but will be reinstalled due to --force flag.${NC}"
            return 1
        fi
    else
        return 1
    fi
}

install_compose_plugin() {
    log "Installing Docker Compose as a plugin..."
    echo -e "${CYAN}Installing Docker Compose as a plugin...${NC}"
    
    # For Compose V2, prefer the Docker CLI plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    # Test Docker Compose installation
    if docker compose version; then
        INSTALLED_VERSION=$(docker compose version --short)
        log "Docker Compose plugin installed successfully: ${INSTALLED_VERSION}"
        echo -e "${GREEN}Docker Compose plugin installed successfully: ${INSTALLED_VERSION}${NC}"
    else
        log "ERROR: Failed to install Docker Compose plugin." "${RED}ERROR: Failed to install Docker Compose plugin.${NC}"
        exit 1
    fi
}

configure_compose() {
    log "Configuring Docker Compose..."
    echo -e "${CYAN}Configuring Docker Compose...${NC}"
    
    # Create default configuration directory
    mkdir -p "${COMPOSE_CONFIG_DIR}/templates"
    
    # Create a basic docker-compose.yml template
    cat > "${COMPOSE_CONFIG_DIR}/templates/base.yml" << EOF
version: '3.8'

networks:
  agencystack:
    external: false

volumes:
  data:
    driver: local

services:
  # Base service template
  base:
    restart: unless-stopped
    networks:
      - agencystack
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    # Copy to client-specific location
    mkdir -p "${CONFIG_DIR}/clients/${CLIENT_ID}/docker_compose/templates"
    cp "${COMPOSE_CONFIG_DIR}/templates/base.yml" "${CONFIG_DIR}/clients/${CLIENT_ID}/docker_compose/templates/"
    
    log "Docker Compose configured successfully"
    echo -e "${GREEN}Docker Compose configured successfully${NC}"
}

create_compose_wrapper() {
    log "Creating Docker Compose wrapper script..."
    echo -e "${CYAN}Creating Docker Compose wrapper script...${NC}"
    
    # Create a wrapper script for consistent Docker Compose usage
    cat > "${COMPOSE_CONFIG_DIR}/docker-compose-wrapper.sh" << 'EOF'
#!/bin/bash
# Docker Compose wrapper for AgencyStack
# Provides consistent environment and config handling

# Get client ID from environment or default
CLIENT_ID="${CLIENT_ID:-default}"
CONFIG_DIR="/opt/agency_stack"

# Set environment variables
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1
export COMPOSE_HTTP_TIMEOUT=300

# Execute docker-compose with all arguments passed to this script
docker compose "$@"
EOF
    
    chmod +x "${COMPOSE_CONFIG_DIR}/docker-compose-wrapper.sh"
    
    # Create symbolic link for easy access
    ln -sf "${COMPOSE_CONFIG_DIR}/docker-compose-wrapper.sh" /usr/local/bin/agencystack-compose
    
    log "Docker Compose wrapper script created"
    echo -e "${GREEN}Docker Compose wrapper script created${NC}"
    echo -e "You can use ${CYAN}agencystack-compose${NC} instead of docker compose for consistent configuration"
}

register_component() {
    log "Registering Docker Compose component..."
    echo -e "${CYAN}Registering Docker Compose component...${NC}"
    
    # Create a component registration file
    mkdir -p "${CONFIG_DIR}/registry"
    INSTALLED_VERSION=$(docker compose version --short)
    
    cat > "${CONFIG_DIR}/registry/docker_compose.json" << EOF
{
  "name": "Docker Compose",
  "version": "${INSTALLED_VERSION}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "active",
  "config_dir": "${COMPOSE_CONFIG_DIR}",
  "log_file": "${LOG_FILE}",
  "client_id": "${CLIENT_ID}",
  "domain": "${DOMAIN}"
}
EOF
    
    log "Docker Compose component registered"
    echo -e "${GREEN}Docker Compose component registered${NC}"
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
        --compose-version)
            COMPOSE_VERSION="$2"
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

echo -e "${MAGENTA}${BOLD}🐙 Installing Docker Compose for AgencyStack...${NC}"
log "Starting Docker Compose installation..."

# Ensure we have necessary directories
ensure_dirs

# Check if Docker is installed
check_docker_installed

# Check if Docker Compose is already installed
if check_compose_installed; then
    # Docker Compose is already installed and --force is not set
    configure_compose
    create_compose_wrapper
    register_component
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root" "${RED}ERROR: This script must be run as root${NC}"
    echo "Please run as root or with sudo"
    exit 1
fi

# Install and configure Docker Compose
install_compose_plugin
configure_compose
create_compose_wrapper
register_component

log "Docker Compose installation completed successfully"
echo -e "${GREEN}${BOLD}✅ Docker Compose installation completed successfully${NC}"
echo -e "You can check Docker Compose status with: ${CYAN}make docker-compose-status${NC}"
