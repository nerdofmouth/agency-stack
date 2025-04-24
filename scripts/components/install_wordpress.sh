#!/bin/bash
# install_wordpress.sh - Installation script for WordPress
# AgencyStack Team

set -e

# --- Ensure logging functions are available (source common.sh and log_helpers.sh) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [[ "$(type -t log)" != "function" ]]; then
  source "$REPO_ROOT/scripts/utils/common.sh"
fi
if [[ "$(type -t log)" != "function" ]]; then
  source "$REPO_ROOT/scripts/utils/log_helpers.sh"
fi

# --- Ensure FORCE is always initialized to avoid unbound variable errors ---
FORCE="${FORCE:-false}"

# --- Parse command-line arguments for --force and others ---
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE="true"
      ;;
    # Add other flags here if needed
  esac
done

# Accept multiple true values for FORCE
FORCE_NORMALIZED="false"
if [[ "$FORCE" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  FORCE_NORMALIZED="true"
fi

# Debug: Show FORCE value
log "INFO" "FORCE variable value: $FORCE (normalized: $FORCE_NORMALIZED)"

# --- Define WordPress DB variables EARLY to avoid unbound variable errors ---
WP_DB_NAME="wordpress"
WP_DB_USER="wordpress"
WP_DB_PASSWORD="${WP_DB_PASSWORD:-wordpresspass}"
WP_ROOT_PASSWORD="${WP_ROOT_PASSWORD:-mariadb_root_password}"
WP_TABLE_PREFIX="wp_"

# --- Define admin credentials early as well ---
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="admin"

# --- Define MariaDB container name early ---
if [ -n "$CLIENT_ID" ]; then
  MARIADB_CONTAINER_NAME="${CLIENT_ID}_mariadb"
else
  MARIADB_CONTAINER_NAME="mariadb"
fi

# --- MariaDB container existence check and auto-handling (robust for Compose patterns) ---
MATCHING_CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep -E "(^${MARIADB_CONTAINER_NAME}$|^${CLIENT_ID}_mariadb$|^mariadb$|^default_mariadb$)" || true)
if [[ -n "$MATCHING_CONTAINERS" ]]; then
  log "WARNING: MariaDB container(s) matching deployment already exist." "${YELLOW}MariaDB container(s) matching deployment already exist.${NC}"
  log "INFO" "Matching containers: $MATCHING_CONTAINERS"
  if [ "$FORCE_NORMALIZED" = "true" ]; then
    log "INFO: Removing all matching MariaDB containers (FORCE enabled)" "${CYAN}Removing all matching MariaDB containers...${NC}"
    echo "$MATCHING_CONTAINERS" | xargs -r -I {} docker rm -f "{}"
    # Robust wait: up to 10 seconds for Docker to fully remove the container
    max_wait=10
    waited=0
    while docker ps -a --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER_NAME}$"; do
      if [ "$waited" -ge "$max_wait" ]; then
        log "ERROR: MariaDB container still exists after $max_wait seconds. Aborting." "${RED}MariaDB container still exists after $max_wait seconds. Aborting.${NC}"
        exit 1
      fi
      sleep 1
      waited=$((waited+1))
    done
    # Double-check the container is gone before proceeding
    if docker ps -a --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER_NAME}$"; then
      log "ERROR: MariaDB container still exists after attempted removal. Aborting." "${RED}MariaDB container still exists after attempted removal. Aborting.${NC}"
      exit 1
    fi
  else
    log "ERROR: MariaDB container name conflict. Use --force to remove the existing container(s), or rename/remove manually." "${RED}MariaDB container name conflict. Use --force to remove, or rename/remove manually.${NC}"
    exit 1
  fi
fi

# --- Preflight/Prerequisite Check ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$REPO_ROOT/scripts/utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}

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
WITH_DEPS=false
DOMAIN=""
CLIENT_ID="default"  # Default client ID
ADMIN_EMAIL=""
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(openssl rand -base64 12)}"
WP_VERSION="latest"
PHP_VERSION="8.1"
ENABLE_KEYCLOAK=false
ENFORCE_HTTPS=true
USE_HOST_NETWORK=true
KEYCLOAK_DOMAIN="keycloak.proto001.alpha.nerdofmouth.com"
CONFIGURE_DNS=false

