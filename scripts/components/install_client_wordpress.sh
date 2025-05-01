#!/bin/bash

# WordPress Client Installation Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Strict Containerization
# - Multi-Tenancy & Security

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Source VM compatibility module
if [[ -f "${SCRIPT_DIR}/../utils/vm_compatibility.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/vm_compatibility.sh"
fi

# Function to check if running in container
is_running_in_container() {
  if [ -f "/.dockerenv" ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to check for docker and docker-compose
check_prerequisites() {
  # Check for Docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    log_error "Please install Docker and ensure it's properly configured"
    exit 1
  fi

  # Check for Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    log_warning "Docker Compose is not installed or not in PATH"
    log_warning "Attempting to use docker compose (without hyphen) if available..."
    
    if ! command -v docker compose &> /dev/null; then
      log_error "Neither docker-compose nor docker compose commands found"
      log_error "Please install Docker Compose or verify Docker installation"
      exit 1
    else
      # Create alias for docker compose to use as docker-compose
      docker_compose="docker compose"
    fi
  else
    docker_compose="docker-compose"
  fi
  
  export docker_compose
}

# Function to exit with warning if running on host directly
exit_with_warning_if_host() {
  if ! is_running_in_container; then
    log_error "⛔ ERROR: This script CANNOT be run directly on the host per AgencyStack Charter v1.0.3"
    log_error "Strict Containerization principle requires all installations to be containerized"
    log_error "Please use the appropriate Makefile target instead:"
    log_error "  make peacefestival-wordpress"
    exit 1
  fi
}

# Default variables
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost:8082"
WP_ADMIN_EMAIL="admin@example.com"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="admin_password"
CONTAINER_PREFIX="pfusa_"
FORCE="false"
DEBUG="false"
ENVIRONMENT="development"
INSTALL_MODE="standard"
WITH_ADMINER="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id)
      CLIENT_ID="$2"
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift
      ;;
    --admin-email)
      WP_ADMIN_EMAIL="$2"
      shift
      ;;
    --admin-user)
      WP_ADMIN_USER="$2"
      shift
      ;;
    --admin-password)
      WP_ADMIN_PASSWORD="$2"
      shift
      ;;
    --container-prefix)
      CONTAINER_PREFIX="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --debug)
      DEBUG="true"
      ;;
    --with-adminer)
      WITH_ADMINER="true"
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift
      ;;
    --install-mode)
      INSTALL_MODE="$2"
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --client-id ID           Client identifier (default: peacefestivalusa)"
      echo "  --domain DOMAIN          Domain for WordPress (default: localhost:8082)"
      echo "  --admin-email EMAIL      WordPress admin email (default: admin@example.com)"
      echo "  --admin-user USER        WordPress admin user (default: admin)"
      echo "  --admin-password PASS    WordPress admin password (default: admin_password)"
      echo "  --container-prefix PRE   Prefix for container names (default: pfusa_)"
      echo "  --with-adminer           Include Adminer container for database management"
      echo "  --force                  Force reinstallation if already exists"
      echo "  --debug                  Enable debug mode"
      echo "  --environment ENV        Set environment (development, staging, production)"
      echo "  --install-mode MODE      Set installation mode (standard, minimal, full)"
      echo "  --help                   Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $key"
      exit 1
      ;;
  esac
  shift
done

log_info "Starting PeaceFestivalUSA WordPress Installation..."
log_info "Client ID: ${CLIENT_ID}"
log_info "Domain: ${DOMAIN}"
log_info "Environment: ${ENVIRONMENT}"
log_info "Installation Mode: ${INSTALL_MODE}"

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Detect environment
ENV_TYPE=$(detect_environment)
log_info "Detected environment: ${ENV_TYPE}"

# Check prerequisites
check_prerequisites
check_vm_requirements

# Prepare environment based on VM or WSL detection
prepare_environment "${CLIENT_ID}"

# Set paths according to environment
eval "$(get_installation_paths "${CLIENT_ID}")"
CLIENT_DIR="${REPO_ROOT}/clients/${CLIENT_ID}"
TARGET_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}"

# Create necessary directories
log_info "Creating necessary directories..."
mkdir -p "${TARGET_DIR}/wordpress/wp-content"
mkdir -p "${TARGET_DIR}/wordpress/database"
mkdir -p "${LOG_DIR}"

# Copy repository files to installation directory
log_info "Copying configuration files from repository..."
cp -f "${CLIENT_DIR}/docker-compose.yml" "${TARGET_DIR}/"

# Create .env file from template if it doesn't exist
if [ ! -f "${TARGET_DIR}/.env" ]; then
  if [ -f "${CLIENT_DIR}/.env.example" ]; then
    log_info "Creating .env file from example..."
    cp -f "${CLIENT_DIR}/.env.example" "${TARGET_DIR}/.env"
    
    # Update environment variables based on parameters
    log_info "Updating environment configuration..."
    # Use sed with | delimiter to handle URLs with slashes
    sed -i "s|DOMAIN=.*|DOMAIN=${DOMAIN}|" "${TARGET_DIR}/.env"
    sed -i "s|CLIENT_ID=.*|CLIENT_ID=${CLIENT_ID}|" "${TARGET_DIR}/.env"
    sed -i "s|WORDPRESS_DEBUG=.*|WORDPRESS_DEBUG=${DEBUG}|" "${TARGET_DIR}/.env"
    
    # Add additional environment variables
    echo "" >> "${TARGET_DIR}/.env"
    echo "# Added by installation script" >> "${TARGET_DIR}/.env"
    echo "CONTAINER_PREFIX=${CONTAINER_PREFIX}" >> "${TARGET_DIR}/.env"
    echo "WORDPRESS_PORT=8082" >> "${TARGET_DIR}/.env"
    echo "MARIADB_PORT=33061" >> "${TARGET_DIR}/.env"
    echo "ENVIRONMENT=${ENVIRONMENT}" >> "${TARGET_DIR}/.env"
  else
    log_error "No .env.example file found at ${CLIENT_DIR}/.env.example"
    exit 1
  fi
