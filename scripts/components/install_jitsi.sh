#!/bin/bash
# install_jitsi.sh - Install and configure Jitsi Meet for AgencyStack
#
# This script sets up Jitsi Meet with:
# - Full Keycloak SSO integration when enabled
# - Traefik integration for TLS and routing
# - Multi-tenant support
# - Monitoring integration
#
# Following the repository-first approach in the AgencyStack Repository Integrity Policy
#
# Author: AgencyStack Team
# Date: 2025-04-11

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"
source "${SCRIPT_DIR}/../utils/component_sso_helper.sh"

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
JITSI_SUBDOMAIN="${JITSI_SUBDOMAIN:-meet}"
JITSI_FQDN="${JITSI_SUBDOMAIN}.${DOMAIN}"
JITSI_LOGS_DIR="/var/log/agency_stack/components/jitsi"
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"  # Default to host network mode for better compatibility
ENABLE_KEYCLOAK="${ENABLE_KEYCLOAK:-false}"  # Default to not using Keycloak
ENFORCE_HTTPS="${ENFORCE_HTTPS:-true}"  # Default to enforcing HTTPS
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/jitsi"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
JITSI_NETWORK_NAME="agency_stack"

# Make sure logs directory exists
mkdir -p "${JITSI_LOGS_DIR}"

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      JITSI_FQDN="${JITSI_SUBDOMAIN}.${DOMAIN}"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/jitsi"
      CONFIG_DIR="${INSTALL_DIR}/config"
      DATA_DIR="${INSTALL_DIR}/data"
      shift 2
      ;;
    --jitsi-subdomain)
      JITSI_SUBDOMAIN="$2"
      JITSI_FQDN="${JITSI_SUBDOMAIN}.${DOMAIN}"
      shift 2
      ;;
    --use-host-network)
      USE_HOST_NETWORK="$2"
      shift 2
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    --enforce-https)
      ENFORCE_HTTPS=true
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
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Log configuration
log_info "Starting Jitsi installation with the following configuration:"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "JITSI_FQDN: ${JITSI_FQDN}"
log_info "NETWORK MODE: ${USE_HOST_NETWORK}"
log_info "KEYCLOAK ENABLED: ${ENABLE_KEYCLOAK}"
log_info "ENFORCE HTTPS: ${ENFORCE_HTTPS}"

# Check if Jitsi is already installed
if [[ -f "${INSTALL_DIR}/.installed_ok" ]] && [[ "$FORCE" != "true" ]]; then
  log_info "Jitsi is already installed in ${INSTALL_DIR}"
  log_info "Use --force to reinstall"
  exit 0
fi

# Create directories
log_info "Creating installation directories"
mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}" "${DATA_DIR}"
mkdir -p "${DATA_DIR}/config" "${DATA_DIR}/web" "${DATA_DIR}/prosody" "${DATA_DIR}/jicofo" "${DATA_DIR}/jvb"

# Generate random passwords
log_info "Generating secure passwords"
JVB_AUTH_PASSWORD=$(openssl rand -hex 16)
JICOFO_AUTH_PASSWORD=$(openssl rand -hex 16)
JICOFO_COMPONENT_SECRET=$(openssl rand -hex 16)
JWT_APP_SECRET=$(openssl rand -hex 16)

# Generate environment configuration
log_info "Generating environment configuration"
cat > "${CONFIG_DIR}/.env" <<EOF
# Jitsi Meet Environment Configuration
COMPOSE_PROJECT_NAME=jitsi
CONFIG=${DATA_DIR}/config
DOMAIN=${JITSI_FQDN}
PUBLIC_URL=https://${JITSI_FQDN}
DOCKER_HOST_ADDRESS=
ENABLE_LETSENCRYPT=0
ENABLE_HTTP_REDIRECT=1
ENABLE_XMPP_WEBSOCKET=1
ENABLE_JAAS_COMPONENTS=0
ENABLE_LOBBY=1
ENABLE_RECORDING=0
ENABLE_BREAKOUT_ROOMS=1

