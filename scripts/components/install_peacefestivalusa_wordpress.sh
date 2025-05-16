#!/bin/bash

# Parse arguments (support --client-id, --domain, --admin-email, --force, etc.)
CLIENT_ID="${CLIENT_ID:-}"
DOMAIN="${DOMAIN:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ALLOW_VM_INSTALL_FLAG=false
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id)
      CLIENT_ID="$2"; shift 2 ;;
    --client-id=*)
      CLIENT_ID="${key#*=}"; shift ;;
    --domain)
      DOMAIN="$2"; shift 2 ;;
    --domain=*)
      DOMAIN="${key#*=}"; shift ;;
    --admin-email)
      ADMIN_EMAIL="$2"; shift 2 ;;
    --admin-email=*)
      ADMIN_EMAIL="${key#*=}"; shift ;;
    --force)
      ALLOW_VM_INSTALL_FLAG=true; shift ;;
    *)
      shift ;;
  esac
done

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: peacefestivalusa_wordpress.sh
# Path: /scripts/components/install_peacefestivalusa_wordpress.sh
#
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  echo "ERROR: This script must be run from the repository context"
  echo "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1
fi

# Source common utilities and logging functions
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

  echo "ERROR: Could not find common.sh"
  exit 1

# Check if running in development container
is_dev_container() {
  if [ -f "/.dockerenv" ] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
    if [ -d "/workspaces" ] || [ -d "/home/vscode" ]; then
      return 0 # true, we're in a dev container
    fi
  fi
  return 1 # false
}

# Set Docker-in-Docker detection and VM override
ALLOW_VM_INSTALL_FLAG=false
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then
    ALLOW_VM_INSTALL_FLAG=true
    break
  fi
done

if [ "${ALLOW_VM_INSTALL}" = "true" ] || [ "$ALLOW_VM_INSTALL_FLAG" = "true" ]; then
  log_warning "Container/VM check bypassed: user asserts this is a dedicated, sovereign VM (per AgencyStack Charter)."
else
  if is_running_in_container; then
    CONTAINER_RUNNING="true"
    DID_MODE="true"
    log_info "Detected Docker-in-Docker environment, adjusting for container compatibility"
    # Source Docker networking configuration
    if type configure_docker_network_mode &>/dev/null; then
      configure_docker_network_mode
      log_info "Configured Docker networking for container environment"
    else
      log_warning "Docker network configuration function not found"
    fi
  elif is_dev_container; then
    CONTAINER_RUNNING="true"
    DID_MODE="false"
    log_info "Detected development container environment"
  else
    echo "[CRITICAL ERROR] AgencyStack Charter v1.0.3 requires STRICT CONTAINERIZATION or approved, dedicated VM deployment!"
    echo "[CRITICAL ERROR] This script must run inside a Docker container, LXC, or a remote, dedicated VM provisioned for a single client."
    echo "[CRITICAL ERROR] Do NOT install components directly on the AgencyStack management host or any shared infrastructure."
    echo "[INSTRUCTION] If this is a dedicated VM, re-run with ALLOW_VM_INSTALL=true or --force to proceed."
    echo "[INSTRUCTION] See README_AGENT.md and Charter for policy details."
    exit 70
  fi
fi

# Client-specific variables (multi-client ready)
CLIENT_ID="${CLIENT_ID:-}"
DOMAIN="${DOMAIN:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@${CLIENT_ID}.nerdofmouth.com}"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD=$(openssl rand -base64 12)
WP_DB_NAME="${CLIENT_ID}_wordpress"
WP_DB_USER="${CLIENT_ID}_wp"
WP_TABLE_PREFIX="wp_"
WP_PORT="${WP_PORT:-8082}"
MARIADB_PORT="${MARIADB_PORT:-3306}"

