#!/bin/bash

# PeaceFestivalUSA Full Deployment Script with Integrated Testing
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Proper Change Workflow
# - TDD Protocol
# - Auditability & Documentation

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="peacefestivalusa.localhost"
WP_PORT="8082"
DB_PORT="33061"
ADMIN_EMAIL="admin@peacefestivalusa.com"
FORCE="false"
SKIP_TESTS="false"
DB_PASSWORD="wordpress_secure_password"
ROOT_PASSWORD="root_secure_password"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --wordpress-port)
      WP_PORT="$2"
      shift
      ;;
    --db-port)
      DB_PORT="$2"
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --skip-tests)
      SKIP_TESTS="true"
      ;;
    --db-password)
      DB_PASSWORD="$2"
      shift
      ;;
    --root-password)
      ROOT_PASSWORD="$2"
      shift
      ;;
    *)
      # Unknown option
      log_warning "Unknown option: $key"
      ;;
  esac
  shift
done

log_info "==================================================="
log_info "Starting deploy_peacefestivalusa_full.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "WP_PORT: ${WP_PORT}"
log_info "DB_PORT: ${DB_PORT}"
log_info "SKIP_TESTS: ${SKIP_TESTS}"
log_info "==================================================="

# Ensure directories exist following Charter directory structure
HOST_LOGS_DIR="/var/log/agency_stack/components/${CLIENT_ID}"
HOST_DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
mkdir -p "${HOST_LOGS_DIR}"
mkdir -p "${HOST_DATA_DIR}/wordpress"
mkdir -p "${HOST_DATA_DIR}/db_data"
mkdir -p "${HOST_DATA_DIR}/logs"
log_success "Created Charter-compliant directory structure"

# Check if network exists
NETWORK_NAME="${CLIENT_ID}_network"
if ! docker network ls | grep -q "${NETWORK_NAME}"; then
  log_info "Creating Docker network ${NETWORK_NAME}..."
  docker network create "${NETWORK_NAME}"
  log_success "Docker network created"
else
  log_info "Docker network ${NETWORK_NAME} already exists"
fi

# Function to remove existing containers if forced
remove_existing_containers() {
  if [[ "${FORCE}" == "true" ]]; then
    log_warning "Force flag set, removing existing containers..."
    docker rm -f "${CLIENT_ID}_wordpress" "${CLIENT_ID}_db" "${CLIENT_ID}_adminer" || true
    log_success "Existing containers removed"
  fi
}

# Setup database container
setup_database() {
  log_info "Setting up MariaDB container..."
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CLIENT_ID}_db$"; then
    if [[ "${FORCE}" != "true" ]]; then
      log_info "Database container already exists, starting if needed..."
      docker start "${CLIENT_ID}_db" || true
      return
    fi
  fi
  
  # Create database container
  docker run -d \
    --name "${CLIENT_ID}_db" \
    --network "${NETWORK_NAME}" \
    -e MYSQL_DATABASE=wordpress \
    -e MYSQL_USER=wordpress \
    -e MYSQL_PASSWORD="${DB_PASSWORD}" \
    -e MYSQL_ROOT_PASSWORD="${ROOT_PASSWORD}" \
    -v "${HOST_DATA_DIR}/db_data:/var/lib/mysql" \
    -p "${DB_PORT}:3306" \
    mariadb:10.11
  
  log_success "MariaDB container setup complete"
  
  # Wait for database to initialize
  log_info "Waiting for database to initialize..."
  sleep 10
}

