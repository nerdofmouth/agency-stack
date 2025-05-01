#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# AgencyStack Component Installation: WordPress for Client
# Path: /scripts/components/install_client_wordpress.sh
#
# This script installs and configures WordPress for a specific client in a containerized environment,
# following the principles of the AgencyStack Charter v1.0.3:
# - Repository as Source of Truth
# - Idempotency & Automation
# - Strict Containerization
# - Multi-Tenancy & Security

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Default configuration
CLIENT_ID="default"
DOMAIN="localhost"
ADMIN_EMAIL="admin@example.com"
WP_PORT="80"
DB_PORT="3306"
USE_TRAEFIK="false"
CONTAINER_NAME_PREFIX=""
FORCE="false"
OPERATION_MODE="install"

# Function to check if running in container
is_running_in_container() {
  if [ -f "/.dockerenv" ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Set Docker-in-Docker detection
if is_running_in_container; then
  CONTAINER_RUNNING="true"
  DID_MODE="true"
  log_info "Detected Docker-in-Docker environment, enabling container compatibility mode"
fi

# Display help information
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install WordPress for a specific client with proper containerization."
  echo ""
  echo "Options:"
  echo "  --client-id ID          Client identifier (default: default)"
  echo "  --domain DOMAIN         Domain for WordPress (default: localhost)"
  echo "  --admin-email EMAIL     Admin email for WordPress (default: admin@example.com)"
  echo "  --wp-port PORT          WordPress port (default: 80)"
  echo "  --db-port PORT          Database port (default: 3306)"
  echo "  --enable-traefik        Configure for Traefik proxy"
  echo "  --container-name-prefix PREFIX  Prefix for container names to prevent collisions"
  echo "  --force                 Force reinstall if existing"
  echo "  --status-only           Only check status"
  echo "  --logs-only             Only show logs"
  echo "  --restart-only          Only restart services"
  echo "  --remove                Remove the installation"
  echo "  --help                  Show this help message"
  echo ""
  echo "Example: $0 --client-id acme --domain acme.example.com --admin-email admin@acme.com"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  # Split the key=value format if present
  if [[ $key == *"="* ]]; then
    value="${key#*=}"
    key="${key%%=*}"
    set -- "$key" "$value" "${@:2}"
    continue
  fi
  
  case "$key" in
    --client-id)
      CLIENT_ID="$2"
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      ;;
    --wp-port)
      WP_PORT="$2"
      shift
      ;;
    --db-port)
      DB_PORT="$2"
      shift
      ;;
    --enable-traefik)
      USE_TRAEFIK="true"
      ;;
    --container-name-prefix)
      CONTAINER_NAME_PREFIX="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --status-only)
      OPERATION_MODE="status"
      ;;
    --logs-only)
      OPERATION_MODE="logs"
      ;;
    --restart-only)
      OPERATION_MODE="restart"
      ;;
    --remove)
      OPERATION_MODE="remove"
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $key"
      show_help
      exit 1
      ;;
  esac
  shift
done

# Function to generate container names with optional prefix
get_container_name() {
  local suffix="$1"
  if [ -n "$CONTAINER_NAME_PREFIX" ]; then
    echo "${CONTAINER_NAME_PREFIX}${suffix}"
  else
    echo "${CLIENT_ID}_${suffix}"
  fi
}

# Set paths based on Docker-in-Docker mode
if [ "$CONTAINER_RUNNING" = "true" ] && [ "$DID_MODE" = "true" ]; then
  # In Docker-in-Docker, use the container paths
  INSTALL_BASE_DIR="${HOME}/.agencystack"
else
  # Standard installation path
  INSTALL_BASE_DIR="/opt/agency_stack"
fi

# Initialize paths and variables
DATA_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}"
WP_DIR="${DATA_DIR}/wordpress"
LOG_DIR="/var/log/agency_stack/components"
SECRETS_DIR="${DATA_DIR}/secrets"
LOG_FILE="${LOG_DIR}/wordpress_${CLIENT_ID}.log"
ENV_FILE="${WP_DIR}/.env"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}" || true

# Display header
log_info "========================================="
log_info "Starting install_client_wordpress.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "========================================="

