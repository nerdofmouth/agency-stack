#!/bin/bash
# install_wordpress.sh - Install WordPress with AgencyStack integration
# https://stack.nerdofmouth.com

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
WORDPRESS_DIR="/opt/agency_stack/wordpress"
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/install_wordpress-$(date +%Y%m%d-%H%M%S).log"

# Default configuration
WORDPRESS_DOMAIN="wordpress.${PRIMARY_DOMAIN}"
WORDPRESS_DB_HOST="db"
WORDPRESS_DB_NAME="wordpress"
WORDPRESS_DB_USER="wordpress"
WORDPRESS_DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
WORDPRESS_ADMIN_USER="admin"
WORDPRESS_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
WORDPRESS_ADMIN_EMAIL="admin@${PRIMARY_DOMAIN}"
WORDPRESS_SITE_TITLE="AgencyStack WordPress"
WORDPRESS_PORT="8020"
WORDPRESS_REDIS_ENABLED="false"
WORDPRESS_PLUGINS_ENABLED="true"
WORDPRESS_CLI_ENABLED="true"
WORDPRESS_DEBUG="false"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    --domain=*)
      WORDPRESS_DOMAIN="${arg#*=}"
      ;;
    --db-name=*)
      WORDPRESS_DB_NAME="${arg#*=}"
      ;;
    --db-user=*)
      WORDPRESS_DB_USER="${arg#*=}"
      ;;
    --db-password=*)
      WORDPRESS_DB_PASSWORD="${arg#*=}"
      ;;
    --admin-user=*)
      WORDPRESS_ADMIN_USER="${arg#*=}"
      ;;
    --admin-password=*)
      WORDPRESS_ADMIN_PASSWORD="${arg#*=}"
      ;;
    --admin-email=*)
      WORDPRESS_ADMIN_EMAIL="${arg#*=}"
      ;;
    --site-title=*)
      WORDPRESS_SITE_TITLE="${arg#*=}"
      ;;
    --port=*)
      WORDPRESS_PORT="${arg#*=}"
      ;;
    --redis=*)
      WORDPRESS_REDIS_ENABLED="${arg#*=}"
      ;;
    --plugins=*)
      WORDPRESS_PLUGINS_ENABLED="${arg#*=}"
      ;;
    --cli=*)
      WORDPRESS_CLI_ENABLED="${arg#*=}"
      ;;
    --debug=*)
      WORDPRESS_DEBUG="${arg#*=}"
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🔌 WordPress Installation${NC}"
log "=============================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  # If PRIMARY_DOMAIN is set in config.env, update the WordPress domain
  if [ -n "$PRIMARY_DOMAIN" ] && [ "$WORDPRESS_DOMAIN" = "wordpress.${PRIMARY_DOMAIN}" ]; then
    WORDPRESS_DOMAIN="wordpress.${PRIMARY_DOMAIN}"
  fi
else
  log "${YELLOW}Warning: config.env not found. Using default values.${NC}"
  
  # Ask for PRIMARY_DOMAIN if not in auto mode
  if [ "$AUTO_MODE" = false ]; then
    read -p "Enter your primary domain (e.g., example.com): " PRIMARY_DOMAIN
    WORDPRESS_DOMAIN="wordpress.${PRIMARY_DOMAIN}"
    WORDPRESS_ADMIN_EMAIL="admin@${PRIMARY_DOMAIN}"
  else
    log "${RED}Error: config.env not found and running in auto mode.${NC}"
    log "Please create config.env with PRIMARY_DOMAIN set."
    exit 1
  fi
fi

