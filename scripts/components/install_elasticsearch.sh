#!/bin/bash
# install_elasticsearch.sh - AgencyStack Elasticsearch Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures Elasticsearch with secure defaults
# Part of the AgencyStack Analytics & Search suite
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
ES_LOG="${COMPONENT_LOG_DIR}/elasticsearch.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Elasticsearch Configuration
ES_VERSION="8.11.1"  # Latest stable version
ES_PORT=9200
ES_TRANSPORT_PORT=9300
ES_HOSTNAME="elasticsearch"
ES_MEMORY="1g"  # Default heap size, adjust based on server capacity
ES_NODE_NAME="es01"
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
ES_CONFIG_DIR="${CONFIG_DIR}/elasticsearch"
DOCKER_COMPOSE_DIR="${ES_CONFIG_DIR}/docker"
WITH_DEPS=false
FORCE=false
VERBOSE=false
SSO=false
ADMIN_EMAIL=""
ES_PASSWORD=$(openssl rand -hex 16)

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${ES_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Elasticsearch Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Elasticsearch (e.g., es.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain es.example.com --with-deps"
  echo -e "  $0 --domain es.client1.com --client-id client1 --with-deps"
  echo -e "  $0 --domain es.client2.com --client-id client2 --force"
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
  mkdir -p "${CLIENT_DIR}/elasticsearch/config"
  mkdir -p "${CLIENT_DIR}/elasticsearch/data"
  mkdir -p "${CLIENT_DIR}/elasticsearch/certs"
  mkdir -p "${CLIENT_DIR}/elasticsearch/logs"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/elasticsearch"
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log "ERROR" "Unknown parameter passed: $1"
      show_help
      ;;
  esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain is required. Use --domain to specify it."
  show_help
fi

# Set up directories
log "INFO" "Setting up directories for Elasticsearch installation"
setup_client_dir

# Check if Elasticsearch is already installed
ELASTICSEARCH_CONTAINER="${CLIENT_ID}_elasticsearch"
if docker ps -a --format '{{.Names}}' | grep -q "$ELASTICSEARCH_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Elasticsearch container '$ELASTICSEARCH_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Elasticsearch containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Elasticsearch container '$ELASTICSEARCH_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$ELASTICSEARCH_CONTAINER"; then
      log "INFO" "Elasticsearch container is running"
      echo -e "${GREEN}Elasticsearch is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Elasticsearch URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Elasticsearch container exists but is not running"
      echo -e "${YELLOW}Elasticsearch is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Elasticsearch containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Elasticsearch has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Elasticsearch URL: https://${DOMAIN}${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR" "Docker is not installed. Please install Docker first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker.sh" || {
        log "ERROR" "Failed to install Docker. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker.sh script. Please install Docker manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR" "Docker Compose is not installed. Please install Docker Compose first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker Compose with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker_compose.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker_compose.sh" || {
        log "ERROR" "Failed to install Docker Compose. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker_compose.sh script. Please install Docker Compose manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Create Docker network if it doesn't exist
NETWORK_NAME="${CLIENT_ID}_network"
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO" "Creating Docker network $NETWORK_NAME"
  docker network create "$NETWORK_NAME" || {
    log "ERROR" "Failed to create Docker network $NETWORK_NAME."
    exit 1
  }
fi

# Create Docker Compose file
log "INFO" "Creating Docker Compose configuration"
cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  elasticsearch:
    container_name: ${ELASTICSEARCH_CONTAINER}
    image: docker.elastic.co/elasticsearch/elasticsearch:${ES_VERSION}
    environment:
      - node.name=${ES_NODE_NAME}
      - cluster.name=${CLIENT_ID}-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms${ES_MEMORY} -Xmx${ES_MEMORY}"
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - ELASTIC_PASSWORD=${ES_PASSWORD}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ${CLIENT_DIR}/elasticsearch/data:/usr/share/elasticsearch/data
      - ${CLIENT_DIR}/elasticsearch/logs:/usr/share/elasticsearch/logs
    ports:
      - ${ES_PORT}:9200
      - ${ES_TRANSPORT_PORT}:9300
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-elasticsearch.loadbalancer.server.port=9200"
      - "traefik.http.middlewares.${CLIENT_ID}-elasticsearch-auth.basicauth.users=admin:${ES_PASSWORD}"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.middlewares=${CLIENT_ID}-elasticsearch-auth"
      - "traefik.http.middlewares.${CLIENT_ID}-elasticsearch-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-elasticsearch-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-elasticsearch-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-elasticsearch-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-elasticsearch.middlewares=${CLIENT_ID}-elasticsearch-headers"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
ELASTICSEARCH_VERSION=${ES_VERSION}
ELASTICSEARCH_HOSTNAME=${ES_HOSTNAME}
ELASTICSEARCH_PORT=${ES_PORT}
ELASTICSEARCH_TRANSPORT_PORT=${ES_TRANSPORT_PORT}
ELASTICSEARCH_MEMORY=${ES_MEMORY}
ELASTICSEARCH_PASSWORD=${ES_PASSWORD}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/elasticsearch"
cat > "${CONFIG_DIR}/secrets/elasticsearch/${DOMAIN}.env" << EOF
ELASTICSEARCH_URL=https://${DOMAIN}
ELASTICSEARCH_PORT=${ES_PORT}
ELASTICSEARCH_INTERNAL_URL=http://${ELASTICSEARCH_CONTAINER}:9200
ELASTICSEARCH_ADMIN_USER=elastic
ELASTICSEARCH_ADMIN_PASSWORD=${ES_PASSWORD}
EOF

# Start Elasticsearch
log "INFO" "Starting Elasticsearch"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Elasticsearch"
  exit 1
}

# Wait for Elasticsearch to be ready
log "INFO" "Waiting for Elasticsearch to be ready"
timeout=120
counter=0
echo -n "Waiting for Elasticsearch to start"
until curl -s "http://localhost:${ES_PORT}" | grep -q "You Know, for Search" || [ $counter -ge $timeout ]; do
  echo -n "."
  sleep 1
  counter=$((counter+1))
done
echo

if [ $counter -ge $timeout ]; then
  log "ERROR" "Timed out waiting for Elasticsearch to start"
  exit 1
fi

log "INFO" "Elasticsearch is now ready"

# Update installation records
if ! grep -q "elasticsearch" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "elasticsearch" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${ES_PORT}" \
       --arg version "${ES_VERSION}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.elasticsearch = {
         "name": "Elasticsearch",
         "url": "https://" + $domain,
         "port": $port,
         "version": $version,
         "status": "running",
         "last_updated": $timestamp
       }' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
       
    # Replace original file with updated data
    mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
  else
    log "WARN" "jq is not installed. Skipping dashboard data update."
  fi
fi

# Update integration status
if [ -f "${INTEGRATION_STATUS}" ]; then
  if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    
    jq --arg domain "${DOMAIN}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.elasticsearch = {
         "integrated": true,
         "domain": $domain,
         "last_updated": $timestamp
       }' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
       
    mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
  else
    log "WARN" "jq is not installed. Skipping integration status update."
  fi
fi

# Display completion message
echo -e "${GREEN}${BOLD}✅ Elasticsearch has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Port: ${ES_PORT}${NC}"
echo -e "${CYAN}Version: ${ES_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Username: elastic"
echo -e "Password: ${ES_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/elasticsearch/${DOMAIN}.env${NC}"

log "INFO" "Elasticsearch installation completed successfully"
exit 0
