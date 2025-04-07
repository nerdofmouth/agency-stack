#!/bin/bash
# install_listmonk.sh - AgencyStack Listmonk Email Newsletter Component Installer
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures Listmonk with hardened settings
# Part of the AgencyStack Email & Communication suite
#
# Author: AgencyStack Team
# Version: 1.0.0
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
LISTMONK_LOG="${COMPONENT_LOG_DIR}/listmonk.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${ROOT_DIR}/docker"
LISTMONK_DIR="${DOCKER_DIR}/listmonk"
DOCKER_COMPOSE_FILE="${LISTMONK_DIR}/docker-compose.yml"
DOCKER_ENV_FILE="${LISTMONK_DIR}/.env"
CONFIG_FILE="${LISTMONK_DIR}/config.toml"
TRAEFIK_CONFIG_DIR="${ROOT_DIR}/traefik/config"

# Listmonk Configuration
LISTMONK_VERSION="v2.5.1"
LISTMONK_PORT=9000
LISTMONK_DB_NAME="listmonk"
LISTMONK_DB_USER="listmonk"
LISTMONK_DB_PASS="$(openssl rand -hex 16)"
LISTMONK_ADMIN_USER="admin"
LISTMONK_ADMIN_PASS="$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)"
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
WITH_DEPS=false
FORCE=false
MAILU_DOMAIN=""
MAILU_USER=""
MAILU_PASSWORD=""

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${LISTMONK_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Listmonk Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>         Domain name for Listmonk (e.g., lists.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>          Client ID for multi-tenant setup and SSO integration"
  echo -e "  ${CYAN}--with-deps${NC}               Install dependencies (Docker, PostgreSQL, etc.)"
  echo -e "  ${CYAN}--force${NC}                   Force installation even if already installed"
  echo -e "  ${CYAN}--mailu-domain${NC} <domain>   Mailu server domain for SMTP integration"
  echo -e "  ${CYAN}--mailu-user${NC} <user>       Mailu username for SMTP integration"
  echo -e "  ${CYAN}--mailu-password${NC} <pass>   Mailu password for SMTP integration"
  echo -e "  ${CYAN}--help${NC}                    Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain lists.example.com --with-deps"
  echo -e "  $0 --domain lists.client1.com --client-id client1 --mailu-domain mail.client1.com --mailu-user listmonk@client1.com --mailu-password securepass"
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
  mkdir -p "${CLIENT_DIR}/listmonk_data/config"
  mkdir -p "${CLIENT_DIR}/listmonk_data/uploads"
  mkdir -p "${CLIENT_DIR}/listmonk_data/postgresql"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/listmonk_data"
  
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
  
  # Check if required port is available
  if ! [ "$WITH_DEPS" = true ] && ! [ "$FORCE" = true ]; then
    if lsof -i:"${LISTMONK_PORT}" &> /dev/null; then
      log "ERROR" "Port ${LISTMONK_PORT} is already in use"
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
  mkdir -p "${LISTMONK_DIR}"
  
  # Install system dependencies
  log "INFO" "Installing system packages..."
  apt-get update
  apt-get install -y curl wget gnupg apt-transport-https ca-certificates \
                    software-properties-common lsof postgresql-client
  
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

# Create Listmonk configuration
create_config() {
  log "INFO" "Creating Listmonk configuration..."
  
  mkdir -p "${CLIENT_DIR}/listmonk_data/config"
  
  # Create main configuration file
  cat > "${CLIENT_DIR}/listmonk_data/config/config.toml" << EOF
[app]
# Interface and port where the app will run
address = "0.0.0.0:9000"

# Public URL where the frontend is hosted (for links in e-mail)
root = "https://${DOMAIN}"

# Path to the static frontend directory
static_dir = "static"

# Maximum request payload size in bytes (multipart form)
max_upload_size = 5242880

# batch_size = 1000

# Enable admin credentials
admin_username = "${LISTMONK_ADMIN_USER}"
admin_password = "${LISTMONK_ADMIN_PASS}"

# Enable or disable CSRF protection on admin endpoints
# Recommended to keep enabled, unless connecting via multiple 3rd party client applications
csrf_secret = "$(openssl rand -base64 32)"
csrf_cookie = "__HOST_csrf"

# Indicates if the instance is being served via a CDN/reverse proxy like Cloudflare.
# This makes a few URL related decisions.
# - SameSite=none on CSRF cookies is enabled when the app is behind a proxy.
behind_proxy = true

# Sane limits for sending e-mail campaigns
concurrency = 10
message_rate = 10
max_send_errors = 1000

# Batch size while querying subscribers for processing campaigns.
# If you run into memory issues, reduce this number.
batch_size = 1000

# Database timeout in (seconds) before giving up on queries
# including those for sending multiple campaigns etc.
db_timeout = 300

# If the app should serve https via a reverse proxy, maintain cookie security by:
# 1. Setting the following flags to true
# 2. Setting "secure" on the reverse proxy for ssl
# 3. Setting "X-Forwarded-Proto" to https on the reverse proxy

cookie_secure = true
cookie_same_site = "lax"

# A domain name for the 'domain' in cookie setting.
# This is optional, but useful for cross-subdomain auth.
# Set this to your main domain, for instance "example.org",
# to have the auth cookie set at ".example.org", which is
# available across all subdomains.
cookie_domain = ".${DOMAIN}"

[privacy]
# Listmonk can anonymize subscriber data for privacy and to honour
# the right to be forgotten. While subscriber info will be retained,
# campaigns and lists will still be tracked, with hashed subscriber info
# IP fields will be set to 127.0.0.1

# Allow subscribers to export all the data stored about them
allow_subscriber_export = true

# Allow subscribers to completely wipe all their data from the platform
# without keeping a hash.
allow_subscriber_wipe = true

# Allow subscribers to bring their own privacy keys. These are separate
# from the AES keys below. Enabling this makes "anonymize_after_months"
# and "send_optin_confirmation" incompatible with each other.
allow_blocks = true

# Automatically anonymize subscribers after the given number of months
# of being in the list. If a subscription is more recent, use that date.
# A value of 0 disables this feature.
anonymize_after_months = 0

# Maximum concurrent background search queries to run at once
max_search_queries = 10

# Prevent users from updating already set blocks/privacy keys.
# Allowed: "none", "any", "secret"
# - none: no blocks at all
# - any: all blocks are valid
# - secret: blocks are valid if the AUTH_* environment variables are defined.
allow_idempotent_subscriber_updates = "any"

[security]
# Security related (passwords, tokens, sessions etc) configurations.

# Set to true to disable dashboard. Only API features will work.
disallow_dashboard = false

# Set to true to disable public subscription forms.
disallow_forms = false

# Listmonk uses secure AES encryption to encrypt/decrypt sensitive data.
# Cached templates etc. Use strong, random keys.
# The first key is used for encryption, the rest, if present, are used for
# decryption of data encrypted with them. This scheme is to enable key
# rotation. A new key can be generated and placed as the first while
# keeping the old one around for sometime for decryption of old data.
# IMPORTANT: Removing a key will break decryption of data encrypted with that key.
# The keys here are examples. DO NOT USE THEM. THIS IS IMPORTANT.
[security.keys]
1 = "$(openssl rand -base64 32)"

[uploads]
# 'local', 'gcs', 's3', 'azblob', or 'filesystem'
provider = "filesystem"
# root upload directory, which will contain subdirectories for files, thumbnails etc.
# upload_uri = "uploads" # for cloud providers
upload_path = "/uploads" # for filesystem

# if set, incoming filenames will be hashed using this algorithm.
# supports: sha256, sha512, md5, xxhash64
hash_name = "sha256"

# Maximum allowed upload file size in bytes.
max_size = 5242880

# Thumbnail image widths to generate for image attachments.
# thumbnail_widths = [100]

[smtp]
# SMTP host string for outgoing e-mail. Defaults to localhost.
host = "${MAILU_DOMAIN}"
port = 587

# Enable SMTP authentication. If there are credentials in the URL, this is enabled anyway.
auth_protocol = "login"
username = "${MAILU_USER}"
password = "${MAILU_PASSWORD}"

# Default SMTP sender. Defaults to noreply@localhost
from_email = "${MAILU_USER}"

# Set to true to skip certificate verification.
# DANGEROUS: Only enable this in testing if you know what you're doing.
# setting this to true makes your server vulnerable to MITM attacks.
skip_cert_verify = false

# Mail headers to add to all messages
[smtp.headers]
X-Mailer = "AgencyStack Listmonk"

[smtp.hello_name]
# Optional domain to pass to SMTP HELO command.
# NOTE: If you run into issues where your hosting provider's reverse DNS lookup
# fails, this is a common problem with hosting providers. Set this value
# rather than changing your DNS settings.
name = "${CLIENT_ID}.stack.agencystack.com"

[db]
host = "postgres"
port = 5432
user = "${LISTMONK_DB_USER}"
password = "${LISTMONK_DB_PASS}"
database = "${LISTMONK_DB_NAME}"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"
EOF

  log "INFO" "Listmonk configuration created successfully"
}

# Create Docker Compose configuration
create_docker_compose() {
  log "INFO" "Creating Docker Compose configuration..."
  
  mkdir -p "${LISTMONK_DIR}"
  
  cat > "${DOCKER_COMPOSE_FILE}" << EOF
version: '3.7'

services:
  listmonk:
    image: listmonk/listmonk:${LISTMONK_VERSION}
    container_name: listmonk-${CLIENT_ID}
    restart: unless-stopped
    ports:
      - "${LISTMONK_PORT}:9000"
    volumes:
      - ${CLIENT_DIR}/listmonk_data/config/config.toml:/listmonk/config.toml:ro
      - ${CLIENT_DIR}/listmonk_data/uploads:/listmonk/uploads:rw
    environment:
      - TZ=UTC
      - LISTMONK_db__host=postgres
      - LISTMONK_db__port=5432
      - LISTMONK_db__user=${LISTMONK_DB_USER}
      - LISTMONK_db__password=${LISTMONK_DB_PASS}
      - LISTMONK_db__database=${LISTMONK_DB_NAME}
      - LISTMONK_app__admin_username=${LISTMONK_ADMIN_USER}
      - LISTMONK_app__admin_password=${LISTMONK_ADMIN_PASS}
    depends_on:
      - postgres
    networks:
      - listmonk_network
      - traefik_network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.listmonk-${CLIENT_ID}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.listmonk-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.listmonk-${CLIENT_ID}.tls=true"
      - "traefik.http.routers.listmonk-${CLIENT_ID}.tls.certresolver=letsencrypt"
      - "traefik.http.services.listmonk-${CLIENT_ID}.loadbalancer.server.port=9000"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.stsPreload=true"
      - "traefik.http.routers.listmonk-${CLIENT_ID}.middlewares=listmonk-${CLIENT_ID}-security"
      - "traefik.http.middlewares.listmonk-${CLIENT_ID}-security.headers.customResponseHeaders.X-Robots-Tag=noindex, nofollow, nosnippet, noarchive"

  postgres:
    image: postgres:14-alpine
    container_name: listmonk-postgres-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/listmonk_data/postgresql:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=${LISTMONK_DB_USER}
      - POSTGRES_PASSWORD=${LISTMONK_DB_PASS}
      - POSTGRES_DB=${LISTMONK_DB_NAME}
    command: postgres -c 'shared_buffers=256MB' -c 'max_connections=200'
    networks:
      - listmonk_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  listmonk_network:
    driver: bridge
  traefik_network:
    external: true
    name: traefik-network
EOF

  # Create .env file
  cat > "${DOCKER_ENV_FILE}" << EOF
# Listmonk Configuration
DOMAIN=${DOMAIN}
LISTMONK_DB_USER=${LISTMONK_DB_USER}
LISTMONK_DB_PASS=${LISTMONK_DB_PASS}
LISTMONK_DB_NAME=${LISTMONK_DB_NAME}
CLIENT_ID=${CLIENT_ID}
LISTMONK_PORT=${LISTMONK_PORT}
EOF

  log "INFO" "Docker Compose configuration created successfully"
}

# Setup Traefik configuration
setup_traefik() {
  log "INFO" "Setting up Traefik configuration..."
  
  # Ensure the Traefik config directory exists
  mkdir -p "${TRAEFIK_CONFIG_DIR}/dynamic"
  
  # Create Listmonk Traefik configuration
  cat > "${TRAEFIK_CONFIG_DIR}/dynamic/listmonk-${CLIENT_ID}.toml" << EOF
[http.routers.listmonk-${CLIENT_ID}]
  rule = "Host(\`${DOMAIN}\`)"
  entrypoints = ["websecure"]
  service = "listmonk-${CLIENT_ID}"
  middlewares = ["listmonk-${CLIENT_ID}-security"]
  [http.routers.listmonk-${CLIENT_ID}.tls]
    certResolver = "letsencrypt"

[http.services.listmonk-${CLIENT_ID}.loadBalancer]
  [[http.services.listmonk-${CLIENT_ID}.loadBalancer.servers]]
    url = "http://listmonk-${CLIENT_ID}:9000"

[http.middlewares.listmonk-${CLIENT_ID}-security.headers]
  stsSeconds = 31536000
  browserXssFilter = true
  contentTypeNosniff = true
  forceSTSHeader = true
  stsIncludeSubdomains = true
  stsPreload = true
  frameDeny = true
  [http.middlewares.listmonk-${CLIENT_ID}-security.headers.customResponseHeaders]
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
  
  # Create a note about SSO setup in the Listmonk directory
  mkdir -p "${CLIENT_DIR}/listmonk_data/config"
  
  cat > "${CLIENT_DIR}/listmonk_data/config/keycloak-sso-note.txt" << EOF
Keycloak SSO Integration Instructions for Listmonk

Listmonk does not have direct SSO integration capabilities in the core product.
However, you can implement SSO by:

1. Setting up a Keycloak proxy in front of Listmonk
2. Using the following Keycloak realm details:
   - Realm: ${CLIENT_ID}
   - Client ID: listmonk
   - Redirect URI: https://${DOMAIN}/*

Ask your AgencyStack administrator to configure Keycloak for this integration.
EOF

  log "INFO" "SSO integration note created"
}

# Register Listmonk component with AgencyStack
register_component() {
  log "INFO" "Registering Listmonk component with AgencyStack..."
  
  # Ensure config directory exists
  mkdir -p "${CONFIG_DIR}"
  
  # Add to installed components
  if ! grep -q "listmonk" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
    echo "listmonk" >> "${INSTALLED_COMPONENTS}"
    log "INFO" "Added Listmonk to installed components list"
  fi
  
  # Update dashboard data
  if [ -f "${DASHBOARD_DATA}" ]; then
    # Check if Listmonk entry already exists
    if ! grep -q '"component": "listmonk"' "${DASHBOARD_DATA}"; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      jq --argjson new_component '{
        "component": "listmonk",
        "name": "Listmonk",
        "description": "Self-hosted newsletter and mailing list manager",
        "category": "Email & Communication",
        "url": "https://'"${DOMAIN}"'",
        "adminUrl": "https://'"${DOMAIN}"'/admin",
        "version": "'"${LISTMONK_VERSION}"'",
        "installDate": "'"$(date -Iseconds)"'",
        "status": "active",
        "icon": "mail",
        "clientId": "'"${CLIENT_ID}"'"
      }' '.components += [$new_component]' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
      log "INFO" "Updated dashboard data with Listmonk component"
    else
      log "INFO" "Listmonk already exists in dashboard data"
    fi
  else
    # Create a new dashboard data file
    cat > "${DASHBOARD_DATA}" << EOF
{
  "components": [
    {
      "component": "listmonk",
      "name": "Listmonk",
      "description": "Self-hosted newsletter and mailing list manager",
      "category": "Email & Communication",
      "url": "https://${DOMAIN}",
      "adminUrl": "https://${DOMAIN}/admin",
      "version": "${LISTMONK_VERSION}",
      "installDate": "$(date -Iseconds)",
      "status": "active",
      "icon": "mail",
      "clientId": "${CLIENT_ID}"
    }
  ]
}
EOF
    log "INFO" "Created new dashboard data file with Listmonk component"
  fi
  
  # Update integration status
  if [ -f "${INTEGRATION_STATUS}" ]; then
    # Check if Listmonk entry already exists
    if ! grep -q '"component": "listmonk"' "${INTEGRATION_STATUS}"; then
      # Create a temporary file with the new integration status
      TEMP_FILE=$(mktemp)
      jq --argjson new_status '{
        "component": "listmonk",
        "clientId": "'"${CLIENT_ID}"'",
        "integrations": {
          "monitoring": true,
          "auth": false,
          "mail": true
        },
        "lastChecked": "'"$(date -Iseconds)"'"
      }' '.status += [$new_status]' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
      log "INFO" "Updated integration status with Listmonk component"
    else
      log "INFO" "Listmonk already exists in integration status"
    fi
  else
    # Create a new integration status file
    cat > "${INTEGRATION_STATUS}" << EOF
{
  "status": [
    {
      "component": "listmonk",
      "clientId": "${CLIENT_ID}",
      "integrations": {
        "monitoring": true,
        "auth": false,
        "mail": true
      },
      "lastChecked": "$(date -Iseconds)"
    }
  ]
}
EOF
    log "INFO" "Created new integration status file with Listmonk component"
  fi
  
  log "INFO" "Listmonk component registered successfully"
}

