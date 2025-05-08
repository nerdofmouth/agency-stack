#!/bin/bash
# MCP Server Launch Script
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
# Follows principles: Repository as Source of Truth, Strict Containerization

# Detect script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  # Minimal implementation if common.sh is not available
  log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
  log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
  log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
  log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1"; }
fi

# Parse arguments
CLIENT_ID="${1:-agencystack}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/mcp"

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

# Verify installation exists
verify_installation() {
  log_info "Verifying MCP server installation for client: ${CLIENT_ID}"
  
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    log_error "MCP server not installed for client: ${CLIENT_ID}"
    log_error "Please run install_mcp_server.sh ${CLIENT_ID} first"
    exit 1
  fi
  
  if [[ ! -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    log_error "docker-compose.yml not found in ${INSTALL_DIR}"
    log_error "MCP server installation may be corrupted"
    exit 1
  fi
  
  log_success "MCP server installation verified"
}

# Start the MCP server
start_mcp_server() {
  log_info "Starting MCP server for client: ${CLIENT_ID}"
  
  # Change to installation directory and start containers
  cd "${INSTALL_DIR}" && docker-compose up -d
  
  if [[ $? -eq 0 ]]; then
    log_success "MCP server started successfully"
  else
    log_error "Failed to start MCP server"
    exit 1
  fi
}

# Configure Docker networks for WordPress communication
setup_mcp_networks() {
  log_info "Setting up MCP server Docker networks"
  
  # Connect to common networks that WordPress containers might use
  networks=(
    "traefik_network"
    "peacefestivalusa_peacefestival_network"
    "pfusa_network"
    "${CLIENT_ID}_network"
  )
  
  # Try connecting to each network, but don't fail if network doesn't exist
  for network in "${networks[@]}"; do
    log_info "Attempting to connect MCP server to ${network}"
    docker network connect "${network}" mcp-server 2>/dev/null || \
      log_warning "Network ${network} not available or already connected"
  done
  
  log_success "MCP server network setup completed"
}

# Check if MCP server is running
check_mcp_status() {
  log_info "Checking MCP server status"
  
  # Check container status
  if docker ps | grep -q "mcp-server"; then
    log_success "MCP server is running"
    
    # Get container IP and port
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mcp-server)
    log_info "MCP server accessible at:"
    log_info "- External: http://localhost:3000"
    log_info "- Internal: http://${CONTAINER_IP}:3000"
    log_info "- Container: http://mcp-server:3000"
    
    # Check if server responds
    if curl -s "http://localhost:3000/health" | grep -q "ok"; then
      log_success "MCP server API is responding correctly"
    else
      log_warning "MCP server API may not be fully operational yet"
    fi
  else
    log_error "MCP server is not running"
    exit 1
  fi
}

# Main launch function
launch_mcp_server() {
  log_info "Launching MCP server for client: ${CLIENT_ID}"
  
  # Execute launch steps
  exit_with_warning_if_host
  verify_installation
  start_mcp_server
  setup_mcp_networks
  check_mcp_status
  
  log_success "MCP server launched successfully for ${CLIENT_ID}"
}

# Run launch if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  launch_mcp_server
fi
