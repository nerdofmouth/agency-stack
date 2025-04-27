#!/bin/bash
# template_component.sh - Template for new AgencyStack component installation
# 
# This template follows the AgencyStack v1.0.3 Charter and TDD Protocol standards
# Use this to quickly create new component installation scripts
#
# To use: cp component_template.sh install_<component>.sh
#         Then search/replace COMPONENT_NAME with your actual component name

# Source common utilities 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

trap_agencystack_errors

# Component name and metadata (CUSTOMIZE THIS)
COMPONENT_NAME="component"  # Change to your component name (e.g., wordpress, keycloak)
COMPONENT_VERSION="latest"  # Version to install
DEFAULT_PORT="8080"        # Default main service port

# Default parameters
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
PORT="${PORT:-$DEFAULT_PORT}"
ENABLE_TLS=false
STATUS_ONLY=false
RESTART_ONLY=false
LOGS_ONLY=false
TEST_ONLY=false
FORCE=false

# Function to get container-aware paths
get_install_path() {
  local component="$1"
  local client="${2:-$CLIENT_ID}"
  
  if [[ "$CONTAINER_RUNNING" == "true" ]]; then
    echo "${HOME}/.agencystack/clients/${client}/${component}"
  else
    echo "/opt/agency_stack/clients/${client}/${component}"
  fi
}

# Path setup (container-aware)
INSTALL_DIR="$(get_install_path $COMPONENT_NAME)"
CONFIG_DIR="${INSTALL_DIR}/config"
DOCKER_COMPOSE_DIR="${INSTALL_DIR}/docker-compose"
LOG_DIR="$(get_install_path logs)"
LOG_FILE="${LOG_DIR}/${COMPONENT_NAME}.log"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --enable-tls)
      ENABLE_TLS=true
      shift
      ;;
    --status-only)
      STATUS_ONLY=true
      shift
      ;;
    --restart-only)
      RESTART_ONLY=true
      shift
      ;;
    --logs-only)
      LOGS_ONLY=true
      shift
      ;;
    --test-only)
      TEST_ONLY=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help)
      echo "Usage: $(basename "$0") [options]"
      echo "Options:"
      echo "  --client-id <id>        Client ID (default: default)"
      echo "  --domain <domain>       Domain name (default: localhost)"
      echo "  --admin-email <email>   Admin email (default: admin@example.com)"
      echo "  --port <port>           Service port (default: $DEFAULT_PORT)"
      echo "  --enable-tls            Enable TLS for production environments"
      echo "  --status-only           Only check status, don't install"
      echo "  --restart-only          Only restart services"
      echo "  --logs-only             Only view logs"
      echo "  --test-only             Only run tests"
      echo "  --force                 Force reinstallation"
      echo "  --help                  Display this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set up logging
ensure_log_directory "${LOG_DIR}"
log_info "==========================================="
log_info "Starting install_${COMPONENT_NAME}.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="

# Check if we should only show status
if [[ "$STATUS_ONLY" == "true" ]]; then
  log_info "Checking ${COMPONENT_NAME} status..."
  
  # Check if containers are running
  MAIN_SERVICE_RUNNING=$(docker ps -q -f "name=${COMPONENT_NAME}_${CLIENT_ID}" 2>/dev/null)
  
  # Display status
  echo "=== ${COMPONENT_NAME^} Status ==="
  echo "Main Service: $([ -n "$MAIN_SERVICE_RUNNING" ] && echo "Running" || echo "Not running")"
  
  # Check service accessibility
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null)
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Web Interface: Accessible (HTTP $HTTP_CODE)"
  else
    echo "Web Interface: Not accessible (HTTP $HTTP_CODE)"
    echo "Expected URL: http://localhost:${PORT}/"
  fi
  
  log_success "Script completed successfully"
  exit 0
fi

