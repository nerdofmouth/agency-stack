#!/bin/bash
# Source common utilities
source "$(dirname "$0")/../utils/common.sh"
        
# install_wordpress.sh - Install and configure WordPress for AgencyStack
# https://stack.nerdofmouth.com
#
# This script sets up WordPress with:
# - MariaDB database
# - Redis caching
# - Nginx with PHP-FPM
# - WP-CLI for management
# - Auto-configured for multi-tenancy
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
WP_DIR="${CONFIG_DIR}/wordpress"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
INTEGRATIONS_LOG_DIR="${LOG_DIR}/integrations"
INSTALL_LOG="${COMPONENTS_LOG_DIR}/wordpress.log"
INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/wordpress.log"
MAIN_INTEGRATION_LOG="${INTEGRATIONS_LOG_DIR}/integration.log"
VERBOSE=false
FORCE=false
WITH_DEPS=false
DOMAIN=""
CLIENT_ID="default"  # Default client ID
ADMIN_EMAIL=""
WP_ADMIN_USER="admin"
WP_DB_PASSWORD=$(openssl rand -base64 12)
WP_ROOT_PASSWORD=$(openssl rand -base64 12)
WP_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/")
WP_VERSION="latest"
PHP_VERSION="8.1"
ENABLE_KEYCLOAK=false
ENFORCE_HTTPS=true
USE_HOST_NETWORK=true
MARIADB_CONTAINER="default_mariadb"

# Source the component_sso_helper.sh if available
if [ -f "${SCRIPT_DIR}/../utils/component_sso_helper.sh" ]; then
  source "${SCRIPT_DIR}/../utils/component_sso_helper.sh"
fi

# Show help message
show_help() {
  echo -e "${BOLD}AgencyStack WordPress Installer${NC}"
  echo -e "Installs and configures WordPress with MariaDB, Redis caching, and Nginx"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} DOMAIN        Domain name for WordPress (required)"
  echo -e "  ${BOLD}--client-id${NC} ID         Client ID for multi-tenant deployment (default: default)"
  echo -e "  ${BOLD}--admin-email${NC} EMAIL    Admin email address (required)"
  echo -e "  ${BOLD}--wp-version${NC} VERSION   WordPress version to install (default: latest)"
  echo -e "  ${BOLD}--php-version${NC} VERSION  PHP version to use (default: 8.1)"
  echo -e "  ${BOLD}--force${NC}                Force reinstallation if already installed"
  echo -e "  ${BOLD}--with-deps${NC}            Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}              Show detailed output during installation"
  echo -e "  ${BOLD}--enable-keycloak${NC}      Enable Keycloak SSO integration"
  echo -e "  ${BOLD}--enforce-https${NC}        Enforce HTTPS for WordPress (default: true)"
  echo -e "  ${BOLD}--use-host-network${NC}     Use host network mode (default: true)"
  echo -e "  ${BOLD}--help${NC}                 Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain wordpress.example.com --admin-email admin@example.com --client-id acme"
  echo -e "  $0 --domain wordpress.example.com --admin-email admin@example.com --enable-keycloak --enforce-https"
  echo -e ""
  echo -e "${YELLOW}Note: This script requires root privileges to run.${NC}"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      shift
      ;;
    --wp-version)
      WP_VERSION="$2"
      shift
      shift
      ;;
    --php-version)
      PHP_VERSION="$2"
      shift
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    --enforce-https)
      ENFORCE_HTTPS=true
      shift
      ;;
    --use-host-network)
      USE_HOST_NETWORK=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: --admin-email is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack WordPress Setup${NC}"
echo -e "=============================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Create log directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$COMPONENTS_LOG_DIR"
mkdir -p "$INTEGRATIONS_LOG_DIR"
touch "$INSTALL_LOG"
touch "$INTEGRATION_LOG"
touch "$MAIN_INTEGRATION_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$INSTALL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

# Integration log function
integration_log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - WordPress - $1" >> "$INTEGRATION_LOG"
  echo "$(date +"%Y-%m-%d %H:%M:%S") - WordPress - $1" >> "$MAIN_INTEGRATION_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[Integration] ${NC}$1"
  fi
}

