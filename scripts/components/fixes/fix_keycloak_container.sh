#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: fix_keycloak_container.sh
# Path: /scripts/components/fix_keycloak_container.sh
#
set -e

# Source common utilities

# Default settings
DOMAIN=""
CLIENT_ID="default"
KEYCLOAK_DIR="/opt/agency_stack/keycloak"
VERBOSE=false
FORCE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --domain DOMAIN         Domain name for Keycloak instance"
      echo "  --client-id CLIENT_ID   Client ID (default: default)"
      echo "  --force                 Force update even if not needed"
      echo "  --verbose               Show verbose output"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if domain is provided
if [[ -z "$DOMAIN" ]]; then
  log_error "No domain specified. Use --domain option."
  exit 1

log_info "==================================================="
log_info "Starting fix_keycloak_container.sh"
log_info "CLIENT_ID: $CLIENT_ID"
log_info "DOMAIN: $DOMAIN"
log_info "==================================================="

# Check if Keycloak is installed
if [[ ! -d "${KEYCLOAK_DIR}/${DOMAIN}" ]]; then
  log_error "Keycloak not installed for domain: $DOMAIN"
  exit 1

# Backup the existing docker-compose file
COMPOSE_FILE="${KEYCLOAK_DIR}/${DOMAIN}/docker-compose.yml"
BACKUP_FILE="${KEYCLOAK_DIR}/${DOMAIN}/docker-compose.yml.backup-$(date +%Y%m%d%H%M%S)"

if [[ -f "$COMPOSE_FILE" ]]; then
  log_info "Backing up existing docker-compose.yml to $BACKUP_FILE"
  cp "$COMPOSE_FILE" "$BACKUP_FILE"

# Get environment variables from the current docker-compose file
log_info "Extracting environment variables from current configuration"
DB_PASSWORD=$(grep -A1 "POSTGRES_PASSWORD:" "$COMPOSE_FILE" | tail -n1 | awk '{print $1}')
ADMIN_PASSWORD=$(grep -A1 "KEYCLOAK_PASSWORD:" "$COMPOSE_FILE" | tail -n1 | awk '{print $1}')

# Create new docker-compose file
log_info "Creating updated docker-compose.yml for Keycloak 21.x"
cat > "$COMPOSE_FILE" << EOF
version: '3.7'

services:
  postgres:
    image: postgres:13-alpine
    container_name: keycloak_postgres_${DOMAIN}
    restart: unless-stopped
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    networks:
      - agency-network

  keycloak:
    image: quay.io/keycloak/keycloak:21.1.2
    container_name: keycloak_${DOMAIN}
    restart: unless-stopped
    command: ["start-dev", "--http-relative-path=/auth"]
    environment:
      KC_DB: postgres
      KC_DB_URL_HOST: postgres
      KC_DB_URL_DATABASE: keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${DB_PASSWORD}
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
      KC_PROXY: edge
      KC_HOSTNAME_URL: https://${DOMAIN}/auth
      KC_HOSTNAME_ADMIN_URL: https://${DOMAIN}/auth
    volumes:
      - ${KEYCLOAK_DIR}/${DOMAIN}/keycloak-data:/opt/keycloak/data
      - ${KEYCLOAK_DIR}/${DOMAIN}/themes:/opt/keycloak/themes
      - ${KEYCLOAK_DIR}/${DOMAIN}/imports:/opt/keycloak/imports
    depends_on:
      - postgres
    networks:
      - agency-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak_${DOMAIN}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.keycloak_${DOMAIN}.entrypoints=websecure"
      - "traefik.http.routers.keycloak_${DOMAIN}.tls.certresolver=myresolver"
      - "traefik.http.services.keycloak_${DOMAIN}.loadbalancer.server.port=8080"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.browserXssFilter=true"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.stsPreload=true"
      - "traefik.http.middlewares.keycloak_${DOMAIN}_security.headers.stsSeconds=31536000"
      - "traefik.http.routers.keycloak_${DOMAIN}.middlewares=keycloak_${DOMAIN}_security"

networks:
  agency-network:
    external: true
EOF

log_info "Ensuring proper directory structure for new Keycloak container"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/keycloak-data"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/themes"
mkdir -p "${KEYCLOAK_DIR}/${DOMAIN}/imports"

# Restart Keycloak services
log_info "Restarting Keycloak services"
cd "${KEYCLOAK_DIR}/${DOMAIN}"
docker-compose down
docker-compose up -d

# Wait for Keycloak to start
log_info "Waiting for Keycloak to start (this may take a few minutes)"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker logs keycloak_${DOMAIN} 2>&1 | grep -q "Started"; then
    log_success "Keycloak started successfully!"
    break
  fi
  
  log_info "Waiting for Keycloak to start... (${RETRY_COUNT}/${MAX_RETRIES})"
  RETRY_COUNT=$((RETRY_COUNT + 1))
  sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  log_error "Keycloak failed to start within the expected time. Please check logs."
  docker logs keycloak_${DOMAIN} | tail -n 50
  exit 1

log_success "Keycloak container fix has been completed and service restarted"
log_info "You can access the Keycloak admin console at: https://${DOMAIN}/auth"
log_success "Script completed successfully"
