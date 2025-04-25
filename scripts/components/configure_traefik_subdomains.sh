#!/bin/bash
# configure_traefik_subdomains.sh - Configure Traefik for local subdomains
# AgencyStack Team

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_CONTAINER_NAME="traefik_${CLIENT_ID}"

# Check if Traefik is running
if ! docker ps | grep -q "${TRAEFIK_CONTAINER_NAME}"; then
  log_error "Traefik container not found: ${TRAEFIK_CONTAINER_NAME}"
  # Try the default name as fallback
  if docker ps | grep -q "traefik_default"; then
    TRAEFIK_CONTAINER_NAME="traefik_default"
    log_info "Using fallback container: ${TRAEFIK_CONTAINER_NAME}"
  else
    log_error "No running Traefik container found. Please start Traefik first."
    exit 1
  fi
fi

# Ensure hosts file has the required entries
log_info "Checking hosts file for required entries"
if ! grep -q "wordpress.localhost" /etc/hosts; then
  log_info "Adding wordpress.localhost to /etc/hosts"
  echo "127.0.0.1 wordpress.localhost" | sudo tee -a /etc/hosts
fi

if ! grep -q "dashboard.localhost" /etc/hosts; then
  log_info "Adding dashboard.localhost to /etc/hosts"
  echo "127.0.0.1 dashboard.localhost" | sudo tee -a /etc/hosts
fi

# Deploy the configuration
log_info "Deploying subdomain configuration to Traefik"
CONFIG_SRC="${SCRIPT_DIR}/../config/traefik/dynamic/subdomains.yml"
CONFIG_DEST="/etc/traefik/dynamic/subdomains.yml"

if [ ! -f "${CONFIG_SRC}" ]; then
  log_error "Configuration file not found: ${CONFIG_SRC}"
  exit 1
fi

# Copy the configuration to the Traefik container
docker cp "${CONFIG_SRC}" "${TRAEFIK_CONTAINER_NAME}:${CONFIG_DEST}"
log_success "Configuration deployed to ${TRAEFIK_CONTAINER_NAME}:${CONFIG_DEST}"

# Update the Nginx container labels for WordPress
if docker ps | grep -q "default_nginx"; then
  log_info "Updating Nginx container labels for WordPress subdomain"
  
  # Add the WordPress subdomain routing label
  docker container update \
    --label-add "traefik.http.routers.wordpress_subdomain.rule=Host(\`wordpress.localhost\`)" \
    --label-add "traefik.http.routers.wordpress_subdomain.entrypoints=websecure" \
    --label-add "traefik.http.routers.wordpress_subdomain.tls=true" \
    default_nginx
    
  log_success "Nginx container labels updated for WordPress subdomain"
else
  log_warning "Nginx container not found, skipping label update"
fi

log_success "Subdomain configuration complete. Please access:"
log_info "WordPress: https://wordpress.localhost"
log_info "Dashboard: https://dashboard.localhost"
log_info "You may need to restart your browser or clear its DNS cache."

# Add to component registry if available
if [ -f "${SCRIPT_DIR}/../utils/update_component_registry.sh" ]; then
  "${SCRIPT_DIR}/../utils/update_component_registry.sh" \
    --component "traefik_subdomains" \
    --category "infrastructure" \
    --description "Traefik subdomain configuration for local development" \
    --set-flag "installed=true" \
    --set-flag "makefile=false"
fi

exit 0