fi

# Create wp-config.php based on environment variables
log_info "Creating WordPress configuration file..."
mkdir -p "${TARGET_DIR}/wordpress"
cat > "${TARGET_DIR}/wordpress/wp-config.php" << EOF
<?php
/**
 * ${CLIENT_ID} WordPress Configuration
 * Generated by AgencyStack installation script
 * Following AgencyStack Charter v1.0.3 principles
 */

// ** Database settings - Using environment variables from container ** //
define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress' );
define( 'DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress' );
define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress_password' );
define( 'DB_HOST', 'db' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', 'utf8mb4_unicode_ci' );

// Authentication Unique Keys and Salts
define( 'AUTH_KEY',         '$(openssl rand -base64 48)' );
define( 'SECURE_AUTH_KEY',  '$(openssl rand -base64 48)' );
define( 'LOGGED_IN_KEY',    '$(openssl rand -base64 48)' );
define( 'NONCE_KEY',        '$(openssl rand -base64 48)' );
define( 'AUTH_SALT',        '$(openssl rand -base64 48)' );
define( 'SECURE_AUTH_SALT', '$(openssl rand -base64 48)' );
define( 'LOGGED_IN_SALT',   '$(openssl rand -base64 48)' );
define( 'NONCE_SALT',       '$(openssl rand -base64 48)' );

/**
 * WordPress Database Table prefix.
 */
\$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

/**
 * For developers: WordPress debugging mode.
 */
define( 'WP_DEBUG', filter_var(getenv('WORDPRESS_DEBUG'), FILTER_VALIDATE_BOOLEAN) );
define( 'WP_DEBUG_LOG', filter_var(getenv('WORDPRESS_DEBUG'), FILTER_VALIDATE_BOOLEAN) );
define( 'WP_DEBUG_DISPLAY', false );

/**
 * Set memory limits according to container environment
 */
define( 'WP_MEMORY_LIMIT', getenv('WORDPRESS_MEMORY_LIMIT') ?: '256M' );
define( 'WP_MAX_MEMORY_LIMIT', '512M' );

/**
 * Disable automatic updates - managed by containerized deployment
 */
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'WP_AUTO_UPDATE_CORE', false );

/**
 * Disable direct file editing from admin panel for security
 */
define( 'DISALLOW_FILE_EDIT', true );

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF

# Adapt Docker Compose for the current environment
log_info "Adapting Docker Compose for ${ENV_TYPE} environment..."
adapt_docker_compose "${TARGET_DIR}/docker-compose.yml"

# Setup Docker network
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

# Stop and remove existing containers if force flag is set
if [ "$FORCE" = "true" ]; then
  log_info "Force flag set, removing existing containers..."
  cd "${TARGET_DIR}" && ${docker_compose} down || true
  log_info "Existing containers removed"
fi

# Launch containers using Docker Compose
log_info "Launching WordPress containers..."
cd "${TARGET_DIR}" && ${docker_compose} up -d

if [ $? -eq 0 ]; then
  log_success "WordPress containers launched successfully!"
  log_info ""
  log_info "Access Information:"
  log_info "- WordPress: http://${DOMAIN}"
  log_info "- WordPress Admin: http://${DOMAIN}/wp-admin/"
  
  # Extract database credentials from env file
  if [ -f "${TARGET_DIR}/.env" ]; then
    WP_DB_USER=$(grep "WORDPRESS_DB_USER" "${TARGET_DIR}/.env" | cut -d= -f2)
    WP_DB_PASS=$(grep "WORDPRESS_DB_PASSWORD" "${TARGET_DIR}/.env" | cut -d= -f2)
    WP_DB_NAME=$(grep "WORDPRESS_DB_NAME" "${TARGET_DIR}/.env" | cut -d= -f2)
    
    log_info "- Database Connection:"
    log_info "  - Host: ${DOMAIN}"
    log_info "  - User: ${WP_DB_USER}"
    log_info "  - Password: ${WP_DB_PASS}"
    log_info "  - Database: ${WP_DB_NAME}"
  fi
  
  # Create a launcher script
  log_info "Creating convenience launcher script..."
  cat > "${TARGET_DIR}/launch-wordpress.sh" << EOF
#!/bin/bash

# Generated by AgencyStack installation script
# Following AgencyStack Charter v1.0.3 principles

# Source common utilities if available
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT}"

if [ -f "\${REPO_ROOT}/scripts/utils/common.sh" ]; then
  source "\${REPO_ROOT}/scripts/utils/common.sh"
else
  # Simple log functions if common.sh is not available
  log_info() { echo "[INFO] \$1"; }
  log_success() { echo "[SUCCESS] \$1"; }
  log_error() { echo "[ERROR] \$1"; }
fi

cd "\${SCRIPT_DIR}" && docker-compose \$@

if [ "\$1" = "up" ] || [ "\$1" = "restart" ]; then
  log_success "WordPress is available at http://${DOMAIN}"
  log_success "Admin interface: http://${DOMAIN}/wp-admin/"
fi
EOF
  chmod +x "${TARGET_DIR}/launch-wordpress.sh"
  
  log_success "Installation completed successfully!"
  log_info "To manage WordPress containers, use: ${TARGET_DIR}/launch-wordpress.sh [up|down|restart|logs]"
else
  log_error "Failed to launch WordPress containers"
  log_error "Please check the error messages above"
  exit 1
fi

exit 0
