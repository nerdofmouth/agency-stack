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

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
if [ -n "$CLIENT_ID" ]; then
  WP_CONTAINER="${CLIENT_ID}_wordpress"
  MARIADB_CONTAINER="${CLIENT_ID}_mariadb"
  REDIS_CONTAINER="${CLIENT_ID}_redis"
  NETWORK_NAME="${CLIENT_ID}_network"
else
  WP_CONTAINER="wordpress_${SITE_NAME}"
  MARIADB_CONTAINER="mariadb_${SITE_NAME}"
  REDIS_CONTAINER="redis_${SITE_NAME}"
  NETWORK_NAME="agency-network"
fi

# Check if WordPress is already installed
if docker ps -a --format '{{.Names}}' | grep -q "$WP_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARNING: WordPress container '$WP_CONTAINER' already exists, will reinstall because --force was specified" "${YELLOW}⚠️ WordPress container '$WP_CONTAINER' already exists, will reinstall because --force was specified${NC}"
    # Stop and remove existing containers
    log "INFO: Stopping and removing existing WordPress containers" "${CYAN}Stopping and removing existing WordPress containers...${NC}"
    cd "${WP_DIR}/${DOMAIN}" && docker-compose down 2>/dev/null || true
  else
    log "INFO: WordPress container '$WP_CONTAINER' already exists" "${GREEN}✅ WordPress installation for $DOMAIN already exists${NC}"
    log "INFO: To reinstall, use --force flag" "${CYAN}To reinstall, use --force flag${NC}"
    
    # Check if the containers are running
    if docker ps --format '{{.Names}}' | grep -q "$WP_CONTAINER"; then
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
mkdir -p "${WP_DIR}/${DOMAIN}/html"
mkdir -p "${WP_DIR}/${DOMAIN}/db"
mkdir -p "${WP_DIR}/${DOMAIN}/certs"
mkdir -p "${WP_DIR}/${DOMAIN}/logs"
mkdir -p "${WP_DIR}/${DOMAIN}/redis"

# Store MySQL credentials for WP-CLI
cat > "${WP_DIR}/${DOMAIN}/.my.cnf" <<EOL
[client]
host=${CLIENT_ID}_mariadb
user=wordpress
password=${WP_DB_PASSWORD}
EOL
chmod 600 "${WP_DIR}/${DOMAIN}/.my.cnf"

# Create WordPress Docker Compose file
log "INFO: Creating WordPress Docker Compose file" "${CYAN}Creating WordPress Docker Compose file...${NC}"
cat > "${WP_DIR}/${DOMAIN}/docker-compose.yml" <<EOL
version: '3.7'