# Parse arguments (support --client-id and --domain)
while [[ $# -gt 0 ]]; do
  key="$1"
  if [[ $key == *"="* ]]; then
    value="${key#*=}"
    key="${key%%=*}"
  else
    value=""
  fi
  case $key in
    --client-id)
      CLIENT_ID="$2"; shift ;;
    --client-id=*)
      CLIENT_ID="$value" ;;
    --domain)
      DOMAIN="$2"; shift ;;
    --domain=*)
      DOMAIN="$value" ;;
    --admin-email)
      ADMIN_EMAIL="$2"; shift ;;
    --admin-email=*)
      ADMIN_EMAIL="$value" ;;
    # (other flags remain unchanged)
    *)
      # existing flag parsing here
      ;;
  esac
  shift
done

# Validate CLIENT_ID
if [ -z "$CLIENT_ID" ]; then
  echo "[ERROR] CLIENT_ID is required. Use --client-id <id> or set CLIENT_ID env variable."
  echo "Usage: $0 --client-id <id> [--domain <domain>] [other options]"
  exit 1
fi
# Default DOMAIN if not set
if [ -z "$DOMAIN" ]; then
  DOMAIN="${CLIENT_ID}.nerdofmouth.com"
fi

# Initialize operation flags
STATUS_ONLY="${STATUS_ONLY:-false}"
LOGS_ONLY="${LOGS_ONLY:-false}"
RESTART_ONLY="${RESTART_ONLY:-false}"
TEST_ONLY="${TEST_ONLY:-false}"
FORCE="${FORCE:-false}"
DID_MODE="${DID_MODE:-false}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  # Split the key=value format if present
  if [[ $key == *"="* ]]; then
    value="${key#*=}"
    key="${key%%=*}"
  else
    # Handle the case where $2 might not be set
    if [[ $# -ge 2 ]]; then
      value="$2"
    else
      value=""
    fi
  fi

  case $key in
    --domain)
      DOMAIN="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --wordpress-port)
      WP_PORT="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --mariadb-port)
      MARIADB_PORT="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --did-mode)
      DID_MODE="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --status-only)
      STATUS_ONLY=true
      shift
      ;;
    --logs-only)
      LOGS_ONLY=true
      shift
      ;;
    --restart-only)
      RESTART_ONLY=true
      shift
      ;;
    --test-only)
      TEST_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--domain peacefestivalusa.nerdofmouth.com] [--admin-email admin@example.com] [--force] [--status-only|--logs-only|--restart-only|--test-only]"
      exit 0
      ;;
    *)
      echo "Unknown option: $key"
      exit 1
      ;;
  esac
done

# Early exit blocks for special flags
if [ "$STATUS_ONLY" = "true" ]; then
  log_info "Checking WordPress installation status for ${CLIENT_ID} (${DOMAIN})..."
  WP_RUNNING=$(docker ps -q -f "name=${WORDPRESS_CONTAINER_NAME}" 2>/dev/null)
  DB_RUNNING=$(docker ps -q -f "name=${MARIADB_CONTAINER_NAME}" 2>/dev/null)
  echo "=== WordPress Status ==="
  echo "WordPress: $([ -n "$WP_RUNNING" ] && echo "Running" || echo "Not running")"
  echo "Database: $([ -n "$DB_RUNNING" ] && echo "Running" || echo "Not running")"
  if [ -n "$WP_RUNNING" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null)
    echo "Website: $([ "$HTTP_CODE" = "200" ] && echo "Accessible (HTTP $HTTP_CODE)" || echo "Not accessible (HTTP $HTTP_CODE)")"
  fi
  exit 0
fi
if [ "$LOGS_ONLY" = "true" ]; then
  log_info "Viewing WordPress logs for ${CLIENT_ID} (${DOMAIN})..."
  if [ -f "${WP_DIR}/docker-compose.yml" ]; then
    cd "${WP_DIR}" && docker-compose logs --tail=100
  else
    log_error "Docker Compose file not found for ${CLIENT_ID} WordPress."
    exit 1
  fi
  exit 0
