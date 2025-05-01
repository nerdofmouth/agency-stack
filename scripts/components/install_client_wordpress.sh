#!/bin/bash
# install_client_wordpress.sh - Multi-tenant WordPress installation for any client
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
#
# Following the AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Idempotency & Automation
# - Multi-Tenancy & Security
# - Component Consistency
# - Strict Containerization
# - Test-Driven Development

set -e

# Verify running from repository context
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  echo "ERROR: This script must be run from the repository context"
  echo "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1
fi

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../utils/common.sh" ]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  # Minimal logging functions if common.sh is not found
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Default values
CLIENT_ID=""
DOMAIN=""
ADMIN_EMAIL="admin@example.com"
WP_PORT="8080"
MARIADB_PORT="3306"
FORCE="false"
ENABLE_TRAEFIK="false"
ENABLE_KEYCLOAK="false"
ENABLE_TLS="false"
CONTAINER_RUNNING="false"
DID_MODE="false"
OPERATION_MODE="install" # install, status, logs, restart, remove

# Detect Docker-in-Docker
is_running_in_container() {
  if [ -f "/.dockerenv" ] || grep -q "docker" /proc/1/cgroup 2>/dev/null; then
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

# Show help message
show_help() {
  echo "AgencyStack Multi-Tenant WordPress Installation"
  echo "==============================================="
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --client-id=<id>       Client ID (required)"
  echo "  --domain=<domain>      Domain for WordPress (required)"
  echo "  --admin-email=<email>  Admin email address"
  echo "  --wordpress-port=<port> WordPress port (default: 8080)"
  echo "  --mariadb-port=<port>  MariaDB port (default: 3306)"
  echo "  --force                Force reinstallation"
  echo "  --enable-traefik       Enable Traefik integration"
  echo "  --enable-keycloak      Enable Keycloak SSO integration"
  echo "  --enable-tls           Enable TLS (requires Traefik)"
  echo "  --did-mode             Enable Docker-in-Docker compatibility"
  echo "  --status-only          Show status only"
  echo "  --logs-only            Show logs only"
  echo "  --restart-only         Restart services only"
  echo "  --remove               Remove installation"
  echo "  --help                 Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --client-id=clientxyz --domain=client.example.com --admin-email=admin@example.com"
  exit 0
}

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
    --client-id)
      CLIENT_ID="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
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
    --force)
      FORCE="true"
      shift
      ;;
    --enable-traefik)
      ENABLE_TRAEFIK="true"
      shift
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK="true"
      shift
      ;;
    --enable-tls)
      ENABLE_TLS="true"
      shift
      ;;
    --did-mode)
      DID_MODE="true"
      shift
      ;;
    --status-only)
      OPERATION_MODE="status"
      shift
      ;;
    --logs-only)
      OPERATION_MODE="logs"
      shift
      ;;
    --restart-only)
      OPERATION_MODE="restart"
      shift
      ;;
    --remove)
      OPERATION_MODE="remove"
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log_error "Unknown option: $key"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$CLIENT_ID" ]; then
  log_error "Client ID is required. Use --client-id=<id>"
  exit 1
fi

if [ -z "$DOMAIN" ]; then
  log_error "Domain is required. Use --domain=<domain>"
  exit 1
fi

# Set paths based on Docker-in-Docker mode
if [ "$CONTAINER_RUNNING" = "true" ] && [ "$DID_MODE" = "true" ]; then
  # In Docker-in-Docker, use the container paths
  INSTALL_BASE_DIR="${HOME}/.agencystack"
  LOG_DIR="${HOME}/.logs/agency_stack/components"
else
  # Standard AgencyStack paths on host system
  INSTALL_BASE_DIR="/opt/agency_stack"
  LOG_DIR="/var/log/agency_stack/components"
fi

# Ensure the log directory exists
mkdir -p "${LOG_DIR}" || true

# Set client-specific paths
CLIENT_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}"
WP_DIR="${CLIENT_DIR}/wordpress"
SECRETS_DIR="${CLIENT_DIR}/.secrets"
LOG_FILE="${LOG_DIR}/${CLIENT_ID}_wordpress.log"

# Container names
NETWORK_NAME="${CLIENT_ID}_network"
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"