services:
  # MariaDB Database
  db:
    image: mariadb:10.6
    container_name: ${CLIENT_ID}_mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${WP_ROOT_PASSWORD}
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
    volumes:
      - ${WP_DIR}/${DOMAIN}/db:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "mariadb_${SITE_NAME}"

  # Redis Cache
  redis:
    image: redis:alpine
    container_name: ${REDIS_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/${DOMAIN}/redis:/data
    networks:
      - ${NETWORK_NAME}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "redis_${SITE_NAME}"

  # WordPress with PHP-FPM and Nginx
  wordpress:
    image: wordpress:php${PHP_VERSION}-fpm
    container_name: wordpress
    restart: unless-stopped
    depends_on:
      - db
      - redis
    environment:
      WORDPRESS_DB_HOST: ${CLIENT_ID}_mariadb
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_REDIS_HOST', 'redis');
        define('WP_REDIS_PORT', 6379);
        define('WP_CACHE', true);
        define('WP_ENVIRONMENT_TYPE', 'production');
        define('AUTOMATIC_UPDATER_DISABLED', false);
        define('WP_AUTO_UPDATE_CORE', 'minor');
    healthcheck:
      test: ["CMD", "php", "-r", "if (!file_exists('/var/www/html/wp-config.php')) { exit(1); } else { exit(0); }"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 30s
    volumes:
      - ${WP_DIR}/${DOMAIN}/html:/var/www/html
      - ${WP_DIR}/${DOMAIN}/php-fpm.conf:/usr/local/etc/php-fpm.d/www.conf
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.wordpress_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls.certresolver=letsencrypt"
      - "traefik.http.routers.wordpress_${SITE_NAME}.middlewares=secure-headers@file"
      - "traefik.http.services.wordpress_${SITE_NAME}.loadbalancer.server.port=9000"
      - "traefik.docker.network=${NETWORK_NAME}"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "wordpress_${SITE_NAME}"
    command: bash -c "docker-php-ext-install mysqli pdo pdo_mysql && docker-php-ext-enable mysqli && php-fpm -R"
    expose:
      - "9000"

  # Nginx as a reverse proxy for WordPress
  nginx:
    image: nginx:alpine
    restart: unless-stopped
    depends_on:
      wordpress:
        condition: service_healthy
    volumes:
      - ${WP_DIR}/${DOMAIN}/html:/var/www/html:ro
      - ${WP_DIR}/${DOMAIN}/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ${WP_DIR}/${DOMAIN}/logs:/var/log/nginx
    ports:
      - "8080:80"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.wordpress_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls.certresolver=letsencrypt"
      - "traefik.http.routers.wordpress_${SITE_NAME}.middlewares=secure-headers@file"
      - "traefik.http.services.wordpress_${SITE_NAME}.loadbalancer.server.port=80"
      - "traefik.docker.network=${NETWORK_NAME}"

networks:
  ${NETWORK_NAME}:
    external: true
EOL

# Create Nginx configuration
log "INFO: Creating Nginx configuration" "${CYAN}Creating Nginx configuration...${NC}"
cat > "${WP_DIR}/${DOMAIN}/nginx.conf" <<EOL
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    root /var/www/html;
    index index.php;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log debug;
    
    client_max_body_size 100M;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 172.20.0.4:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        fastcgi_intercept_errors on;
        fastcgi_param HTTPS \$https if_not_empty;
        # Additional FastCGI parameters
        fastcgi_param SERVER_NAME \$host;
        fastcgi_param HTTP_HOST \$host;
        fastcgi_keep_conn on;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to wp-config.php
    location ~* wp-config\.php {
        deny all;
    }
    
    # Deny access to debug.log
    location ~* debug\.log {
        deny all;
    }
}
EOL

# Create PHP-FPM configuration
log "INFO: Creating PHP-FPM configuration" "${CYAN}Creating PHP-FPM configuration...${NC}"
cat > "${WP_DIR}/${DOMAIN}/php-fpm.conf" <<EOL
[global]
daemonize = no

[www]
listen = 0.0.0.0:9000
user = www-data
group = www-data
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

# Start the WordPress stack
log "INFO: Starting WordPress stack" "${CYAN}Starting WordPress stack...${NC}"
cd "${WP_DIR}/${DOMAIN}" && docker-compose up -d

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start WordPress stack" "${RED}Failed to start WordPress stack. See log for details.${NC}"
  exit 1
fi

# Wait for WordPress to start
log "INFO: Waiting for WordPress to start" "${YELLOW}Waiting for WordPress to start...${NC}"
sleep 10

# Install WP-CLI
log "INFO: Installing WP-CLI" "${CYAN}Installing WP-CLI...${NC}"
if ! command -v wp &> /dev/null; then
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar >> "$INSTALL_LOG" 2>&1
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
fi

# Configure WordPress using WP-CLI
log "INFO: Configuring WordPress site" "${CYAN}Configuring WordPress site...${NC}"
docker exec -it wordpress wp core install --url="${DOMAIN}" --title="AgencyStack WordPress" --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${ADMIN_EMAIL}" --path="/var/www/html" --skip-email

if [ $? -ne 0 ]; then
  log "WARNING: WordPress may need manual configuration" "${YELLOW}WordPress may need manual configuration. Please visit https://${DOMAIN}/ to complete setup.${NC}"
else
  # Install and activate essential plugins
  log "INFO: Installing essential plugins" "${CYAN}Installing essential plugins...${NC}"
  docker exec -it wordpress wp plugin install redis-cache wordfence sucuri-scanner wordpress-seo duplicate-post --activate --path="/var/www/html"
  
  # Enable Redis Object Cache
  docker exec -it wordpress wp redis enable --path="/var/www/html"
  
  # Update permalink structure
  docker exec -it wordpress wp rewrite structure '/%postname%/' --path="/var/www/html"
  
  # Configure security settings
  docker exec -it wordpress wp option update blog_public 0 --path="/var/www/html"  # Discourage search engines until site is ready
  
  # Create a sample page
  docker exec -it wordpress wp post create --post_type=page --post_title='Welcome to AgencyStack WordPress' --post_content='This WordPress site is powered by AgencyStack.' --post_status=publish --path="/var/www/html"
  
  # Set as homepage
  docker exec -it wordpress wp option update show_on_front 'page' --path="/var/www/html"
  docker exec -it wordpress wp option update page_on_front 2 --path="/var/www/html"
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
MARIADB_CONTAINER=${MARIADB_CONTAINER}
REDIS_CONTAINER=${REDIS_CONTAINER}
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
      docker exec -it wordpress wp plugin install openid-connect-generic --activate
      
      # Get client credentials from the SSO configuration
      if [ -f "${WP_DIR}/${DOMAIN}/sso/credentials" ]; then
        source "${WP_DIR}/${DOMAIN}/sso/credentials"
        
        # Configure the OpenID Connect plugin
        log "INFO: Configuring OpenID Connect plugin" "${CYAN}Configuring OpenID Connect plugin...${NC}"
        docker exec -it wordpress wp option update openid_connect_generic_settings '{
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