# Display configuration
log "${BLUE}WordPress Configuration:${NC}"
log "Domain: ${WORDPRESS_DOMAIN}"
log "Database Name: ${WORDPRESS_DB_NAME}"
log "Database User: ${WORDPRESS_DB_USER}"
log "Admin User: ${WORDPRESS_ADMIN_USER}"
log "Admin Email: ${WORDPRESS_ADMIN_EMAIL}"
log "Site Title: ${WORDPRESS_SITE_TITLE}"
log "Port: ${WORDPRESS_PORT}"
log "Redis Enabled: ${WORDPRESS_REDIS_ENABLED}"
log "Plugins Enabled: ${WORDPRESS_PLUGINS_ENABLED}"
log "WP-CLI Enabled: ${WORDPRESS_CLI_ENABLED}"
log "Debug Mode: ${WORDPRESS_DEBUG}"
log ""

# Ask for confirmation if not in auto mode
if [ "$AUTO_MODE" = false ]; then
  read -p "Continue with installation? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    log "${YELLOW}Installation cancelled${NC}"
    exit 0
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "${RED}Error: Docker is not installed${NC}"
  log "Please install Docker first: https://docs.docker.com/get-docker/"
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "${RED}Error: Docker Compose is not installed${NC}"
  log "Please install Docker Compose first: https://docs.docker.com/compose/install/"
  exit 1
fi

# Check if Traefik is installed
if ! grep -q "Traefik" /opt/agency_stack/installed_components.txt 2>/dev/null; then
  log "${YELLOW}Warning: Traefik is not installed${NC}"
  log "Consider installing Traefik for proper SSL and routing"
  
  # Fallback to direct port exposure if Traefik is not found
  TRAEFIK_NETWORK_EXISTS=false
else
  # Check if traefik-public network exists
  if docker network ls | grep -q "traefik-public"; then
    TRAEFIK_NETWORK_EXISTS=true
  else
    log "${YELLOW}Warning: traefik-public network not found${NC}"
    log "Creating traefik-public network..."
    docker network create traefik-public
    TRAEFIK_NETWORK_EXISTS=true
  fi
fi

# Create WordPress directory
log "${BLUE}Creating WordPress directory...${NC}"
mkdir -p "$WORDPRESS_DIR"
mkdir -p "${WORDPRESS_DIR}/wp-content"
mkdir -p "${WORDPRESS_DIR}/db-data"

# Create docker-compose.yml
log "${BLUE}Creating docker-compose.yml...${NC}"
cat > "${WORDPRESS_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  wordpress:
    image: wordpress:latest
    container_name: agency_stack_wordpress
    restart: unless-stopped
    depends_on:
      - db
    environment:
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}
      - WORDPRESS_DEBUG=${WORDPRESS_DEBUG}
EOL