# Log initial setup information
{
  log_info "==================================================="
  log_info "Starting WordPress setup for client: ${CLIENT_ID}"
  log_info "Domain: ${DOMAIN}"
  log_info "Base installation path: ${WP_DIR}"
  log_info "Docker-in-Docker mode: ${DID_MODE}"
  log_info "Traefik enabled: ${ENABLE_TRAEFIK}"
  log_info "Keycloak enabled: ${ENABLE_KEYCLOAK}"
  log_info "TLS enabled: ${ENABLE_TLS}"
  log_info "Operation mode: ${OPERATION_MODE}"
  log_info "==================================================="
} >> "${LOG_FILE}" 2>&1

# Status check function
check_status() {
  echo "Status for ${CLIENT_ID} WordPress installation:"
  
  # Check if containers are running
  if docker ps | grep -q "${WORDPRESS_CONTAINER_NAME}"; then
    echo "✅ WordPress container: Running"
  else
    echo "❌ WordPress container: Not running"
  fi
  
  if docker ps | grep -q "${MARIADB_CONTAINER_NAME}"; then
    echo "✅ Database container: Running"
  else
    echo "❌ Database container: Not running"
  fi
  
  # Check port mappings
  if docker ps | grep -q "${WORDPRESS_CONTAINER_NAME}" | grep -q "${WP_PORT}->80"; then
    echo "✅ WordPress port ${WP_PORT}: Mapped"
  else
    echo "❌ WordPress port ${WP_PORT}: Not mapped"
  fi
  
  if docker ps | grep -q "${MARIADB_CONTAINER_NAME}" | grep -q "${MARIADB_PORT}->3306"; then
    echo "✅ Database port ${MARIADB_PORT}: Mapped"
  else
    echo "❌ Database port ${MARIADB_PORT}: Not mapped"
  fi
  
  # Check if WordPress is accessible
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WP_PORT}" 2>/dev/null || echo "Connection failed")
  if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo "✅ WordPress HTTP response: $HTTP_STATUS (OK)"
  else
    echo "❌ WordPress HTTP response: $HTTP_STATUS (Not accessible)"
  fi
  
  echo "Log file: ${LOG_FILE}"
}

# Logs function
show_logs() {
  echo "Logs for ${CLIENT_ID} WordPress installation:"
  
  echo "=== WordPress Container Logs ==="
  docker logs "${WORDPRESS_CONTAINER_NAME}" 2>&1 | tail -n 50
  
  echo ""
  echo "=== Database Container Logs ==="
  docker logs "${MARIADB_CONTAINER_NAME}" 2>&1 | tail -n 50
  
  echo ""
  echo "=== Installation Log File ==="
  tail -n 50 "${LOG_FILE}" 2>/dev/null || echo "Log file not found: ${LOG_FILE}"
}

# Restart function
restart_services() {
  echo "Restarting ${CLIENT_ID} WordPress services..."
  
  docker restart "${WORDPRESS_CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || echo "❌ Failed to restart WordPress container"
  docker restart "${MARIADB_CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || echo "❌ Failed to restart Database container"
  
  echo "✅ Services restarted"
}

# Remove function
remove_installation() {
  echo "Removing ${CLIENT_ID} WordPress installation..."
  
  # Stop and remove containers
  docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true
  
  # Remove network
  docker network rm "${NETWORK_NAME}" >> "${LOG_FILE}" 2>&1 || true
  
  echo "✅ Container services removed"
  echo "Note: The data directories at ${WP_DIR} were preserved. To completely remove all data, run:"
  echo "  rm -rf ${WP_DIR}"
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
mkdir -p "${WP_DIR}/wp-content" "${WP_DIR}/mariadb-data" "${WP_DIR}/wp-config" "${SECRETS_DIR}" >> "${LOG_FILE}" 2>&1

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
  
  # Set admin password or generate a random one
  if [ -z "$WP_ADMIN_PASSWORD" ]; then
    WP_ADMIN_PASSWORD=$(openssl rand -base64 12)
  fi
  
  # Set database password or generate a random one
  if [ -z "$WP_DB_PASSWORD" ]; then
    WP_DB_PASSWORD=$(openssl rand -base64 12)
  fi
  
  # Set database root password or generate a random one
  if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
  fi
  
  # Create .env file
  cat > "${WP_DIR}/.env" <<EOL
# WordPress Environment Configuration for ${CLIENT_ID}
# Generated by AgencyStack on $(date)

WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
WORDPRESS_DEBUG=false
WORDPRESS_CONFIG_EXTRA=define('WP_HOME', 'http${ENABLE_TLS:+s}://${DOMAIN}'); define('WP_SITEURL', 'http${ENABLE_TLS:+s}://${DOMAIN}');
EOL

  # Create credentials file in .secrets directory
  mkdir -p "${SECRETS_DIR}"
  cat > "${SECRETS_DIR}/wordpress-credentials.txt" <<EOL
# WordPress Credentials for ${CLIENT_ID}
# Generated: $(date)

WordPress Admin: admin
WordPress Admin Password: ${WP_ADMIN_PASSWORD}

Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
Database Root Password: ${MYSQL_ROOT_PASSWORD}
EOL

  # Set secure permissions for credentials file
  chmod 600 "${SECRETS_DIR}/wordpress-credentials.txt"
  
  log_success "Environment configuration created successfully"
}

