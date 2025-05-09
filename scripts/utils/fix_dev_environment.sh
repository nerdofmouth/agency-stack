#!/bin/bash
# AgencyStack Development Environment Fix
# Fixes container networking issues and establishes proper communication
# Following AgencyStack Charter v1.0.3 principles

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  # Fallback logging functions
  log_info() { echo -e "[INFO] $1"; }
  log_error() { echo -e "[ERROR] $1"; }
  log_success() { echo -e "[SUCCESS] $1"; }
  log_warning() { echo -e "[WARNING] $1"; }
fi

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
CONFIG_DIR="${REPO_ROOT}/configs/network"
CONFIG_FILE="${CONFIG_DIR}/bridge_config.json"

# Log header
log_info "=================================================="
log_info "AgencyStack Development Environment Fix"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "=================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Repository Root: ${REPO_ROOT}"
log_info "=================================================="

# Create config directory if it doesn't exist
mkdir -p "${CONFIG_DIR}"

# Detect host environment
detect_environment() {
  # Check if running in Docker container
  if [ -f "/.dockerenv" ]; then
    echo "container"
    return
  fi

  # Check for WSL environment
  if grep -q "microsoft" /proc/version 2>/dev/null || grep -q "Microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "wsl"
    return
  fi

  # Assume regular Linux
  echo "linux"
}

# Get IP addresses
HOST_IP="$(ip route | grep default | awk '{print $3}')"
WSL_IP="$(hostname -I | awk '{print $1}')"

ENV_TYPE=$(detect_environment)
log_info "Detected environment: ${ENV_TYPE}"
log_info "Host IP: ${HOST_IP}"
log_info "WSL IP: ${WSL_IP}"

# Check Docker status
if ! docker info > /dev/null 2>&1; then
  log_error "Docker is not running or not accessible. Please ensure Docker is running."
  exit 1
fi

# Identify Docker network for our services
identify_network() {
  local container=$1
  
  if [[ -n "${container}" ]]; then
    docker inspect ${container} --format='{{range $net, $v := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null
  fi
}

# Get container IDs
log_info "Identifying container IDs for services..."
MCP_CONTAINER=$(docker ps | grep mcp-server | awk '{print $1}')
WORDPRESS_CONTAINER=$(docker ps | grep wordpress | awk '{print $1}')
TRAEFIK_CONTAINER=$(docker ps | grep traefik | awk '{print $1}')

# Get network
DOCKER_NETWORK=""
if [[ -n "${MCP_CONTAINER}" ]]; then
  DOCKER_NETWORK=$(identify_network "${MCP_CONTAINER}")
  log_info "Identified Docker network from MCP container: ${DOCKER_NETWORK}"
fi

if [[ -z "${DOCKER_NETWORK}" && -n "${WORDPRESS_CONTAINER}" ]]; then
  DOCKER_NETWORK=$(identify_network "${WORDPRESS_CONTAINER}")
  log_info "Identified Docker network from WordPress container: ${DOCKER_NETWORK}"
fi

if [[ -z "${DOCKER_NETWORK}" ]]; then
  DOCKER_NETWORK="mcp-servers_mcp-network"
  log_warning "Could not identify Docker network, using default: ${DOCKER_NETWORK}"
  
  # Create network if it doesn't exist
  if ! docker network ls | grep -q "${DOCKER_NETWORK}"; then
    log_info "Creating Docker network ${DOCKER_NETWORK}..."
    docker network create "${DOCKER_NETWORK}"
    
    if [[ $? -eq 0 ]]; then
      log_success "Created Docker network: ${DOCKER_NETWORK}"
    else
      log_error "Failed to create Docker network"
      exit 1
    fi
  fi
fi

# Create mapping between container-to-container and host-to-container access
log_info "Creating container network mapping..."

