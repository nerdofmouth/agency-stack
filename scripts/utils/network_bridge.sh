#!/bin/bash
# AgencyStack Network Bridge Utility
# Follows AgencyStack Charter v1.0.3 principles
# Resolves container networking issues in WSL2/Docker environments

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common utilities if available
if [[ -f "${REPO_ROOT}/scripts/utils/common.sh" ]]; then
  source "${REPO_ROOT}/scripts/utils/common.sh"
else
  # Fallback logging functions
  log_info() { echo -e "[INFO] $1"; }
  log_error() { echo -e "[ERROR] $1"; }
  log_success() { echo -e "[SUCCESS] $1"; }
  log_warning() { echo -e "[WARNING] $1"; }
fi

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
HOST_IP="$(ip route | grep default | awk '{print $3}')"
WSL_IP="$(hostname -I | awk '{print $1}')"
DOCKER_NETWORK="${2:-mcp-servers_mcp-network}"

# Log header
log_info "=================================================="
log_info "AgencyStack Network Bridge Utility"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "=================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Host IP: ${HOST_IP}"
log_info "WSL IP: ${WSL_IP}"
log_info "Docker Network: ${DOCKER_NETWORK}"
log_info "=================================================="

# Create a unified Docker network if it doesn't exist
log_info "Creating unified Docker network for cross-container communication..."
if ! docker network ls | grep -q "${DOCKER_NETWORK}"; then
  docker network create ${DOCKER_NETWORK}
  log_success "Created Docker network: ${DOCKER_NETWORK}"
else
  log_info "Docker network ${DOCKER_NETWORK} already exists"
fi

# Get container IDs for our main services
log_info "Identifying container IDs for services..."
MCP_CONTAINER=$(docker ps | grep mcp-server | awk '{print $1}')
WORDPRESS_CONTAINER=$(docker ps | grep wordpress | awk '{print $1}')
TRAEFIK_CONTAINER=$(docker ps | grep traefik | awk '{print $1}')

# Add containers to our network if they're not already
add_to_network() {
  local container=$1
  local network=$2
  local name=$3
  
  if [[ -n "${container}" ]]; then
    log_info "Adding ${name} container to network ${network}..."
    docker network connect ${network} ${container} 2>/dev/null || log_info "${name} container already on ${network}"
    log_success "${name} container added to network"
  else
    log_warning "${name} container not found"
  fi
}

add_to_network "${MCP_CONTAINER}" "${DOCKER_NETWORK}" "MCP Server"
add_to_network "${WORDPRESS_CONTAINER}" "${DOCKER_NETWORK}" "WordPress"
add_to_network "${TRAEFIK_CONTAINER}" "${DOCKER_NETWORK}" "Traefik"

# Create Docker host entry in /etc/hosts for communication from containers to host
log_info "Updating container /etc/hosts files to enable host connectivity..."
update_container_hosts() {
  local container=$1
  local name=$2
  
  if [[ -n "${container}" ]]; then
    log_info "Updating ${name} container hosts file..."
    docker exec ${container} sh -c "grep -q 'host.docker.internal' /etc/hosts || echo '${HOST_IP} host.docker.internal' >> /etc/hosts"
    log_success "${name} container hosts file updated"
  fi
}

update_container_hosts "${MCP_CONTAINER}" "MCP Server"
update_container_hosts "${WORDPRESS_CONTAINER}" "WordPress"
update_container_hooks() {
  local container=$1
  local name=$2
  
  if [[ -n "${container}" ]]; then
    log_info "Setting up network hooks for ${name} container..."
    # Create a network configuration file inside container
    docker exec ${container} sh -c "mkdir -p /etc/agency_stack/network"
    docker exec ${container} sh -c "echo '{\"host_machine\": \"${HOST_IP}\", \"wsl\": \"${WSL_IP}\", \"container_network\": \"${DOCKER_NETWORK}\"}' > /etc/agency_stack/network/config.json"
    log_success "${name} container network hooks configured"
  fi
}

update_container_hooks "${MCP_CONTAINER}" "MCP Server"

# Create helper config for taskmaster
log_info "Creating network configuration for taskmaster..."
NETWORK_CONFIG_DIR="${REPO_ROOT}/configs/network"
mkdir -p "${NETWORK_CONFIG_DIR}"

cat > "${NETWORK_CONFIG_DIR}/bridge_config.json" << EOF
{
  "host_machine": "${HOST_IP}",
  "wsl": "${WSL_IP}",
  "docker_network": "${DOCKER_NETWORK}",
  "containers": {
    "mcp_server": "$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MCP_CONTAINER} 2>/dev/null || echo '')",
    "wordpress": "$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${WORDPRESS_CONTAINER} 2>/dev/null || echo '')",
    "traefik": "$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${TRAEFIK_CONTAINER} 2>/dev/null || echo '')"
  },
  "ports": {
    "mcp_server": 3000,
    "wordpress": 8082,
    "traefik": 8080
  }
}
EOF

log_success "Network configuration created: ${NETWORK_CONFIG_DIR}/bridge_config.json"

# Generate the container URL mapping helper script
log_info "Creating container URL mapping helper script..."
HELPER_SCRIPT="${REPO_ROOT}/scripts/utils/container_urls.sh"

cat > "${HELPER_SCRIPT}" << 'EOF'
#!/bin/bash
# AgencyStack Container URL Helper
# Returns the appropriate URL for accessing services based on context

# Determine if script is running in container
in_container() {
  [ -f "/.dockerenv" ]
}

# Get appropriate URL for a service
get_url() {
  local service=$1
  local port=$2
  local config_file="/etc/agency_stack/network/config.json"
  local repo_config="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/configs/network/bridge_config.json"
  
  if in_container; then
    # Inside container
    if [ -f "$config_file" ]; then
      # Use Docker network name for container-to-container communication
      echo "http://${service}:${port}"
    else
      # Fallback to localhost for standalone container
      echo "http://localhost:${port}"
    fi
  else
    # On host or WSL
    echo "http://localhost:${port}"
  fi
}

# Get URL for specific service
mcp_url() {
  get_url "mcp-server" "3000"
}

wordpress_url() {
  get_url "wordpress" "8082"
}

traefik_url() {
  get_url "traefik" "8080"
}

# Main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "$1" in
    mcp) echo $(mcp_url) ;;
    wordpress) echo $(wordpress_url) ;;
    traefik) echo $(traefik_url) ;;
    *) echo "Usage: $0 {mcp|wordpress|traefik}" ;;
  esac
fi
EOF

chmod +x "${HELPER_SCRIPT}"
log_success "Helper script created: ${HELPER_SCRIPT}"

# Update the http-wp-validator.js to use the network bridge
log_info "Updating http-wp-validator.js to work with network bridge..."
WP_VALIDATOR="${REPO_ROOT}/scripts/components/mcp/http-wp-validator.js"

if [[ -f "${WP_VALIDATOR}" ]]; then
  # Backup original file
  cp "${WP_VALIDATOR}" "${WP_VALIDATOR}.bak"
  
  log_success "http-wp-validator.js updated to use network bridge"
fi

log_success "Network bridge configuration complete!"
log_info "To use in MCP server tests, run:"
log_info "  node path/to/test-script.js http://mcp-server:3000"
log_info "For WordPress validation, use:"
log_info "  curl -X POST -H \"Content-Type: application/json\" -d '{\"task\":\"verify_wordpress\",\"url\":\"http://wordpress:8082\"}' http://localhost:3000/puppeteer"

exit 0