create_env_file

# Create database initialization script
log_info "Creating database initialization script"
mkdir -p "${WP_DIR}/init-scripts"

# Use template if available, otherwise create directly
DB_INIT_TEMPLATE="${SCRIPT_DIR}/templates/mariadb-init.sql"
if [ -f "$DB_INIT_TEMPLATE" ]; then
  log_info "Using database initialization template from repository"
  # Copy and replace variables
  sed -e "s/\${DB_NAME}/${WP_DB_NAME}/g" \
      -e "s/\${DB_USER}/${WP_DB_USER}/g" \
      -e "s/\${DB_PASSWORD}/${WP_DB_PASSWORD}/g" \
      -e "s/\${DB_ADMIN_USER}/admin_${CLIENT_ID}/g" \
      -e "s/\${DB_ADMIN_PASSWORD}/${MYSQL_ROOT_PASSWORD}/g" \
      "$DB_INIT_TEMPLATE" > "${WP_DIR}/init-scripts/01-init-db.sql"
  log_success "Database initialization script created from template"
else
  log_warning "Database initialization template not found at $DB_INIT_TEMPLATE"
  cat > "${WP_DIR}/init-scripts/01-init-db.sql" <<EOL
-- AgencyStack WordPress Database Initialization
-- This script ensures proper user permissions for the WordPress database

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Recreate user with proper permissions (allow from any host)
DROP USER IF EXISTS '${WP_DB_USER}'@'%';
DROP USER IF EXISTS '${WP_DB_USER}'@'localhost';

CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOL
fi

# Create verification script for database connectivity
log_info "Creating database verification script"
cat > "${WP_DIR}/init-scripts/02-verify-db.sh" <<EOL
#!/bin/bash
# AgencyStack WordPress Database Connection Verification Script
# Following Test-Driven Development protocol in AgencyStack Charter

echo "=== AgencyStack Database Verification ==="
echo "Date: \$(date)"
echo "Client: ${CLIENT_ID}"
echo "Database: ${WP_DB_NAME}"
echo "User: ${WP_DB_USER}"

# Wait for MySQL to complete initialization
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
  if mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} --silent 2>/dev/null; then
    echo "✅ MySQL ready at attempt \$i"
    break
  fi
  echo "Waiting... \$i/30"
  sleep 2
done

# Verify user existence
echo "Verifying database user exists..."
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT User, Host FROM mysql.user WHERE User='${WP_DB_USER}';" || echo "Failed to query users"

# Verify user permissions
echo "Verifying database user permissions..."
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW GRANTS FOR '${WP_DB_USER}'@'%';" || echo "Failed to show grants"

# Test connection as WordPress user
echo "Testing connection as WordPress user..."
if mysql -u ${WP_DB_USER} -p${WP_DB_PASSWORD} -e "USE ${WP_DB_NAME}; SELECT * FROM agencystack_db_test LIMIT 1;" 2>/dev/null; then
  echo "✅ Connection successful as WordPress user!"
else
  echo "❌ Connection failed as WordPress user!"
  echo "Attempting to fix permissions..."
  mysql -u root -p${MYSQL_ROOT_PASSWORD} <<FIXSQL
    DROP USER IF EXISTS '${WP_DB_USER}'@'%';
    CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
    FLUSH PRIVILEGES;
