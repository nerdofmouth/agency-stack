#!/bin/bash
# install_crowdsec.sh - Installation script for CrowdSec
#
# This script installs and configures CrowdSec for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: 2025-04-10

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/crowdsec"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/crowdsec.log"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
CROWDSEC_NETWORK_NAME="agency_stack"

# Parse command-line arguments
FORCE=false
WITH_DEPS=false
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
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
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

log_info "Starting CrowdSec installation..."

# Check if CrowdSec is already installed
if [ -f "${INSTALL_DIR}/.installed" ] && [ "${FORCE}" != "true" ]; then
  log_info "CrowdSec is already installed for client ${CLIENT_ID}."
  log_info "Use --force to reinstall."
  exit 0
fi

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"

# Create Docker network if it doesn't exist
log_cmd "Creating Docker network ${CROWDSEC_NETWORK_NAME}..."
if ! docker network inspect "${CROWDSEC_NETWORK_NAME}" &>/dev/null; then
  docker network create "${CROWDSEC_NETWORK_NAME}" || {
    log_error "Failed to create Docker network: ${CROWDSEC_NETWORK_NAME}"
    exit 1
  }
  log_success "Created Docker network: ${CROWDSEC_NETWORK_NAME}"
else
  log_info "Docker network ${CROWDSEC_NETWORK_NAME} already exists"
fi

# Create CrowdSec configuration files
log_cmd "Creating CrowdSec configuration files..."

# Create local API credentials
CROWDSEC_LOCAL_API_KEY=$(openssl rand -hex 32)
log_info "Generated local API key for CrowdSec"

# Create online API credentials if not in local mode
if [[ "${DOMAIN}" != "localhost" ]]; then
  CROWDSEC_ONLINE_API_KEY=$(openssl rand -hex 32)
  log_info "Generated online API key for CrowdSec dashboard"
else
  CROWDSEC_ONLINE_API_KEY="local-mode-no-online-api"
  log_info "Running in local mode, no online API key generated"
fi

# Create config.yaml for CrowdSec
cat > "${CONFIG_DIR}/config.yaml" <<EOF
common:
  log_media: file
  log_level: info
  log_dir: /var/log/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  pid_dir: /var/run/

config_paths:
  config_dir: /etc/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  simulation_path: /etc/crowdsec/simulation.yaml
  hub_dir: /etc/crowdsec/hub/
  index_path: /etc/crowdsec/hub/.index.json

crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  parser_routines: 1

db_config:
  type: sqlite
  db_path: /var/lib/crowdsec/data/crowdsec.db

api:
  server:
    listen_uri: 0.0.0.0:8080
    profiles_path: /etc/crowdsec/profiles.yaml
    online_client:
      credentials_path: /etc/crowdsec/online_api_credentials.yaml

  client:
    insecure_skip_verify: false
    credentials_path: /etc/crowdsec/local_api_credentials.yaml
EOF

# Create acquis.yaml for log acquisition
cat > "${CONFIG_DIR}/acquis.yaml" <<EOF
filenames:
  - /var/log/auth.log
  - /var/log/syslog
  - /var/log/nginx/*.log
  - /var/log/apache2/*.log
labels:
  type: syslog
---
filenames:
  - /var/log/docker/containers/*/*.log
labels:
  type: docker
EOF

# Create local API credentials file
cat > "${CONFIG_DIR}/local_api_credentials.yaml" <<EOF
url: http://localhost:8080/
login: admin
password: ${CROWDSEC_LOCAL_API_KEY}
EOF

# Create online API credentials file
cat > "${CONFIG_DIR}/online_api_credentials.yaml" <<EOF
url: https://api.crowdsec.net/
login: ${ADMIN_EMAIL}
password: ${CROWDSEC_ONLINE_API_KEY}
EOF

# Create profiles.yaml for scenario configuration
cat > "${CONFIG_DIR}/profiles.yaml" <<EOF
name: default_ip_remediation
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
 - type: ban
   duration: 4h
on_success: break
---
name: default_username_remediation
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Username"
decisions:
 - type: ban
   duration: 4h
