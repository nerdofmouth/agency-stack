#!/bin/bash
# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# --- BEGIN: Preflight/Prerequisite Check ---
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# install_peertube.sh - AgencyStack PeerTube Component Installer
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures PeerTube with hardened settings
# Part of the AgencyStack Content & Media suite
#
# Author: AgencyStack Team
# Version: 1.1.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Color definitions
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
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
PEERTUBE_LOG="${COMPONENT_LOG_DIR}/peertube.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${ROOT_DIR}/docker"
DOCKER_COMPOSE_FILE="${DOCKER_DIR}/peertube/docker-compose.yml"
DOCKER_ENV_FILE="${DOCKER_DIR}/peertube/.env"
TRAEFIK_CONFIG_DIR="${ROOT_DIR}/traefik/config"

# PeerTube Configuration
PEERTUBE_VERSION="5.1.0"
PEERTUBE_WEB_PORT=9000
PEERTUBE_RTMP_PORT=1935
PEERTUBE_ADMIN_PORT=9001
PEERTUBE_HOSTNAME="peertube"
PEERTUBE_DB_NAME="peertube"
PEERTUBE_DB_USER="peertube"
PEERTUBE_DB_PASS="$(openssl rand -hex 16)"
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
WITH_DEPS=false
FORCE=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${PEERTUBE_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack PeerTube Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>       Domain name for PeerTube (e.g., peertube.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>        Client ID for multi-tenant setup and SSO integration"
  echo -e "  ${CYAN}--with-deps${NC}             Install dependencies (PostgreSQL, Redis, ffmpeg, etc.)"
  echo -e "  ${CYAN}--force${NC}                 Force installation even if already installed"
  echo -e "  ${CYAN}--help${NC}                  Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain video.example.com --with-deps"
  echo -e "  $0 --domain peertube.client1.com --client-id client1 --with-deps"
  echo -e "  $0 --domain peertube.client2.com --client-id client2 --force"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}"
  
  # Create persistent data directories
  mkdir -p "${CLIENT_DIR}/peertube_data/config"
  mkdir -p "${CLIENT_DIR}/peertube_data/videos"
  mkdir -p "${CLIENT_DIR}/peertube_data/data"
  mkdir -p "${CLIENT_DIR}/peertube_data/postgresql"
  mkdir -p "${CLIENT_DIR}/peertube_data/redis"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/peertube_data"
  
  # Save client ID to file if it doesn't exist
  if [ ! -f "${CLIENT_ID_FILE}" ]; then
    echo "${CLIENT_ID}" > "${CLIENT_ID_FILE}"
    log "INFO" "Saved client ID to ${CLIENT_ID_FILE}"
  fi
}

# Check system requirements
check_requirements() {
  log "INFO" "Checking system requirements..."
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check if Docker Compose is installed
  if ! command -v docker-compose &> /dev/null; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check if required ports are available
  if ! [ "$WITH_DEPS" = true ] && ! [ "$FORCE" = true ]; then
    if lsof -i:"${PEERTUBE_WEB_PORT}" &> /dev/null; then
      log "ERROR" "Port ${PEERTUBE_WEB_PORT} is already in use"
      exit 1
    fi
    
    if lsof -i:"${PEERTUBE_RTMP_PORT}" &> /dev/null; then
      log "ERROR" "Port ${PEERTUBE_RTMP_PORT} is already in use"
      exit 1
    fi
    
    if lsof -i:"${PEERTUBE_ADMIN_PORT}" &> /dev/null; then
      log "ERROR" "Port ${PEERTUBE_ADMIN_PORT} is already in use"
      exit 1
    fi
  fi
  
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Create installation directories
  mkdir -p "${DOCKER_DIR}/peertube"
  
  # Install system dependencies
  log "INFO" "Installing system packages..."
  apt-get update
  apt-get install -y curl wget gnupg apt-transport-https ca-certificates \
                    software-properties-common lsof ffmpeg \
                    nodejs npm build-essential python3-dev
  
  # Install Yarn
  if ! command -v yarn &> /dev/null; then
    log "INFO" "Installing Yarn..."
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
    apt-get update && apt-get install -y yarn
  fi
  
  # Install Docker if not present
  if ! command -v docker &> /dev/null; then
    log "INFO" "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker "${USER}"
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
  fi
  
  # Install Docker Compose if not present
  if ! command -v docker-compose &> /dev/null; then
    log "INFO" "Installing Docker Compose..."
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi
  
  log "INFO" "Dependencies installed successfully"
}