log "INFO: Starting WordPress installation validation for $DOMAIN" "${BLUE}Starting WordPress installation validation for $DOMAIN...${NC}"

# Set container names based on client ID
log "INFO: Setting container names" "Setting container names..."
DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')
SITE_NAME=${DOMAIN//./_}
DOMAIN_UNDERSCORE=$(echo "$DOMAIN" | tr '.' '_')
if [ -n "$CLIENT_ID" ]; then
  WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
  NGINX_CONTAINER_NAME="${CLIENT_ID}_nginx"
  MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"
  REDIS_CONTAINER_NAME="${CLIENT_ID}_redis"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  WORDPRESS_CONTAINER_NAME="wordpress"
  NGINX_CONTAINER_NAME="nginx"
  MARIADB_CONTAINER_NAME="mariadb"
  REDIS_CONTAINER_NAME="redis"
  NETWORK_NAME="default_network"
fi

# Check if WordPress is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$WORDPRESS_CONTAINER_NAME"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: WordPress container '$WORDPRESS_CONTAINER_NAME' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ WordPress container '$WORDPRESS_CONTAINER_NAME' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing WordPress containers" "${CYAN}Stopping and removing existing WordPress containers...${NC}"
    cd "${WP_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: WordPress container '$WORDPRESS_CONTAINER_NAME' already exists" "${GREEN}✅ WordPress installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$WORDPRESS_CONTAINER_NAME"; then
      log "INFO: WordPress container is running" "${GREEN}✅ WordPress is running${NC}"
      echo -e "${GREEN}WordPress is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/wp-admin/${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARNING: WordPress container exists but is not running" "${YELLOW}⚠️ WordPress container exists but is not running${NC}"
      echo -e "${YELLOW}WordPress is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting WordPress containers...${NC}"
      cd "${WP_DIR}/${DOMAIN}" && docker-compose up -d
      echo -e "${GREEN}WordPress has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Admin URL: https://${DOMAIN}/wp-admin/${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR: Docker is not installed" "${RED}Docker is not installed. Please install Docker first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker with --with-deps flag" "${CYAN}Installing Docker with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log "ERROR: Failed to install Docker" "${RED}Failed to install Docker. Please install it manually.${NC}"
        exit 1
      }
    else
      log "ERROR: Cannot find install_infrastructure.sh script" "${RED}Cannot find install_infrastructure.sh script. Please install Docker manually.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  log "ERROR: Docker is not running" "${RED}Docker is not running. Please start Docker first.${NC}"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR: Docker Compose is not installed" "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing Docker Compose with --with-deps flag" "${CYAN}Installing Docker Compose with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_infrastructure.sh" || {
        log "ERROR: Failed to install Docker Compose" "${RED}Failed to install Docker Compose. Please install it manually.${NC}"
        exit 1
      }
    else
      log "ERROR: Cannot find install_infrastructure.sh script" "${RED}Cannot find install_infrastructure.sh script. Please install Docker Compose manually.${NC}"
      exit 1
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
    exit 1
  fi
fi

# Check if network exists, create if it doesn't
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO: Creating Docker network $NETWORK_NAME" "${CYAN}Creating Docker network $NETWORK_NAME...${NC}"
  docker network create "$NETWORK_NAME" >> "$INSTALL_LOG" 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to create Docker network $NETWORK_NAME" "${RED}Failed to create Docker network $NETWORK_NAME. See log for details.${NC}"
    exit 1
  fi
else
  log "INFO: Docker network $NETWORK_NAME already exists" "${GREEN}✅ Docker network $NETWORK_NAME already exists${NC}"
fi

# Check for Traefik
if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
  log "WARNING: Traefik container not found" "${YELLOW}⚠️ Traefik container not found. WordPress may not be accessible without a reverse proxy.${NC}"
  if [ "$WITH_DEPS" = true ]; then
    log "INFO: Installing security infrastructure with --with-deps flag" "${CYAN}Installing security infrastructure with --with-deps flag...${NC}"
    if [ -f "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" ]; then
      bash "${ROOT_DIR}/scripts/core/install_security_infrastructure.sh" --domain "$DOMAIN" --email "$ADMIN_EMAIL" || {
        log "ERROR: Failed to install security infrastructure" "${RED}Failed to install security infrastructure. Please install it manually.${NC}"
      }
    else
      log "ERROR: Cannot find install_security_infrastructure.sh script" "${RED}Cannot find install_security_infrastructure.sh script. Please install security infrastructure manually.${NC}"
    fi
  else
    log "INFO: Use --with-deps to automatically install dependencies" "${CYAN}Use --with-deps to automatically install dependencies${NC}"
  fi