# Register component in component registry
register_component_registry() {
  log "INFO" "Registering Listmonk in the component registry..."
  
  local REGISTRY_DIR="${CONFIG_DIR}/registry"
  local REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
  
  mkdir -p "${REGISTRY_DIR}"
  
  if [ -f "${REGISTRY_FILE}" ]; then
    # Check if Listmonk entry already exists
    if ! jq -e '.components.communication.listmonk' "${REGISTRY_FILE}" > /dev/null 2>&1; then
      # Create a temporary file with the new component
      TEMP_FILE=$(mktemp)
      
      jq --arg version "${LISTMONK_VERSION}" '.components.communication.listmonk = {
        "name": "Listmonk",
        "category": "Email & Communication",
        "version": $version,
        "integration_status": {
          "installed": true,
          "hardened": true,
          "makefile": true,
          "sso": false,
          "dashboard": true,
          "logs": true,
          "docs": true,
          "auditable": true,
          "traefik_tls": true,
          "multi_tenant": true
        },
        "description": "Self-hosted newsletter and mailing list manager",
        "ports": {
          "web": 9000
        }
      }' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      
      # Replace the original file with the new one
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      # Update the timestamp
      TEMP_FILE=$(mktemp)
      jq --arg ts "$(date -Iseconds)" '.last_updated = $ts' "${REGISTRY_FILE}" > "${TEMP_FILE}"
      mv "${TEMP_FILE}" "${REGISTRY_FILE}"
      
      log "INFO" "Added Listmonk to component registry"
    else
      log "INFO" "Listmonk already exists in component registry"
    fi
  else
    log "WARN" "Component registry not found, skipping registration"
  fi
}