# Source the component_sso_helper.sh if available
if [ -f "${SCRIPT_DIR}/../utils/component_sso_helper.sh" ]; then
  source "${SCRIPT_DIR}/../utils/component_sso_helper.sh"
fi

# --- Enable AgencyStack Standard Error Trap ---
trap_agencystack_errors

# --- Set container and volume names BEFORE any pre-flight logic ---
# (This logic should match the main container naming logic used later)
# --- Ensure DOMAIN_UNDERSCORE and SITE_NAME are initialized BEFORE use ---
DOMAIN="${DOMAIN:-localhost}"
DOMAIN_UNDERSCORE="$(echo "$DOMAIN" | tr '.' '_')"
SITE_NAME="${DOMAIN//./_}"

# --- Set up network name and container names based on CLIENT_ID (must be before any use) ---
if [ -n "$CLIENT_ID" ]; then
  NETWORK_NAME="${CLIENT_ID}_network"
  WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"
  NGINX_CONTAINER_NAME="${CLIENT_ID}_nginx"
  REDIS_CONTAINER_NAME="${CLIENT_ID}_redis"
else
  NETWORK_NAME="default_network"
  WORDPRESS_CONTAINER_NAME="wordpress"
  NGINX_CONTAINER_NAME="nginx"
  REDIS_CONTAINER_NAME="redis"
fi

# --- Ensure Docker Compose file is generated before MariaDB pre-flight ---
log "INFO: Creating WordPress Docker Compose file (early, for pre-flight validation)" "${CYAN}Creating WordPress Docker Compose file (early, for pre-flight validation)...${NC}"
# Ensure parent directory exists for idempotence (fix for install failure)
mkdir -p "${WP_DIR}/${DOMAIN}"
cat > "${WP_DIR}/${DOMAIN}/docker-compose.yml" <<EOL
version: '3'

networks:
  wordpress_network:
    name: default_wordpress_${DOMAIN_UNDERSCORE}_network
  default_network:
    external: true
    name: ${NETWORK_NAME}