else
  log "INFO: Traefik container found" "${GREEN}✅ Traefik container found${NC}"
fi

log "INFO: Starting WordPress installation for $DOMAIN" "${BLUE}Starting WordPress installation for $DOMAIN...${NC}"

# Create WordPress directories
log "INFO: Creating WordPress directories" "${CYAN}Creating WordPress directories...${NC}"
mkdir -p "${WP_DIR}/${DOMAIN}"
mkdir -p "${WP_DIR}/${DOMAIN}/wordpress"
mkdir -p "${WP_DIR}/${DOMAIN}/mariadb"
mkdir -p "${WP_DIR}/${DOMAIN}/certs"
mkdir -p "${WP_DIR}/${DOMAIN}/logs"
mkdir -p "${WP_DIR}/${DOMAIN}/redis"

# Generate random passwords if not specified
if [ -z "$WP_DB_PASSWORD" ]; then
  WP_DB_PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
fi

if [ -z "$WP_ROOT_PASSWORD" ]; then
  WP_ROOT_PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
fi

if [ -z "$WP_ADMIN_PASSWORD" ]; then
  WP_ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
fi

# Define consistent database variables
WP_DB_NAME="wordpress"
WP_DB_USER="wordpress"
WP_TABLE_PREFIX="wp_"

# Store database credentials in environment file for reference
mkdir -p "${WP_DIR}/${DOMAIN}/config"
cat > "${WP_DIR}/${DOMAIN}/config/.env" <<EOL
# WordPress Database Configuration
# Generated by AgencyStack installation script
WP_DB_NAME=${WP_DB_NAME}
WP_DB_USER=${WP_DB_USER}
WP_DB_PASSWORD=${WP_DB_PASSWORD}
WP_ROOT_PASSWORD=${WP_ROOT_PASSWORD}
EOL

# Create MariaDB initialization script
log "INFO: Creating MariaDB initialization script" "${CYAN}Creating MariaDB initialization script...${NC}"
mkdir -p "${WP_DIR}/${DOMAIN}/mariadb-init"

# Create an entrypoint script that will initialize the database reliably
cat > "${WP_DIR}/${DOMAIN}/mariadb-init/docker-entrypoint.sh" <<EOL
#!/bin/bash
set -e

# Start MariaDB in the background
/usr/local/bin/docker-entrypoint.sh mysqld &
PID=\$!

# Wait for MariaDB to become available
echo "Waiting for MariaDB to start..."
for i in {30..0}; do
  if mysql -u root -p${WP_ROOT_PASSWORD} -e "SELECT 1" &> /dev/null; then
    break
  fi
  echo "MariaDB not ready yet, waiting..."
  sleep 1
done

if [ \$i = 0 ]; then
  echo >&2 "MariaDB did not start in time"
  exit 1
fi

echo "MariaDB started successfully"

# Run initialization commands
echo "Initializing WordPress database..."
mysql -u root -p${WP_ROOT_PASSWORD} <<EOF
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};

-- Clean up any existing users with the same name to avoid conflicts
DROP USER IF EXISTS '${WP_DB_USER}'@'%';
DROP USER IF EXISTS '${WP_DB_USER}'@'localhost';

-- Create WordPress user with wildcard host access
CREATE USER '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
CREATE USER '${WP_DB_USER}'@'localhost' IDENTIFIED BY '${WP_DB_PASSWORD}';

-- Grant privileges to WordPress user
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'%';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'localhost';

-- Flush privileges
FLUSH PRIVILEGES;