# Setup monitoring hooks
setup_monitoring() {
  log "INFO" "Setting up monitoring hooks..."
  
  # Create monitoring configuration for Listmonk
  mkdir -p "${ROOT_DIR}/monitoring/config/components"
  
  # Create Prometheus configuration
  cat > "${ROOT_DIR}/monitoring/config/components/listmonk-${CLIENT_ID}.yml" << EOF
- job_name: 'listmonk-${CLIENT_ID}'
  scrape_interval: 30s
  metrics_path: '/metrics'
  static_configs:
    - targets: ['listmonk-${CLIENT_ID}:9000']
      labels:
        instance: 'listmonk'
        component: 'email_communication'
        client_id: '${CLIENT_ID}'
EOF

  # Create monitoring check script
  mkdir -p "${ROOT_DIR}/monitoring/scripts"
  
  cat > "${ROOT_DIR}/monitoring/scripts/check_listmonk-${CLIENT_ID}.sh" << EOF
#!/bin/bash
# Listmonk monitoring check script for ${CLIENT_ID}

# Check if Listmonk is responding
curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/health" | grep -q "200"
exit \$?
EOF
  
  chmod +x "${ROOT_DIR}/monitoring/scripts/check_listmonk-${CLIENT_ID}.sh"
  
  log "INFO" "Monitoring hooks set up successfully"
}