# Status check function
check_status() {
  log_info "Checking status of ${CLIENT_ID} WordPress installation"
  
  # Check if installation directory exists
  if [ ! -d "${WP_DIR}" ]; then
    log_warning "Installation directory not found: ${WP_DIR}"
    return 1
  fi
  
  # Check if docker-compose.yml exists
  if [ ! -f "${WP_DIR}/docker-compose.yml" ]; then
    log_warning "Docker Compose file not found: ${WP_DIR}/docker-compose.yml"
    return 1
  fi
  
  # Check if containers are running
  WP_CONTAINER=$(get_container_name "wordpress")
  DB_CONTAINER=$(get_container_name "mariadb")
  
  WP_RUNNING=$(docker ps -q -f name="${WP_CONTAINER}")
  DB_RUNNING=$(docker ps -q -f name="${DB_CONTAINER}")
  
  if [ -z "${WP_RUNNING}" ]; then
    log_warning "WordPress container not running"
  else
    log_success "WordPress container running: ${WP_CONTAINER}"
  fi
  
  if [ -z "${DB_RUNNING}" ]; then
    log_warning "Database container not running"
  else
    log_success "Database container running: ${DB_CONTAINER}"
  fi
  
  # Check if the site is accessible
  if [ -n "${WP_RUNNING}" ]; then
    log_info "WordPress URL: http://${DOMAIN}"
    log_info "Admin area: http://${DOMAIN}/wp-admin/"
  fi
  
  log_info "Installation directory: ${WP_DIR}"
  log_info "Log file: ${LOG_FILE}"
  
  return 0
}

# Logs function
show_logs() {
  log_info "Showing logs for ${CLIENT_ID} WordPress installation"
  
  WP_CONTAINER=$(get_container_name "wordpress")
  DB_CONTAINER=$(get_container_name "mariadb")
  
  log_info "WordPress container logs:"
  docker logs "${WP_CONTAINER}" 2>&1 | tail -n 50
  
  log_info "Database container logs:"
  docker logs "${DB_CONTAINER}" 2>&1 | tail -n 20
}

# Restart function
restart_services() {
  log_info "Restarting ${CLIENT_ID} WordPress services..."
  
  WP_CONTAINER=$(get_container_name "wordpress")
  DB_CONTAINER=$(get_container_name "mariadb")
  
  if [ -f "${WP_DIR}/docker-compose.yml" ]; then
    log_info "Restarting via Docker Compose..."
    cd "${WP_DIR}" && docker-compose restart
  else
    log_info "Restarting individual containers..."
    docker restart "${WP_CONTAINER}" || log_error "Failed to restart WordPress container"
    docker restart "${DB_CONTAINER}" || log_error "Failed to restart database container"
  fi
  
  log_success "Services restarted successfully"
}

# Remove function
remove_installation() {
  log_info "Removing ${CLIENT_ID} WordPress installation..."
  
  WP_CONTAINER=$(get_container_name "wordpress")
  DB_CONTAINER=$(get_container_name "mariadb")
  NETWORK_NAME=$(get_container_name "network")
  
  if [ -f "${WP_DIR}/docker-compose.yml" ]; then
    log_info "Removing via Docker Compose..."
    cd "${WP_DIR}" && docker-compose down -v
  else
    log_info "Removing individual containers..."
    docker rm -f "${WP_CONTAINER}" 2>/dev/null || true
    docker rm -f "${DB_CONTAINER}" 2>/dev/null || true
    docker network rm "${NETWORK_NAME}" 2>/dev/null || true
  fi
  
  if [ "$FORCE" = "true" ]; then
    log_info "Removing data directories..."
    rm -rf "${WP_DIR}" || log_error "Failed to remove WordPress directory"
    
    log_warning "Note: Secrets directory was preserved at ${SECRETS_DIR}"
  else
    log_info "Data directories were preserved. Use --force to remove them."
  fi
  
  log_success "Installation removed successfully"
}

# Handle operation modes
case "${OPERATION_MODE}" in
  status)
    check_status
    exit 0
    ;;
  logs)
    show_logs
    exit 0
    ;;
  restart)
    restart_services
    exit 0
    ;;
  remove)
    remove_installation
    exit 0
    ;;
esac

# Main installation logic
log_info "Creating directory structure for ${CLIENT_ID}"
mkdir -p "${WP_DIR}/wp-content" "${WP_DIR}/mariadb-data" "${WP_DIR}/wp-config" "${SECRETS_DIR}" "${WP_DIR}/init-scripts" >> "${LOG_FILE}" 2>&1