USE ${WP_DB_NAME};
CREATE TABLE IF NOT EXISTS wp_options (
  option_id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  option_name varchar(191) NOT NULL DEFAULT '',
  option_value longtext NOT NULL,
  autoload varchar(20) NOT NULL DEFAULT 'yes',
  PRIMARY KEY (option_id),
  UNIQUE KEY option_name (option_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default site URL
INSERT INTO wp_options (option_name, option_value, autoload) 
VALUES ('siteurl', 'https://${DOMAIN}', 'yes')
ON DUPLICATE KEY UPDATE option_value = 'https://${DOMAIN}';

-- Insert default home URL
INSERT INTO wp_options (option_name, option_value, autoload) 
VALUES ('home', 'https://${DOMAIN}', 'yes')
ON DUPLICATE KEY UPDATE option_value = 'https://${DOMAIN}';
EOF

echo "Database initialization completed"

# Keep the server running in the foreground
wait \$PID
EOL

chmod +x "${WP_DIR}/${DOMAIN}/mariadb-init/docker-entrypoint.sh"

# Create MariaDB configuration file
cat > "${WP_DIR}/${DOMAIN}/mariadb-init/my.cnf" <<EOL
[mysqld]
default_authentication_plugin=mysql_native_password
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
skip-host-cache
skip-name-resolve
bind-address=0.0.0.0
max_allowed_packet=128M
EOL

# Create WordPress Docker Compose file
log "INFO: Creating WordPress Docker Compose file" "${CYAN}Creating WordPress Docker Compose file...${NC}"
cat > "${WP_DIR}/${DOMAIN}/docker-compose.yml" <<EOL
version: '3'

networks:
  wordpress_network:
    name: ${CLIENT_ID}_wordpress_${SITE_NAME}_network
  ${CLIENT_ID}_network:
    external: true

services:
  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:php8.2-fpm
    restart: unless-stopped
    depends_on:
      - mariadb
      - redis
    networks:
      - wordpress_network
      - ${CLIENT_ID}_network
    volumes:
      - ${WP_DIR}/${DOMAIN}/wordpress:/var/www/html
      - ${WP_DIR}/${DOMAIN}/php-fpm/www.conf:/usr/local/etc/php-fpm.d/www.conf
      - ${WP_DIR}/${DOMAIN}/php-fpm/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
    environment:
      - WORDPRESS_DB_HOST=${MARIADB_CONTAINER_NAME}
      - WORDPRESS_DB_NAME=${WP_DB_NAME}
      - WORDPRESS_DB_USER=${WP_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
      - WORDPRESS_TABLE_PREFIX=wp_
      - WORDPRESS_DEBUG=true
      - WORDPRESS_CONFIG_EXTRA=define('WP_HOME', 'https://${DOMAIN}');define('WP_SITEURL', 'https://${DOMAIN}');
    healthcheck:
      test: ["CMD", "php", "-r", "if(!file_exists('/var/www/html/wp-includes/version.php')) exit(1);"]
      interval: 10s
      timeout: 5s
      retries: 3
    labels:
      - "traefik.enable=false"
  
  nginx:
    container_name: ${NGINX_CONTAINER_NAME}
    image: nginx:latest
    restart: unless-stopped
    depends_on:
      wordpress:
        condition: service_healthy
    networks:
      - wordpress_network
      - ${CLIENT_ID}_network
    volumes:
      - ${WP_DIR}/${DOMAIN}/wordpress:/var/www/html
      - ${WP_DIR}/${DOMAIN}/nginx/default.conf:/etc/nginx/conf.d/default.conf
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.wordpress_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.wordpress_${SITE_NAME}.loadbalancer.server.port=80"
  
  mariadb:
    container_name: ${MARIADB_CONTAINER_NAME}
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/${DOMAIN}/mariadb:/var/lib/mysql
      - ${WP_DIR}/${DOMAIN}/mariadb-init/my.cnf:/etc/mysql/my.cnf
      - ${WP_DIR}/${DOMAIN}/mariadb-init/docker-entrypoint.sh:/docker-entrypoint.sh
    environment:
      - MYSQL_DATABASE=${WP_DB_NAME}
      - MYSQL_USER=${WP_DB_USER}
      - MYSQL_PASSWORD=${WP_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${WP_ROOT_PASSWORD}
      - MYSQL_ROOT_HOST=%
      - MYSQL_ALLOW_EMPTY_PASSWORD=no
    networks:
      - wordpress_network
    command: /docker-entrypoint.sh
    entrypoint: []
    labels:
      - "traefik.enable=false"
  
  redis:
    container_name: ${REDIS_CONTAINER_NAME}
    image: redis:alpine
    restart: unless-stopped
    networks:
      - wordpress_network
    labels:
      - "traefik.enable=false"
EOL

# Create PHP-FPM configuration
log "INFO: Creating PHP-FPM configuration" "${CYAN}Creating PHP-FPM configuration...${NC}"
mkdir -p "${WP_DIR}/${DOMAIN}/php-fpm"
cat > "${WP_DIR}/${DOMAIN}/php-fpm/www.conf" <<EOL
[www]
user = www-data
group = www-data
listen = 9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

cat > "${WP_DIR}/${DOMAIN}/php-fpm/uploads.ini" <<EOL
file_uploads = On
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 600
EOL

# Create Nginx configuration
log "INFO: Creating Nginx configuration" "${CYAN}Creating Nginx configuration...${NC}"
mkdir -p "${WP_DIR}/${DOMAIN}/nginx"
cat > "${WP_DIR}/${DOMAIN}/nginx/default.conf" <<EOL
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/html;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }
}
EOL

# Start WordPress stack
log "INFO: Starting WordPress stack" "${CYAN}Starting WordPress stack...${NC}"
cd "${WP_DIR}/${DOMAIN}" && docker-compose up -d
if [ $? -ne 0 ]; then
  log "ERROR: Failed to start WordPress stack" "${RED}Failed to start WordPress stack${NC}"
  exit 1
fi

# Wait for WordPress stack to initialize
log "INFO: Waiting for WordPress to start" "${CYAN}Waiting for WordPress to start...${NC}"
sleep 15

# Install MySQL client for diagnostics
log "INFO: Installing MySQL client for diagnostics" "${CYAN}Installing MySQL client for diagnostics...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "apt-get update && apt-get install -y default-mysql-client" || log "WARNING: Unable to install MySQL client" "${YELLOW}⚠️ Unable to install MySQL client${NC}"

# NOW we can initialize the database AFTER the containers are started
# Improve database initialization with a direct approach that properly escapes special characters
log "INFO: Ensuring database is properly initialized" "${CYAN}Ensuring database is properly initialized...${NC}"

# Wait for MariaDB to be fully initialized (important for fresh installs)
sleep 10

# Use the environment variables already specified in the docker-compose file
log "INFO: Checking database connection" "${CYAN}Checking database connection...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_DB_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -u${WP_DB_USER} -e 'SELECT 1;'" && {
  log "INFO: Database connection successful with WordPress user" "${GREEN}✅ Database connection successful with WordPress user${NC}"
} || {
  log "WARNING: Database connection with WordPress user failed, initializing database" "${YELLOW}⚠️ Database connection with WordPress user failed, initializing database${NC}"
  
  # Try with root
  docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e 'SELECT 1;'" && {
    log "INFO: Database connection successful with root user" "${GREEN}✅ Database connection successful with root user${NC}"
    
    # These direct SQL commands handle initialization without relying on potentially problematic heredoc escaping
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};\"" || log "WARNING: Unable to create database" "${YELLOW}⚠️ Unable to create database${NC}"
    
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'localhost' IDENTIFIED BY '${WP_DB_PASSWORD}';\"" || log "WARNING: Unable to create localhost user" "${YELLOW}⚠️ Unable to create localhost user${NC}"
    
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';\"" || log "WARNING: Unable to create wildcard user" "${YELLOW}⚠️ Unable to create wildcard user${NC}"
    
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'localhost';\"" || log "WARNING: Unable to grant privileges to localhost user" "${YELLOW}⚠️ Unable to grant privileges to localhost user${NC}"
    
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'%';\"" || log "WARNING: Unable to grant privileges to wildcard user" "${YELLOW}⚠️ Unable to grant privileges to wildcard user${NC}"
    
    docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"FLUSH PRIVILEGES;\"" || log "WARNING: Unable to flush privileges" "${YELLOW}⚠️ Unable to flush privileges${NC}"
  } || {
    log "WARNING: Database connection with root user failed" "${YELLOW}⚠️ Database connection with root user failed${NC}"
  }
}