create_network_config() {
  local config_file=$1
  
  cat > "${config_file}" << EOF
{
  "client_id": "${CLIENT_ID}",
  "host_machine": "${HOST_IP}",
  "wsl": "${WSL_IP}",
  "docker_network": "${DOCKER_NETWORK}",
  "environment": "${ENV_TYPE}",
  "containers": {
    "wordpress": {
      "id": "$(docker ps | grep wordpress | awk '{print $1}')",
      "name": "wordpress",
      "host_port": 8082,
      "container_port": 80,
      "ip": "$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${WORDPRESS_CONTAINER} 2>/dev/null || echo '')"
    },
    "mcp_server": {
      "id": "$(docker ps | grep mcp-server | awk '{print $1}')",
      "name": "mcp-server",
      "host_port": 3000,
      "container_port": 3000,
      "ip": "$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MCP_CONTAINER} 2>/dev/null || echo '')"
    },
    "traefik": {
      "id": "$(docker ps | grep traefik | awk '{print $1}')",
      "name": "traefik",
      "host_port": 8080,
      "container_port": 8080,
      "ip": "$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${TRAEFIK_CONTAINER} 2>/dev/null || echo '')"
    }
  },
  "urls": {
    "wordpress": {
      "from_host": "http://localhost:8082",
      "from_container": "http://wordpress:80",
      "from_wsl": "http://localhost:8082"
    },
    "mcp_server": {
      "from_host": "http://localhost:3000",
      "from_container": "http://mcp-server:3000",
      "from_wsl": "http://localhost:3000"
    }
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

create_network_config "${CONFIG_FILE}"
log_success "Created network config at: ${CONFIG_FILE}"

# Docker host entry setup - ensures containers can reach the host machine
add_hosts_entry() {
  local container=$1
  local name=$2
  
  if [[ -n "${container}" ]]; then
    log_info "Setting up host entry for ${name} container..."
    docker exec ${container} sh -c "grep -q 'host.docker.internal' /etc/hosts || echo '${HOST_IP} host.docker.internal' >> /etc/hosts"
    log_success "Added host.docker.internal entry to ${name} container"
  else
    log_warning "${name} container not found, skipping hosts file setup"
  fi
}

# Add host entries to containers
add_hosts_entry "${MCP_CONTAINER}" "MCP Server"
add_hosts_entry "${WORDPRESS_CONTAINER}" "WordPress"
add_hosts_entry "${TRAEFIK_CONTAINER}" "Traefik"

# Create helper scripts to ensure proper URL usage in different contexts
log_info "Creating helper scripts for proper URL usage..."

cat > "${REPO_ROOT}/scripts/utils/get_url.sh" << 'EOF'
#!/bin/bash
# AgencyStack URL Helper
# Returns appropriate URL based on environment context

# Get repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Config path
CONFIG_FILE="${REPO_ROOT}/configs/network/bridge_config.json"

# Check if running in Docker container
is_container() {
  [ -f "/.dockerenv" ]
}

# Check if running in WSL
is_wsl() {
  grep -q "microsoft\|Microsoft" /proc/version 2>/dev/null || grep -q "Microsoft" /proc/sys/kernel/osrelease 2>/dev/null
}

# Get URL for a service
get_url() {
  local service=$1
  
  # Default URLs if no config is available
  local container_url="http://${service}:$(get_default_port ${service})"
  local host_url="http://localhost:$(get_default_port ${service})"
  
  # Check if config exists
  if [ -f "${CONFIG_FILE}" ]; then
    if command -v jq > /dev/null 2>&1; then
      if is_container; then
        container_url=$(jq -r ".urls.${service}.from_container" "${CONFIG_FILE}")
        echo "${container_url}"
        return
      elif is_wsl; then
        wsl_url=$(jq -r ".urls.${service}.from_wsl" "${CONFIG_FILE}")
        echo "${wsl_url}"
        return
      else
        host_url=$(jq -r ".urls.${service}.from_host" "${CONFIG_FILE}")
        echo "${host_url}"
        return
      fi
    fi
  fi
  
  # Fallback based on environment if no config or jq
  if is_container; then
    echo "${container_url}"
  else
    echo "${host_url}"
  fi
}

# Default ports for services
get_default_port() {
  local service=$1
  
  case "$service" in
    wordpress) echo "8082" ;;
    mcp_server) echo "3000" ;;
    traefik) echo "8080" ;;
    *) echo "80" ;;
  esac
}

# Main
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <service>"
  echo "Available services: wordpress, mcp_server, traefik"
  exit 1