services:
  wordpress:
    container_name: ${WORDPRESS_CONTAINER_NAME}
    image: wordpress:php8.2-fpm
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/${DOMAIN}/wordpress:/var/www/html
      - ${WP_DIR}/${DOMAIN}/php/custom.ini:/usr/local/etc/php/conf.d/custom.ini
    environment:
      - WORDPRESS_DB_HOST=mariadb
      - WORDPRESS_DB_USER=${WP_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WP_DB_NAME}
      - WORDPRESS_DEBUG=1
      - WORDPRESS_CONFIG_EXTRA=define('WP_HOME', 'https://${DOMAIN}'); define('WP_SITEURL', 'https://${DOMAIN}');
    networks:
      wordpress_network:
        aliases:
          - wordpress
          - wp
      default_network: {}
    depends_on:
      - mariadb
      - redis
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
      wordpress_network:
        aliases:
          - nginx
          - web
      default_network: {}
    volumes:
      - ${WP_DIR}/${DOMAIN}/wordpress:/var/www/html
      - ${WP_DIR}/${DOMAIN}/nginx/:/etc/nginx/conf.d/
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.wordpress_${SITE_NAME}.entrypoints=websecure"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}.tls.certresolver=myresolver"
      - "traefik.http.services.wordpress_${SITE_NAME}.loadbalancer.server.port=80"
      # HTTP to HTTPS redirect
      - "traefik.http.routers.wordpress_${SITE_NAME}_http.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.wordpress_${SITE_NAME}_http.entrypoints=web"
      - "traefik.http.middlewares.redirect_https.redirectscheme.scheme=https"
      - "traefik.http.middlewares.redirect_https.redirectscheme.permanent=true"
      - "traefik.http.routers.wordpress_${SITE_NAME}_http.middlewares=redirect_https"
  
  mariadb:
    container_name: ${MARIADB_CONTAINER_NAME}
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/${DOMAIN}/mariadb:/var/lib/mysql
      - ${WP_DIR}/${DOMAIN}/mariadb-init/my.cnf:/etc/mysql/my.cnf
      - ${WP_DIR}/${DOMAIN}/mariadb-init/init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      - MYSQL_DATABASE=${WP_DB_NAME}
      - MYSQL_USER=${WP_DB_USER}
      - MYSQL_PASSWORD=${WP_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${WP_ROOT_PASSWORD}
      - MYSQL_ROOT_HOST=%
      - MYSQL_ALLOW_EMPTY_PASSWORD=no
    networks:
      wordpress_network:
        aliases:
          - mariadb
          - db
      default_network: {}
    labels:
      - "traefik.enable=false"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "--password=${WP_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 10
  redis:
    container_name: ${REDIS_CONTAINER_NAME}
    image: redis:alpine
    restart: unless-stopped
    networks:
      wordpress_network:
        aliases:
          - redis
          - cache
      default_network: {}
    labels:
      - "traefik.enable=false"
EOL

if [ ! -f "${WP_DIR}/${DOMAIN}/docker-compose.yml" ]; then
  log "FATAL: Docker Compose file ${WP_DIR}/${DOMAIN}/docker-compose.yml not found. Cannot proceed with MariaDB startup." "${RED}[FATAL] Docker Compose file ${WP_DIR}/${DOMAIN}/docker-compose.yml not found. Cannot proceed with MariaDB startup.${NC}"
  exit 14
fi

# --- BULLETPROOF: Always create/overwrite my.cnf as a file before any Docker logic, even for existing installs ---
log "INFO: Ensuring MariaDB init directory exists" "${CYAN}Ensuring MariaDB init directory exists...${NC}"
mkdir -p "/opt/agency_stack/wordpress/localhost/mariadb-init"
MYCNF_PATH="${WP_DIR}/localhost/mariadb-init/my.cnf"

# --- MariaDB Pre-Flight Setup & Validation ---
log "INFO: Validating MariaDB config and Docker volume state before startup" "${CYAN}Validating MariaDB config and Docker volume state before startup...${NC}"

# Ensure MariaDB config file is a file (not a directory)
if [ -d "$MYCNF_PATH" ]; then
  log "FATAL: $MYCNF_PATH is a directory. Removing to allow file mount." "${RED}[FATAL] $MYCNF_PATH is a directory. Removing to allow file mount.${NC}"
  rm -rf "$MYCNF_PATH"
fi

if [ ! -f "$MYCNF_PATH" ]; then
  log "INFO: Creating MariaDB my.cnf configuration" "${CYAN}Creating MariaDB my.cnf configuration...${NC}"
  cat > "$MYCNF_PATH" <<EOL
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
bind-address=0.0.0.0
max_allowed_packet=128M
EOL
  chown ${AGENCY_USER:-developer}:${AGENCY_GROUP:-developer} "$MYCNF_PATH" 2>/dev/null || true
  chmod 644 "$MYCNF_PATH"
fi

# Check for leftover/failed MariaDB containers and volumes
if docker ps -a --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER_NAME}$"; then
  log "INFO: Removing existing MariaDB container ${MARIADB_CONTAINER_NAME} before startup" "${YELLOW}Removing existing MariaDB container ${MARIADB_CONTAINER_NAME} before startup...${NC}"
  docker rm -f "${MARIADB_CONTAINER_NAME}"
fi
if docker volume ls --format '{{.Name}}' | grep -q "^${MARIADB_CONTAINER_NAME}_data$"; then
  log "INFO: Removing existing MariaDB Docker volume ${MARIADB_CONTAINER_NAME}_data before startup" "${YELLOW}Removing existing MariaDB Docker volume ${MARIADB_CONTAINER_NAME}_data before startup...${NC}"
  docker volume rm "${MARIADB_CONTAINER_NAME}_data"
fi

docker volume prune -f

log "INFO: MariaDB config and Docker environment validated. Proceeding with container startup." "${CYAN}MariaDB config and Docker environment validated. Proceeding with container startup...${NC}"