# Run a brief verification
log "INFO: Verifying database setup" "${CYAN}Verifying database setup...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "MYSQL_PWD=${WP_ROOT_PASSWORD} mysql -h${MARIADB_CONTAINER_NAME} -uroot -e \"SHOW DATABASES; SELECT User, Host FROM mysql.user WHERE User='${WP_DB_USER}' OR User='root';\"" || log "WARNING: Unable to verify database setup" "${YELLOW}⚠️ Unable to verify database setup${NC}"

# Create a better test_db script that demonstrates proper service discovery and connectivity checks
# This approach can be reused for connecting to shared services in the future
cat > "${WP_DIR}/${DOMAIN}/test_db.sh" <<EOL
#!/bin/bash
# Technology Reuse Database Connection Test Script
# This script demonstrates proper service discovery and connection validation
# that could be reused across components in AgencyStack

echo "=========================================="
echo "DATABASE CONNECTION TEST"
echo "Target: ${MARIADB_CONTAINER_NAME}"
echo "User: ${WP_DB_USER}"
echo "Database: ${WP_DB_NAME}"
echo "=========================================="

# Try the connection with environment variables
export MYSQL_PWD="${WP_DB_PASSWORD}"
if mysql -h${MARIADB_CONTAINER_NAME} -u${WP_DB_USER} -e "USE ${WP_DB_NAME}; SELECT 'Database connection successful!' as Status;" 2>/dev/null; then
    echo "SUCCESS: Connected to database ${MARIADB_CONTAINER_NAME}"
    exit 0
