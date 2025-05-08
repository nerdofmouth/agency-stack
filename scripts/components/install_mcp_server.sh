#!/bin/bash
# MCP Server Installation Script
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
# Follows principles: Repository as Source of Truth, Strict Containerization

# Detect script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  # Minimal implementation if common.sh is not available
  log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
  log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
  log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
  log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1"; }
  ensure_directory_exists() { mkdir -p "$1"; }
fi

# Parse arguments
CLIENT_ID="${1:-agencystack}"
MCP_PORT="${2:-3000}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/mcp"
LOG_DIR="/var/log/agency_stack/components/mcp"

# Strict containerization check (Charter requirement)
is_running_in_container() {
  if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup; then
    return 0  # true
  else
    return 1  # false
  fi
}

exit_with_warning_if_host() {
  if ! is_running_in_container; then
    log_warning "This script must be run in a container according to AgencyStack Charter v1.0.3"
    log_warning "Please use the containerized deployment approach"
    exit 1
  fi
}

# Check for prerequisites
check_prerequisites() {
  log_info "Checking prerequisites for MCP server installation"
  
  # Check Docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
  fi
  
  # Check Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
  fi
  
  # Check if Node.js is available (for local testing)
  if ! command -v node &> /dev/null; then
    log_warning "Node.js is not installed on host. This is OK for containerized deployment."
  fi
  
  log_success "All prerequisites checked"
}

# Create necessary directories with proper permissions
setup_directories() {
  log_info "Setting up MCP server directories for client: ${CLIENT_ID}"
  
  # Create installation directory
  ensure_directory_exists "${INSTALL_DIR}"
  
  # Create log directory
  ensure_directory_exists "${LOG_DIR}"
  
  # Create client-specific log directories
  ensure_directory_exists "${LOG_DIR}/${CLIENT_ID}"
  
  log_success "Directory structure created at ${INSTALL_DIR}"
}

# Copy MCP server files to installation directory
install_mcp_files() {
  log_info "Installing MCP server files"
  
  # Copy server files from repository to installation directory
  cp -r "${SCRIPT_DIR}/mcp/"* "${INSTALL_DIR}/"
  
  # Copy Dockerfile and docker-compose.yml
  if [[ ! -f "${INSTALL_DIR}/Dockerfile" ]]; then
    cat > "${INSTALL_DIR}/Dockerfile" <<EOL
FROM node:18-slim

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

EXPOSE 3000
CMD ["node", "server.js"]
EOL
  fi
  
  if [[ ! -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    cat > "${INSTALL_DIR}/docker-compose.yml" <<EOL
version: '3.7'

services:
  mcp-server:
    container_name: mcp-server
    build: .
    ports:
      - "${MCP_PORT}:3000"
    volumes:
      - ./:/app
      - ${LOG_DIR}/${CLIENT_ID}:/app/logs
    restart: unless-stopped
    networks:
      - mcp-network

networks:
  mcp-network:
    name: mcp-network
EOL
  fi
  
  log_success "MCP server files installed to ${INSTALL_DIR}"
}

# Setup logging with proper paths
setup_logging() {
  log_info "Setting up MCP server logging"
  
  # Create symlink from installation to log directory
  ln -sf "${LOG_DIR}/${CLIENT_ID}" "${INSTALL_DIR}/logs"
  
  log_success "Logging configured to ${LOG_DIR}/${CLIENT_ID}"
}

# Register component in AgencyStack registry if available
register_component() {
  log_info "Registering MCP server in component registry"
  
  # If registry script exists, register component
  if [[ -f "${SCRIPT_DIR}/../utils/register_component.sh" ]]; then
    bash "${SCRIPT_DIR}/../utils/register_component.sh" \
      --name "mcp_server" \
      --version "1.0.0" \
      --client "${CLIENT_ID}" \
      --install-dir "${INSTALL_DIR}" \
      --log-dir "${LOG_DIR}/${CLIENT_ID}"
  else
    log_warning "Component registry not available, skipping registration"
  fi
  
  log_success "MCP server registered as a component"
}

# Main installation function
install_mcp_server() {
  log_info "Starting MCP server installation for client: ${CLIENT_ID}"
  
  # Execute installation steps
  exit_with_warning_if_host
  check_prerequisites
  setup_directories
  install_mcp_files
  setup_logging
  register_component
  
  log_success "MCP server installation completed for ${CLIENT_ID}"
  log_info "Use 'launch_mcp_server.sh ${CLIENT_ID}' to start the MCP server"
}

# Run installation if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_mcp_server
fi
