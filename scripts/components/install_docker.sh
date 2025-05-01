#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: docker.sh
# Path: /scripts/components/install_docker.sh
#

# Enforce containerization (prevent host contamination)

# AgencyStack Component Installer: docker.sh
# Path: /scripts/components/install_docker.sh
#
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Use a robust, portable path for common.sh
source "$(dirname "$0")/../utils/log_helpers.sh"

# Define component-specific variables
COMPONENT="docker"
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

# Docker version - can be overridden with --version
DOCKER_VERSION="latest"
DOCKER_COMPOSE_VERSION="latest"

# Show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Installs and configures Docker for AgencyStack"
  echo
  echo "Options:"
  echo "  --domain DOMAIN        Domain name for the installation"
  echo "  --admin-email EMAIL    Admin email for notifications"
  echo "  --client-id ID         Client ID for multi-tenant setup"
  echo "  --version VER          Docker version to install (default: latest)"
  echo "  --force                Force reinstallation even if already installed"
  echo "  --with-deps            Install dependencies if missing"
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
      DOCKER_VERSION="$2"
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

log "INFO" "Starting Docker installation" "${BLUE}Starting Docker installation...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"

# Create necessary directories
mkdir -p "${COMPONENT_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${COMPONENT_CONFIG_DIR}"

# Check for existing Docker installation
if command -v docker &> /dev/null && [[ "${FORCE}" != "true" ]]; then
  CURRENT_DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
  log "INFO" "Docker already installed (version ${CURRENT_DOCKER_VERSION})" "${GREEN}✅ Docker already installed (version ${CURRENT_DOCKER_VERSION})${NC}"
  
  # Create installation marker if it doesn't exist
  if [[ ! -f "${COMPONENT_INSTALLED_MARKER}" ]]; then
    touch "${COMPONENT_INSTALLED_MARKER}"
    log "INFO" "Added installation marker for existing Docker" "${CYAN}Added installation marker for existing Docker${NC}"
  fi
  
  # Exit if we're not forcing reinstallation
  if [[ "${FORCE}" != "true" ]]; then
    log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
    exit 0
  fi

# Check system requirements
log "INFO" "Checking system requirements" "${CYAN}Checking system requirements...${NC}"
SYSTEM_MEMORY=$(free -m | awk '/^Mem:/{print $2}')
DISK_SPACE=$(df -m / | awk 'NR==2 {print $4}')

if [[ ${SYSTEM_MEMORY} -lt 1024 ]]; then
  log "WARNING" "Low memory detected: ${SYSTEM_MEMORY}MB" "${YELLOW}⚠️ Low memory detected: ${SYSTEM_MEMORY}MB. Docker may not perform optimally.${NC}"

if [[ ${DISK_SPACE} -lt 10240 ]]; then
  log "WARNING" "Low disk space detected: ${DISK_SPACE}MB" "${YELLOW}⚠️ Low disk space detected: ${DISK_SPACE}MB. Consider adding more storage.${NC}"

# Install prerequisites
log "INFO" "Installing prerequisites" "${CYAN}Installing prerequisites...${NC}"
apt-get update >> "${INSTALL_LOG}" 2>&1
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common >> "${INSTALL_LOG}" 2>&1

# Remove old versions if present
if dpkg -l | grep -q docker; then
  log "INFO" "Removing old Docker versions" "${CYAN}Removing old Docker versions...${NC}"
  apt-get remove -y docker docker-engine docker.io containerd runc >> "${INSTALL_LOG}" 2>&1 || true

# Install Docker using the official script
log "INFO" "Installing Docker via official script" "${CYAN}Installing Docker via official script...${NC}"
curl -fsSL https://get.docker.com -o "${INSTALL_DIR}/get-docker.sh" >> "${INSTALL_LOG}" 2>&1
chmod +x "${INSTALL_DIR}/get-docker.sh"
"${INSTALL_DIR}/get-docker.sh" >> "${INSTALL_LOG}" 2>&1

# Verify installation
if command -v docker &> /dev/null; then
  INSTALLED_DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
  log "SUCCESS" "Docker installed successfully (version ${INSTALLED_DOCKER_VERSION})" "${GREEN}✅ Docker installed successfully (version ${INSTALLED_DOCKER_VERSION})${NC}"
  log "ERROR" "Docker installation failed" "${RED}❌ Docker installation failed. Check the logs for details.${NC}"
  exit 1

# Add current user to the docker group if not running as root
if [[ $(id -u) -ne 0 ]]; then
  log "INFO" "Adding current user to docker group" "${CYAN}Adding current user to docker group...${NC}"
  sudo usermod -aG docker "$(whoami)" >> "${INSTALL_LOG}" 2>&1
  log "INFO" "You may need to log out and back in for group changes to take effect" "${YELLOW}⚠️ You may need to log out and back in for group changes to take effect.${NC}"

# Create Docker daemon configuration with best practices
log "INFO" "Creating Docker daemon configuration" "${CYAN}Creating Docker daemon configuration...${NC}"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOL
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOL

# Restart Docker to apply configuration
log "INFO" "Restarting Docker service" "${CYAN}Restarting Docker service...${NC}"
systemctl restart docker >> "${INSTALL_LOG}" 2>&1
systemctl enable docker >> "${INSTALL_LOG}" 2>&1

# Create AgencyStack Docker network if it doesn't exist
log "INFO" "Creating AgencyStack Docker network" "${CYAN}Creating AgencyStack Docker network...${NC}"
if ! docker network inspect agency_stack_network &> /dev/null; then
  docker network create agency_stack_network >> "${INSTALL_LOG}" 2>&1
  log "SUCCESS" "Created Docker network: agency_stack_network" "${GREEN}✅ Created Docker network: agency_stack_network${NC}"
  log "INFO" "Docker network agency_stack_network already exists" "${CYAN}Docker network agency_stack_network already exists${NC}"

# Save Docker version information
echo "${INSTALLED_DOCKER_VERSION}" > "${COMPONENT_DIR}/version.txt"
docker info > "${COMPONENT_DIR}/docker_info.txt"

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Docker installed" "{\"version\":\"${INSTALLED_DOCKER_VERSION}\",\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\"}"

log "SUCCESS" "Docker installation completed" "${GREEN}✅ Docker installation completed!${NC}"
echo
log "INFO" "Docker configuration" "${CYAN}Docker configuration:${NC}"
echo -e "  - Log max size: 100MB with 5 rotations"
echo -e "  - Storage driver: overlay2"
echo -e "  - Live restore: enabled"
echo -e "  - File limits: 64000"
echo
echo -e "${CYAN}Docker network: agency_stack_network${NC}"
echo -e "${GREEN}You can now use Docker for container deployments.${NC}"

exit 0