# --- Remove existing MariaDB container if present (idempotence fix for name conflict) ---
if docker ps -a --format '{{.Names}}' | grep -q '^default_mariadb$'; then
  log "INFO: Removing existing MariaDB container (default_mariadb) to prevent name conflict" "${CYAN}Removing existing MariaDB container (default_mariadb)...${NC}"
  docker rm -f default_mariadb
  # Wait for container removal to complete before proceeding
  MAX_WAIT=10
  WAITED=0
  while docker ps -a --format '{{.Names}}' | grep -q '^default_mariadb$'; do
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
      log "ERROR: MariaDB container still exists after $MAX_WAIT seconds. Aborting." "${RED}MariaDB container still exists after $MAX_WAIT seconds. Aborting.${NC}"
      exit 1
    fi
    log "INFO: Waiting for Docker to fully remove default_mariadb container..." "${YELLOW}Waiting for Docker to fully remove default_mariadb container...${NC}"
    sleep 1
    WAITED=$((WAITED+1))
  done
  # Check for dead/zombie containers with same name and force remove
  if docker ps -a --filter "status=dead" --format '{{.Names}}' | grep -q '^default_mariadb$'; then
    log "INFO: Forcibly removing dead MariaDB container (default_mariadb) after normal removal" "${YELLOW}Forcibly removing dead MariaDB container (default_mariadb)...${NC}"
    docker rm -f default_mariadb
  fi
  log "INFO: Docker ps -a after MariaDB removal:" "$(docker ps -a)"
fi
# Log Docker state after removal for diagnostics
log "INFO: Docker ps -a after MariaDB removal:" "$(docker ps -a)"

# --- MariaDB port pre-check (fail-safe) ---
MARIADB_PORT=3306
if ss -ltn | grep -q ":$MARIADB_PORT "; then
  log "ERROR: Port $MARIADB_PORT is already in use. MariaDB cannot start." "${RED}Port $MARIADB_PORT is already in use. MariaDB cannot start.${NC}"
  ss -ltn | grep ":$MARIADB_PORT " || true
  exit 1
else
  log "INFO: MariaDB port $MARIADB_PORT is available."
fi

# --- Docker network state pre-startup (debug) ---
log "INFO: Docker network state before MariaDB startup" "${CYAN}Docker network state before MariaDB startup...${NC}"
docker network ls || true
if docker network inspect wordpress_network &>/dev/null; then
  docker network inspect wordpress_network || true
fi

# --- Ensure MariaDB Docker volume exists for data persistence ---
MARIADB_VOLUME="default_mariadb_data"
if ! docker volume ls --format '{{.Name}}' | grep -q "^$MARIADB_VOLUME$"; then
  log "INFO: Creating Docker volume $MARIADB_VOLUME for MariaDB data persistence" "${CYAN}Creating Docker volume $MARIADB_VOLUME for MariaDB data persistence...${NC}"
  docker volume create $MARIADB_VOLUME
fi

# --- Ensure the external Docker network exists before running Docker Compose ---
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  log "INFO: Creating external Docker network '${NETWORK_NAME}'" "${CYAN}Creating external Docker network '${NETWORK_NAME}'...${NC}"
  docker network create "${NETWORK_NAME}"
fi

# --- Bulletproof cleanup and diagnostics for nginx config directory ---
log "INFO: Sanity checking ${WP_DIR}/${DOMAIN}/nginx/ before creation" "${CYAN}Sanity checking ${WP_DIR}/${DOMAIN}/nginx/ before creation...${NC}"
NGINX_CONF_DIR="${WP_DIR}/${DOMAIN}/nginx"
DEFAULT_CONF="${NGINX_CONF_DIR}/default.conf"

# CRITICAL WSL2/Docker Fix: Ensure both parent directory AND config file are clean
# First make sure the parent directory exists
mkdir -p "${NGINX_CONF_DIR}"

# Then remove any existing default.conf, whether it's a file, directory, or symlink
if [ -e "${DEFAULT_CONF}" ]; then
  log "WARNING: ${DEFAULT_CONF} exists. Removing it completely." "${YELLOW}${DEFAULT_CONF} exists. Removing it completely.${NC}"
  rm -rf "${DEFAULT_CONF}"
fi

# Create a new default.conf with proper permissions
log "INFO: Creating fresh nginx default.conf file" "${CYAN}Creating fresh nginx default.conf file...${NC}"
cat > "${DEFAULT_CONF}" <<'EOL'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Docker-compatible PHP configuration that doesn't rely on snippets
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }

    # Deny access to WordPress files that don't need to be accessed via web
    location ~ /\. {
        deny all;
    }
    location ~* /(?:uploads|files)/.*.php$ {
        deny all;
    }

    error_log  /var/log/nginx/error.log warn;
    access_log /var/log/nginx/access.log;
}
EOL

