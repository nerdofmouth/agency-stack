#!/bin/bash
# install_peacefestivalusa_wordpress_did.sh - Client-specific WordPress Docker-in-Docker installation
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
# This script follows the AgencyStack Repository Integrity Policy

# Set strict error handling
set -e

# Client-specific variables
CLIENT_ID="peacefestivalusa"
DOMAIN="peacefestivalusa.nerdofmouth.com"
ADMIN_EMAIL="admin@peacefestivalusa.com"
WP_PORT="8082"
FORCE="true"  # Default to force=true in Docker-in-Docker for clean installs

# Set Docker-in-Docker specific paths
INSTALL_BASE_DIR="${HOME}/.agencystack"
LOG_DIR="${HOME}/.logs/agency_stack/components"
WP_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/wordpress"

# Create required directories
mkdir -p "${WP_DIR}/wp-content"
mkdir -p "${WP_DIR}/mariadb-data"
mkdir -p "${LOG_DIR}"

echo "=== Installing WordPress for ${CLIENT_ID} in Docker-in-Docker environment ==="
echo "Domain: ${DOMAIN}"
echo "WordPress Port: ${WP_PORT}"
echo "Installation Directory: ${WP_DIR}"

# Define container names and network
TIMESTAMP=$(date +%s)
NETWORK_NAME="host" # Use host networking mode for Docker-in-Docker

# Function to ensure network is ready
ensure_network_ready() {
  # Remove any existing conflicting networks
  for net in $(docker network ls --filter "name=${CLIENT_ID}_network" --format "{{.Name}}"); do
    echo "Removing existing network: $net"
    docker network rm "$net" || true
  done
  
  # Create fresh network
  echo "Creating fresh Docker network: ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}" || { 
    echo "Failed to create network ${NETWORK_NAME}, trying alternate approach"
    # If network creation failed, try with a different name
    NETWORK_NAME="${CLIENT_ID}_net_$(date +%s%N | md5sum | head -c 8)"
    echo "Attempting with alternate network name: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" || {
      echo "Network creation failed completely. Exiting."
      exit 1
    }
  }
  echo "Network ${NETWORK_NAME} created successfully"
}

WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"

# Generate secure passwords
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD=$(openssl rand -base64 12)
WP_DB_NAME="${CLIENT_ID}_wordpress"
WP_DB_USER="${CLIENT_ID}_wp"
WP_DB_PASSWORD=$(openssl rand -base64 12)
WP_TABLE_PREFIX="wp_"

# Create .env file for Docker Compose
echo "Creating environment configuration..."
cat > "${WP_DIR}/.env" <<EOL
WORDPRESS_DB_HOST=127.0.0.1
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
WORDPRESS_DEBUG=true
WORDPRESS_CONFIG_EXTRA=define('WP_HOME', 'http://localhost:${WP_PORT}'); define('WP_SITEURL', 'http://localhost:${WP_PORT}');
EOL

# Set proper permissions
chmod 600 "${WP_DIR}/.env"

# Create docker-compose.yml
echo "Creating Docker Compose configuration..."
cat > "${WP_DIR}/docker-compose.yml" <<EOL
version: '3'

services:
  database:
    container_name: ${MARIADB_CONTAINER_NAME}
    image: mariadb:10.5
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ${WP_DIR}/mariadb-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: $(openssl rand -base64 12)
      MYSQL_DATABASE: ${WP_DB_NAME}
      MYSQL_USER: ${WP_DB_USER}
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    extra_hosts:
      - "host.docker.internal:host-gateway"

  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:6.1-php8.1-apache
    restart: unless-stopped
    depends_on:
      - database
    network_mode: "host" # Use host networking for Docker-in-Docker
    volumes:
      - ${WP_DIR}/wp-content:/var/www/html/wp-content
      - ${WP_DIR}/wp-config/wp-config-agency.php:/tmp/wp-config-agency.php
    env_file:
      - ${WP_DIR}/.env
    environment:
      - WORDPRESS_CONFIG_EXTRA=define('FORCE_SSL_ADMIN', false); define('WP_DEBUG', true);
      - WORDPRESS_DB_HOST=127.0.0.1:3306
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOL

# Create WordPress wp-config customizations
mkdir -p "${WP_DIR}/wp-config"
cat > "${WP_DIR}/wp-config/wp-config-agency.php" <<EOL
<?php
/**
 * AgencyStack WordPress Configuration Additions
 * Client: ${CLIENT_ID}
 * Domain: ${DOMAIN}
 */

// Security enhancements
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false); 
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_AUTO_UPDATE_CORE', false);

// Performance optimizations
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Set site URL
define('WP_HOME', 'http://localhost:${WP_PORT}');
define('WP_SITEURL', 'http://localhost:${WP_PORT}');

// Debug settings (disabled in production)
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
EOL

# Remove existing containers if they exist and force is enabled
if [ "$FORCE" = "true" ]; then
  echo "Force flag enabled - removing existing containers if present..."
  docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" 2>/dev/null || true
  # Set up clean network
  ensure_network_ready
fi

# Start WordPress with Docker Compose
echo "Starting WordPress containers with Docker Compose..."
cd "${WP_DIR}" && docker-compose up -d

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

# Run the verification script asynchronously to check when WordPress is available
nohup "${WP_DIR}/verify_installation.sh" > "${WP_DIR}/verify.log" 2>&1 &

# Store credentials safely
mkdir -p "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets"
cat > "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt" <<EOL
Domain: ${DOMAIN}
WordPress Port: ${WP_PORT}
WordPress Admin: ${WP_ADMIN_USER}
WordPress Admin Password: ${WP_ADMIN_PASSWORD}
Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
EOL
chmod 600 "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt"

# Display success message
echo "=== WordPress installation for ${CLIENT_ID} complete ==="
echo " Access WordPress at: http://localhost:${WP_PORT}"
echo " WordPress Admin: ${WP_ADMIN_USER}"
echo " WordPress Admin Password: ${WP_ADMIN_PASSWORD}"
echo " Database Name: ${WP_DB_NAME}"
echo " Database User: ${WP_DB_USER}"
echo " Database Password: ${WP_DB_PASSWORD}"
echo " Docker compose file: ${WP_DIR}/docker-compose.yml"
echo " Credentials stored in: ${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt"
echo "  For best TDD Protocol compliance, run tests with make peacefestivalusa-wordpress-test"