on_success: break
EOF

# Create bouncer configuration for Traefik
cat > "${CONFIG_DIR}/bouncer_traefik.yaml" <<EOF
api_url: http://crowdsec:8080/
api_key: ${CROWDSEC_LOCAL_API_KEY}
update_frequency: 10s
log_level: info
EOF

# Create docker-compose.yml
log_cmd "Creating CrowdSec docker-compose.yml..."
cat > "${DOCKER_COMPOSE_FILE}" <<EOF
version: '3'

services:
  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec_${CLIENT_ID}
    environment:
      - GID=1000
      - COLLECTIONS=crowdsecurity/apache2 crowdsecurity/nginx crowdsecurity/linux crowdsecurity/traefik
    restart: always
    volumes:
      - ${CONFIG_DIR}/config.yaml:/etc/crowdsec/config.yaml
      - ${CONFIG_DIR}/acquis.yaml:/etc/crowdsec/acquis.yaml
      - ${CONFIG_DIR}/local_api_credentials.yaml:/etc/crowdsec/local_api_credentials.yaml
      - ${CONFIG_DIR}/online_api_credentials.yaml:/etc/crowdsec/online_api_credentials.yaml
      - ${CONFIG_DIR}/profiles.yaml:/etc/crowdsec/profiles.yaml
      - ${DATA_DIR}:/var/lib/crowdsec/data
      - /var/log:/var/log:ro
      - /var/log/auth.log:/var/log/auth.log:ro
      - /var/log/syslog:/var/log/syslog:ro
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - ${CROWDSEC_NETWORK_NAME}

  crowdsec-traefik-bouncer:
    image: fbonalair/traefik-crowdsec-bouncer:latest
    container_name: crowdsec-traefik-bouncer_${CLIENT_ID}
    restart: always
    environment:
      - CROWDSEC_BOUNCER_API_KEY=${CROWDSEC_LOCAL_API_KEY}
      - CROWDSEC_AGENT_HOST=crowdsec:8080
    depends_on:
      - crowdsec
    networks:
      - ${CROWDSEC_NETWORK_NAME}

  crowdsec-dashboard:
    image: crowdsecurity/crowdsec-dashboard:latest
    container_name: crowdsec-dashboard_${CLIENT_ID}
    restart: always
    ports:
      - "127.0.0.1:8082:8080"
    environment:
      - CROWDSEC_URL=http://crowdsec:8080
      - CROWDSEC_LOGIN=admin
      - CROWDSEC_PASSWORD=${CROWDSEC_LOCAL_API_KEY}
    depends_on:
      - crowdsec
    networks:
      - ${CROWDSEC_NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.crowdsec.rule=Host(\`crowdsec.${DOMAIN}\`)"
      - "traefik.http.routers.crowdsec.entrypoints=websecure"
      - "traefik.http.routers.crowdsec.tls=true"
      - "traefik.http.routers.crowdsec.tls.certresolver=letsencrypt"
      - "traefik.http.services.crowdsec.loadbalancer.server.port=8080"

networks:
  ${CROWDSEC_NETWORK_NAME}:
    external: true
EOF

# Start CrowdSec
if [ "$DRY_RUN" = false ]; then
  log_cmd "Starting CrowdSec..."
  cd "${INSTALL_DIR}" || exit 1
  docker-compose up -d || {
    log_error "Failed to start CrowdSec"
    exit 1
  }
  
  # Verify CrowdSec is running
  if docker ps | grep -q "crowdsec_${CLIENT_ID}"; then
    log_success "CrowdSec is running"
  else
    log_error "Failed to start CrowdSec container"
    exit 1
  fi
  
  # Create installation marker
  touch "${INSTALL_DIR}/.installed"
  
  log_success "CrowdSec installation completed successfully!"
  log_info "CrowdSec dashboard available at: https://crowdsec.${DOMAIN}"
  log_info "Local API credentials saved to: ${CONFIG_DIR}/local_api_credentials.yaml"
else
  log_info "Dry run mode: Skipping CrowdSec startup"
fi

exit 0
