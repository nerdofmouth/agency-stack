#!/bin/bash

# PeaceFestivalUSA WordPress Launcher
# Following AgencyStack Charter v1.0.3 Principles
# - Strict containerization
# - Repository as source of truth
# - Multi-tenancy & security

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost"
WP_PORT="8082"
DB_PORT="33061"
CONTAINER_PREFIX="pfusa_"
FORCE="false"
OPERATION_MODE="launch"

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case "$key" in
    --client-id) CLIENT_ID="$2"; shift ;;
    --domain) DOMAIN="$2"; shift ;;
    --wp-port) WP_PORT="$2"; shift ;;
    --db-port) DB_PORT="$2"; shift ;;
    --container-prefix) CONTAINER_PREFIX="$2"; shift ;;
    --force) FORCE="true"; shift; continue ;;
    --stop) OPERATION_MODE="stop"; shift; continue ;;
    --restart) OPERATION_MODE="restart"; shift; continue ;;
    --status) OPERATION_MODE="status"; shift; continue ;;
    --help) 
      echo "Usage: $0 [--client-id ID] [--domain example.com] [--container-prefix prefix_] [--wp-port 8082] [--db-port 33061] [--force] [--stop] [--restart] [--status]"
      echo "  --client-id ID          Client identifier (default: peacefestivalusa)"
      echo "  --domain DOMAIN         Domain for WordPress (default: localhost)"
      echo "  --wp-port PORT          WordPress port (default: 8082)"
      echo "  --db-port PORT          Database port (default: 33061)"
      echo "  --container-prefix      Container name prefix (default: pfusa_)"
      echo "  --force                 Force recreation of containers"
      echo "  --stop                  Stop running containers"
      echo "  --restart               Restart running containers"
      echo "  --status                Check status of containers"
      echo "  --help                  Show this help message"
      exit 0 
      ;;
    *) log_error "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Header display
log_info "🚀 PeaceFestivalUSA WordPress Launcher"
log_info "======================================="
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info ""
log_info "Client: ${CLIENT_ID}"
log_info "Domain: ${DOMAIN}"
log_info "WordPress Port: ${WP_PORT}"
log_info "Database Port: ${DB_PORT}"
log_info "Container Prefix: ${CONTAINER_PREFIX}"
log_info "Operation: ${OPERATION_MODE}"
log_info "======================================="
log_info ""

# Set paths according to AgencyStack Charter's directory structure
REPO_ROOT="${SCRIPT_DIR}/../.."
CLIENT_DIR="${REPO_ROOT}/clients/${CLIENT_ID}"
DOCKER_COMPOSE_DIR="${CLIENT_DIR}"
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_DIR}/docker-compose.yml"
DOCKER_ENV_FILE="${DOCKER_COMPOSE_DIR}/.env"

# Function to check for Docker and Docker Compose
check_prerequisites() {
  # Check for Docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    log_error "Please install Docker and ensure it's properly configured"
    exit 1
  fi

  # Check for Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed or not in PATH"
    log_error "Please install Docker Compose or verify Docker Desktop installation"
    exit 1
  fi
}

# Function to setup environment file
setup_env_file() {
  if [ ! -f "${DOCKER_ENV_FILE}" ]; then
    if [ -f "${DOCKER_COMPOSE_DIR}/.env.example" ]; then
      log_info "Creating .env file from example..."
      cp "${DOCKER_COMPOSE_DIR}/.env.example" "${DOCKER_ENV_FILE}"
    else
      log_error "No .env.example file found at ${DOCKER_COMPOSE_DIR}/.env.example"
      exit 1
    fi
  fi

  # Update environment variables based on parameters
  log_info "Updating environment configuration..."
  sed -i "s/DOMAIN=.*/DOMAIN=${DOMAIN}:${WP_PORT}/" "${DOCKER_ENV_FILE}" || true
  sed -i "s/WORDPRESS_PORT=.*/WORDPRESS_PORT=${WP_PORT}/" "${DOCKER_ENV_FILE}" || true
  sed -i "s/MARIADB_PORT=.*/MARIADB_PORT=${DB_PORT}/" "${DOCKER_ENV_FILE}" || true
  sed -i "s/CONTAINER_PREFIX=.*/CONTAINER_PREFIX=${CONTAINER_PREFIX}/" "${DOCKER_ENV_FILE}" || true
  sed -i "s/CLIENT_ID=.*/CLIENT_ID=${CLIENT_ID}/" "${DOCKER_ENV_FILE}" || true
}

# Function to create Docker network
setup_network() {
  NETWORK_NAME="${CONTAINER_PREFIX}network"
  
  if ! docker network inspect "${NETWORK_NAME}" &> /dev/null; then
    log_info "Creating Docker network: ${NETWORK_NAME}..."
    docker network create "${NETWORK_NAME}" || {
      log_error "Failed to create Docker network"
      exit 1
    }
    log_success "Created ${NETWORK_NAME}"
  else
    log_info "Using existing network: ${NETWORK_NAME}"
  fi
}