# Generate secure passwords and credentials
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD=$(openssl rand -base64 12)
WP_DB_NAME="${CLIENT_ID}_wordpress"
WP_DB_USER="${CLIENT_ID}_wp"
WP_DB_PASSWORD=$(openssl rand -base64 12)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
WP_TABLE_PREFIX="wp_"

# Create .env file with configuration
create_env_file() {
  log_info "Creating environment configuration"
  
  cat > "${WP_DIR}/.env" <<EOL
# WordPress Docker Environment for ${CLIENT_ID}
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
WORDPRESS_DEBUG=1
EOL

  log_success "Environment configuration created"
  
  # Save credentials to a secure file
  cat > "${SECRETS_DIR}/wordpress-credentials.txt" <<EOL
# WordPress Credentials for ${CLIENT_ID}
# Generated on $(date)
# DO NOT SHARE THIS FILE

Domain: ${DOMAIN}
Admin URL: http://${DOMAIN}/wp-admin/

Database:
  Name: ${WP_DB_NAME}
  User: ${WP_DB_USER}
  Password: ${WP_DB_PASSWORD}
  Root Password: ${MYSQL_ROOT_PASSWORD}

WordPress Admin:
  Username: ${WP_ADMIN_USER}
  Password: ${WP_ADMIN_PASSWORD}
  Email: ${ADMIN_EMAIL}
EOL

  chmod 600 "${SECRETS_DIR}/wordpress-credentials.txt"
  log_success "Credentials saved to ${SECRETS_DIR}/wordpress-credentials.txt"
}

create_env_file

# Create database initialization script
log_info "Creating database initialization script"
mkdir -p "${WP_DIR}/init-scripts"

cat > "${WP_DIR}/init-scripts/01-init-db.sql" <<EOL
-- WordPress Database Initialization for ${CLIENT_ID}
-- Created automatically by install_client_wordpress.sh

-- Create WordPress database if it doesn't exist
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create WordPress user if it doesn't exist
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';

