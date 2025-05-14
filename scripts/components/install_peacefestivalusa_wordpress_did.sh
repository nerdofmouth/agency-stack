#!/bin/bash

# PeaceFestivalUSA WordPress Docker-in-Docker Installer
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Strict Containerization
# - Component Consistency

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost"
WP_PORT="8082"
DB_PORT="33061"
ADMIN_EMAIL="admin@peacefestivalusa.com"
FORCE="false"
STATUS_ONLY="false"
DID_MODE="true"  # Docker-in-Docker mode always true

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
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --status)
      STATUS_ONLY="true"
      ;;
    *)
      # Unknown option
      ;;
  esac
  shift
done

log_info "==========================================="
log_info "Starting install_peacefestivalusa_wordpress_did.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "WP_PORT: ${WP_PORT}"
log_info "DID_MODE: ${DID_MODE}"
log_info "================================================="

# Set container names
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_db"
ADMINER_CONTAINER_NAME="${CLIENT_ID}_adminer"

# Set docker network
NETWORK_NAME="${CLIENT_ID}_network"

# Directory paths
CLIENT_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
WP_DIR="${CLIENT_DIR}/wordpress"
WP_CUSTOM_DIR="${CLIENT_DIR}/wordpress-custom"
DB_DATA_DIR="${CLIENT_DIR}/db_data"
BACKUP_DIR="${CLIENT_DIR}/backups"
LOG_DIR="${CLIENT_DIR}/logs"

# Create directories if they don't exist
ensure_directory "${CLIENT_DIR}"
ensure_directory "${WP_DIR}"
ensure_directory "${WP_CUSTOM_DIR}"
ensure_directory "${DB_DATA_DIR}"
ensure_directory "${BACKUP_DIR}"
ensure_directory "${LOG_DIR}"

# Function to generate a random password
generate_random_password() {
  local length=${1:-16}
  tr -dc 'a-zA-Z0-9!@#$%^&*()_+{}|:<>?=' < /dev/urandom | head -c ${length}
}

# Set database credentials
WP_DB_NAME="wordpress"
WP_DB_USER="wordpress"
WP_DB_PASS="$(generate_random_password 16)"
MYSQL_ROOT_PASS="$(generate_random_password 20)"

# Function to check container status
check_container_status() {
  log_info "Checking container status for Peace Festival USA WordPress..."
  
  WP_RUNNING=$(docker ps -q -f "name=${WORDPRESS_CONTAINER_NAME}" 2>/dev/null)
  DB_RUNNING=$(docker ps -q -f "name=${MARIADB_CONTAINER_NAME}" 2>/dev/null)
  
  if [ -n "$WP_RUNNING" ]; then
    log_success "WordPress container is running (ID: ${WP_RUNNING})"
  else
    log_warning "WordPress container is not running"
  fi
  
  if [ -n "$DB_RUNNING" ]; then
    log_success "MariaDB container is running (ID: ${DB_RUNNING})"
  else
    log_warning "MariaDB container is not running"
  fi
}

# If status check only, perform check and exit
if [ "$STATUS_ONLY" = "true" ]; then
  check_container_status
  exit 0
fi

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "${NETWORK_NAME}"; then
  log_info "Creating Docker network: ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}" || log_error "Failed to create Docker network"
fi

# Copy the custom entrypoint script from the template
log_info "Creating custom entrypoint script"
cp "${SCRIPT_DIR}/templates/peacefestivalusa-wordpress-custom-entrypoint.sh" "${WP_DIR}/custom-entrypoint.sh"
chmod +x "${WP_DIR}/custom-entrypoint.sh"
log_success "Custom entrypoint script created from template"

# Create WordPress config
cat > "${WP_DIR}/wp-config.php" << 'EOL'
<?php
// ** Database settings - from Docker environment variables ** //
define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') );
define( 'DB_USER', getenv('WORDPRESS_DB_USER') );
define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') );
define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