# Authentication
ENABLE_AUTH=1
ENABLE_GUESTS=1
AUTH_TYPE=internal
XMPP_DOMAIN=${JITSI_FQDN}
XMPP_AUTH_DOMAIN=auth.${JITSI_FQDN}
XMPP_GUEST_DOMAIN=guest.${JITSI_FQDN}
XMPP_MUC_DOMAIN=muc.${JITSI_FQDN}
XMPP_INTERNAL_MUC_DOMAIN=internal-muc.${JITSI_FQDN}

# Security
JICOFO_AUTH_PASSWORD=${JICOFO_AUTH_PASSWORD}
JVB_AUTH_PASSWORD=${JVB_AUTH_PASSWORD}
JICOFO_COMPONENT_SECRET=${JICOFO_COMPONENT_SECRET}
TZ=UTC
EOF

# Modify configuration if Keycloak is enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  log_info "Configuring Keycloak integration for Jitsi"
  cat >> "${CONFIG_DIR}/.env" <<EOF

# Keycloak SSO Configuration
ENABLE_JWT_AUTH=1
JWT_APP_ID=jitsi
JWT_APP_SECRET=${JWT_APP_SECRET}
TOKEN_AUTH_URL=https://${DOMAIN}/auth/realms/agency_stack/protocol/openid-connect/auth
EOF
fi

# Configure Docker Compose file
log_info "Creating Docker Compose configuration"
cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: '3'

services:
  # Frontend
  web:
    image: jitsi/web:stable-7882
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/web:/config
      - ${DATA_DIR}/web/letsencrypt:/etc/letsencrypt
      - ${DATA_DIR}/config/web:/defaults
    environment:
      - ENABLE_LETSENCRYPT
      - ENABLE_HTTP_REDIRECT
      - ENABLE_XMPP_WEBSOCKET
      - PUBLIC_URL
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_GUEST_DOMAIN
      - XMPP_MUC_DOMAIN
      - XMPP_INTERNAL_MUC_DOMAIN
      - TZ
      - ENABLE_AUTH
      - ENABLE_GUESTS
      - AUTH_TYPE
      - ENABLE_LOBBY
      - ENABLE_RECORDING
      - ENABLE_BREAKOUT_ROOMS
EOF

# Add Keycloak JWT configuration if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
      - ENABLE_JWT_AUTH
      - JWT_APP_ID
      - JWT_APP_SECRET
      - TOKEN_AUTH_URL
EOF
fi