# Create Docker Compose configuration
create_docker_compose() {
  log "INFO" "Creating Docker Compose configuration..."
  
  mkdir -p "$(dirname "$DOCKER_COMPOSE_FILE")"
  
  cat > "$DOCKER_COMPOSE_FILE" << EOF
version: '3.3'

services:
  peertube:
    image: chocobozzz/peertube:production-bookworm
    container_name: peertube-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    ports:
      - "${PEERTUBE_WEB_PORT}:9000"
      - "${PEERTUBE_RTMP_PORT}:1935"
      - "${PEERTUBE_ADMIN_PORT}:9001"
    environment:
      - PEERTUBE_DB_USERNAME=\${DB_USERNAME}
      - PEERTUBE_DB_PASSWORD=\${DB_PASSWORD}
      - PEERTUBE_DB_HOSTNAME=postgres
      - PEERTUBE_DB_PORT=5432
      - PEERTUBE_DB_SUFFIX=_prod
      - PEERTUBE_DB_NAME=\${DB_NAME}
      - PEERTUBE_WEBSERVER_HOSTNAME=\${DOMAIN}
      - PEERTUBE_WEBSERVER_PORT=443
      - PEERTUBE_WEBSERVER_HTTPS=true
      - PEERTUBE_REDIS_HOSTNAME=redis
      - PEERTUBE_ADMIN_EMAIL=admin@\${DOMAIN}
      - PEERTUBE_INSTANCE_NAME=AgencyStack PeerTube - \${CLIENT_ID}
      - PEERTUBE_INSTANCE_DESCRIPTION=Self-hosted video platform for \${CLIENT_ID}
      - PEERTUBE_CONTACT_FORM_ENABLED=true
    volumes:
      - ${CLIENT_DIR}/peertube_data/config:/config
      - ${CLIENT_DIR}/peertube_data/data:/data
      - ${CLIENT_DIR}/peertube_data/videos:/videos
    networks:
      - peertube_network
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.peertube-${CLIENT_ID}.rule=Host(\`\${DOMAIN}\`)"
      - "traefik.http.routers.peertube-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.peertube-${CLIENT_ID}.tls=true"
      - "traefik.http.routers.peertube-${CLIENT_ID}.tls.certResolver=letsencrypt"
      - "traefik.http.services.peertube-${CLIENT_ID}.loadbalancer.server.port=9000"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.stsPreload=true"
      - "traefik.http.routers.peertube-${CLIENT_ID}.middlewares=peertube-${CLIENT_ID}-security"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.customResponseHeaders.X-Robots-Tag=noindex, nofollow, nosnippet, noarchive"
      - "traefik.http.middlewares.peertube-${CLIENT_ID}-security.headers.frameDeny=true"

  postgres:
    image: postgres:14-alpine
    container_name: peertube-postgres-${CLIENT_ID}
    restart: unless-stopped
    environment:
      - POSTGRES_USER=\${DB_USERNAME}
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
      - POSTGRES_DB=\${DB_NAME}
    volumes:
      - ${CLIENT_DIR}/peertube_data/postgresql:/var/lib/postgresql/data
    networks:
      - peertube_network

  redis:
    image: redis:7-alpine
    container_name: peertube_redis-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/peertube_data/redis:/data
    networks:
      - peertube_network

networks:
  peertube_network:
    driver: bridge
  traefik_network:
    external: true
    name: traefik-network
EOF

  # Create .env file
  cat > "$DOCKER_ENV_FILE" << EOF
# PeerTube Configuration
DOMAIN=${DOMAIN}
DB_USERNAME=${PEERTUBE_DB_USER}
DB_PASSWORD=${PEERTUBE_DB_PASS}
DB_NAME=${PEERTUBE_DB_NAME}
CLIENT_ID=${CLIENT_ID}
EOF

  log "INFO" "Docker Compose configuration created successfully"
}

# Setup Traefik configuration
setup_traefik() {
  log "INFO" "Setting up Traefik configuration..."
  
  # Ensure the Traefik config directory exists
  mkdir -p "${TRAEFIK_CONFIG_DIR}/dynamic"
  
  # Create PeerTube Traefik configuration
  cat > "${TRAEFIK_CONFIG_DIR}/dynamic/peertube-${CLIENT_ID}.toml" << EOF
[http.routers.peertube-${CLIENT_ID}]
  rule = "Host(\`${DOMAIN}\`)"
  entrypoints = ["websecure"]
  service = "peertube-${CLIENT_ID}"
  middlewares = ["peertube-${CLIENT_ID}-security"]
  [http.routers.peertube-${CLIENT_ID}.tls]
    certResolver = "letsencrypt"

[http.services.peertube-${CLIENT_ID}.loadBalancer]
  [[http.services.peertube-${CLIENT_ID}.loadBalancer.servers]]
    url = "http://peertube-${CLIENT_ID}:9000"

[http.middlewares.peertube-${CLIENT_ID}-security.headers]
  stsSeconds = 31536000
  browserXssFilter = true
  contentTypeNosniff = true
  forceSTSHeader = true
  stsIncludeSubdomains = true
  stsPreload = true
  frameDeny = true
  [http.middlewares.peertube-${CLIENT_ID}-security.headers.customResponseHeaders]
    X-Robots-Tag = "noindex, nofollow, nosnippet, noarchive"
EOF

  log "INFO" "Traefik configuration created successfully"
}

# Configure Keycloak SSO integration if client ID is provided
setup_sso() {
  if [ -z "$CLIENT_ID" ]; then
    log "INFO" "Skipping SSO setup (no client ID provided)"
    return
  fi
  
  log "INFO" "Setting up Keycloak SSO integration..."
  
  # Create PeerTube OAuth configuration directory
  mkdir -p "${CLIENT_DIR}/peertube_data/config/production.yaml.d"
  
  # Create OAuth configuration
  cat > "${CLIENT_DIR}/peertube_data/config/production.yaml.d/oauth.yaml" << EOF
oauth2:
  silent_authentication: true
  default_update_role: "User"
  trusted_browsers: []
  providers:
    - name: 'keycloak'
      display_name: 'Keycloak'
      open_id_configuration_url: 'https://keycloak.${DOMAIN/peertube./}/realms/${CLIENT_ID}/.well-known/openid-configuration'
      client_id: 'peertube'
      client_secret: 'peertube-secret'
      scope: 'openid email profile'
      additional_params:
        prompt: 'login'
EOF

  log "INFO" "SSO integration configured successfully"
}

# Register PeerTube component with AgencyStack
register_component() {
  log "INFO" "Registering PeerTube component with AgencyStack..."
  
  # Ensure config directory exists
  mkdir -p "${CONFIG_DIR}"
  
  # Add to installed components
  if ! grep -q "peertube" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
    echo "peertube" >> "${INSTALLED_COMPONENTS}"
    log "INFO" "Added PeerTube to installed components list"
  fi
  
  # Update dashboard data
  if [ -f "${DASHBOARD_DATA}" ]; then
    # Check if PeerTube entry already exists
    if ! grep -q '"component": "peertube"' "${DASHBOARD_DATA}"; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      jq --argjson new_component '{
        "component": "peertube",
        "name": "PeerTube",
        "description": "Self-hosted video streaming platform",
        "category": "Content & Media",
        "url": "https://'"${DOMAIN}"'",
        "adminUrl": "https://'"${DOMAIN}"'/admin",
        "version": "'"${PEERTUBE_VERSION}"'",
        "installDate": "'"$(date -Iseconds)"'",
        "status": "active",
        "icon": "video",
        "clientId": "'"${CLIENT_ID}"'"
      }' '.components += [$new_component]' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
      log "INFO" "Updated dashboard data with PeerTube component"
    else
      log "INFO" "PeerTube already exists in dashboard data"
    fi
  else
    # Create a new dashboard data file
    cat > "${DASHBOARD_DATA}" << EOF
{
  "components": [
    {
      "component": "peertube",
      "name": "PeerTube",
      "description": "Self-hosted video streaming platform",
      "category": "Content & Media",
      "url": "https://${DOMAIN}",
      "adminUrl": "https://${DOMAIN}/admin",
      "version": "${PEERTUBE_VERSION}",
      "installDate": "$(date -Iseconds)",
      "status": "active",
      "icon": "video",
      "clientId": "${CLIENT_ID}"
    }
  ]
}
EOF
    log "INFO" "Created new dashboard data file with PeerTube component"
  fi
  
  # Update integration status
  if [ -f "${INTEGRATION_STATUS}" ]; then
    # Check if PeerTube entry already exists
    if ! grep -q '"component": "peertube"' "${INTEGRATION_STATUS}"; then
      # Create a temporary file with the new integration status
      TEMP_FILE=$(mktemp)
      jq --argjson new_status '{
        "component": "peertube",
        "clientId": "'"${CLIENT_ID}"'",
        "integrations": {
          "monitoring": true,
          "auth": '$([ -n "$CLIENT_ID" ] && echo "true" || echo "false")',
          "mail": true
        },
        "lastChecked": "'"$(date -Iseconds)"'"
      }' '.status += [$new_status]' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
      log "INFO" "Updated integration status with PeerTube component"
    else
      log "INFO" "PeerTube already exists in integration status"
    fi
  else
    # Create a new integration status file
    cat > "${INTEGRATION_STATUS}" << EOF
{
  "status": [
    {
      "component": "peertube",
      "clientId": "${CLIENT_ID}",
      "integrations": {
        "monitoring": true,
        "auth": $([ -n "$CLIENT_ID" ] && echo "true" || echo "false"),
        "mail": true
      },
      "lastChecked": "$(date -Iseconds)"
    }
  ]
}
EOF
    log "INFO" "Created new integration status file with PeerTube component"
  fi
  
  log "INFO" "PeerTube component registered successfully"
}

# Setup monitoring hooks
setup_monitoring() {
  log "INFO" "Setting up monitoring hooks..."
  
  # Create monitoring configuration for PeerTube
  mkdir -p "${ROOT_DIR}/monitoring/config/components"
  
  # Create Prometheus configuration
  cat > "${ROOT_DIR}/monitoring/config/components/peertube-${CLIENT_ID}.yml" << EOF
- job_name: 'peertube-${CLIENT_ID}'
  scrape_interval: 30s
  static_configs:
    - targets: ['peertube-${CLIENT_ID}:9000']
      labels:
        instance: 'peertube'
        component: 'content_media'
        client_id: '${CLIENT_ID}'
EOF

  # Create monitoring check script
  mkdir -p "${ROOT_DIR}/monitoring/scripts"
  
  cat > "${ROOT_DIR}/monitoring/scripts/check_peertube-${CLIENT_ID}.sh" << EOF
#!/bin/bash
# PeerTube monitoring check script for ${CLIENT_ID}

# Check if PeerTube is responding
curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/api/v1/ping" | grep -q "200"
exit \$?
EOF
  
  chmod +x "${ROOT_DIR}/monitoring/scripts/check_peertube-${CLIENT_ID}.sh"
  
  log "INFO" "Monitoring hooks set up successfully"
}

# Setup mail integration
setup_mail() {
  log "INFO" "Setting up mail integration..."
  
  # Configure SMTP settings for PeerTube
  mkdir -p "${CLIENT_DIR}/peertube_data/config/production.yaml.d"
  
  cat > "${CLIENT_DIR}/peertube_data/config/production.yaml.d/mail.yaml" << EOF
smtp:
  hostname: 'mail.${DOMAIN/peertube./}'
  port: 587
  username: 'peertube@${DOMAIN/peertube./}'
  password: 'mail_password_here'
  tls: true
  disable_starttls: false
  ca_file: null
  from_address: 'peertube@${DOMAIN/peertube./}'
EOF

  log "INFO" "Mail integration set up successfully"
}

# Start PeerTube containers
start_services() {
  log "INFO" "Starting PeerTube services..."
  
  cd "${DOCKER_DIR}/peertube"
  docker-compose up -d
  
  log "INFO" "PeerTube services started successfully"
}

# Validate installation
validate_installation() {
  log "INFO" "Validating PeerTube installation..."
  
  # Ensure validate_system.sh exists
  if [ ! -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
    log "WARN" "validate_system.sh not found, skipping validation"
    return
  fi
  
  # Run validation
  "${ROOT_DIR}/scripts/utils/validate_system.sh" --component=peertube --client-id="${CLIENT_ID}"
  
  # Check if validation was successful
  if [ $? -eq 0 ]; then
    log "INFO" "PeerTube installation validated successfully"
  else
    log "WARN" "PeerTube installation validation failed"
  fi
}

# Main installation function
install_peertube() {
  log "INFO" "Starting PeerTube installation..."
  
  # Check if already installed
  if grep -q "peertube" "${INSTALLED_COMPONENTS}" 2>/dev/null && [ "$FORCE" = false ]; then
    log "ERROR" "PeerTube is already installed. Use --force to reinstall."
    exit 1
  fi
  
  # Setup client directory
  setup_client_dir
  
  # Check requirements
  check_requirements
  
  # Install dependencies if requested
  install_dependencies
  
  # Create Docker Compose configuration
  create_docker_compose
  
  # Setup Traefik configuration
  setup_traefik
  
  # Configure SSO integration if client ID is provided
  setup_sso
  
  # Setup monitoring hooks
  setup_monitoring
  
  # Setup mail integration
  setup_mail
  
  # Start PeerTube services
  start_services
  
  # Register PeerTube component with AgencyStack
  register_component
  
  # Validate installation
  validate_installation
  
  log "INFO" "PeerTube installation completed successfully"
  echo -e "\n${BOLD}${GREEN}PeerTube installation completed successfully${NC}"
  echo -e "${BOLD}Web UI:${NC} https://${DOMAIN}"
  echo -e "${BOLD}Admin UI:${NC} https://${DOMAIN}/admin"
  echo -e "${BOLD}RTMP Port:${NC} ${PEERTUBE_RTMP_PORT}"
  echo -e "${BOLD}Client ID:${NC} ${CLIENT_ID}"
  echo -e "${BOLD}Data Directory:${NC} ${CLIENT_DIR}/peertube_data"
  echo -e "${BOLD}Log File:${NC} ${PEERTUBE_LOG}"
}

# Process command-line arguments
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
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --force)
      FORCE=true
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

# Validate required parameters
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain name is required. Use --domain to specify."
  echo -e "${RED}Error: Domain name is required.${NC} Use --domain to specify."
  echo -e "Use --help for usage information"
  exit 1
fi

# Run the installer
install_peertube
