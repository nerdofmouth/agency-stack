#!/bin/bash
# install_peacefestivalusa_wordpress_localhost.sh - Client-specific WordPress for localhost
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
# Following the Repository Integrity Policy and Host-to-Container Rule

set -e

# Client-specific variables
CLIENT_ID="peacefestivalusa"
WP_PORT="8082"
MARIADB_PORT="33306"

# Docker-in-Docker specific paths
INSTALL_BASE_DIR="${HOME}/.agencystack"
LOG_DIR="${HOME}/.logs/agency_stack/components"
WP_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/wordpress"

# Create required directories
mkdir -p "${WP_DIR}/wp-content"
mkdir -p "${WP_DIR}/mariadb-data"
mkdir -p "${LOG_DIR}"

echo "=== Installing WordPress for ${CLIENT_ID} on localhost ==="
echo "WordPress Port: ${WP_PORT}"
echo "MariaDB Port: ${MARIADB_PORT}"
echo "Installation Directory: ${WP_DIR}"

# Define container names
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"

# Generate secure passwords
WP_DB_NAME="${CLIENT_ID}_wordpress"
WP_DB_USER="${CLIENT_ID}_wp"
WP_DB_PASSWORD=$(openssl rand -base64 12)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)

# Clean up any existing containers first
echo "Cleaning up existing containers..."
docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" 2>/dev/null || true

# Start the MariaDB container first
echo "Starting MariaDB container..."
docker run -d \
  --name "${MARIADB_CONTAINER_NAME}" \
  -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  -e MYSQL_DATABASE="${WP_DB_NAME}" \
  -e MYSQL_USER="${WP_DB_USER}" \
  -e MYSQL_PASSWORD="${WP_DB_PASSWORD}" \
  -v "${WP_DIR}/mariadb-data:/var/lib/mysql" \
  -p "${MARIADB_PORT}:3306" \
  mariadb:10.5

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
RETRIES=30
until [ $RETRIES -eq 0 ] || docker exec "${MARIADB_CONTAINER_NAME}" mysqladmin ping -h localhost --silent; do
  echo "Waiting for database connection... (attempts left: $RETRIES)"
  RETRIES=$((RETRIES-1))
  sleep 1
done

# If we ran out of retries, exit with error
if [ $RETRIES -eq 0 ]; then
  echo "Error: Could not connect to MariaDB after multiple attempts."
  echo "Showing MariaDB logs:"
  docker logs "${MARIADB_CONTAINER_NAME}"
  exit 1
fi

echo "MariaDB is now ready."

# Get the IP address of the MariaDB container
DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${MARIADB_CONTAINER_NAME}")
echo "MariaDB IP address: ${DB_IP}"

# Start the WordPress container
echo "Starting WordPress container..."
docker run -d \
  --name "${WORDPRESS_CONTAINER_NAME}" \
  -e WORDPRESS_DB_HOST="${DB_IP}" \
  -e WORDPRESS_DB_NAME="${WP_DB_NAME}" \
  -e WORDPRESS_DB_USER="${WP_DB_USER}" \
  -e WORDPRESS_DB_PASSWORD="${WP_DB_PASSWORD}" \
  -e WORDPRESS_TABLE_PREFIX="wp_" \
  -e WORDPRESS_DEBUG="1" \
  -v "${WP_DIR}/wp-content:/var/www/html/wp-content" \
  -p "${WP_PORT}:80" \
  wordpress:6.1-php8.1-apache

# Wait for WordPress to be ready
echo "Waiting for WordPress to be ready..."
RETRIES=30
until [ $RETRIES -eq 0 ] || curl -s "http://localhost:${WP_PORT}" > /dev/null; do
  echo "Waiting for WordPress to be accessible... (attempts left: $RETRIES)"
  RETRIES=$((RETRIES-1))
  sleep 1
done

if [ $RETRIES -eq 0 ]; then
  echo "Warning: WordPress may not be fully initialized yet."
  echo "Showing WordPress logs:"
  docker logs "${WORDPRESS_CONTAINER_NAME}"
else
  echo "WordPress is now accessible."
fi

# Store credentials
mkdir -p "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets"
cat > "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt" <<EOL
WordPress URL: http://localhost:${WP_PORT}
Database Host: ${DB_IP}
Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
MariaDB Root Password: ${MYSQL_ROOT_PASSWORD}
EOL

echo "=== WordPress for ${CLIENT_ID} has been installed ==="
echo "WordPress URL: http://localhost:${WP_PORT}"
echo "Database Host: ${DB_IP}"
echo "Database Name: ${WP_DB_NAME}"
echo "Database User: ${WP_DB_USER}"
echo "Database Password: ${WP_DB_PASSWORD}"
echo "MariaDB Root Password: ${MYSQL_ROOT_PASSWORD}"
echo "Credentials saved to: ${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress_credentials.txt"