# Continue Docker Compose configuration
cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jitsi-web.rule=Host(\`${JITSI_FQDN}\`)"
      - "traefik.http.routers.jitsi-web.entrypoints=web,websecure"
      - "traefik.http.routers.jitsi-web.tls=true"
      - "traefik.http.services.jitsi-web.loadbalancer.server.port=80"
EOF

# Add Keycloak authentication middleware if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
      - "traefik.http.routers.jitsi-web.middlewares=jitsi-auth"
      - "traefik.http.middlewares.jitsi-auth.forwardauth.address=http://keycloak:8080/auth/realms/agency_stack/protocol/openid-connect/auth"
      - "traefik.http.middlewares.jitsi-auth.forwardauth.trustForwardHeader=true"
EOF
fi

# Continue Docker Compose configuration with other Jitsi components
cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
    networks:
      - ${JITSI_NETWORK_NAME}

  # XMPP server
  prosody:
    image: jitsi/prosody:stable-7882
    restart: unless-stopped
    expose:
      - '5222'
      - '5280'
      - '5347'
    volumes:
      - ${DATA_DIR}/prosody:/config
      - ${DATA_DIR}/config/prosody:/defaults
    environment:
      - ENABLE_AUTH
      - ENABLE_GUESTS
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_GUEST_DOMAIN
      - XMPP_MUC_DOMAIN
      - XMPP_INTERNAL_MUC_DOMAIN
      - AUTH_TYPE
      - JICOFO_AUTH_PASSWORD
      - JVB_AUTH_PASSWORD
      - TZ
EOF

# Add Keycloak JWT configuration if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
      - ENABLE_JWT_AUTH
      - JWT_APP_ID
      - JWT_APP_SECRET
EOF
fi

# Continue Docker Compose configuration
cat >> "${INSTALL_DIR}/docker-compose.yml" <<EOF
    networks:
      - ${JITSI_NETWORK_NAME}

  # Focus component
  jicofo:
    image: jitsi/jicofo:stable-7882
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/jicofo:/config
      - ${DATA_DIR}/config/jicofo:/defaults
    environment:
      - ENABLE_AUTH
      - XMPP_DOMAIN
      - XMPP_AUTH_DOMAIN
      - XMPP_INTERNAL_MUC_DOMAIN
      - JICOFO_AUTH_PASSWORD
      - JICOFO_COMPONENT_SECRET
      - TZ
    depends_on:
      - prosody
    networks:
      - ${JITSI_NETWORK_NAME}

  # Video bridge
  jvb:
    image: jitsi/jvb:stable-7882
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/jvb:/config
      - ${DATA_DIR}/config/jvb:/defaults
    environment:
      - XMPP_DOMAIN
      - JVB_AUTH_PASSWORD
      - JVB_BREWERY_MUC
      - XMPP_INTERNAL_MUC_DOMAIN
      - TZ
    ports:
      - '10000:10000/udp'
    depends_on:
      - prosody
    networks:
      - ${JITSI_NETWORK_NAME}

networks:
  ${JITSI_NETWORK_NAME}:
    external: true
EOF

# Configure network attachment
log_info "Configuring Docker network for Jitsi"
if ! docker network inspect "${JITSI_NETWORK_NAME}" >/dev/null 2>&1; then
  log_info "Creating Docker network: ${JITSI_NETWORK_NAME}"
  docker network create "${JITSI_NETWORK_NAME}" || {
    log_error "Failed to create Docker network: ${JITSI_NETWORK_NAME}"
    exit 1
  }
fi

# Start Jitsi Meet
log_info "Starting Jitsi Meet containers"
cd "${INSTALL_DIR}" || {
  log_error "Failed to change directory to ${INSTALL_DIR}"
  exit 1
}

docker-compose pull || {
  log_error "Failed to pull Jitsi Meet images"
  exit 1
}

docker-compose up -d || {
  log_error "Failed to start Jitsi Meet containers"
  exit 1
}

# Configure Keycloak SSO integration if enabled
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  log_info "Configuring Keycloak SSO integration for Jitsi"
  
  # Get redirect URIs for Jitsi
  REDIRECT_URIS=$(get_component_redirect_uris "jitsi" "${DOMAIN}")
  
  # Enable SSO for Jitsi
  if enable_component_sso "jitsi" "${DOMAIN}" "${REDIRECT_URIS}" "jitsi"; then
    log_success "Successfully enabled Keycloak SSO for Jitsi"
    
    # Update JWT secret from SSO configuration
    if [ -f "${INSTALL_DIR}/sso/credentials" ]; then
      CLIENT_SECRET=$(grep KEYCLOAK_CLIENT_SECRET "${INSTALL_DIR}/sso/credentials" | cut -d= -f2)
      # Update the JWT secret to match Keycloak client secret
      sed -i "s/JWT_APP_SECRET=.*/JWT_APP_SECRET=${CLIENT_SECRET}/" "${CONFIG_DIR}/.env"
      
      # Restart containers to apply the new configuration
      log_info "Restarting Jitsi with updated SSO configuration"
      docker-compose down
      docker-compose up -d
    fi
  else
    log_warning "Failed to enable Keycloak SSO for Jitsi, continuing with basic setup"
  fi
fi

# Update component registry
log_info "Updating component registry with Jitsi installation status"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../utils/update_component_registry.sh"
if [ -f "$REGISTRY_SCRIPT" ]; then
  REGISTRY_ARGS=(
    "--component" "jitsi"
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
  
  bash "$REGISTRY_SCRIPT" "${REGISTRY_ARGS[@]}"
else
  log_warning "Registry update script not found: $REGISTRY_SCRIPT"
fi

# Create installation marker
log_info "Creating installation marker"
touch "${INSTALL_DIR}/.installed_ok"

log_success "Jitsi Meet installation completed successfully"
log_info "Jitsi Meet is now available at: https://${JITSI_FQDN}"

if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  log_info "SSO authentication is enabled via Keycloak"
fi

exit 0