# Add Redis configuration if enabled
if [ "$WORDPRESS_REDIS_ENABLED" = "true" ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
      - WORDPRESS_CONFIG_EXTRA=define('WP_REDIS_HOST', 'redis');define('WP_REDIS_PORT', '6379');define('WP_CACHE', true);
EOL
fi

# Continue with docker-compose.yml
cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
    volumes:
      - ./wp-content:/var/www/html/wp-content
    ports:
      - "${WORDPRESS_PORT}:80"
EOL

# Add Traefik labels if Traefik is available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
    labels:
      - traefik.enable=true
      - traefik.http.routers.wordpress.rule=Host(\`${WORDPRESS_DOMAIN}\`)
      - traefik.http.routers.wordpress.entrypoints=websecure
      - traefik.http.routers.wordpress.tls=true
      - traefik.http.routers.wordpress.tls.certresolver=letsencrypt
      - traefik.http.services.wordpress.loadbalancer.server.port=80
EOL
fi

# Continue with services
cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
    networks:
      - wordpress
EOL

# Add Traefik network if available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
      - traefik-public
EOL
fi

# Database service
cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL

  db:
    image: mysql:5.7
    container_name: agency_stack_wordpress_db
    restart: unless-stopped
    environment:
      - MYSQL_DATABASE=${WORDPRESS_DB_NAME}
      - MYSQL_USER=${WORDPRESS_DB_USER}
      - MYSQL_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${WORDPRESS_DB_PASSWORD}
    volumes:
      - ./db-data:/var/lib/mysql
    networks:
      - wordpress
EOL

# Add WP-CLI service if enabled
if [ "$WORDPRESS_CLI_ENABLED" = "true" ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL

  wpcli:
    image: wordpress:cli
    container_name: agency_stack_wordpress_cli
    depends_on:
      - wordpress
      - db
    environment:
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./wp-cli.yml:/var/www/html/wp-cli.yml
    networks:
      - wordpress
    user: xfs
EOL
fi

# Add Redis service if enabled
if [ "$WORDPRESS_REDIS_ENABLED" = "true" ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL

  redis:
    image: redis:alpine
    container_name: agency_stack_wordpress_redis
    restart: unless-stopped
    networks:
      - wordpress
EOL
fi

# Add networks
cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL

networks:
  wordpress:
    driver: bridge
EOL

# Add Traefik network if available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${WORDPRESS_DIR}/docker-compose.yml" << EOL
  traefik-public:
    external: true
EOL
fi

# Create WP-CLI configuration if enabled
if [ "$WORDPRESS_CLI_ENABLED" = "true" ]; then
  log "${BLUE}Creating WP-CLI configuration...${NC}"
  cat > "${WORDPRESS_DIR}/wp-cli.yml" << EOL
path: /var/www/html
url: https://${WORDPRESS_DOMAIN}
EOL

  # Create helper script for WP-CLI
  cat > "${WORDPRESS_DIR}/wp.sh" << EOL
#!/bin/bash
# Helper script for WP-CLI

docker-compose -f "${WORDPRESS_DIR}/docker-compose.yml" run --rm wpcli "\$@"
EOL

  chmod +x "${WORDPRESS_DIR}/wp.sh"
fi

# Create initialization script
log "${BLUE}Creating initialization script...${NC}"
cat > "${WORDPRESS_DIR}/init-wordpress.sh" << EOL
#!/bin/bash
# Initialize WordPress with admin user and plugins

# Wait for WordPress to be ready
echo "Waiting for WordPress to be ready..."
until curl -s http://wordpress/wp-admin/ > /dev/null; do
  sleep 5
done

cd /var/www/html

# Check if WordPress is already installed
if ! wp core is-installed; then
  echo "Installing WordPress..."
  wp core install --url="https://${WORDPRESS_DOMAIN}" --title="${WORDPRESS_SITE_TITLE}" --admin_user="${WORDPRESS_ADMIN_USER}" --admin_password="${WORDPRESS_ADMIN_PASSWORD}" --admin_email="${WORDPRESS_ADMIN_EMAIL}"
  
  echo "Updating permalinks..."
  wp rewrite structure '/%postname%/'
  wp rewrite flush
  
  echo "Removing sample content..."
  wp post delete 1 --force
  wp post delete 2 --force
  
  # Install and activate useful plugins
  if [ "${WORDPRESS_PLUGINS_ENABLED}" = "true" ]; then
    echo "Installing plugins..."
    
    # Essential plugins
    wp plugin install wordpress-seo --activate
    wp plugin install wp-mail-smtp --activate
    wp plugin install wordfence --activate
    
    # Performance plugins
    wp plugin install autoptimize --activate
    
    # Redis cache plugin if Redis is enabled
    if [ "${WORDPRESS_REDIS_ENABLED}" = "true" ]; then
      wp plugin install redis-cache --activate
      wp redis enable
    fi
    
    # Headless/API plugins for integration
    wp plugin install wp-graphql --activate
    wp plugin install wp-rest-api-v2-menus --activate
    
    # Builder.io integration plugin
    wp plugin install custom-post-type-ui --activate
  fi
  
  echo "WordPress installation complete!"
  echo "Admin URL: https://${WORDPRESS_DOMAIN}/wp-admin/"
  echo "Username: ${WORDPRESS_ADMIN_USER}"
  echo "Password: ${WORDPRESS_ADMIN_PASSWORD}"
else
  echo "WordPress is already installed"
fi
EOL

chmod +x "${WORDPRESS_DIR}/init-wordpress.sh"

# Start containers
log "${BLUE}Starting WordPress containers...${NC}"
cd "$WORDPRESS_DIR"
docker-compose up -d

# Wait for the containers to be ready
log "${BLUE}Waiting for containers to start...${NC}"
sleep 10

# Initialize WordPress if WP-CLI is enabled
if [ "$WORDPRESS_CLI_ENABLED" = "true" ]; then
  log "${BLUE}Initializing WordPress...${NC}"
  docker-compose run --rm wpcli bash /var/www/html/init-wordpress.sh
fi

# Check if WordPress container is running
if docker ps | grep -q "agency_stack_wordpress"; then
  log "${GREEN}✅ WordPress container started successfully${NC}"
  
  # Add to installed components
  echo "WordPress" >> /opt/agency_stack/installed_components.txt
  
  # Update config.env
  if ! grep -q "WORDPRESS_DOMAIN" "$CONFIG_ENV"; then
    echo -e "\n# WordPress Configuration" >> "$CONFIG_ENV"
    echo "WORDPRESS_DOMAIN=${WORDPRESS_DOMAIN}" >> "$CONFIG_ENV"
    echo "WORDPRESS_ADMIN_USER=${WORDPRESS_ADMIN_USER}" >> "$CONFIG_ENV"
    echo "WORDPRESS_ADMIN_PASSWORD=${WORDPRESS_ADMIN_PASSWORD}" >> "$CONFIG_ENV"
    echo "WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}" >> "$CONFIG_ENV"
    echo "WORDPRESS_DB_USER=${WORDPRESS_DB_USER}" >> "$CONFIG_ENV"
    echo "WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}" >> "$CONFIG_ENV"
  fi
  
  # Display access information
  log "${GREEN}✅ WordPress has been successfully installed!${NC}"
  log "${CYAN}WordPress site URL: https://${WORDPRESS_DOMAIN}${NC}"
  log "${CYAN}WordPress admin URL: https://${WORDPRESS_DOMAIN}/wp-admin/${NC}"
  log "${CYAN}Admin username: ${WORDPRESS_ADMIN_USER}${NC}"
  log "${CYAN}Admin password: ${WORDPRESS_ADMIN_PASSWORD}${NC}"
  log ""
  log "${YELLOW}Please save these credentials in a secure location${NC}"
  
  # If Traefik is not available, show direct port
  if [ "$TRAEFIK_NETWORK_EXISTS" = false ]; then
    log "${YELLOW}Note: Traefik is not installed${NC}"
    log "${YELLOW}WordPress is accessible at: http://$(hostname -I | awk '{print $1}'):${WORDPRESS_PORT}${NC}"
  fi
  
  # Additional notes
  log ""
  log "${BLUE}Additional Information:${NC}"
  log "- WordPress files are stored in: ${WORDPRESS_DIR}/wp-content"
  log "- Database files are stored in: ${WORDPRESS_DIR}/db-data"
  
  if [ "$WORDPRESS_CLI_ENABLED" = "true" ]; then
    log "- WP-CLI is available via: ${WORDPRESS_DIR}/wp.sh"
    log "  Example: ${WORDPRESS_DIR}/wp.sh plugin list"
  fi
  
  # Next steps
  log ""
  log "${BLUE}Next Steps:${NC}"
  log "1. Configure your DNS to point ${WORDPRESS_DOMAIN} to this server"
  log "2. Secure your WordPress installation (use Wordfence plugin)"
  log "3. Install additional plugins as needed"
  
  # For integration with Next.js
  log ""
  log "${BLUE}Integrating with Next.js:${NC}"
  log "For headless WordPress with Next.js, use the installed WP GraphQL plugin"
  log "GraphQL endpoint: https://${WORDPRESS_DOMAIN}/graphql"
  log "REST API endpoint: https://${WORDPRESS_DOMAIN}/wp-json/wp/v2"
  
  exit 0
else
  log "${RED}❌ Failed to start WordPress container${NC}"
  log "Please check the logs: docker logs agency_stack_wordpress"
  exit 1
fi
