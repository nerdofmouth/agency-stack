#!/bin/bash
# reset_traefik_dashboard_password.sh - Reset Traefik dashboard credentials
# AgencyStack Team

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"
source "${SCRIPT_DIR}/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
TRAEFIK_CONTAINER_NAME="traefik_${CLIENT_ID}"
NEW_PASSWORD="${1:-admin}"  # Default password is 'admin' if not provided

# Check if htpasswd is available
if ! command -v htpasswd &> /dev/null; then
    log_info "Installing apache2-utils to use htpasswd..."
    apt-get update -q
    apt-get install -y apache2-utils
fi

# Generate hashed password
HASHED_PASSWORD=$(htpasswd -nbB admin "${NEW_PASSWORD}")
# Escape $ for use in sed
ESCAPED_HASH=$(echo "${HASHED_PASSWORD}" | sed 's/\$/\\\$/g')

# Update dashboard.yml in repository first (respecting the repository integrity policy)
DASHBOARD_YML="${SCRIPT_DIR}/../config/traefik/dynamic/dashboard.yml"

# Create directory if it doesn't exist
mkdir -p "$(dirname "${DASHBOARD_YML}")"

# Create or update dashboard.yml with correct auth
cat > "${DASHBOARD_YML}" <<EOL
http:
  routers:
    dashboard:
      rule: "Host(\`localhost\`) && (PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`))"
      service: "api@internal"
      entrypoints:
        - "websecure"
      middlewares:
        - "auth"
      tls: {}

  middlewares:
    auth:
      basicAuth:
        users:
          - "${HASHED_PASSWORD}"
EOL

log_success "Updated dashboard.yml in repository"

# Now update the client configuration directory
if [ -d "${TRAEFIK_CONFIG_DIR}" ]; then
    cp "${DASHBOARD_YML}" "${TRAEFIK_CONFIG_DIR}/dynamic/dashboard.yml"
    log_success "Updated dashboard.yml in client configuration directory"
else
    log_warning "Client configuration directory not found: ${TRAEFIK_CONFIG_DIR}"
fi

# Restart Traefik container if it exists
if docker ps | grep -q "${TRAEFIK_CONTAINER_NAME}"; then
    log_info "Restarting Traefik container..."
    docker restart "${TRAEFIK_CONTAINER_NAME}"
    log_success "Traefik container restarted with new credentials"
    log_info "Username: admin"
    log_info "Password: ${NEW_PASSWORD}"
else
    log_warning "Traefik container not found: ${TRAEFIK_CONTAINER_NAME}"
fi

log_success "Traefik dashboard credentials have been reset."
log_info "Use the following credentials to login:"
log_info "Username: admin"
log_info "Password: ${NEW_PASSWORD}"

exit 0