# Ensure proper ownership and permissions
chmod 644 "${DEFAULT_CONF}"
chown "$(id -u):$(id -g)" "${DEFAULT_CONF}" 2>/dev/null || true

# Triple-check that default.conf is a file, not a directory
if [ ! -f "${DEFAULT_CONF}" ]; then
  log "ERROR: ${DEFAULT_CONF} is not a regular file after creation. Aborting." "${RED}${DEFAULT_CONF} is not a regular file after creation. Aborting.${NC}"
  ls -la "${NGINX_CONF_DIR}"
  file "${DEFAULT_CONF}" 2>/dev/null || echo "Cannot determine file type"
  exit 1
fi

# WSL2/Docker volume mount verification 
log "INFO: Verified nginx config is a proper file (critical for Docker mounts)" "${GREEN}✅ Verified nginx config is a proper file (critical for Docker mounts)${NC}"
ls -l "${DEFAULT_CONF}"

# --- Start WordPress stack
log "INFO: Starting WordPress stack with Docker Compose" "${CYAN}Starting WordPress stack with Docker Compose...${NC}"
cd "${WP_DIR}/${DOMAIN}"
docker-compose -f "${WP_DIR}/${DOMAIN}/docker-compose.yml" up -d
log "INFO: Docker Compose up completed" "${GREEN}Docker Compose up completed.${NC}"
cd - > /dev/null

# Wait for WordPress stack to initialize
log "INFO: Waiting for WordPress to start" "${CYAN}Waiting for WordPress to start...${NC}"
sleep 15

# Add network diagnostics to help troubleshoot connectivity issues
log "INFO: Running network diagnostics" "${CYAN}Running network diagnostics...${NC}"
docker network inspect default_wordpress_${DOMAIN_UNDERSCORE}_network
echo "Testing connectivity between containers:"
# Install ping utility for network diagnostics
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "apt-get update && apt-get install -y iputils-ping" || log "WARNING: Unable to install ping utilities" "${YELLOW}⚠️ Unable to install ping utilities${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} ping -c 2 ${MARIADB_CONTAINER_NAME} || log "WARNING: Ping failed between WordPress and MariaDB" "${YELLOW}⚠️ Ping failed between WordPress and MariaDB${NC}"

# Install MySQL client for diagnostics
log "INFO: Installing MySQL client for diagnostics" "${CYAN}Installing MySQL client for diagnostics...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "apt-get update && apt-get install -y default-mysql-client" || log "WARNING: Unable to install MySQL client" "${YELLOW}⚠️ Unable to install MySQL client${NC}"

# Create script to install WordPress properly
log "INFO: Creating WordPress installation scripts" "${CYAN}Creating WordPress installation scripts...${NC}"
mkdir -p "${WP_DIR}/${DOMAIN}/scripts"

# Default values for Keycloak integration
KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-"client_secret"}
KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL:-"https://${DOMAIN}/auth/realms/agency-stack"}

# Create the OpenID Connect configuration directly in the container script
cat > "${WP_DIR}/${DOMAIN}/scripts/install_wp.sh" <<EOL
#!/bin/bash
# WordPress Installation Script
# Generated by AgencyStack installation script
set -e

# Set default values for variables to prevent unbound variable errors
CLIENT_ID="${CLIENT_ID:-default}"
KEYCLOAK_CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET:-client_secret}" 
KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-https://${DOMAIN}/realms/agency-stack}"
ENABLE_KEYCLOAK="${ENABLE_KEYCLOAK:-false}"

cd /var/www/html

# Install WP-CLI first
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
wp --info

# Install WordPress core
echo "Installing WordPress core..."
wp --allow-root core install --url="https://${DOMAIN}" --title="WordPress on AgencyStack" --admin_user="${WP_ADMIN_USER}" --admin_password="${ADMIN_PASSWORD}" --admin_email="${ADMIN_EMAIL}" --skip-email

# Install essential plugins
echo "Installing essential plugins..."
wp --allow-root plugin install redis-cache wordfence sucuri-scanner wordpress-seo duplicate-post --activate