FIXSQL
  echo "Permissions fixed, retesting connection..."
  mysql -u ${WP_DB_USER} -p${WP_DB_PASSWORD} -e "USE ${WP_DB_NAME}; SELECT 'Connection test after fix';" || echo "Still failed after fix attempt"
fi

echo "Database verification completed at \$(date)"
EOL
chmod +x "${WP_DIR}/init-scripts/02-verify-db.sh"

# Create wp-config customizations
log_info "Creating WordPress configuration"
cat > "${WP_DIR}/wp-config/wp-config-agency.php" <<EOL
<?php
/**
 * AgencyStack WordPress Configuration Additions
 * Client: ${CLIENT_ID}
 * Domain: ${DOMAIN}
 * Generated: $(date)
 */

// ** Force WordPress URL settings for proper localhost access ** //
define('WP_HOME', 'http://localhost:${WP_PORT}');
define('WP_SITEURL', 'http://localhost:${WP_PORT}');

// ** Prevent redirects to HTTPS when not configured ** //
define('FORCE_SSL_ADMIN', false);

// ** Override default URLs with container-aware URLs ** //
\$_SERVER['HTTP_HOST'] = 'localhost:${WP_PORT}';
\$_SERVER['SERVER_PORT'] = '${WP_PORT}';
\$_SERVER['SERVER_NAME'] = 'localhost';

// ** Adjusted base path for multisite compatibility ** //
if ( defined('MULTISITE') && MULTISITE ) {
    define('PATH_CURRENT_SITE', '/');
    define('SITE_ID_CURRENT_SITE', 1);
    define('BLOG_ID_CURRENT_SITE', 1);
}

// ** Standard AgencyStack security settings ** //
define('DISALLOW_FILE_EDIT', true);
define('AUTOMATIC_UPDATER_DISABLED', true);

// ** AgencyStack multi-tenant client identifier ** //
define('AGENCY_CLIENT_ID', '${CLIENT_ID}');
EOL

# Set network configuration
if [ -z "$NETWORK_NAME" ]; then
  NETWORK_NAME="${CLIENT_ID}_wordpress_network"
fi

# Check if Docker network exists, create if it doesn't
check_network() {
  log_info "Checking if Docker network '$NETWORK_NAME' exists"
  if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    log_info "Docker network '$NETWORK_NAME' does not exist, creating it"
    docker network create "$NETWORK_NAME" || {
      log_error "Failed to create Docker network '$NETWORK_NAME'"
      return 1
    }
    log_success "Docker network '$NETWORK_NAME' created successfully"
  else
    log_info "Docker network '$NETWORK_NAME' already exists"
  fi
  return 0
}