# Function to check container status
check_status() {
  WP_CONTAINER="${CONTAINER_PREFIX}wordpress"
  DB_CONTAINER="${CONTAINER_PREFIX}mariadb"
  
  log_info "Checking PeaceFestivalUSA WordPress container status..."
  
  WP_RUNNING=$(docker ps -q -f name="${WP_CONTAINER}")
  DB_RUNNING=$(docker ps -q -f name="${DB_CONTAINER}")
  
  if [ -n "$WP_RUNNING" ]; then
    log_success "WordPress container (${WP_CONTAINER}) is running"
    log_info "WordPress URL: http://${DOMAIN}:${WP_PORT}"
  else
    log_warning "WordPress container (${WP_CONTAINER}) is not running"
  fi
  
  if [ -n "$DB_RUNNING" ]; then
    log_success "Database container (${DB_CONTAINER}) is running"
    log_info "Database connection: ${DOMAIN}:${DB_PORT}"
  else
    log_warning "Database container (${DB_CONTAINER}) is not running"
  fi
  
  # Show all containers with this prefix
  log_info "All containers with prefix ${CONTAINER_PREFIX}:"
  docker ps -a -f name="${CONTAINER_PREFIX}"
}

# Function to stop containers
stop_containers() {
  log_info "Stopping PeaceFestivalUSA WordPress containers..."
  
  if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_info "Stopping via Docker Compose..."
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down
    
    if [ $? -eq 0 ]; then
      log_success "Containers stopped successfully"
    else
      log_error "Failed to stop containers"
      exit 1
    fi
  else
    log_error "Docker Compose file not found at ${DOCKER_COMPOSE_FILE}"
    exit 1
  fi
}

# Function to restart containers
restart_containers() {
  log_info "Restarting PeaceFestivalUSA WordPress containers..."
  
  if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_info "Restarting via Docker Compose..."
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose restart
    
    if [ $? -eq 0 ]; then
      log_success "Containers restarted successfully"
      log_info "WordPress URL: http://${DOMAIN}:${WP_PORT}"
    else
      log_error "Failed to restart containers"
      exit 1
    fi
  else
    log_error "Docker Compose file not found at ${DOCKER_COMPOSE_FILE}"
    exit 1
  fi
}

# Function to launch containers
launch_containers() {
  log_info "Launching PeaceFestivalUSA WordPress containers..."
  
  # Check if containers are already running
  WP_CONTAINER="${CONTAINER_PREFIX}wordpress"
  DB_CONTAINER="${CONTAINER_PREFIX}mariadb"
  
  WP_RUNNING=$(docker ps -q -f name="${WP_CONTAINER}")
  DB_RUNNING=$(docker ps -q -f name="${DB_CONTAINER}")
  
  if [ -n "$WP_RUNNING" ] && [ -n "$DB_RUNNING" ] && [ "$FORCE" != "true" ]; then
    log_info "PeaceFestivalUSA containers are already running"
    log_info "WordPress URL: http://${DOMAIN}:${WP_PORT}"
    log_info ""
    log_info "To force recreation, use --force"
    log_info "To restart: $0 --restart"
    log_info "To stop: $0 --stop"
    exit 0
  fi
  
  # If force is specified, stop containers first
  if [ "$FORCE" = "true" ]; then
    log_info "Force flag specified, stopping any existing containers..."
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  fi
  
  # Launch containers
  if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_info "Launching via Docker Compose..."
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
    
    if [ $? -eq 0 ]; then
      log_success "Containers launched successfully"
      log_info ""
      log_info "📊 Access Information:"
      log_info "- WordPress: http://${DOMAIN}:${WP_PORT}"
      log_info "- WordPress Admin: http://${DOMAIN}:${WP_PORT}/wp-admin/"
      log_info "- Database: ${DOMAIN}:${DB_PORT}"
      
      # Extract database credentials from env file
      if [ -f "${DOCKER_ENV_FILE}" ]; then
        WP_DB_USER=$(grep "WORDPRESS_DB_USER" "${DOCKER_ENV_FILE}" | cut -d= -f2)
        WP_DB_PASS=$(grep "WORDPRESS_DB_PASSWORD" "${DOCKER_ENV_FILE}" | cut -d= -f2)
        WP_DB_NAME=$(grep "WORDPRESS_DB_NAME" "${DOCKER_ENV_FILE}" | cut -d= -f2)
        
        log_info "  - User: ${WP_DB_USER}"
        log_info "  - Password: ${WP_DB_PASS}"
        log_info "  - Database: ${WP_DB_NAME}"
      fi
      
      log_info ""
      log_info "🔍 Container Information:"
      docker ps -f name="${CONTAINER_PREFIX}"
      log_info ""
      log_info "📋 To view logs: docker logs ${CONTAINER_PREFIX}wordpress"
      log_info "📋 To check status: $0 --status"
      log_info "⏹️ To stop: $0 --stop"
    else
      log_error "Failed to launch containers"
      log_error "Check the error messages above"
      exit 1
    fi
  else
    log_error "Docker Compose file not found at ${DOCKER_COMPOSE_FILE}"
    exit 1
  fi
}

# Main execution
check_prerequisites
setup_env_file
setup_network

# Handle operation modes
case "${OPERATION_MODE}" in
  status)
    check_status
    ;;
  stop)
    stop_containers
    ;;
  restart)
    restart_containers
    ;;
  launch)
    launch_containers
    ;;
esac

exit 0