# Basic WordPress configuration
echo "Configuring WordPress..."
wp --allow-root option update blogname "WordPress on AgencyStack"
wp --allow-root option update blogdescription "Powered by AgencyStack"
wp --allow-root rewrite structure "/%postname%/"
wp --allow-root rewrite flush

if [ "\${ENABLE_KEYCLOAK}" = "true" ]; then
  echo "Installing Keycloak integration..."
  # Install the OpenID Connect Generic plugin directly from GitHub
  cd /tmp
  curl -L -O https://github.com/daggerhart/openid-connect-generic/archive/refs/heads/master.zip
  cd /var/www/html
  wp --allow-root plugin install /tmp/master.zip --activate
  rm /tmp/master.zip
  
  # Configure Keycloak OpenID Connect
  echo "Configuring OpenID Connect..."
  
  # Create JSON configuration
  OC_CONFIG='{
    "login_type": "auto",
    "client_id": "wordpress-'"${CLIENT_ID}"'",
    "client_secret": "'"${KEYCLOAK_CLIENT_SECRET}"'",
    "scope": "openid email profile",
    "endpoint_login": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/auth",
    "endpoint_userinfo": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/userinfo",
    "endpoint_token": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/token",
    "endpoint_end_session": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/logout",
    "identity_key": "preferred_username",
    "no_sslverify": 1,
    "http_request_timeout": 5,
    "redirect_user_back": 1,
    "redirect_on_logout": 1,
    "link_existing_users": 1,
    "create_if_does_not_exist": 1,
    "enforce_privacy": 0,
    "nickname_key": "nickname",
    "email_format": "{email}",
    "displayname_format": "{given_name} {family_name}",
    "identify_with_username": true,
    "state_time_limit": 180,
    "token_refresh_enable": 1,
    "nickname_format": "{preferred_username}",
    "support_state": 1
  }'
  
  # Update OpenID Connect configuration
  wp --allow-root option update openid_connect_generic_settings "\$OC_CONFIG"
fi

echo "WordPress installation complete."
EOL

# Make the script executable
chmod +x "${WP_DIR}/${DOMAIN}/scripts/install_wp.sh"

# Copy the script to the WordPress container
log "INFO: Copying installation scripts to WordPress container" "${CYAN}Copying installation scripts to WordPress container...${NC}"
docker cp "${WP_DIR}/${DOMAIN}/scripts/install_wp.sh" ${WORDPRESS_CONTAINER_NAME}:/tmp/install_wp.sh || log "WARNING: Failed to copy installation script" "${YELLOW}⚠️ Failed to copy installation script${NC}"

# Execute the WordPress installation script
log "INFO: Running WordPress installation script" "${CYAN}Running WordPress installation script...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "chmod +x /tmp/install_wp.sh && /tmp/install_wp.sh" || log "WARNING: WordPress installation script failed" "${YELLOW}⚠️ WordPress installation script failed${NC}"

# Check if WordPress database tables exist and install if needed
log "INFO: Ensuring database schema is initialized" "${CYAN}Ensuring database schema is initialized...${NC}"
  
# Test database connection
echo "=========================================="
echo "DATABASE CONNECTION TEST"
echo "Target: mariadb"
echo "User: ${WP_DB_USER}"
echo "Database: ${WP_DB_NAME}"
echo "=========================================="
  
if docker exec "${MARIADB_CONTAINER_NAME}" mysql -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" -e "SELECT 1" "${WP_DB_NAME}" > /dev/null 2>&1; then
  echo "SUCCESS: Connected to database"
else
  log "ERROR: Failed to connect to database" "${RED}❌ Failed to connect to database${NC}"
  exit 1
fi
  
# Create database backup if exists
log "INFO: Creating database backup" "${CYAN}Creating WordPress database backup (if database exists)...${NC}"
BACKUP_DIR="${WP_DIR}/${DOMAIN}/mariadb"
mkdir -p "${BACKUP_DIR}"
BACKUP_FILE="${BACKUP_DIR}/backup_$(date +%Y%m%d%H%M%S).sql"
docker exec "${MARIADB_CONTAINER_NAME}" mysqldump -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" "${WP_DB_NAME}" > "${BACKUP_FILE}" 2>/dev/null || true
  