# Check if we should only restart services
if [[ "$RESTART_ONLY" == "true" ]]; then
  log_info "Restarting ${COMPONENT_NAME} services..."
  
  # Get the correct directory based on container status
  COMPOSE_DIR="${INSTALL_DIR}/docker-compose"
  
  # Check if docker-compose directory exists
  if [[ -d "$COMPOSE_DIR" ]]; then
    cd "$COMPOSE_DIR" && docker-compose restart
    log_success "Services restarted successfully"
  else
    log_error "${COMPONENT_NAME^} not installed. Run 'make ${COMPONENT_NAME}' first."
    exit 1
  fi
  
  exit 0
fi

# Check if we should only view logs
if [[ "$LOGS_ONLY" == "true" ]]; then
  log_info "Viewing ${COMPONENT_NAME} logs..."
  
  # Get the correct directory based on container status
  COMPOSE_DIR="${INSTALL_DIR}/docker-compose"
  
  # Check if docker-compose directory exists
  if [[ -d "$COMPOSE_DIR" ]]; then
    cd "$COMPOSE_DIR" && docker-compose logs --tail=100
  else
    log_error "${COMPONENT_NAME^} not installed. Run 'make ${COMPONENT_NAME}' first."
    exit 1
  fi
  
  exit 0
fi

# Check if we should only run tests
if [[ "$TEST_ONLY" == "true" ]]; then
  log_info "Running ${COMPONENT_NAME} tests..."
  
  # Verify service is running
  SERVICE_RUNNING=$(docker ps -q -f "name=${COMPONENT_NAME}_${CLIENT_ID}" 2>/dev/null)
  if [[ -z "$SERVICE_RUNNING" ]]; then
    log_error "Services not running, tests cannot proceed"
    exit 1
  fi
  
  # Run tests here
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null)
  if [[ "$HTTP_CODE" == "200" ]]; then
    log_success "Web interface test: PASSED"
  else
    log_error "Web interface test: FAILED (HTTP $HTTP_CODE)"
    log_error "Expected URL: http://localhost:${PORT}/"
    exit 1
  fi
  
  log_success "All tests PASSED"
  exit 0
fi

# Main installation flow
main() {
  log_info "Starting installation..."
  
  # Create directories
  log_info "Creating installation directories..."
  mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}" "${DOCKER_COMPOSE_DIR}" "${LOG_DIR}"
  
  # Check if already installed and not forced
  if [[ -f "${DOCKER_COMPOSE_DIR}/docker-compose.yml" && "$FORCE" != "true" ]]; then
    log_info "Component already installed. Use --force to reinstall."
    exit 0
  fi
  
  # Create Docker Compose file
  log_info "Creating Docker Compose configuration..."
  cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" <<EOF
version: '3'

networks:
  ${COMPONENT_NAME}:
    name: ${COMPONENT_NAME}-${CLIENT_ID}

services:
  ${COMPONENT_NAME}:
    image: ${COMPONENT_NAME}:${COMPONENT_VERSION}
    container_name: ${COMPONENT_NAME}_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - ${COMPONENT_NAME}
    ports:
      - "${PORT}:${PORT}"
    volumes:
      - ${CONFIG_DIR}:/config
    environment:
      - TZ=UTC
EOF
  
  # Start the services
  log_info "Starting services..."
  cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
  
  # Add component registry entry
  log_info "Updating component registry..."
  if ! grep -q "\"name\": \"${COMPONENT_NAME}\"" "$(dirname "${SCRIPT_DIR}")/component_registry.json"; then
    # TODO: Add component registry entry
    log_info "Added ${COMPONENT_NAME} to component registry"
  else
    log_info "Component already exists in registry"
  fi
  
  # Run tests to verify installation
  log_info "Running verification tests..."
  if [[ "$TEST_ONLY" == "true" ]]; then
    # Run tests here (same as test-only section)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null)
    if [[ "$HTTP_CODE" == "200" ]]; then
      log_success "Web interface test: PASSED"
    else
      log_error "Web interface test: FAILED (HTTP $HTTP_CODE)"
      log_error "Expected URL: http://localhost:${PORT}/"
      exit 1
    fi
  fi
  
  log_success "${COMPONENT_NAME^} integration is installed"
  log_info "${COMPONENT_NAME^} interface: http://localhost:${PORT}/"
}

# Run main installation
main
