#!/bin/bash
# install_docker_compose.sh - Docker Compose installation for AgencyStack
# https://stack.nerdofmouth.com
#
# This script installs and configures Docker Compose with:
# - Version selection
# - System-wide installation
# - Verification of binaries
# - Integration with existing Docker installation
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/common.sh"
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="docker_compose"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

# Docker Compose version - can be overridden with --version
# Use "latest" to get the latest version
DOCKER_COMPOSE_VERSION="latest"
DOCKER_COMPOSE_BIN="/usr/local/bin/docker-compose"

# Show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Installs and configures Docker Compose for AgencyStack"
  echo
  echo "Options:"
  echo "  --domain DOMAIN        Domain name for the installation"
  echo "  --admin-email EMAIL    Admin email for notifications"
  echo "  --client-id ID         Client ID for multi-tenant setup"
  echo "  --version VER          Docker Compose version to install (default: latest)"
  echo "  --force                Force reinstallation even if already installed"
  echo "  --with-deps            Install Docker if not already installed"
  echo "  --verbose              Enable verbose output"
  echo "  --enable-cloud         Enable cloud storage backends"
  echo "  --enable-openai        Enable OpenAI API integration"
  echo "  --use-github           Use GitHub for repository operations"
  echo "  -h, --help             Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --version)
      DOCKER_COMPOSE_VERSION="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Setup logging
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")"
exec &> >(tee -a "${COMPONENT_LOG_FILE}")

# Log function
log() {
  local level="$1"
  local message="$2"
  local display="$3"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${COMPONENT_LOG_FILE}"
  if [[ -n "${display}" ]]; then
    echo -e "${display}"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  local json_data="$2"
  
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"component\":\"${COMPONENT}\",\"message\":\"${message}\",\"data\":${json_data}}" >> "${AGENCY_LOG_DIR}/integration.log"
}

log "INFO" "Starting Docker Compose installation" "${BLUE}Starting Docker Compose installation...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"

# Create necessary directories
mkdir -p "${COMPONENT_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${COMPONENT_CONFIG_DIR}"

# Check for Docker
if ! command -v docker &> /dev/null; then
  log "WARNING" "Docker not found" "${YELLOW}⚠️ Docker not found.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker with --with-deps flag" "${CYAN}Installing Docker with --with-deps flag...${NC}"
    if [ -f "${AGENCY_SCRIPTS_DIR}/components/install_docker.sh" ]; then
      "${AGENCY_SCRIPTS_DIR}/components/install_docker.sh" --domain "${DOMAIN}" --admin-email "${ADMIN_EMAIL}" --client-id "${CLIENT_ID}" >> "${INSTALL_LOG}" 2>&1
      log "SUCCESS" "Docker installed" "${GREEN}✅ Docker installed.${NC}"
    else
      log "ERROR" "Docker installation script not found" "${RED}❌ Docker installation script not found.${NC}"
      exit 1
    fi
  else
    log "ERROR" "Docker is required but not installed" "${RED}❌ Docker is required but not installed.${NC}"
    log "INFO" "Install Docker first or use --with-deps" "${CYAN}Install Docker first or use --with-deps flag.${NC}"
    exit 1
  fi
fi

# Check for existing Docker Compose installation
if command -v docker-compose &> /dev/null && [[ "${FORCE}" != "true" ]]; then
  CURRENT_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
  log "INFO" "Docker Compose already installed (version ${CURRENT_VERSION})" "${GREEN}✅ Docker Compose already installed (version ${CURRENT_VERSION})${NC}"
  
  # Create installation marker if it doesn't exist
  if [[ ! -f "${COMPONENT_INSTALLED_MARKER}" ]]; then
    touch "${COMPONENT_INSTALLED_MARKER}"
    log "INFO" "Added installation marker for existing Docker Compose" "${CYAN}Added installation marker for existing Docker Compose${NC}"
  fi
  
  # Exit if we're not forcing reinstallation
  if [[ "${FORCE}" != "true" ]]; then
    log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
    exit 0
  fi
fi

# Download and install Docker Compose
log "INFO" "Downloading Docker Compose" "${CYAN}Downloading Docker Compose...${NC}"

