#!/bin/bash
# install_erpnext.sh - Install ERPNext (Frappe) with AgencyStack integration
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
ERPNEXT_DIR="/opt/agency_stack/erpnext"
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/install_erpnext-$(date +%Y%m%d-%H%M%S).log"

# Default configuration
ERPNEXT_DOMAIN="erp.${PRIMARY_DOMAIN}"
ERPNEXT_VERSION="v14"
ERPNEXT_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
ERPNEXT_MARIADB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
ERPNEXT_SITE_NAME="erp.${PRIMARY_DOMAIN}"
ERPNEXT_DEVELOPER_MODE="false"
ERPNEXT_HTTP_PORT="8000"
ERPNEXT_HTTPS_PORT="8443"
ERPNEXT_SETUP_MULTISITE="false"

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
      ERPNEXT_DOMAIN="${arg#*=}"
      ;;
    --version=*)
      ERPNEXT_VERSION="${arg#*=}"
      ;;
    --admin-password=*)
      ERPNEXT_ADMIN_PASSWORD="${arg#*=}"
      ;;
    --mariadb-password=*)
      ERPNEXT_MARIADB_PASSWORD="${arg#*=}"
      ;;
    --site-name=*)
      ERPNEXT_SITE_NAME="${arg#*=}"
      ;;
    --developer-mode=*)
      ERPNEXT_DEVELOPER_MODE="${arg#*=}"
      ;;
    --http-port=*)
      ERPNEXT_HTTP_PORT="${arg#*=}"
      ;;
    --https-port=*)
      ERPNEXT_HTTPS_PORT="${arg#*=}"
      ;;
    --multisite=*)
      ERPNEXT_SETUP_MULTISITE="${arg#*=}"
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

log "${MAGENTA}${BOLD}🏢 ERPNext Installation${NC}"
log "=============================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  # If PRIMARY_DOMAIN is set in config.env, update the ERPNext domain
  if [ -n "$PRIMARY_DOMAIN" ] && [ "$ERPNEXT_DOMAIN" = "erp.${PRIMARY_DOMAIN}" ]; then
    ERPNEXT_DOMAIN="erp.${PRIMARY_DOMAIN}"
    ERPNEXT_SITE_NAME="erp.${PRIMARY_DOMAIN}"
  fi
else
  log "${YELLOW}Warning: config.env not found. Using default values.${NC}"
  
  # Ask for PRIMARY_DOMAIN if not in auto mode
  if [ "$AUTO_MODE" = false ]; then
    read -p "Enter your primary domain (e.g., example.com): " PRIMARY_DOMAIN
    ERPNEXT_DOMAIN="erp.${PRIMARY_DOMAIN}"
    ERPNEXT_SITE_NAME="erp.${PRIMARY_DOMAIN}"
  else
    log "${RED}Error: config.env not found and running in auto mode.${NC}"
    log "Please create config.env with PRIMARY_DOMAIN set."
    exit 1
  fi
fi

# Display configuration
log "${BLUE}ERPNext Configuration:${NC}"
log "Domain: ${ERPNEXT_DOMAIN}"
log "Version: ${ERPNEXT_VERSION}"
log "Site Name: ${ERPNEXT_SITE_NAME}"
log "Developer Mode: ${ERPNEXT_DEVELOPER_MODE}"
log "HTTP Port: ${ERPNEXT_HTTP_PORT}"
log "HTTPS Port: ${ERPNEXT_HTTPS_PORT}"
log "Multisite Setup: ${ERPNEXT_SETUP_MULTISITE}"
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

# Check if git is installed
if ! command -v git &> /dev/null; then
  log "${RED}Error: Git is not installed${NC}"
  log "Please install Git first: apt-get install git"
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

# Create ERPNext directory
log "${BLUE}Creating ERPNext directory...${NC}"
mkdir -p "$ERPNEXT_DIR"
cd "$ERPNEXT_DIR"

# Clone the official Frappe Docker repository
log "${BLUE}Cloning Frappe Docker repository...${NC}"
if [ ! -d "${ERPNEXT_DIR}/frappe_docker" ]; then
  git clone https://github.com/frappe/frappe_docker.git
  cd frappe_docker
else
  cd frappe_docker
  git pull
fi

log "${BLUE}Setting up ERPNext environment...${NC}"

# Create env-file for MariaDB
cat > "${ERPNEXT_DIR}/frappe_docker/env-mariadb" << EOL
DB_ROOT_PASSWORD=${ERPNEXT_MARIADB_PASSWORD}
EOF
EOL

# Create env-file for Redis
cat > "${ERPNEXT_DIR}/frappe_docker/env-redis" << EOL
REDIS_QUEUE=redis-queue
REDIS_CACHE=redis-cache
REDIS_SOCKETIO=redis-socketio
EOL