fi
if [ "$RESTART_ONLY" = "true" ]; then
  log_info "Restarting WordPress services for ${CLIENT_ID} (${DOMAIN})..."
  if [ -f "${WP_DIR}/docker-compose.yml" ]; then
    cd "${WP_DIR}" && docker-compose restart
    log_success "WordPress services restarted successfully."
  else
    log_error "Docker Compose file not found for ${CLIENT_ID} WordPress."
    exit 1
  fi
  exit 0
fi
if [ "$TEST_ONLY" = "true" ]; then
  log_info "Testing WordPress installation for ${CLIENT_ID} (${DOMAIN})..."
  WP_RUNNING=$(docker ps -q -f "name=${WORDPRESS_CONTAINER_NAME}" 2>/dev/null)
  DB_RUNNING=$(docker ps -q -f "name=${MARIADB_CONTAINER_NAME}" 2>/dev/null)
  if [ -z "$WP_RUNNING" ] || [ -z "$DB_RUNNING" ]; then
    log_error "WordPress or Database container not running. Start with 'make wordpress CLIENT_ID=${CLIENT_ID}' first."
    exit 1
  fi
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/wp-json" 2>/dev/null)
  if [ "$HTTP_CODE" = "200" ]; then
    log_success "WordPress API test: PASSED (HTTP $HTTP_CODE)"
  else
    log_error "WordPress API test: FAILED (HTTP $HTTP_CODE)"
    exit 1
  fi
  log_success "All WordPress tests PASSED"
  exit 0
fi

# Force DID_MODE based on parameter if provided
if [ "$DID_MODE" = "true" ]; then
  CONTAINER_RUNNING="true"
  DID_MODE="true"
  log_info "Docker-in-Docker mode enabled via parameter"
  
  # Source Docker networking configuration
  if type configure_docker_network_mode &>/dev/null; then
    configure_docker_network_mode
    log_info "Configured Docker networking for container environment"
  else
    log_warning "Docker network configuration function not found"
  fi
fi

# Set paths based on environment
if [ "$CONTAINER_RUNNING" = "true" ]; then
  # Container-safe paths
  if [ "$DID_MODE" = "true" ]; then
    # Docker-in-Docker environment
    INSTALL_BASE_DIR="${HOME}/.agencystack"
    LOG_DIR="${HOME}/.logs/agency_stack/components"
  else
    # Dev container environment
    INSTALL_BASE_DIR="${HOME}/agency_stack"
    LOG_DIR="${HOME}/logs/agency_stack/components"
  fi
else
  # Host system paths
  INSTALL_BASE_DIR="/opt/agency_stack"
  LOG_DIR="/var/log/agency_stack/components"
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${CLIENT_ID}_wordpress.log"
touch "$LOG_FILE"

# Set special networking variables for Docker-in-Docker
if [ "$DID_MODE" = "true" ]; then
  # For Docker-in-Docker, we need to use special port mappings and DNS
  WP_PORT=8082  # Use a specific port for this service
  WP_HOST="localhost:$WP_PORT"
  
  # Add local domain to hosts file
  if ! grep -q "$DOMAIN" /etc/hosts 2>/dev/null; then
    log_info "Adding $DOMAIN to /etc/hosts inside container"
    echo "127.0.0.1 $DOMAIN" >> "${HOME}/.dind_hosts"
  fi

# Define container names and network
NETWORK_NAME="${CLIENT_ID}_network"
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"

# Set client-specific installation paths
if [ "$CONTAINER_RUNNING" = "true" ] && [ "$DID_MODE" = "true" ]; then
  # In Docker-in-Docker, use a path that mirrors the host structure
  WP_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/wordpress"
  # Direct path for normal installation
  WP_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/wordpress"

mkdir -p "${WP_DIR}"
fi

# Main installation logic
log_info "Starting WordPress installation for ${CLIENT_ID} at ${DOMAIN}..."

# Generate simple alphanumeric passwords without special characters for stability
DB_ROOT_PASSWORD=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
log_info "Generated MariaDB root password: ${DB_ROOT_PASSWORD}"

