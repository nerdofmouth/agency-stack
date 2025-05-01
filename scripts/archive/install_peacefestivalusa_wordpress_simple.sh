#!/bin/bash
# install_peacefestivalusa_wordpress_simple.sh - Client-specific WordPress installation for local testing
# Part of AgencyStack Alpha - https://stack.nerdofmouth.com
# Following the Repository Integrity Policy and Host-to-Container Rule

set -e

# Client-specific variables
CLIENT_ID="peacefestivalusa"
WP_PORT="8082"
MARIADB_PORT="33060"

# Docker-in-Docker specific paths
INSTALL_BASE_DIR="${HOME}/.agencystack"
LOG_DIR="${HOME}/.logs/agency_stack/components"
WP_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/wordpress"

# Create required directories
mkdir -p "${WP_DIR}/wp-content"
mkdir -p "${WP_DIR}/mariadb-data"
mkdir -p "${LOG_DIR}"

echo "=== Installing WordPress for ${CLIENT_ID} (simple localhost version) ==="
echo "WordPress Port: ${WP_PORT}"
echo "MariaDB Port: ${MARIADB_PORT}"
echo "Installation Directory: ${WP_DIR}"

# Define container names and network
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
WORDPRESS_DB_HOST=database
WORDPRESS_DB_NAME=${WP_DB_NAME}
WORDPRESS_DB_USER=${WP_DB_USER}
WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
WORDPRESS_DEBUG=true
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
    ports:
      - "${MARIADB_PORT}:3306"
    networks:
      - wordpress_network

  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:6.1-php8.1-apache
    restart: unless-stopped
    depends_on:
      - database
    volumes:
      - ${WP_DIR}/wp-content:/var/www/html/wp-content
    env_file:
      - ${WP_DIR}/.env
    environment:
      - WORDPRESS_DEBUG=1
    ports:
      - "${WP_PORT}:80"
    networks:
      - wordpress_network

networks:
  wordpress_network:
    driver: bridge
EOL

# Remove existing containers if they exist
echo "Removing any existing containers..."
docker rm -f "${WORDPRESS_CONTAINER_NAME}" "${MARIADB_CONTAINER_NAME}" 2>/dev/null || true

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
    echo "WordPress may not be fully started yet. Check logs with 'docker logs ${WORDPRESS_CONTAINER_NAME}'"
  fi
  
  sleep 2
done
EOL

chmod +x "${WP_DIR}/verify_installation.sh"

# Run the verification script
echo "Running verification script..."
"${WP_DIR}/verify_installation.sh"

# Store credentials safely
mkdir -p "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets"
cat > "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt" <<EOL
WordPress Port: ${WP_PORT}
WordPress Admin: ${WP_ADMIN_USER}
WordPress Admin Password: ${WP_ADMIN_PASSWORD}
Database Name: ${WP_DB_NAME}
Database User: ${WP_DB_USER}
Database Password: ${WP_DB_PASSWORD}
MariaDB Port: ${MARIADB_PORT}
EOL
chmod 600 "${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt"

# Display success message
echo "=== WordPress installation for ${CLIENT_ID} (simple localhost version) complete ==="
echo "Access WordPress at: http://localhost:${WP_PORT}"
echo "WordPress Admin: ${WP_ADMIN_USER}"
echo "WordPress Admin Password: ${WP_ADMIN_PASSWORD}"
echo "Database Name: ${WP_DB_NAME}"
echo "Database User: ${WP_DB_USER}"
echo "Database Password: ${WP_DB_PASSWORD}"
echo "MariaDB accessible at: localhost:${MARIADB_PORT}"
echo "Docker compose file: ${WP_DIR}/docker-compose.yml"
echo "Credentials stored in: ${INSTALL_BASE_DIR}/clients/${CLIENT_ID}/.secrets/wordpress-credentials.txt"
