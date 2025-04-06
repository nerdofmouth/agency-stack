#!/bin/bash
# install_etcd.sh - AgencyStack etcd Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures etcd with security hardening
# Part of the AgencyStack Infrastructure suite
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
ETCD_LOG="${COMPONENT_LOG_DIR}/etcd.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# etcd Configuration
ETCD_VERSION="3.5.10"  # Latest stable version
ETCD_CLIENT_PORT=2379
ETCD_PEER_PORT=2380
ETCD_METRICS_PORT=2381
ETCD_HOSTNAME="etcd"
ETCD_NODE_NAME="etcd0"
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
ETCD_CONFIG_DIR="${CONFIG_DIR}/etcd"
DOCKER_COMPOSE_DIR="${ETCD_CONFIG_DIR}/docker"
WITH_DEPS=false
FORCE=false
VERBOSE=false
ADMIN_EMAIL=""
ETCD_ROOT_PASSWORD=$(openssl rand -hex 16)

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${ETCD_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack etcd Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for etcd (e.g., etcd.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain etcd.example.com --with-deps"
  echo -e "  $0 --domain etcd.client1.com --client-id client1 --with-deps"
  echo -e "  $0 --domain etcd.client2.com --client-id client2 --force"
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
  mkdir -p "${CLIENT_DIR}/etcd/config"
  mkdir -p "${CLIENT_DIR}/etcd/data"
  mkdir -p "${CLIENT_DIR}/etcd/certs"
  mkdir -p "${CLIENT_DIR}/etcd/logs"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/etcd"
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
log "INFO" "Setting up directories for etcd installation"
setup_client_dir

# Check if etcd is already installed
ETCD_CONTAINER="${CLIENT_ID}_etcd"
if docker ps -a --format '{{.Names}}' | grep -q "$ETCD_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "etcd container '$ETCD_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing etcd containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "etcd container '$ETCD_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$ETCD_CONTAINER"; then
      log "INFO" "etcd container is running"
      echo -e "${GREEN}etcd is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}etcd URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "etcd container exists but is not running"
      echo -e "${YELLOW}etcd is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting etcd containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}etcd has been started for $DOMAIN${NC}"
      echo -e "${CYAN}etcd URL: https://${DOMAIN}${NC}"
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

# Generate self-signed certificates for secure etcd
mkdir -p "${CLIENT_DIR}/etcd/certs"
if [ ! -f "${CLIENT_DIR}/etcd/certs/ca.pem" ]; then
  log "INFO" "Generating TLS certificates for etcd"
  
  # Create temporary directory for certificate generation
  CERT_TEMP_DIR=$(mktemp -d)
  cd "$CERT_TEMP_DIR"
  
  # Generate CA certificate
  openssl genrsa -out ca-key.pem 4096
  openssl req -x509 -new -nodes -key ca-key.pem -days 3650 -out ca.pem -subj "/CN=etcd-ca"
  
  # Generate server certificate
  openssl genrsa -out server-key.pem 4096
  openssl req -new -key server-key.pem -out server.csr -subj "/CN=${DOMAIN}" -config <(
    cat <<EOF
[req]
req_extensions = etcd_ext
distinguished_name = req_distinguished_name

[req_distinguished_name]

[etcd_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = ${ETCD_HOSTNAME}
DNS.3 = ${ETCD_CONTAINER}
DNS.4 = localhost
IP.1 = 127.0.0.1
EOF
  )
  
  openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -days 3650 -extensions etcd_ext -extfile <(
    cat <<EOF
[etcd_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = ${ETCD_HOSTNAME}
DNS.3 = ${ETCD_CONTAINER}
DNS.4 = localhost
IP.1 = 127.0.0.1
EOF
  )
  
  # Generate client certificate
  openssl genrsa -out client-key.pem 4096
  openssl req -new -key client-key.pem -out client.csr -subj "/CN=etcd-client"
  openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client.pem -days 3650
  
  # Copy certificates to etcd directory
  cp ca.pem "${CLIENT_DIR}/etcd/certs/"
  cp server-key.pem "${CLIENT_DIR}/etcd/certs/"
  cp server.pem "${CLIENT_DIR}/etcd/certs/"
  cp client-key.pem "${CLIENT_DIR}/etcd/certs/"
  cp client.pem "${CLIENT_DIR}/etcd/certs/"
  
  # Clean up temporary directory
  cd - > /dev/null
  rm -rf "$CERT_TEMP_DIR"
  
  log "INFO" "TLS certificates generated and stored in ${CLIENT_DIR}/etcd/certs"
fi

# Create Docker Compose file
log "INFO" "Creating Docker Compose configuration"
cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  etcd:
    container_name: ${ETCD_CONTAINER}
    image: bitnami/etcd:${ETCD_VERSION}
    environment:
      - ALLOW_NONE_AUTHENTICATION=no
      - ETCD_ROOT_PASSWORD=${ETCD_ROOT_PASSWORD}
      - ETCD_NAME=${ETCD_NODE_NAME}
      - ETCD_ADVERTISE_CLIENT_URLS=https://0.0.0.0:2379
      - ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
      - ETCD_LISTEN_PEER_URLS=https://0.0.0.0:2380
      - ETCD_INITIAL_ADVERTISE_PEER_URLS=https://0.0.0.0:2380
      - ETCD_INITIAL_CLUSTER=${ETCD_NODE_NAME}=https://0.0.0.0:2380
      - ETCD_INITIAL_CLUSTER_STATE=new
      - ETCD_INITIAL_CLUSTER_TOKEN=${CLIENT_ID}-etcd-cluster
      - ETCD_CERT_FILE=/opt/bitnami/etcd/certs/server.pem
      - ETCD_KEY_FILE=/opt/bitnami/etcd/certs/server-key.pem
      - ETCD_CLIENT_CERT_AUTH=true
      - ETCD_TRUSTED_CA_FILE=/opt/bitnami/etcd/certs/ca.pem
      - ETCD_PEER_CERT_FILE=/opt/bitnami/etcd/certs/server.pem
      - ETCD_PEER_KEY_FILE=/opt/bitnami/etcd/certs/server-key.pem
      - ETCD_PEER_CLIENT_CERT_AUTH=true
      - ETCD_PEER_TRUSTED_CA_FILE=/opt/bitnami/etcd/certs/ca.pem
    volumes:
      - ${CLIENT_DIR}/etcd/data:/bitnami/etcd/data
      - ${CLIENT_DIR}/etcd/certs:/opt/bitnami/etcd/certs
    ports:
      - ${ETCD_CLIENT_PORT}:2379
      - ${ETCD_PEER_PORT}:2380
      - ${ETCD_METRICS_PORT}:2381
    networks:
      - ${NETWORK_NAME}
    healthcheck:
      test: ["CMD", "etcdctl", "--endpoints=https://localhost:2379", "--cacert=/opt/bitnami/etcd/certs/ca.pem", "--cert=/opt/bitnami/etcd/certs/client.pem", "--key=/opt/bitnami/etcd/certs/client-key.pem", "endpoint", "health"]
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-etcd.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-etcd.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-etcd.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-etcd.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-etcd.loadbalancer.server.port=2379"
      - "traefik.http.middlewares.${CLIENT_ID}-etcd-auth.basicauth.users=root:${ETCD_ROOT_PASSWORD}"
      - "traefik.http.routers.${CLIENT_ID}-etcd.middlewares=${CLIENT_ID}-etcd-auth"
      - "traefik.http.middlewares.${CLIENT_ID}-etcd-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-etcd-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-etcd-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-etcd-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-etcd.middlewares=${CLIENT_ID}-etcd-headers"

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
ETCD_VERSION=${ETCD_VERSION}
ETCD_HOSTNAME=${ETCD_HOSTNAME}
ETCD_CLIENT_PORT=${ETCD_CLIENT_PORT}
ETCD_PEER_PORT=${ETCD_PEER_PORT}
ETCD_METRICS_PORT=${ETCD_METRICS_PORT}
ETCD_ROOT_PASSWORD=${ETCD_ROOT_PASSWORD}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Create etcdctl configuration and client script
cat > "${CLIENT_DIR}/etcd/config/etcd.env" << EOF
ETCDCTL_API=3
ETCDCTL_ENDPOINTS=https://${DOMAIN}:${ETCD_CLIENT_PORT}
ETCDCTL_CACERT=${CLIENT_DIR}/etcd/certs/ca.pem
ETCDCTL_CERT=${CLIENT_DIR}/etcd/certs/client.pem
ETCDCTL_KEY=${CLIENT_DIR}/etcd/certs/client-key.pem
ETCDCTL_USER=root:${ETCD_ROOT_PASSWORD}
EOF

# Create client script
cat > "${CLIENT_DIR}/etcd/etcdctl.sh" << EOF
#!/bin/bash
# etcdctl.sh - Configure environment and run etcdctl

# Load etcd environment variables
source ${CLIENT_DIR}/etcd/config/etcd.env

# Execute etcdctl with the provided arguments
etcdctl \$@
EOF
chmod +x "${CLIENT_DIR}/etcd/etcdctl.sh"

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/etcd"
cat > "${CONFIG_DIR}/secrets/etcd/${DOMAIN}.env" << EOF
ETCD_URL=https://${DOMAIN}
ETCD_PORT=${ETCD_CLIENT_PORT}
ETCD_INTERNAL_URL=https://${ETCD_CONTAINER}:2379
ETCD_ROOT_USER=root
ETCD_ROOT_PASSWORD=${ETCD_ROOT_PASSWORD}
EOF

# Start etcd
log "INFO" "Starting etcd"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start etcd"
  exit 1
}

# Wait for etcd to be ready
log "INFO" "Waiting for etcd to be ready"
timeout=120
counter=0
echo -n "Waiting for etcd to start"
while [ $counter -lt $timeout ]; do
  if docker exec ${ETCD_CONTAINER} etcdctl --cacert=/opt/bitnami/etcd/certs/ca.pem --cert=/opt/bitnami/etcd/certs/client.pem --key=/opt/bitnami/etcd/certs/client-key.pem --user root:${ETCD_ROOT_PASSWORD} endpoint health 2>/dev/null | grep -q "is healthy"; then
    break
  fi
  echo -n "."
  sleep 1
  counter=$((counter+1))
done
echo

if [ $counter -ge $timeout ]; then
  log "ERROR" "Timed out waiting for etcd to start"
  exit 1
fi

log "INFO" "etcd is now ready"

# Update installation records
if ! grep -q "etcd" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "etcd" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${ETCD_CLIENT_PORT}" \
       --arg version "${ETCD_VERSION}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.etcd = {
         "name": "etcd",
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
       '.etcd = {
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
echo -e "${GREEN}${BOLD}✅ etcd has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Port: ${ETCD_CLIENT_PORT}${NC}"
echo -e "${CYAN}Version: ${ETCD_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "Username: root"
echo -e "Password: ${ETCD_ROOT_PASSWORD}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/etcd/${DOMAIN}.env${NC}"
echo -e "${CYAN}Client script: ${CLIENT_DIR}/etcd/etcdctl.sh${NC}"
echo -e ""
echo -e "Example usage:"
echo -e "${CYAN}${CLIENT_DIR}/etcd/etcdctl.sh put foo bar${NC}"
echo -e "${CYAN}${CLIENT_DIR}/etcd/etcdctl.sh get foo${NC}"

log "INFO" "etcd installation completed successfully"
exit 0