# Determine download URL based on version
if [[ "${DOCKER_COMPOSE_VERSION}" == "latest" ]]; then
  DOWNLOAD_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64"
  log "INFO" "Using latest Docker Compose version" "${CYAN}Using latest Docker Compose version${NC}"
else
  DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64"
  log "INFO" "Using Docker Compose version ${DOCKER_COMPOSE_VERSION}" "${CYAN}Using Docker Compose version ${DOCKER_COMPOSE_VERSION}${NC}"
fi

# Download to a temporary location
TMP_DOWNLOAD="${INSTALL_DIR}/docker-compose-tmp"
if [[ "${VERBOSE}" == "true" ]]; then
  curl -SL "${DOWNLOAD_URL}" -o "${TMP_DOWNLOAD}"
else
  curl -SL "${DOWNLOAD_URL}" -o "${TMP_DOWNLOAD}" >> "${INSTALL_LOG}" 2>&1
fi

# Check if download was successful
if [[ ! -f "${TMP_DOWNLOAD}" ]]; then
  log "ERROR" "Failed to download Docker Compose" "${RED}❌ Failed to download Docker Compose.${NC}"
  exit 1
fi

# Check file integrity
FILE_SIZE=$(stat -c%s "${TMP_DOWNLOAD}")
if [[ ${FILE_SIZE} -lt 1000000 ]]; then
  log "ERROR" "Downloaded file too small, likely not valid: ${FILE_SIZE} bytes" "${RED}❌ Downloaded file too small, likely not valid: ${FILE_SIZE} bytes.${NC}"
  exit 1
fi

# Make executable and move to final location
chmod +x "${TMP_DOWNLOAD}"
mv "${TMP_DOWNLOAD}" "${DOCKER_COMPOSE_BIN}"

# Verify installation
if command -v docker-compose &> /dev/null; then
  INSTALLED_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
  log "SUCCESS" "Docker Compose installed successfully (version ${INSTALLED_VERSION})" "${GREEN}✅ Docker Compose installed successfully (version ${INSTALLED_VERSION})${NC}"
  
  # Save version information
  echo "${INSTALLED_VERSION}" > "${COMPONENT_DIR}/version.txt"
else
  log "ERROR" "Docker Compose installation verification failed" "${RED}❌ Docker Compose installation verification failed.${NC}"
  exit 1
fi

# Create a simple Docker Compose test script
log "INFO" "Creating test script" "${CYAN}Creating test script...${NC}"
cat > "${INSTALL_DIR}/test-docker-compose.sh" <<EOL
#!/bin/bash
# Test Docker Compose functionality

set -e

# Create a simple docker-compose file
DOCKER_COMPOSE_FILE="\$(mktemp -d)/docker-compose.yml"

cat > "\${DOCKER_COMPOSE_FILE}" <<EOF
version: '3'
services:
  hello-world:
    image: hello-world
    container_name: docker-compose-test
EOF

# Run the compose file
echo "Testing Docker Compose with a simple hello-world container..."
docker-compose -f "\${DOCKER_COMPOSE_FILE}" up

# Clean up
docker-compose -f "\${DOCKER_COMPOSE_FILE}" down
rm "\${DOCKER_COMPOSE_FILE}"

echo "Docker Compose test completed successfully."
EOL

chmod +x "${INSTALL_DIR}/test-docker-compose.sh"

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Docker Compose installed" "{\"version\":\"${INSTALLED_VERSION}\",\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\"}"

log "SUCCESS" "Docker Compose installation completed" "${GREEN}✅ Docker Compose installation completed!${NC}"
echo
log "INFO" "Docker Compose information" "${CYAN}Docker Compose information:${NC}"
echo -e "  - Version: ${INSTALLED_VERSION}"
echo -e "  - Binary: ${DOCKER_COMPOSE_BIN}"
echo
echo -e "${GREEN}You can now use Docker Compose for container orchestration.${NC}"
echo -e "${CYAN}Test script available at: ${INSTALL_DIR}/test-docker-compose.sh${NC}"

exit 0