else
    echo "FAILURE: Could not connect to database"
    echo "Testing root connection as diagnostic:"
    export MYSQL_PWD="${WP_ROOT_PASSWORD}"
    mysql -h${MARIADB_CONTAINER_NAME} -uroot -e "SHOW DATABASES;" 2>&1 || echo "Root connection failed"
    echo "Testing IP resolution:"
    getent hosts ${MARIADB_CONTAINER_NAME} || echo "Host lookup failed"
    exit 1
fi
EOL

chmod +x "${WP_DIR}/${DOMAIN}/test_db.sh"

# Copy test_db.sh to the WordPress container
docker cp "${WP_DIR}/${DOMAIN}/test_db.sh" ${WORDPRESS_CONTAINER_NAME}:/tmp/test_db.sh

# Run test_db.sh
docker exec ${WORDPRESS_CONTAINER_NAME} /tmp/test_db.sh || log "WARNING: Database connection test failed, but continuing..." "${YELLOW}⚠️ Database connection test failed, but continuing...${NC}"

# Install WP-CLI inside the container
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"

# Ensure database is ready
log "INFO: Ensuring database is ready" "${CYAN}Ensuring database is ready...${NC}"
sleep 10

# Configure WordPress using WP-CLI
log "INFO: Configuring WordPress site" "${CYAN}Configuring WordPress site...${NC}"

# Wait for WordPress to be ready
sleep 10

# Run WP-CLI
docker exec ${WORDPRESS_CONTAINER_NAME} wp --allow-root --path=/var/www/html core install \
  --url="https://${DOMAIN}" \
  --title="WordPress on AgencyStack" \
  --admin_user="${WP_ADMIN_USER}" \
  --admin_password="${WP_ADMIN_PASSWORD}" \
  --admin_email="${ADMIN_EMAIL}"

if [ $? -ne 0 ]; then
  log "WARNING: WordPress may need manual configuration" "${YELLOW}WordPress may need manual configuration. Please visit https://${DOMAIN}/ to complete setup.${NC}"