fi

get_url "$1"
EOF

chmod +x "${REPO_ROOT}/scripts/utils/get_url.sh"
log_success "Created URL helper script"

# Generate an ASK make target for easy troubleshooting
log_info "Creating ASK make target for troubleshooting..."

# Check if Makefile exists
if [ -f "${REPO_ROOT}/Makefile" ]; then
  # Check if ask target already exists
  if ! grep -q "^ask:" "${REPO_ROOT}/Makefile"; then
    cat >> "${REPO_ROOT}/Makefile" << 'EOF'

# Network troubleshooting target
ask:
	@echo "AgencyStack Network Diagnostics"
	@echo "=============================="
	@echo "Environment: $(shell scripts/utils/fix_dev_environment.sh env)"
	@echo "WordPress URL: $(shell scripts/utils/get_url.sh wordpress)"
	@echo "MCP Server URL: $(shell scripts/utils/get_url.sh mcp_server)"
	@echo "=============================="
	@scripts/utils/fix_dev_environment.sh check
EOF
    log_success "Added 'ask' target to Makefile"
  else
    log_info "'ask' target already exists in Makefile"
  fi
else
  log_warning "Makefile not found, skipping 'ask' target creation"
fi

# Docker network command for reconnecting containers
log_info "Ensuring containers are on the same network..."
reconnect_containers() {
  local network=$1
  
  for container in "${MCP_CONTAINER}" "${WORDPRESS_CONTAINER}" "${TRAEFIK_CONTAINER}"; do
    if [[ -n "${container}" ]]; then
      local name=$(docker inspect --format='{{.Name}}' ${container} 2>/dev/null | sed 's/^\///')
      log_info "Connecting ${name} to network ${network}..."
      docker network connect ${network} ${container} 2>/dev/null || log_info "${name} already on ${network}"
    fi
  done
}

reconnect_containers "${DOCKER_NETWORK}"

# Testing connectivity
log_info "Testing connectivity between services..."
test_container_connectivity() {
  local src_container=$1
  local target=$2
  local target_port=$3
  local name=$4
  
  if [[ -n "${src_container}" ]]; then
    log_info "Testing connectivity from ${name} to ${target}:${target_port}..."
    docker exec ${src_container} sh -c "timeout 1 nc -z ${target} ${target_port} 2>/dev/null"
    
    if [[ $? -eq 0 ]]; then
      log_success "${name} can connect to ${target}:${target_port}"
      return 0
    else
      log_warning "${name} cannot connect to ${target}:${target_port}"
      return 1
    fi
  fi
}

if [[ -n "${MCP_CONTAINER}" && -n "${WORDPRESS_CONTAINER}" ]]; then
  # Get WordPress container IP
  WP_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${WORDPRESS_CONTAINER})
  
  # Test MCP to WordPress
  test_container_connectivity "${MCP_CONTAINER}" "wordpress" "80" "MCP Server"
  if [[ $? -ne 0 ]]; then
    test_container_connectivity "${MCP_CONTAINER}" "${WP_IP}" "80" "MCP Server"
  fi
fi

# Add custom header and footer to MCP server
log_info "Checking for updated MCP server..."

# Generate summary
log_info "====================================================="
log_info "AgencyStack Development Environment Fix - SUMMARY"
log_info "====================================================="
log_info "Environment: ${ENV_TYPE}"
log_info "Docker Network: ${DOCKER_NETWORK}"
log_info "Configuration: ${CONFIG_FILE}"
log_info "Helper Script: ${REPO_ROOT}/scripts/utils/get_url.sh"
log_info "====================================================="
log_info "MCP Server Container: ${MCP_CONTAINER:-Not found}"
log_info "WordPress Container: ${WORDPRESS_CONTAINER:-Not found}"
log_info "Traefik Container: ${TRAEFIK_CONTAINER:-Not found}"
log_info "====================================================="
log_info "For troubleshooting: make ask"
log_info "For network diagnostics: curl -X POST -H \"Content-Type: application/json\" -d '{\"target_url\":\"http://wordpress:80\"}' http://localhost:3000/network-diagnostics"
log_info "====================================================="

log_success "Development environment fix completed!"
exit 0