# Generate database user password
WP_DB_PASSWORD=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
log_info "Generated WordPress database password: ${WP_DB_PASSWORD}"

# Store passwords in a file for reference
mkdir -p "${WP_DIR}/credentials"
cat > "${WP_DIR}/credentials/db_passwords.txt" <<EOL
# AgencyStack MariaDB Credentials
# Generated: $(date)
# Client: ${CLIENT_ID}

MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_DB_NAME=${WP_DB_NAME}
EOL

# Secure the credentials file
chmod 600 "${WP_DIR}/credentials/db_passwords.txt"

# Create required directories
log_info "Creating required directories"
mkdir -p "${WP_DIR}/wp-config"
mkdir -p "${WP_DIR}/mariadb-data"
mkdir -p "${WP_DIR}/wp-content"
mkdir -p "${WP_DIR}/init-scripts"

# Create database initialization script
log_info "Creating database initialization script"
mkdir -p "${WP_DIR}/init-scripts"

# Create a root access configuration script
cat > "${WP_DIR}/init-scripts/00-configure-root-access.sql" <<EOL
-- Configure root access for both localhost and remote connections
-- This must run before any other scripts

-- First, ensure root can connect from any host
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Update root@localhost password to match our configuration
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;

-- Make changes take effect immediately
FLUSH PRIVILEGES;

-- Log completion
SELECT 'Root access configuration completed successfully' AS 'Init Status';
EOL

# Create direct initialization script - simplified for reliability
log_info "Creating main database initialization script"
cat > "${WP_DIR}/init-scripts/01-init-db.sql" <<EOL
-- AgencyStack WordPress Database Initialization
-- This script ensures proper user permissions for both local and remote connections

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Drop existing users to prevent conflicts
DROP USER IF EXISTS '${WP_DB_USER}'@'%';
DROP USER IF EXISTS '${WP_DB_USER}'@'localhost';

-- Create user with proper permissions FOR BOTH remote and local connections
-- This is critical - MySQL treats connections differently based on origin
CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';

CREATE USER '${WP_DB_USER}'@'localhost' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'localhost';

-- Ensure permissions take effect
FLUSH PRIVILEGES;