else
  # Install and activate essential plugins
  log "INFO: Installing essential plugins" "${CYAN}Installing essential plugins...${NC}"
  docker exec ${WORDPRESS_CONTAINER_NAME} wp plugin install redis-cache wordfence sucuri-scanner wordpress-seo duplicate-post --activate --path="/var/www/html"
  
  # Enable Redis Object Cache
  docker exec ${WORDPRESS_CONTAINER_NAME} wp redis enable --path="/var/www/html"
  
  # Update permalink structure
  docker exec ${WORDPRESS_CONTAINER_NAME} wp rewrite structure '/%postname%/' --path="/var/www/html"
  
  # Configure security settings
  docker exec ${WORDPRESS_CONTAINER_NAME} wp option update blog_public 0 --path="/var/www/html"  # Discourage search engines until site is ready
  
  # Create a sample page
  docker exec ${WORDPRESS_CONTAINER_NAME} wp post create --post_type=page --post_title='Welcome to AgencyStack WordPress' --post_content='This WordPress site is powered by AgencyStack.' --post_status=publish --path="/var/www/html"
  
  # Set as homepage
  docker exec ${WORDPRESS_CONTAINER_NAME} wp option update show_on_front 'page' --path="/var/www/html"
  docker exec ${WORDPRESS_CONTAINER_NAME} wp option update page_on_front 2 --path="/var/www/html"
fi

# Store credentials in a secure location
log "INFO: Storing credentials" "${CYAN}Storing credentials...${NC}"
mkdir -p "${CONFIG_DIR}/secrets/wordpress"
chmod 700 "${CONFIG_DIR}/secrets/wordpress"

cat > "${CONFIG_DIR}/secrets/wordpress/${DOMAIN}.env" <<EOF
# WordPress Credentials for ${DOMAIN}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

WP_ADMIN_URL=https://${DOMAIN}/wp-admin/
WP_ADMIN_USER=${WP_ADMIN_USER}
WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
WP_ADMIN_EMAIL=${ADMIN_EMAIL}

DB_ROOT_PASSWORD=${WP_ROOT_PASSWORD}
WP_DB_PASSWORD=${WP_DB_PASSWORD}

# Docker containers
WP_CONTAINER=wordpress
MARIADB_CONTAINER=${MARIADB_CONTAINER_NAME}
REDIS_CONTAINER=${REDIS_CONTAINER_NAME}
EOF

chmod 600 "${CONFIG_DIR}/secrets/wordpress/${DOMAIN}.env"

# Register the installation in components registry
if [ -d "${CONFIG_DIR}/components" ]; then
  log "INFO: Registering WordPress in components registry" "${CYAN}Registering WordPress in components registry...${NC}"
  mkdir -p "${CONFIG_DIR}/components/wordpress"
  
  cat > "${CONFIG_DIR}/components/wordpress/${DOMAIN}.json" <<EOF
{
  "component": "wordpress",
  "version": "${WP_VERSION}",
  "domain": "${DOMAIN}",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "client_id": "${CLIENT_ID}",
  "status": "active"
}
EOF
fi