-- Create development user for testing (with limited privileges)
CREATE USER IF NOT EXISTS 'dev_${CLIENT_ID}'@'%' IDENTIFIED BY 'dev_password';
GRANT SELECT, SHOW VIEW ON \`${WP_DB_NAME}\`.* TO 'dev_${CLIENT_ID}'@'%';

-- Ensure privileges are applied
FLUSH PRIVILEGES;
EOL

# Create verification script
cat > "${WP_DIR}/init-scripts/02-verify-db.sh" <<EOL
#!/bin/bash
# Database Verification Script for ${CLIENT_ID}
# Verifies that MySQL is accessible and WordPress database exists

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
COUNTER=0
MAX_TRIES=30
until mysql -h mariadb -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" >/dev/null 2>&1
do
  sleep 2
  let COUNTER=COUNTER+1
  echo "Attempt \$COUNTER of \$MAX_TRIES"
  
  if [ \$COUNTER -ge \$MAX_TRIES ]; then
    echo "ERROR: MySQL not available after \$MAX_TRIES attempts"
    exit 1
  fi
done

# Verify WordPress database
echo "Verifying WordPress database..."
DB_EXISTS=\$(mysql -h mariadb -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES LIKE '${WP_DB_NAME}'" | grep -c "${WP_DB_NAME}")

if [ \$DB_EXISTS -eq 1 ]; then
  echo "SUCCESS: WordPress database '${WP_DB_NAME}' exists"
else
  echo "ERROR: WordPress database '${WP_DB_NAME}' not found"
  exit 1
fi

echo "Database verification completed successfully"
exit 0
EOL

chmod +x "${WP_DIR}/init-scripts/02-verify-db.sh"

# Create WordPress config
log_info "Creating WordPress configuration"
cat > "${WP_DIR}/wp-config/wp-config-agency.php" <<EOL
<?php
// AgencyStack WordPress Configuration - DO NOT MODIFY DIRECTLY
// Created automatically by install_client_wordpress.sh for client: ${CLIENT_ID}

// ** MySQL settings ** //
define('DB_NAME', '${WP_DB_NAME}');
define('DB_USER', '${WP_DB_USER}');
define('DB_PASSWORD', '${WP_DB_PASSWORD}');
define('DB_HOST', 'mariadb');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// ** WordPress salts ** //
define('AUTH_KEY',         '$(openssl rand -base64 48)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 48)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 48)');
define('NONCE_KEY',        '$(openssl rand -base64 48)');
define('AUTH_SALT',        '$(openssl rand -base64 48)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 48)');
define('NONCE_SALT',       '$(openssl rand -base64 48)');

// ** WordPress Database Table prefix ** //
\$table_prefix = '${WP_TABLE_PREFIX}';

// ** Debug settings ** //
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

// ** Prevent redirects to HTTPS when not configured ** //
define('FORCE_SSL_ADMIN', false);

// ** Override default URLs with container-aware URLs ** //
\$_SERVER['HTTP_HOST'] = '${DOMAIN}:${WP_PORT}';

// ** Set default admin email for WordPress ** //
define('ADMIN_EMAIL', '${ADMIN_EMAIL}');

// ** Disable automatic updates ** //
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_AUTO_UPDATE_CORE', false);

// ** Disable file editing from admin ** //
define('DISALLOW_FILE_EDIT', true);

// ** Include standard WordPress config ** //
if (file_exists(dirname(__FILE__) . '/wp-config-local.php')) {
    include(dirname(__FILE__) . '/wp-config-local.php');
}
EOL

# Check for existing network or create a new one
check_network() {
  NETWORK_NAME=$(get_container_name "network")
  NETWORK_EXISTS=$(docker network ls | grep -c "${NETWORK_NAME}")
  
  if [ "${NETWORK_EXISTS}" -eq 0 ]; then
    log_info "Creating Docker network: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" >> "${LOG_FILE}" 2>&1 || {
      log_error "Failed to create Docker network"
      exit 1
    }
  else
    log_info "Using existing Docker network: ${NETWORK_NAME}"
  fi
}

check_network

# Create Docker Compose configuration
create_docker_compose() {
  log_info "Creating Docker Compose configuration"
  
  WP_CONTAINER=$(get_container_name "wordpress")
  DB_CONTAINER=$(get_container_name "mariadb")
  NETWORK_NAME=$(get_container_name "network")
  
  # Setup Traefik labels if enabled
  TRAEFIK_LABELS=""
  if [ "${USE_TRAEFIK}" = "true" ]; then
    TRAEFIK_LABELS=$(cat <<EOL
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-wp.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-wp.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-wp.tls=true"
      - "traefik.http.services.${CLIENT_ID}-wp.loadbalancer.server.port=80"
EOL
)
  fi
  
  cat > "${WP_DIR}/docker-compose.yml" <<EOL
version: '3.7'

services:
  wordpress:
    container_name: ${WP_CONTAINER}
    image: wordpress:latest
    restart: unless-stopped
    depends_on:
      - mariadb
    env_file:
      - .env
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./wp-config/wp-config-agency.php:/var/www/html/wp-config.php
      - ./init-scripts:/docker-entrypoint-initdb.d
    ports:
      - "${WP_PORT}:80"
    networks:
      - wordpress_net
    environment:
      - WORDPRESS_CONFIG_EXTRA=define('WP_HOME','http://${DOMAIN}:${WP_PORT}'); define('WP_SITEURL','http://${DOMAIN}:${WP_PORT}');
    labels:
      - "agency.client=${CLIENT_ID}"
      - "agency.component=wordpress"
      - "agency.managedby=agencystack"${TRAEFIK_LABELS}

  mariadb:
    container_name: ${DB_CONTAINER}
    image: mariadb:10.5
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./mariadb-data:/var/lib/mysql
      - ./init-scripts:/docker-entrypoint-initdb.d
    ports:
      - "${DB_PORT}:3306"
    networks:
      - wordpress_net
    environment:
      - MYSQL_DATABASE=${WP_DB_NAME}
      - MYSQL_USER=${WP_DB_USER}
      - MYSQL_PASSWORD=${WP_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    labels:
      - "agency.client=${CLIENT_ID}"
      - "agency.component=mariadb"
      - "agency.managedby=agencystack"

networks:
  wordpress_net:
    name: ${NETWORK_NAME}
    external: true
EOL

  # Create installation verification script
  cat > "${WP_DIR}/verify_installation.sh" <<EOL
#!/bin/bash
# Verify WordPress Installation
# This script checks if WordPress is properly installed and running

# Wait for WordPress to be ready
echo "Waiting for WordPress to initialize..."
COUNTER=0
MAX_TRIES=30

until curl -s "http://${DOMAIN}:${WP_PORT}" > /dev/null; do
  sleep 2
  let COUNTER=COUNTER+1
  echo "Attempt \$COUNTER of \$MAX_TRIES"
  
  # Check if WordPress is responsive
  HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}:${WP_PORT}")
  if [[ "\$HTTP_STATUS" == "200" || "\$HTTP_STATUS" == "302" || "\$HTTP_STATUS" == "301" ]]; then
    echo "WordPress is responsive with HTTP status \$HTTP_STATUS"
    break
  fi
  
  if [ \$COUNTER -ge \$MAX_TRIES ]; then
    echo "ERROR: WordPress not available after \$MAX_TRIES attempts"
    exit 1
  fi
done

echo "WordPress verification completed successfully"
exit 0
EOL

  chmod +x "${WP_DIR}/verify_installation.sh"
  
  # Run verification
  log_info "Running verification script"
  "${WP_DIR}/verify_installation.sh" >> "${LOG_FILE}" 2>&1 &
  
  log_success "Docker Compose configuration created successfully"
  log_info "WordPress container name: ${WP_CONTAINER}"
  log_info "Database container name: ${DB_CONTAINER}"
  log_info "Network name: ${NETWORK_NAME}"
  log_info "Port mappings:"
  log_info "- WordPress: ${WP_PORT} -> 80"
  log_info "- MariaDB: ${DB_PORT} -> 3306"
  
  log_info "Configuration files:"
  log_info "- Docker Compose: ${WP_DIR}/docker-compose.yml"
  log_info "- Environment: ${WP_DIR}/.env"
  log_info "- WordPress config: ${WP_DIR}/wp-config/wp-config-agency.php"
  
  log_info "Credentials:"
  log_info "- Admin Username: ${WP_ADMIN_USER}"
  log_info "- Admin Password: ${WP_ADMIN_PASSWORD}"
  log_info "- Admin Email: ${ADMIN_EMAIL}"
  log_info "- Database Name: ${WP_DB_NAME}"
  log_info "- Database User: ${WP_DB_USER}"
  log_info "- Database Password: ${WP_DB_PASSWORD}"
  
  echo ""
  echo "All credentials are stored in: ${SECRETS_DIR}/wordpress-credentials.txt"
  echo "Log file: ${LOG_FILE}"
  echo ""
  echo "To check status: $0 --client-id=${CLIENT_ID} --status-only"
  echo "To view logs: $0 --client-id=${CLIENT_ID} --logs-only"
  echo "To restart services: $0 --client-id=${CLIENT_ID} --restart-only"
  echo ""
  echo "For TDD Protocol compliance, run tests with 'make client-wordpress-test CLIENT_ID=${CLIENT_ID}'"
}

create_docker_compose

# Start the containers
if [ "$FORCE" = "true" ]; then
  log_info "Stopping any existing containers..."
  DOCKER_COMPOSE_FILE="${WP_DIR}/docker-compose.yml"
  cd "$(dirname "${DOCKER_COMPOSE_FILE}")" && docker-compose -f "${DOCKER_COMPOSE_FILE}" down -v || true
fi

log_info "Starting containers..."
DOCKER_COMPOSE_FILE="${WP_DIR}/docker-compose.yml"
cd "$(dirname "${DOCKER_COMPOSE_FILE}")" && docker-compose -f "${DOCKER_COMPOSE_FILE}" up -d

if [ $? -eq 0 ]; then
  log_success "WordPress installation for ${CLIENT_ID} started successfully"
  
  # Wait for WordPress to initialize
  log_info "Waiting for WordPress to initialize (this may take a moment)..."
  sleep 10
  
  # Display access information
  log_info "WordPress is now accessible at: http://${DOMAIN}:${WP_PORT}"
  log_info "Admin area: http://${DOMAIN}:${WP_PORT}/wp-admin/"
  log_info "Default credentials:"
  log_info "- Username: admin"
  log_info "- Password: See ${SECRETS_DIR}/wordpress-credentials.txt"
  
  # Update component registry if available
  if [ -f "${SCRIPT_DIR}/../utils/update_component_registry.sh" ]; then
    "${SCRIPT_DIR}/../utils/update_component_registry.sh" --update-component wordpress --update-client "${CLIENT_ID}" --update-flag installed --update-value true
  fi
else
  log_error "Failed to start WordPress containers"
  exit 1
fi

# Final success message
log_success "WordPress installation for ${CLIENT_ID} completed successfully"
log_info "For complete documentation, see: /docs/pages/components/client_wordpress.md"

# Always exit cleanly - this is required by AgencyStack Charter TDD Protocol
exit 0