# Start Listmonk containers
start_services() {
  log "INFO" "Starting Listmonk services..."
  
  cd "${LISTMONK_DIR}"
  docker-compose up -d
  
  log "INFO" "Listmonk services started successfully"
}

# Validate installation
validate_installation() {
  log "INFO" "Validating Listmonk installation..."
  
  # Ensure validate_system.sh exists
  if [ ! -f "${ROOT_DIR}/scripts/utils/validate_system.sh" ]; then
    log "WARN" "validate_system.sh not found, skipping validation"
    return
  fi
  
  # Run validation
  "${ROOT_DIR}/scripts/utils/validate_system.sh" --component=listmonk --client-id="${CLIENT_ID}"
  
  # Check if validation was successful
  if [ $? -eq 0 ]; then
    log "INFO" "Listmonk installation validated successfully"
  else
    log "WARN" "Listmonk installation validation failed"
  fi
}

# Main installation function
install_listmonk() {
  log "INFO" "Starting Listmonk installation..."
  
  # Check if already installed
  if grep -q "listmonk" "${INSTALLED_COMPONENTS}" 2>/dev/null && [ "$FORCE" = false ]; then
    log "ERROR" "Listmonk is already installed. Use --force to reinstall."
    exit 1
  fi
  
  # Setup client directory
  setup_client_dir
  
  # Check requirements
  check_requirements
  
  # Install dependencies if requested
  install_dependencies
  
  # Create configuration
  create_config
  
  # Create Docker Compose configuration
  create_docker_compose
  
  # Setup Traefik configuration
  setup_traefik
  
  # Configure SSO integration if client ID is provided
  setup_sso
  
  # Setup monitoring hooks
  setup_monitoring
  
  # Start Listmonk services
  start_services
  
  # Register Listmonk component with AgencyStack
  register_component
  
  # Register in component registry
  register_component_registry
  
  # Validate installation
  validate_installation
  
  log "INFO" "Listmonk installation completed successfully"
  echo -e "\n${BOLD}${GREEN}Listmonk installation completed successfully${NC}"
  echo -e "${BOLD}Web UI:${NC} https://${DOMAIN}"
  echo -e "${BOLD}Admin UI:${NC} https://${DOMAIN}/admin"
  echo -e "${BOLD}Admin Username:${NC} ${LISTMONK_ADMIN_USER}"
  echo -e "${BOLD}Admin Password:${NC} ${LISTMONK_ADMIN_PASS}"
  echo -e "${BOLD}Client ID:${NC} ${CLIENT_ID}"
  echo -e "${BOLD}Data Directory:${NC} ${CLIENT_DIR}/listmonk_data"
  echo -e "${BOLD}Log File:${NC} ${LISTMONK_LOG}"
  echo -e "\n${BOLD}${YELLOW}NOTE: Please save these credentials in a secure location.${NC}"
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
    --mailu-domain)
      MAILU_DOMAIN="$2"
      shift
      shift
      ;;
    --mailu-user)
      MAILU_USER="$2"
      shift
      shift
      ;;
    --mailu-password)
      MAILU_PASSWORD="$2"
      shift
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

# If Mailu parameters are not provided, use defaults
if [ -z "$MAILU_DOMAIN" ]; then
  MAILU_DOMAIN="mail.${DOMAIN/lists./}"
  log "INFO" "Mailu domain not specified, using default: ${MAILU_DOMAIN}"
fi

if [ -z "$MAILU_USER" ]; then
  MAILU_USER="listmonk@${DOMAIN/lists./}"
  log "INFO" "Mailu user not specified, using default: ${MAILU_USER}"
fi

if [ -z "$MAILU_PASSWORD" ]; then
  log "WARN" "Mailu password not specified. SMTP may not work properly."
  MAILU_PASSWORD="password_not_set"
fi

# Run the installer
install_listmonk