# Setup WordPress container
setup_wordpress() {
  log_info "Setting up WordPress container..."
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CLIENT_ID}_wordpress$"; then
    if [[ "${FORCE}" != "true" ]]; then
      log_info "WordPress container already exists, starting if needed..."
      docker start "${CLIENT_ID}_wordpress" || true
      return
    fi
  fi
  
  # Copy health check file to WordPress data directory
  cp "${SCRIPT_DIR}/templates/agencystack-health.php" "${HOST_DATA_DIR}/wordpress/agencystack-health.php"
  log_success "Health check file copied to WordPress directory"
  
  # Create WordPress container with proper network configuration
  docker run -d \
    --name "${CLIENT_ID}_wordpress" \
    --network "${NETWORK_NAME}" \
    -e WORDPRESS_DB_HOST="${CLIENT_ID}_db" \
    -e WORDPRESS_DB_USER=wordpress \
    -e WORDPRESS_DB_PASSWORD="${DB_PASSWORD}" \
    -e WORDPRESS_DB_NAME=wordpress \
    -e WORDPRESS_DEBUG=1 \
    -e CLIENT_ID="${CLIENT_ID}" \
    -v "${HOST_DATA_DIR}/wordpress:/var/www/html" \
    -p "${WP_PORT}:80" \
    wordpress:6.4-php8.2-apache
  
  log_success "WordPress container setup complete"
}

# Setup Adminer container
setup_adminer() {
  log_info "Setting up Adminer container..."
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CLIENT_ID}_adminer$"; then
    if [[ "${FORCE}" != "true" ]]; then
      log_info "Adminer container already exists, starting if needed..."
      docker start "${CLIENT_ID}_adminer" || true
      return
    fi
  fi
  
  # Create Adminer container
  docker run -d \
    --name "${CLIENT_ID}_adminer" \
    --network "${NETWORK_NAME}" \
    -e ADMINER_DEFAULT_SERVER="${CLIENT_ID}_db" \
    -p "8080:8080" \
    adminer:latest
  
  log_success "Adminer container setup complete"
}

# Save environment configuration according to Charter
save_environment_config() {
  log_info "Saving environment configuration..."
  
  cat > "${HOST_DATA_DIR}/.env" << EOL
# PeaceFestivalUSA WordPress Environment Variables
# Generated: $(date)
# Following AgencyStack Charter v1.0.3 principles

# Client identification
CLIENT_ID=${CLIENT_ID}
DOMAIN=${DOMAIN}

# WordPress database configuration
WORDPRESS_DB_HOST=${CLIENT_ID}_db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=wp_
MYSQL_ROOT_PASSWORD=${ROOT_PASSWORD}

# Container names
WP_CONTAINER=${CLIENT_ID}_wordpress
DB_CONTAINER=${CLIENT_ID}_db
ADMINER_CONTAINER=${CLIENT_ID}_adminer
NETWORK_NAME=${NETWORK_NAME}

# Ports
WP_PORT=${WP_PORT}
DB_PORT=${DB_PORT}
EOL
  
  log_success "Environment configuration saved to ${HOST_DATA_DIR}/.env"
}

# Function to run tests
run_tests() {
  if [[ "${SKIP_TESTS}" == "true" ]]; then
    log_info "Skipping tests as requested"
    return 0
  fi
  
  log_info "Running tests for ${CLIENT_ID} deployment..."
  
  # Wait for containers to start
  log_info "Waiting for containers to initialize..."
  sleep 10
  
  # Run the comprehensive test script
  "${SCRIPT_DIR}/../utils/test_peacefestivalusa_wordpress.sh"
  TEST_RESULT=$?
  
  if [[ ${TEST_RESULT} -eq 0 ]]; then
    log_success "All tests passed"
  else
    log_error "Some tests failed"
  fi
  
  return ${TEST_RESULT}
}

# Main execution flow
remove_existing_containers
setup_database
setup_wordpress
setup_adminer
save_environment_config

# Run tests
if run_tests; then
  log_success "Deployment and testing completed successfully"
else
  log_warning "Deployment completed but some tests failed, see test output for details"
fi

# Display deployment summary
log_info "==================== DEPLOYMENT SUMMARY ===================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Domain: ${DOMAIN}"
log_info "WordPress URL: http://localhost:${WP_PORT}"
log_info "Adminer URL: http://localhost:8080"
log_info "Database: MariaDB 10.11"
log_info "WordPress: 6.4-php8.2-apache"
log_info "Health check: http://localhost:${WP_PORT}/agencystack-health.php"
log_info "============================================================"

exit 0