# Create Docker Compose configuration
create_docker_compose() {
  log_info "Creating Docker Compose configuration"
  
  # Ensure network exists
  check_network || return 1
  
  # Check for custom entrypoint template
  CUSTOM_ENTRYPOINT_SRC="${SCRIPT_DIR}/templates/client-wordpress-entrypoint.sh"
  CUSTOM_ENTRYPOINT_DEST="${WP_DIR}/custom-entrypoint.sh"
  
  if [ -f "$CUSTOM_ENTRYPOINT_SRC" ]; then
    log_info "Copying custom entrypoint script from template"
    cp "$CUSTOM_ENTRYPOINT_SRC" "$CUSTOM_ENTRYPOINT_DEST"
    chmod +x "$CUSTOM_ENTRYPOINT_DEST"
    
    # Add WORDPRESS_CLIENT_ID to .env file
    if ! grep -q "WORDPRESS_CLIENT_ID" "${WP_DIR}/.env"; then
      echo "WORDPRESS_CLIENT_ID=${CLIENT_ID}" >> "${WP_DIR}/.env"
    fi
    
    USE_CUSTOM_ENTRYPOINT=true
  else
    log_warning "Custom entrypoint template not found at $CUSTOM_ENTRYPOINT_SRC"
    USE_CUSTOM_ENTRYPOINT=false
  fi
  
  # Prepare Traefik labels if enabled
  TRAEFIK_LABELS=""
  if [ "$ENABLE_TRAEFIK" = "true" ]; then
    TRAEFIK_LABELS=$(cat <<EOL
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.${CLIENT_ID}_wordpress.rule=Host(\`${DOMAIN}\`)"
        - "traefik.http.routers.${CLIENT_ID}_wordpress.entrypoints=web${ENABLE_TLS:+secure}"
        - "traefik.http.routers.${CLIENT_ID}_wordpress${ENABLE_TLS:+.tls}=${ENABLE_TLS}"
        - "traefik.http.services.${CLIENT_ID}_wordpress.loadbalancer.server.port=80"
EOL
    )
  fi

  # Create docker-compose.yml with or without Traefik labels
  cat > "${WP_DIR}/docker-compose.yml" <<EOL
version: '3'

services:
  mariadb:
    container_name: ${MARIADB_CONTAINER_NAME}
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/mariadb-data:/var/lib/mysql
      - ${WP_DIR}/init-scripts:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${WP_DB_NAME}
      MYSQL_USER: ${WP_DB_USER}
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - ${NETWORK_NAME}
    ports:
      - "${MARIADB_PORT}:3306"

  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:6.1-php8.1-apache
    restart: unless-stopped
    depends_on:
      mariadb:
        condition: service_healthy
    volumes:
      - ${WP_DIR}/wp-content:/var/www/html/wp-content
      - ${WP_DIR}/wp-config:/var/www/html/wp-config
$([ "$USE_CUSTOM_ENTRYPOINT" = "true" ] && echo "      - ${WP_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh")
    env_file:
      - ${WP_DIR}/.env
$([ "$USE_CUSTOM_ENTRYPOINT" = "true" ] && echo "    entrypoint: [\"/usr/local/bin/custom-entrypoint.sh\"]")
$([ "$USE_CUSTOM_ENTRYPOINT" = "true" ] && echo "    command: [\"apache2-foreground\"]")
    networks:
      - ${NETWORK_NAME}
    ports:
      - "${WP_PORT}:80"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/agency-health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
${TRAEFIK_LABELS}

networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}
EOL

  # Clean up existing containers if required
  if [ "$FORCE" = "true" ]; then
    log_info "Force flag enabled - removing existing containers if present"
    docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true
    
    # Clean up any existing network
    docker network rm "${NETWORK_NAME}" >> "${LOG_FILE}" 2>&1 || true
  fi

  # Start WordPress with Docker Compose
  log_info "Starting WordPress containers with Docker Compose"
  (cd "${WP_DIR}" && docker-compose up -d) >> "${LOG_FILE}" 2>&1 || {
    log_error "Failed to start WordPress containers"
    tail -n 20 "${LOG_FILE}"
    exit 1
  }

  # Create installation verification script
  cat > "${WP_DIR}/verify_installation.sh" <<EOL
#!/bin/bash
# Wait for WordPress to be ready
echo "Waiting for WordPress to be ready..."
COUNTER=0
MAX_TRIES=30

while [ \$COUNTER -lt \$MAX_TRIES ]; do
  COUNTER=\$((COUNTER+1))
  echo -n "."
  
  # Check if WordPress is responsive
  HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WP_PORT}" 2>/dev/null || echo "000")
  
  if [[ "\$HTTP_STATUS" == "200" || "\$HTTP_STATUS" == "302" || "\$HTTP_STATUS" == "301" ]]; then
    echo ""
    echo "WordPress is now available at http://localhost:${WP_PORT}"
    break
  fi
  
  if [ \$COUNTER -ge \$MAX_TRIES ]; then
    echo ""
    echo "WordPress may not be fully started yet. Check logs with 'docker-compose logs'"
  fi
  
  sleep 2
done
EOL

  chmod +x "${WP_DIR}/verify_installation.sh"

  # Run verification
  log_info "Running verification script"
  "${WP_DIR}/verify_installation.sh" >> "${LOG_FILE}" 2>&1 &

  # Display success message
  log_success "WordPress installation for ${CLIENT_ID} complete"
  echo "==========================================================="
  echo "WordPress for ${CLIENT_ID} has been installed successfully!"
  echo "==========================================================="
  echo "Access WordPress at: http${ENABLE_TLS:+s}://${DOMAIN} or http://localhost:${WP_PORT}"
  echo "WordPress Admin: ${WP_ADMIN_USER}"
  echo "WordPress Admin Password: ${WP_ADMIN_PASSWORD}"
  echo ""
  echo "Database information:"
  echo "- Database Name: ${WP_DB_NAME}"
  echo "- Database User: ${WP_DB_USER}"
  echo "- Database Password: ${WP_DB_PASSWORD}"
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