// ** Authentication Unique Keys and Salts ** //
define('AUTH_KEY',         '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('NONCE_KEY',        '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('AUTH_SALT',        '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');
define('NONCE_SALT',       '$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()' | fold -w 64 | head -n 1)');

$table_prefix = 'wp_';

define( 'WP_DEBUG', false );
define( 'WP_DEBUG_LOG', false );
define( 'WP_DEBUG_DISPLAY', false );

// Enable full error reporting for security
@ini_set( 'display_errors', 0 );

// Disable file editing from dashboard
define( 'DISALLOW_FILE_EDIT', true );

// Set recommended memory limits
define( 'WP_MEMORY_LIMIT', '256M' );

// Force SSL for admin
define( 'FORCE_SSL_ADMIN', getenv('WORDPRESS_FORCE_SSL_ADMIN') === 'true' );

// Auto save interval
define( 'AUTOSAVE_INTERVAL', 160 );
define( 'WP_POST_REVISIONS', 5 );

// ** Absolute path to the WordPress directory ** //
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOL

log_success "WordPress configuration file created"

# Create .env file
cat > "${CLIENT_DIR}/.env" << EOL
# Peace Festival USA WordPress Environment Variables
# Generated: $(date)
# Client: ${CLIENT_ID}

# WordPress settings
WORDPRESS_DB_HOST=${MARIADB_CONTAINER_NAME}
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASS}
WORDPRESS_DEBUG=false
WORDPRESS_FORCE_SSL_ADMIN=false

# Database settings
MYSQL_DATABASE=${WP_DB_NAME}
MYSQL_USER=${WP_DB_USER}
MYSQL_PASSWORD=${WP_DB_PASS}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}

# Site settings
WORDPRESS_SITE_URL=${DOMAIN}
WORDPRESS_ADMIN_EMAIL=${ADMIN_EMAIL}
EOL

log_success "Environment file created"

# Create docker-compose.yml file
cat > "${CLIENT_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:6.4-php8.2-apache
    restart: unless-stopped
    environment:
      - WORDPRESS_DB_HOST=${MARIADB_CONTAINER_NAME}
      - WORDPRESS_DB_NAME=${WP_DB_NAME}
      - WORDPRESS_DB_USER=${WP_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WP_DB_PASS}
      - WORDPRESS_DEBUG=false
    volumes:
      - ${WP_DIR}:/var/www/html
      - ${WP_CUSTOM_DIR}:/var/www/html/wp-content/themes/custom
      - ${WP_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
    entrypoint: ["/usr/local/bin/custom-entrypoint.sh"]
    ports:
      - "${WP_PORT}:80"
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - db

  db:
    container_name: ${MARIADB_CONTAINER_NAME}
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      - MYSQL_DATABASE=${WP_DB_NAME}
      - MYSQL_USER=${WP_DB_USER}
      - MYSQL_PASSWORD=${WP_DB_PASS}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
    volumes:
      - ${DB_DATA_DIR}:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}

  adminer:
    container_name: ${ADMINER_CONTAINER_NAME}
    image: adminer:latest
    restart: unless-stopped
    ports:
      - "8080:8080"
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - db

networks:
  ${NETWORK_NAME}:
    driver: bridge
EOL

log_success "Docker Compose file created"

# Start containers
log_info "Starting Docker containers..."
cd "${CLIENT_DIR}" && docker compose up -d

# Check if containers are running
if docker ps | grep -q "${WORDPRESS_CONTAINER_NAME}" && docker ps | grep -q "${MARIADB_CONTAINER_NAME}"; then
  log_success "Peace Festival USA WordPress installed successfully"
  log_info "WordPress is available at http://localhost:${WP_PORT}"
  log_info "Adminer is available at http://localhost:8080"
  log_info "Database credentials:"
  log_info "  Database name: ${WP_DB_NAME}"
  log_info "  Database user: ${WP_DB_USER}"
  log_info "  Database password: ${WP_DB_PASS}"
else
  log_error "Failed to start Peace Festival USA WordPress containers"
  docker compose logs
  exit 1
fi

# Add custom theme
if [[ -d "${SCRIPT_DIR}/templates/peacefestivalusa-theme" ]]; then
  log_info "Installing custom theme..."
  cp -r "${SCRIPT_DIR}/templates/peacefestivalusa-theme" "${WP_CUSTOM_DIR}/peacefestivalusa"
  log_success "Custom theme installed"
fi

log_success "Installation complete"
exit 0