# Configure Keycloak SSO integration if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  log "INFO: Configuring Keycloak SSO integration for WordPress" "${CYAN}Configuring Keycloak SSO integration for WordPress...${NC}"
  
  # Check if component_sso_helper.sh is available and the enable_component_sso function exists
  if type enable_component_sso &>/dev/null; then
    # Get redirect URIs for WordPress
    WP_REDIRECT_URIS='["https://'"${DOMAIN}"'/*", "https://'"${DOMAIN}"'/wp-login.php", "https://'"${DOMAIN}"'/wp-admin/*"]'
    
    # Enable SSO for WordPress
    if enable_component_sso "wordpress" "${DOMAIN}" "${WP_REDIRECT_URIS}" "wordpress" "agency_stack"; then
      log "INFO: Successfully registered WordPress with Keycloak" "${GREEN}Successfully registered WordPress with Keycloak${NC}"
      
      # Create SSO configuration directory
      mkdir -p "${WP_DIR}/${DOMAIN}/sso"
      
      # Install and configure the OpenID Connect plugin
      log "INFO: Installing OpenID Connect plugin for WordPress" "${CYAN}Installing OpenID Connect plugin for WordPress...${NC}"
      docker exec ${WORDPRESS_CONTAINER_NAME} wp plugin install openid-connect-generic --activate
      
      # Get client credentials from the SSO configuration
      if [ -f "${WP_DIR}/${DOMAIN}/sso/credentials" ]; then
        source "${WP_DIR}/${DOMAIN}/sso/credentials"
        
        # Configure the OpenID Connect plugin
        log "INFO: Configuring OpenID Connect plugin" "${CYAN}Configuring OpenID Connect plugin...${NC}"
        docker exec ${WORDPRESS_CONTAINER_NAME} wp option update openid_connect_generic_settings '{
          "login_type":"auto",
          "client_id":"'"${KEYCLOAK_CLIENT_ID}"'",
          "client_secret":"'"${KEYCLOAK_CLIENT_SECRET}"'",
          "scope":"openid email profile",
          "endpoint_login":"'"${KEYCLOAK_URL}"'/realms/'"${KEYCLOAK_REALM}"'/protocol/openid-connect/auth",
          "endpoint_token":"'"${KEYCLOAK_URL}"'/realms/'"${KEYCLOAK_REALM}"'/protocol/openid-connect/token",
          "endpoint_userinfo":"'"${KEYCLOAK_URL}"'/realms/'"${KEYCLOAK_REALM}"'/protocol/openid-connect/userinfo",
          "identity_key":"preferred_username",
          "link_existing_users":true,
          "create_if_does_not_exist":true,
          "redirect_user_back":true,
          "redirect_on_logout":true,
          "enable_logging":true
        }' --format=json
        
        # Create a marker file for the SSO configuration
        touch "${WP_DIR}/${DOMAIN}/sso/.sso_configured"
        
        log "INFO: SSO integration completed for WordPress" "${GREEN}SSO integration completed for WordPress${NC}"
      else
        log "WARNING: Keycloak credentials not found" "${YELLOW}Keycloak credentials not found${NC}"
        log "INFO: Manual SSO configuration will be required" "${CYAN}Manual SSO configuration will be required${NC}"
      fi
    else
      log "WARNING: Failed to enable Keycloak SSO for WordPress" "${YELLOW}Failed to enable Keycloak SSO for WordPress${NC}"
    fi
  else
    log "WARNING: component_sso_helper.sh not found or not properly sourced" "${YELLOW}Keycloak SSO integration helper not available${NC}"
    log "INFO: Manual SSO configuration will be required" "${CYAN}Manual SSO configuration will be required${NC}"
  fi
fi

# Update component registry
if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
  log "INFO: Updating component registry" "${CYAN}Updating component registry...${NC}"
  
  REGISTRY_ARGS=(
    "--component" "wordpress"
    "--installed" "true"
    "--monitoring" "true"
    "--traefik_tls" "true"
  )
  
  if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
    REGISTRY_ARGS+=(
      "--sso" "true"
      "--sso_configured" "true"
    )
  fi
  
  bash "${ROOT_DIR}/scripts/utils/update_component_registry.sh" "${REGISTRY_ARGS[@]}"
fi

log "INFO: WordPress installation completed successfully" "${GREEN}WordPress installation completed successfully!${NC}"
log "INFO: WordPress is now accessible at https://${DOMAIN}" "${GREEN}WordPress is now accessible at:${NC} https://${DOMAIN}"
log "INFO: Admin URL: https://${DOMAIN}/wp-admin/" "${GREEN}Admin URL:${NC} https://${DOMAIN}/wp-admin/"
log "INFO: Admin username: ${WP_ADMIN_USER}" "${GREEN}Admin username:${NC} ${WP_ADMIN_USER}"
log "INFO: Admin password: ${WP_ADMIN_PASSWORD}" "${GREEN}Admin password:${NC} ${WP_ADMIN_PASSWORD}"

log "INFO: Installation complete" "${GREEN}Installation complete!${NC}"
echo -e "${CYAN}WordPress URL: https://${DOMAIN}/${NC}"
echo -e "${CYAN}Admin URL: https://${DOMAIN}/wp-admin/${NC}"
echo -e "${YELLOW}Admin Username: ${WP_ADMIN_USER}${NC}"
echo -e "${YELLOW}Admin Password: ${WP_ADMIN_PASSWORD}${NC}"
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely and change the password!${NC}"
echo -e ""
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/wordpress/${DOMAIN}.env${NC}"

exit 0