# Create env-file for ERPNext
cat > "${ERPNEXT_DIR}/frappe_docker/env-erpnext" << EOL
FRAPPE_VERSION=${ERPNEXT_VERSION}
ERPNEXT_VERSION=${ERPNEXT_VERSION}
IS_DEVELOPMENT=${ERPNEXT_DEVELOPER_MODE}
ADMIN_PASSWORD=${ERPNEXT_ADMIN_PASSWORD}
MARIADB_HOST=mariadb
DB_ROOT_PASSWORD=${ERPNEXT_MARIADB_PASSWORD}
SITE_NAME=${ERPNEXT_SITE_NAME}
SITES=${ERPNEXT_SITE_NAME}
DB_NAME=${ERPNEXT_SITE_NAME//./_}
EOL

# Create custom docker-compose.yml with Traefik integration if available
log "${BLUE}Creating docker-compose.yml...${NC}"
cat > "${ERPNEXT_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  backend:
    image: frappe/erpnext:${ERPNEXT_VERSION}
    container_name: agency_stack_erpnext_backend
    restart: unless-stopped
    env_file:
      - frappe_docker/env-erpnext
    volumes:
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
    depends_on:
      - mariadb
      - redis-cache
      - redis-queue
      - redis-socketio
EOL

# Add Traefik labels if Traefik is available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    labels:
      - traefik.enable=true
      - traefik.http.routers.erpnext.rule=Host(\`${ERPNEXT_DOMAIN}\`)
      - traefik.http.routers.erpnext.entrypoints=websecure
      - traefik.http.routers.erpnext.tls=true
      - traefik.http.routers.erpnext.tls.certresolver=letsencrypt
      - traefik.http.services.erpnext.loadbalancer.server.port=8000
EOL
else
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    ports:
      - "${ERPNEXT_HTTP_PORT}:8000"
EOL
fi

# Continue with services
cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    networks:
      - erpnext
EOL

# Add Traefik network if available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
      - traefik-public
EOL
fi

# Continue with services
cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL

  frontend:
    image: frappe/erpnext-nginx:${ERPNEXT_VERSION}
    container_name: agency_stack_erpnext_frontend
    restart: unless-stopped
    depends_on:
      - backend
    volumes:
      - sites:/var/www/html/sites
      - assets:/assets
EOL

# Add Traefik labels for frontend if Traefik is available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    labels:
      - traefik.enable=true
      - traefik.http.routers.erpnext-assets.rule=Host(\`${ERPNEXT_DOMAIN}\`) && PathPrefix(\`/assets\`)
      - traefik.http.routers.erpnext-assets.entrypoints=websecure
      - traefik.http.routers.erpnext-assets.tls=true
      - traefik.http.routers.erpnext-assets.tls.certresolver=letsencrypt
      - traefik.http.services.erpnext-assets.loadbalancer.server.port=80
EOL
else
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    ports:
      - "${ERPNEXT_HTTPS_PORT}:80"
EOL
fi

# Continue with services
cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
    networks:
      - erpnext
EOL

# Add Traefik network if available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
      - traefik-public
EOL
fi

# Continue with database and redis services
cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL

  mariadb:
    image: mariadb:10.6
    container_name: agency_stack_erpnext_mariadb
    restart: unless-stopped
    env_file:
      - frappe_docker/env-mariadb
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - erpnext

  redis-cache:
    image: redis:6.2-alpine
    container_name: agency_stack_erpnext_redis_cache
    restart: unless-stopped
    volumes:
      - redis-cache-data:/data
    networks:
      - erpnext

  redis-queue:
    image: redis:6.2-alpine
    container_name: agency_stack_erpnext_redis_queue
    restart: unless-stopped
    volumes:
      - redis-queue-data:/data
    networks:
      - erpnext

  redis-socketio:
    image: redis:6.2-alpine
    container_name: agency_stack_erpnext_redis_socketio
    restart: unless-stopped
    volumes:
      - redis-socketio-data:/data
    networks:
      - erpnext

volumes:
  sites:
  logs:
  assets:
  mariadb-data:
  redis-cache-data:
  redis-queue-data:
  redis-socketio-data:

networks:
  erpnext:
    driver: bridge
EOL

# Add Traefik network if available
if [ "$TRAEFIK_NETWORK_EXISTS" = true ]; then
  cat >> "${ERPNEXT_DIR}/docker-compose.yml" << EOL
  traefik-public:
    external: true
EOL
fi

# Create setup script for ERPNext site
log "${BLUE}Creating site setup script...${NC}"
cat > "${ERPNEXT_DIR}/setup-site.sh" << EOL
#!/bin/bash
# Setup script for ERPNext site

# Set environment variables
export SITE_NAME="${ERPNEXT_SITE_NAME}"
export ADMIN_PASSWORD="${ERPNEXT_ADMIN_PASSWORD}"
export DB_ROOT_PASSWORD="${ERPNEXT_MARIADB_PASSWORD}"

cd "${ERPNEXT_DIR}"

# Wait for backend to be ready
echo "Waiting for ERPNext backend to be ready..."
sleep 30

# Create site
docker-compose exec -T backend bench new-site ${SITE_NAME} \
  --mariadb-root-password ${DB_ROOT_PASSWORD} \
  --admin-password ${ADMIN_PASSWORD} \
  --install-app erpnext

# Set site as default
docker-compose exec -T backend bench use ${SITE_NAME}

# Enable developer mode if requested
if [ "${ERPNEXT_DEVELOPER_MODE}" = "true" ]; then
  docker-compose exec -T backend bench set-config developer_mode 1
  docker-compose exec -T backend bench clear-cache
fi

echo "ERPNext site setup complete!"
echo "Site: ${SITE_NAME}"
echo "Admin password: ${ADMIN_PASSWORD}"
EOL

chmod +x "${ERPNEXT_DIR}/setup-site.sh"

# Create bench commands wrapper
log "${BLUE}Creating bench commands wrapper...${NC}"
cat > "${ERPNEXT_DIR}/bench.sh" << EOL
#!/bin/bash
# Bench commands wrapper for ERPNext

docker-compose -f "${ERPNEXT_DIR}/docker-compose.yml" exec backend bench "\$@"
EOL

chmod +x "${ERPNEXT_DIR}/bench.sh"

# Start containers
log "${BLUE}Starting ERPNext containers...${NC}"
cd "$ERPNEXT_DIR"
docker-compose up -d

# Wait for containers to start
log "${BLUE}Waiting for containers to start...${NC}"
sleep 20

# Set up the site
log "${BLUE}Setting up ERPNext site...${NC}"
"${ERPNEXT_DIR}/setup-site.sh"

# Check if ERPNext containers are running
if docker ps | grep -q "agency_stack_erpnext_backend" && docker ps | grep -q "agency_stack_erpnext_frontend"; then
  log "${GREEN}✅ ERPNext containers started successfully${NC}"
  
  # Add to installed components
  echo "ERPNext" >> /opt/agency_stack/installed_components.txt
  
  # Update config.env
  if ! grep -q "ERPNEXT_DOMAIN" "$CONFIG_ENV"; then
    echo -e "\n# ERPNext Configuration" >> "$CONFIG_ENV"
    echo "ERPNEXT_DOMAIN=${ERPNEXT_DOMAIN}" >> "$CONFIG_ENV"
    echo "ERPNEXT_ADMIN_PASSWORD=${ERPNEXT_ADMIN_PASSWORD}" >> "$CONFIG_ENV"
    echo "ERPNEXT_MARIADB_PASSWORD=${ERPNEXT_MARIADB_PASSWORD}" >> "$CONFIG_ENV"
    echo "ERPNEXT_SITE_NAME=${ERPNEXT_SITE_NAME}" >> "$CONFIG_ENV"
  fi
  
  # Display access information
  log "${GREEN}✅ ERPNext has been successfully installed!${NC}"
  log "${CYAN}ERPNext URL: https://${ERPNEXT_DOMAIN}${NC}"
  log "${CYAN}Username: Administrator${NC}"
  log "${CYAN}Password: ${ERPNEXT_ADMIN_PASSWORD}${NC}"
  log ""
  log "${YELLOW}Please save these credentials in a secure location${NC}"
  
  # If Traefik is not available, show direct ports
  if [ "$TRAEFIK_NETWORK_EXISTS" = false ]; then
    log "${YELLOW}Note: Traefik is not installed${NC}"
    log "${YELLOW}ERPNext is accessible at: http://$(hostname -I | awk '{print $1}'):${ERPNEXT_HTTP_PORT}${NC}"
    log "${YELLOW}ERPNext assets are accessible at: http://$(hostname -I | awk '{print $1}'):${ERPNEXT_HTTPS_PORT}${NC}"
  fi
  
  # Additional notes
  log ""
  log "${BLUE}Additional Information:${NC}"
  log "- ERPNext files are stored in Docker volumes for persistence"
  log "- You can use bench commands via: ${ERPNEXT_DIR}/bench.sh"
  log "  Example: ${ERPNEXT_DIR}/bench.sh list-apps"
  
  # Next steps
  log ""
  log "${BLUE}Next Steps:${NC}"
  log "1. Configure your DNS to point ${ERPNEXT_DOMAIN} to this server"
  log "2. Complete the initial ERPNext setup by accessing the URL"
  log "3. Setup your company, users, and initial data"
  
  # For multisite setup
  if [ "$ERPNEXT_SETUP_MULTISITE" = "true" ]; then
    log ""
    log "${BLUE}Multisite Setup:${NC}"
    log "To create additional sites, use the bench command:"
    log "${ERPNEXT_DIR}/bench.sh new-site new-site.example.com --admin-password password"
    log "${ERPNEXT_DIR}/bench.sh --site new-site.example.com install-app erpnext"
  fi
  
  exit 0
else
  log "${RED}❌ Failed to start ERPNext containers${NC}"
  log "Please check the logs:"
  log "  docker logs agency_stack_erpnext_backend"
  log "  docker logs agency_stack_erpnext_frontend"
  exit 1
fi