-- Create test table to verify proper setup
USE \`${WP_DB_NAME}\`;
CREATE TABLE IF NOT EXISTS \`wp_agencystack_test\` (
  \`id\` int(11) NOT NULL AUTO_INCREMENT,
  \`test_value\` varchar(255) NOT NULL,
  \`created_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (\`id\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert test data
INSERT INTO \`wp_agencystack_test\` (\`test_value\`) VALUES ('Database initialization successful - Connection test table');
EOL
log_success "Database initialization scripts created"

# Create a database verification script
cat > "${WP_DIR}/init-scripts/02-verify-db.sh" <<EOL
#!/bin/bash
echo "=== AgencyStack WordPress Database Verification ==="
echo "Date: \$(date)"
echo "Database: ${WP_DB_NAME}"
echo "User: ${WP_DB_USER}"

# Wait for MySQL to start
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
  if mysqladmin ping -h localhost -u root -p${DB_ROOT_PASSWORD} --silent; then
    echo "✅ MySQL ready at attempt \$i"
    break
  fi
  echo "Waiting... \$i/30"
  sleep 2
done

# Verify user permissions
echo "Verifying database user permissions..."
mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW GRANTS FOR '${WP_DB_USER}'@'%';" && echo "✅ User permissions verified" || {
  echo "❌ User permissions check failed, attempting to fix..."
  mysql -u root -p${DB_ROOT_PASSWORD} <<FIXSQL
    DROP USER IF EXISTS '${WP_DB_USER}'@'%';
    CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
    FLUSH PRIVILEGES;
FIXSQL
  echo "User permissions fixed, retesting..."
  mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW GRANTS FOR '${WP_DB_USER}'@'%';" && echo "✅ User permissions verified after fix"
}

# Test connection as WordPress user
echo "Testing connection as WordPress user..."
mysql -u ${WP_DB_USER} -p${WP_DB_PASSWORD} -e "USE ${WP_DB_NAME}; SELECT 'Connection successful as WordPress user!';" && echo "✅ Database connection successful!"
EOL
chmod +x "${WP_DIR}/init-scripts/02-verify-db.sh"

# Create custom entrypoint script
log_info "Creating custom entrypoint script"
if [ -f "${SCRIPT_DIR}/templates/wordpress-entrypoint.sh" ]; then
  log_info "Using entrypoint template from repository"
  # Copy and customize the entrypoint script
  cp "${SCRIPT_DIR}/templates/wordpress-entrypoint.sh" "${WP_DIR}/custom-entrypoint.sh"
  chmod +x "${WP_DIR}/custom-entrypoint.sh"
  log_success "Custom entrypoint script created from template"
else
  log_warning "Entrypoint template not found, creating basic entrypoint"
  cat > "${WP_DIR}/custom-entrypoint.sh" <<'EOL'
#!/bin/bash
# Custom entrypoint script for WordPress following AgencyStack Charter principles
set -e

# Install additional packages needed for diagnostics
if [ ! -f /tmp/.packages-installed ]; then
  echo "[$(date)] Installing diagnostic packages..."
  apt-get update && apt-get install -y --no-install-recommends \
    dnsutils \
    netcat-openbsd \
    iputils-ping \
    mariadb-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  touch /tmp/.packages-installed
fi

# Function to check if MySQL is ready
function wait_for_db() {
  echo "[$(date)] Checking DNS resolution for mariadb..."
  dig mariadb
  
  echo "[$(date)] Checking network connectivity to database..."
  nc -zv mariadb 3306
  if [ $? -eq 0 ]; then
    echo "[$(date)]  Port 3306 is reachable"
  else
    echo "[$(date)]  ERROR: Cannot reach database port"
    return 1
  fi

  echo "[$(date)] Waiting for database connection..."
  local max_attempts=60
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt+1))
    echo "[$(date)] Waiting for database connection... attempt $attempt/$max_attempts"
    
    if mysql -h mariadb -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" -e "SELECT 1" &>/dev/null; then
      echo "[$(date)] Database connection successful!"
      return 0
    fi
    
    sleep 3
  done
  
  echo "[$(date)] ERROR: Database connection failed after $max_attempts attempts"
  return 1
}

# Create a health check endpoint
mkdir -p /var/www/html/agency-health
echo "<?php echo 'OK'; ?>" > /var/www/html/agency-health/index.php

# Wait for database to be available
wait_for_db

# Now run the standard entrypoint
exec docker-entrypoint.sh "$@"
EOL
  chmod +x "${WP_DIR}/custom-entrypoint.sh"
fi


# Create WordPress config
mkdir -p "${WP_DIR}/wp-config"
log_info "Creating WordPress configuration"
cat > "${WP_DIR}/wp-config/wp-config-agency.php" <<EOL
<?php
/**
 * AgencyStack WordPress Configuration
 * Following AgencyStack Charter v1.0.3 principles
 */

// ** Database settings - Using Docker service name 'mariadb' as the host ** //
define('DB_NAME', '${WP_DB_NAME}');
define('DB_USER', '${WP_DB_USER}');
define('DB_PASSWORD', '${WP_DB_PASSWORD}');
define('DB_HOST', 'mariadb');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// Authentication unique keys and salts
define('AUTH_KEY',         '$(openssl rand -base64 48)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 48)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 48)');
define('NONCE_KEY',        '$(openssl rand -base64 48)');
define('AUTH_SALT',        '$(openssl rand -base64 48)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 48)');
define('NONCE_SALT',       '$(openssl rand -base64 48)');

// WordPress database table prefix
\$table_prefix = '${WP_TABLE_PREFIX}';

// For developers: WordPress debugging mode
define('WP_DEBUG', false);

// Absolute path to the WordPress directory
if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}
EOL

# Create .env file for WordPress
log_info "Creating .env file for WordPress"
cat > "${WP_DIR}/.env" <<EOL
# WordPress Environment Variables
# Generated via AgencyStack installation script
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
WORDPRESS_DEBUG=0
WORDPRESS_CONFIG_EXTRA=define('FS_METHOD', 'direct');

# Admin credentials
WORDPRESS_ADMIN_USER=admin
WORDPRESS_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
WORDPRESS_ADMIN_EMAIL=admin@${DOMAIN}
EOL

# Create Docker Compose configuration
log_info "Creating Docker Compose configuration"
cat > "${WP_DIR}/docker-compose.yml" <<EOL
version: '3'

services:
  mariadb:
    container_name: peacefestivalusa_mariadb
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/mariadb-data:/var/lib/mysql
      - ${WP_DIR}/init-scripts:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${WP_DB_NAME}
      MYSQL_USER: ${WP_DB_USER}
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
      MYSQL_ALLOW_EMPTY_PASSWORD: "no"
      MYSQL_ROOT_HOST: "%"
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${DB_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wordpress_network
    ports:
      - "33060:3306"

  wordpress:
    container_name: peacefestivalusa_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
    depends_on:
      - mariadb
    volumes:
      - ${WP_DIR}/wp-content:/var/www/html/wp-content
      - ${WP_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
      - ${WP_DIR}/wp-config/wp-config-agency.php:/tmp/wp-config-agency.php
    env_file:
      - ${WP_DIR}/.env
    entrypoint: ["/usr/local/bin/custom-entrypoint.sh"]
    command: ["apache2-foreground"]
    networks:
      - wordpress_network
    ports:
      - "${WP_PORT}:80"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/agency-health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  wordpress_network:
    driver: bridge
EOL

# Create verification script in the repository first, then copy to installation directory
log_info "Creating verification script"
cat > "${WP_DIR}/verify_wordpress.sh" <<EOL
#!/bin/bash
# Verification script for WordPress installation

# Check if WordPress is running
WORDPRESS_CONTAINER_NAME="peacefestivalusa_wordpress"
WP_RUNNING=\$(docker ps -q -f "name=\${WORDPRESS_CONTAINER_NAME}" 2>/dev/null)
if [ -z "\$WP_RUNNING" ]; then
  echo "WordPress container not running"
  exit 1
fi

# Check if WordPress is accessible
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WP_PORT}" 2>/dev/null)
if [ "\$HTTP_CODE" != "200" ]; then
  echo "WordPress not accessible (HTTP \$HTTP_CODE)"
  exit 1
fi

echo "WordPress installation verified successfully"
exit 0
EOL
chmod +x "${WP_DIR}/verify_wordpress.sh"

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "${NETWORK_NAME}"; then
  log_info "Creating Docker network: ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}" || log_error "Failed to create network ${NETWORK_NAME}"
fi

# Check if Traefik network exists, create if not
if ! docker network ls | grep -q "traefik-keycloak-default"; then
  log_info "Creating Traefik network: traefik-keycloak-default"
  docker network create traefik-keycloak-default || log_error "Failed to create Traefik network"
fi

# Remove existing containers if they exist and force is enabled
if [ "$FORCE" = "true" ]; then
  log_info "Force flag enabled - removing existing containers if present..."
  docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" 2>/dev/null || true
fi

# Start WordPress with Docker Compose
log_info "Starting WordPress containers with Docker Compose..."

# Special handling for Docker-in-Docker environment
if [ "$DID_MODE" = "true" ]; then
  log_info "Configuring WordPress for Docker-in-Docker environment"
  
  # Create a custom configuration script
  cat > "${WP_DIR}/configure_wordpress.sh" <<EOF
#!/bin/bash

# Wait for WordPress to be ready
echo "[$(date)] Waiting for WordPress to be ready..."
while ! grep -q "define('ABSPATH'" /var/www/html/wp-config.php 2>/dev/null; do
  sleep 2
  echo "[$(date)] Still waiting for wp-config.php..."
done

# Append custom agency configurations
if [ -f /tmp/wp-config-agency.php ]; then
  echo "[$(date)] Adding AgencyStack configuration to wp-config.php..."
  
  # Extract the closing PHP tag
  if grep -q "?>" /var/www/html/wp-config.php; then
    sed -i 's/?>//' /var/www/html/wp-config.php
  fi
  
  # Append the custom configuration
  cat /tmp/wp-config-agency.php >> /var/www/html/wp-config.php
  echo "?>" >> /var/www/html/wp-config.php
  
  echo "[$(date)] WordPress configuration updated successfully!"
else
  echo "[$(date)] Custom configuration file not found!"
fi

EOF
  
  # Make script executable
  chmod +x "${WP_DIR}/configure_wordpress.sh"
fi
cd "${WP_DIR}" && docker-compose up -d

# For Docker-in-Docker, run the configuration script
if [ "$DID_MODE" = "true" ]; then
  log_info "Running WordPress configuration in Docker-in-Docker environment"
  docker cp "${WP_DIR}/configure_wordpress.sh" "${WORDPRESS_CONTAINER_NAME}:/configure_wordpress.sh"
  docker exec -it "${WORDPRESS_CONTAINER_NAME}" bash -c "chmod +x /configure_wordpress.sh && /configure_wordpress.sh" || log_warning "Error running configuration script"
fi

# Wait for WordPress to be ready
log_info "Waiting for WordPress to start (this may take a minute)..."
COUNTER=0
MAX_TRIES=30

while [ $COUNTER -lt $MAX_TRIES ]; do
  COUNTER=$((COUNTER+1))
  echo -n "."
  
  # Check if WordPress is responsive (adjust for Docker-in-Docker)
  if [ "$DID_MODE" = "true" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WP_PORT:-8080}" 2>/dev/null || echo "000")
  else
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null || echo "000")
  fi
  
  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" || "$HTTP_STATUS" == "301" ]]; then
    echo ""
    if [ "$DID_MODE" = "true" ]; then
      log_success "WordPress is now available at http://localhost:${WP_PORT:-8080}"
    else
      log_success "WordPress is now available at https://${DOMAIN}"
    fi
    break
  fi
  
  # If we've reached max tries, show a warning
  if [ $COUNTER -ge $MAX_TRIES ]; then
    echo ""
    log_warning "WordPress may not be fully started yet. Check logs with 'make peacefestivalusa-wordpress-logs'"
  fi
  
  sleep 2
done

# Register in component registry if available
if [ -f "${SCRIPTS_DIR}/utils/register_component.sh" ]; then
  log_info "Registering WordPress in component registry..."
  "${SCRIPTS_DIR}/utils/register_component.sh" \
    --name="wordpress_${CLIENT_ID}" \
    --category="Content Management" \
    --description="WordPress for ${CLIENT_ID} (${DOMAIN})" \
    --installed=true \
    --makefile=true \
    --docs=true \
    --hardened=true \
    --multi_tenant=true || true
fi

# Display success message
log_success "✅ WordPress installation for ${CLIENT_ID} complete"
echo ""
echo "🌐 Access WordPress at: ${DOMAIN}"
echo "👤 WordPress Admin: ${WP_ADMIN_USER}"
echo "🔑 WordPress Admin Password: ${WP_ADMIN_PASSWORD}"
echo "🗄️ Database Name: ${WP_DB_NAME}"
echo "👤 Database User: ${WP_DB_USER}"
echo "🔑 Database Password: ${WP_DB_PASSWORD}"
echo ""
echo "Make sure to save these credentials securely!"
echo "Credentials are stored in ${WP_DIR}/.env"

# Save credentials to a secure file
mkdir -p "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets"
cat > "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt" <<EOL
Domain: ${DOMAIN}
WordPress Admin: ${WP_ADMIN_USER}
WordPress Admin Password: ${WP_ADMIN_PASSWORD}
Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
EOL
chmod 600 "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt"
fi

exit 0