# Check if wp_posts table exists
if ! docker exec "${MARIADB_CONTAINER_NAME}" mysql -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" -e "SHOW TABLES LIKE 'wp_posts'" "${WP_DB_NAME}" | grep -q "wp_posts"; then
  log "INFO: WordPress tables not found, initializing database" "${CYAN}WordPress tables not found, initializing database...${NC}"
  
  # Reset database to ensure a clean state
  docker exec -u www-data "${WORDPRESS_CONTAINER_NAME}" wp db reset --yes
  
  # Directly initialize WordPress database
  docker exec -u www-data "${WORDPRESS_CONTAINER_NAME}" bash -c "
    # Initialize WordPress database directly
    cd /var/www/html
    wp core install \
      --url=\"https://${DOMAIN}\" \
      --title=\"WordPress on AgencyStack\" \
      --admin_user=\"admin\" \
      --admin_password=\"${ADMIN_PASSWORD}\" \
      --admin_email=\"${ADMIN_EMAIL}\" \
      --skip-email
  "
      
  # Verify tables were created
  if docker exec "${MARIADB_CONTAINER_NAME}" mysql -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" -e "SHOW TABLES LIKE 'wp_posts'" "${WP_DB_NAME}" | grep -q "wp_posts"; then
    log "INFO: Database schema initialized successfully" "${GREEN}✅ WordPress database tables created successfully${NC}"
  else
    log "ERROR: Failed to initialize WordPress database schema" "${RED}❌ Failed to initialize WordPress database schema${NC}"
    exit 1
  fi
else
  log "INFO: WordPress database schema already initialized" "${GREEN}✅ WordPress database schema already initialized${NC}"
fi

# Verify WordPress installation
log "INFO: Verifying WordPress installation" "${CYAN}Verifying WordPress installation...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "wp --allow-root core verify-checksums" || log "WARNING: WordPress core verification failed" "${YELLOW}⚠️ WordPress core verification failed${NC}"

# Set a few basic configurations
log "INFO: Configuring WordPress" "${CYAN}Configuring WordPress...${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "wp --allow-root option update blogname 'WordPress on AgencyStack'" || log "WARNING: Failed to update blog name" "${YELLOW}⚠️ Failed to update blog name${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "wp --allow-root option update blogdescription 'Powered by AgencyStack'" || log "WARNING: Failed to update blog description" "${YELLOW}⚠️ Failed to update blog description${NC}"
docker exec ${WORDPRESS_CONTAINER_NAME} bash -c "wp --allow-root rewrite structure '/%postname%/'" || log "WARNING: Failed to update permalink structure" "${YELLOW}⚠️ Failed to update permalink structure${NC}"

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
WP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
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
    if enable_component_sso "wordpress" "${DOMAIN}" "${WP_REDIRECT_URIS}" "wordpress" "agency_stack" "${KEYCLOAK_DOMAIN}"; then
      log "INFO: Successfully registered WordPress with Keycloak" "${GREEN}Successfully registered WordPress with Keycloak${NC}"
      
      # Create SSO configuration directory
      mkdir -p "${WP_DIR}/${DOMAIN}/sso"
      
      # Install and configure the OpenID Connect plugin
      log "INFO: Installing OpenID Connect plugin for WordPress" "${CYAN}Installing OpenID Connect plugin for WordPress...${NC}"
      docker exec -w /var/www/html ${WORDPRESS_CONTAINER_NAME} bash -c "cd /tmp && curl -L -O https://github.com/daggerhart/openid-connect-generic/archive/refs/heads/master.zip && cd /var/www/html && wp --allow-root plugin install /tmp/master.zip --activate && rm /tmp/master.zip" || log "WARNING: Failed to install OpenID Connect plugin" "${YELLOW}⚠️ Failed to install OpenID Connect plugin${NC}"
      
      # Configure OpenID Connect plugin
      log "INFO: Configuring OpenID Connect plugin" "${CYAN}Configuring OpenID Connect plugin...${NC}"
      KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL:-"https://${KEYCLOAK_DOMAIN}/realms/agency-stack"}
      KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-"client_secret"}
      
      # Prepare Keycloak configuration with proper escaping
      OC_CONFIG='{
        "login_type": "auto",
        "client_id": "wordpress-'"${CLIENT_ID}"'",
        "client_secret": "'"${KEYCLOAK_CLIENT_SECRET}"'",
        "scope": "openid email profile",
        "endpoint_login": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/auth",
        "endpoint_userinfo": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/userinfo",
        "endpoint_token": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/token",
        "endpoint_end_session": "'"${KEYCLOAK_BASE_URL}"'/protocol/openid-connect/logout",
        "identity_key": "preferred_username",
        "no_sslverify": 1,
        "http_request_timeout": 5,
        "redirect_user_back": 1,
        "redirect_on_logout": 1,
        "link_existing_users": 1,
        "create_if_does_not_exist": 1,
        "enforce_privacy": 0,
        "nickname_key": "nickname",
        "email_format": "{email}",
        "displayname_format": "{given_name} {family_name}",
        "identify_with_username": true,
        "state_time_limit": 180,
        "token_refresh_enable": 1,
        "nickname_format": "{preferred_username}",
        "support_state": 1
      }'
      
      # Update OpenID Connect configuration
      KEYCLOAK_CLIENT_ID=$(jq -r '.client_id' "$SSO_CREDENTIALS_FILE")
      KEYCLOAK_CLIENT_SECRET=$(jq -r '.client_secret' "$SSO_CREDENTIALS_FILE")

      # Configure OpenID Connect plugin with correct settings
      docker exec -u www-data "${WORDPRESS_CONTAINER_NAME}" wp option set openid_connect_generic_settings --format=json '{
        "login_type": "auto",
        "client_id": "'${KEYCLOAK_CLIENT_ID}'",
        "client_secret": "'${KEYCLOAK_CLIENT_SECRET}'",
        "scope": "openid email profile",
        "endpoint_login": "https://'${KEYCLOAK_DOMAIN}'/realms/agency_stack/protocol/openid-connect/auth",
        "endpoint_userinfo": "https://'${KEYCLOAK_DOMAIN}'/realms/agency_stack/protocol/openid-connect/userinfo",
        "endpoint_token": "https://'${KEYCLOAK_DOMAIN}'/realms/agency_stack/protocol/openid-connect/token",
        "endpoint_end_session": "https://'${KEYCLOAK_DOMAIN}'/realms/agency_stack/protocol/openid-connect/logout",
        "identity_key": "preferred_username",
        "no_sslverify": 1,
        "http_request_timeout": 5,
        "redirect_user_back": 1,
        "redirect_on_logout": 1,
        "link_existing_users": 1,
        "create_if_does_not_exist": 1,
        "enforce_privacy": 0,
        "nickname_key": "nickname",
        "email_format": "{email}",
        "displayname_format": "{given_name} {family_name}",
        "identify_with_username": true,
        "state_time_limit": 180,
        "token_refresh_enable": 1,
        "nickname_format": "{preferred_username}",
        "support_state": 1
      }'

      # Add login button to the login page
      docker exec -u www-data "${WORDPRESS_CONTAINER_NAME}" wp option add openid-connect-generic-login-button-text "Login with Keycloak SSO" --autoload=yes
      
      # Create a marker file for the SSO configuration
      touch "${WP_DIR}/${DOMAIN}/sso/.sso_configured"
      
      log "INFO: SSO integration completed for WordPress" "${GREEN}SSO integration completed for WordPress${NC}"
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
    --update-component "wordpress"
    --update-flag "installed" --update-value "true"
    --update-flag "monitoring" --update-value "true"
    --update-flag "traefik_tls" --update-value "true"
  )
  
  if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
    REGISTRY_ARGS+=(
      --update-flag "sso" --update-value "true"
      --update-flag "sso_configured" --update-value "true"
    )
  fi
  
  bash "${ROOT_DIR}/scripts/utils/update_component_registry.sh" "${REGISTRY_ARGS[@]}"
fi

log "SUCCESS: WordPress installation completed!" "${GREEN}✅ WordPress installation completed!${NC}"
echo -e "\n${CYAN}WordPress should now be accessible at: https://${DOMAIN}/\nAdmin user: ${WP_ADMIN_USER}\nAdmin password: (see secrets in ${WP_DIR}/${DOMAIN}/)\n${NC}"
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  echo -e "${CYAN}Keycloak SSO is enabled. Configure your IdP as needed.${NC}"
fi
exit 0
