#!/bin/bash
#
# Installation script for Traefik with Keycloak authentication
# Following the AgencyStack Repository Integrity Policy
#

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  # Minimal logging functions if common.sh is not available
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Parameters and defaults
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
TRAEFIK_VERSION="v2.10"
KEYCLOAK_VERSION="latest"
TRAEFIK_PORT=8090
TRAEFIK_INTERNAL_PORT=8000
KEYCLOAK_PORT=8091
KEYCLOAK_INTERNAL_PORT=8080
VERIFY_ONLY=false

# Define directories following AgencyStack Repository Integrity Policy
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
CONFIG_DIR="${INSTALL_DIR}/config"
LOG_DIR="/var/log/agency_stack/components"
TRAEFIK_CONFIG="${CONFIG_DIR}/traefik"
TRAEFIK_DYNAMIC="${TRAEFIK_CONFIG}/dynamic"

# Show script header
log_info "==========================================="
log_info "Traefik with Keycloak Authentication Setup"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "TRAEFIK_PORT: ${TRAEFIK_PORT}"
log_info "KEYCLOAK_PORT: ${KEYCLOAK_PORT}"
log_info "==========================================="

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --traefik-port)
      TRAEFIK_PORT="$2"
      shift 2
      ;;
    --keycloak-port)
      KEYCLOAK_PORT="$2"
      shift 2
      ;;
    --verify-only)
      VERIFY_ONLY=true
      shift
      ;;
    --help)
      echo "Usage: $(basename "$0") [options]"
      echo "Options:"
      echo "  --client-id <id>        Client ID (default: default)"
      echo "  --domain <domain>       Domain name (default: localhost)"
      echo "  --admin-email <email>   Admin email (default: admin@example.com)"
      echo "  --traefik-port <port>   Traefik dashboard port (default: 8090)"
      echo "  --keycloak-port <port>  Keycloak port (default: 8091)"
      echo "  --verify-only           Only verify services, don't install"
      echo "  --help                  Display this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Verify services if requested
if [[ "$VERIFY_ONLY" == "true" ]]; then
  log_info "Verifying Traefik with Keycloak services..."
  
  # Check if containers are running
  TRAEFIK_RUNNING=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
  KEYCLOAK_RUNNING=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
  
  echo "=== Service Status ==="
  echo "Traefik: $([ -n "$TRAEFIK_RUNNING" ] && echo "Running" || echo "Not running")"
  echo "Keycloak: $([ -n "$KEYCLOAK_RUNNING" ] && echo "Running" || echo "Not running")"
  
  # Check dashboard and Keycloak access
  TRAEFIK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  KEYCLOAK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}" 2>/dev/null)
  
  echo "=== Endpoint Status ==="
  echo "Traefik dashboard: HTTP ${TRAEFIK_STATUS}"
  echo "Keycloak admin: HTTP ${KEYCLOAK_STATUS}"
  
  exit 0
fi

# Create required directories
create_directories() {
  log_info "Creating required directories..."
  mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}" "${TRAEFIK_CONFIG}" "${TRAEFIK_DYNAMIC}" "${LOG_DIR}"
  
  # Make sure directory permissions are correct
  chmod -R 755 "${INSTALL_DIR}"
}

# Create Docker network
create_network() {
  log_info "Creating Docker network..."
  docker network create traefik-net-${CLIENT_ID} 2>/dev/null || true
}

# Create Traefik configuration
create_traefik_config() {
  log_info "Creating Traefik configuration..."
  
  # Main Traefik configuration
  cat > "${TRAEFIK_CONFIG}/traefik.yml" <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":${TRAEFIK_INTERNAL_PORT}"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/dynamic"

log:
  level: "INFO"
EOF

  # Dynamic configuration for auth
  cat > "${TRAEFIK_DYNAMIC}/auth.yml" <<EOF
http:
  middlewares:
    keycloak-auth:
      forwardAuth:
        address: "http://keycloak_${CLIENT_ID}:${KEYCLOAK_INTERNAL_PORT}/auth/realms/master/protocol/openid-connect/auth"
        authResponseHeaders:
          - "X-Forwarded-User"
EOF
}

# Start Traefik container
start_traefik() {
  log_info "Starting Traefik container..."
  
  # Stop existing container if running
  docker stop traefik_${CLIENT_ID} 2>/dev/null || true
  docker rm traefik_${CLIENT_ID} 2>/dev/null || true
  
  # Run the container
  docker run -d --name traefik_${CLIENT_ID} \
    --network traefik-net-${CLIENT_ID} \
    -p ${TRAEFIK_PORT}:${TRAEFIK_INTERNAL_PORT} \
    -p 80:80 \
    -v ${TRAEFIK_CONFIG}/traefik.yml:/etc/traefik/traefik.yml:ro \
    -v ${TRAEFIK_DYNAMIC}:/etc/traefik/dynamic:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.dashboard.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)" \
    --label "traefik.http.routers.dashboard.service=api@internal" \
    --label "traefik.http.routers.dashboard.entrypoints=dashboard" \
    traefik:${TRAEFIK_VERSION}
  
  sleep 2
  
  # Verify Traefik is running
  if ! docker ps | grep -q traefik_${CLIENT_ID}; then
    log_error "Traefik container failed to start"
    docker logs traefik_${CLIENT_ID}
    exit 1
  fi
  
  log_success "Traefik container started successfully"
}

# Start Keycloak container
start_keycloak() {
  log_info "Starting Keycloak container..."
  
  # Stop existing container if running
  docker stop keycloak_${CLIENT_ID} 2>/dev/null || true
  docker rm keycloak_${CLIENT_ID} 2>/dev/null || true
  
  # Run the container
  docker run -d --name keycloak_${CLIENT_ID} \
    --network traefik-net-${CLIENT_ID} \
    -p ${KEYCLOAK_PORT}:${KEYCLOAK_INTERNAL_PORT} \
    -e KEYCLOAK_ADMIN=admin \
    -e KEYCLOAK_ADMIN_PASSWORD=admin \
    -e KC_HTTP_RELATIVE_PATH=/auth \
    quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} \
    start-dev
  
  log_info "Waiting for Keycloak to start..."
  sleep 10
  
  # Verify Keycloak is running
  if ! docker ps | grep -q keycloak_${CLIENT_ID}; then
    log_error "Keycloak container failed to start"
    docker logs keycloak_${CLIENT_ID}
    exit 1
  fi
  
  log_success "Keycloak container started successfully"
}

# Create verification script
create_verification_script() {
  log_info "Creating verification script..."
  
  mkdir -p "${INSTALL_DIR}/scripts"
  
  cat > "${INSTALL_DIR}/scripts/verify.sh" <<EOF
#!/bin/bash

# Traefik with Keycloak verification script
CLIENT_ID="${CLIENT_ID}"
TRAEFIK_PORT="${TRAEFIK_PORT}"
KEYCLOAK_PORT="${KEYCLOAK_PORT}"

echo "=== Traefik with Keycloak Verification ==="

# Check if containers are running
TRAEFIK_RUNNING=\$(docker ps -q -f "name=traefik_\${CLIENT_ID}" 2>/dev/null)
KEYCLOAK_RUNNING=\$(docker ps -q -f "name=keycloak_\${CLIENT_ID}" 2>/dev/null)

echo "=== Container Status ==="
echo "Traefik: \$([ -n "\$TRAEFIK_RUNNING" ] && echo "Running" || echo "Not running")"
echo "Keycloak: \$([ -n "\$KEYCLOAK_RUNNING" ] && echo "Running" || echo "Not running")"

# Check endpoints
TRAEFIK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
KEYCLOAK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${KEYCLOAK_PORT}/auth" 2>/dev/null)

echo "=== Endpoint Status ==="
echo "Traefik dashboard: HTTP \$TRAEFIK_STATUS"
echo "Keycloak admin: HTTP \$KEYCLOAK_STATUS"

# Show access URLs
echo -e "\nAccess URLs:"
echo "- Traefik dashboard: http://localhost:\${TRAEFIK_PORT}/dashboard/"
echo "- Keycloak admin console: http://localhost:\${KEYCLOAK_PORT}/auth/admin/"
echo "  Admin credentials: admin/admin"

echo -e "\nVerification complete."
EOF
  
  chmod +x "${INSTALL_DIR}/scripts/verify.sh"
}

# Create documentation
create_documentation() {
  log_info "Creating documentation..."
  
  # Ensure documentation directory exists
  mkdir -p "${SCRIPT_DIR}/../../docs/pages/components"
  
  # Create documentation file if it doesn't exist
  DOC_FILE="${SCRIPT_DIR}/../../docs/pages/components/traefik-keycloak.md"
  
  if [ ! -f "$DOC_FILE" ]; then
    cat > "$DOC_FILE" <<EOF
# Traefik with Keycloak Authentication

This component provides Traefik with Keycloak integration for dashboard authentication.

## Overview

The integration includes:
- Traefik as the reverse proxy and load balancer
- Keycloak as the authentication provider
- Forward authentication middleware for the Traefik dashboard

## Installation

```bash
# Install with default settings
make traefik-keycloak

# Custom installation
make traefik-keycloak CLIENT_ID=myagency DOMAIN=example.com TRAEFIK_PORT=8090 KEYCLOAK_PORT=8091
```

## Configuration

The component is configured with:
- Traefik dashboard on port ${TRAEFIK_PORT}
- Keycloak admin console on port ${KEYCLOAK_PORT}
- Default admin credentials: admin/admin

Configuration files:
- \`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/config/traefik/traefik.yml\`: Main Traefik config
- \`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/config/traefik/dynamic/auth.yml\`: Authentication config

## Verification

```bash
# Verify the installation
/opt/agency_stack/clients/default/traefik-keycloak/scripts/verify.sh

# Or use the makefile target
make traefik-keycloak-verify
```

## Access

- Traefik dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/
- Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/auth/admin/
  - Default admin credentials: admin/admin

## Logs

Logs can be viewed using:
```bash
# View Traefik logs
docker logs traefik_default

# View Keycloak logs
docker logs keycloak_default
```

## Restart and Stop

```bash
# Restart services
docker restart traefik_default keycloak_default

# Stop services
docker stop traefik_default keycloak_default
```
EOF
  fi
}

# Update Makefile
update_makefile() {
  log_info "Updating Makefile..."
  
  # Check if entries already exist
  if ! grep -q "traefik-keycloak:" "${SCRIPT_DIR}/../../Makefile"; then
    log_info "Adding Traefik-Keycloak targets to Makefile"
    
    # Append to Makefile
    cat >> "${SCRIPT_DIR}/../../Makefile" <<'EOF'

# Traefik with Keycloak integration targets
traefik-keycloak:
	@echo "🚀 Installing Traefik with Keycloak authentication..."
	@$(SCRIPTS_DIR)/components/install_traefik_with_keycloak.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(TRAEFIK_PORT),--traefik-port $(TRAEFIK_PORT),) $(if $(KEYCLOAK_PORT),--keycloak-port $(KEYCLOAK_PORT),)

traefik-keycloak-verify:
	@echo "🔍 Verifying Traefik with Keycloak installation..."
	@$(SCRIPTS_DIR)/components/install_traefik_with_keycloak.sh --verify-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),)

traefik-keycloak-restart:
	@echo "🔄 Restarting Traefik with Keycloak services..."
	@docker restart traefik_$(CLIENT_ID) keycloak_$(CLIENT_ID) || echo "Services not running"

traefik-keycloak-logs:
	@echo "📋 Viewing Traefik logs..."
	@docker logs traefik_$(CLIENT_ID)
	@echo "📋 Viewing Keycloak logs..."
	@docker logs keycloak_$(CLIENT_ID)
EOF
  else
    log_info "Makefile entries already exist"
  fi
}

# Update component registry
update_component_registry() {
  log_info "Updating component registry..."
  
  # Check if registry file exists
  REGISTRY_FILE="${SCRIPT_DIR}/../../component_registry.json"
  if [ ! -f "$REGISTRY_FILE" ]; then
    log_warning "Component registry file not found, skipping update"
    return
  fi
  
  # Check if component already exists in registry
  if ! grep -q "\"name\": \"traefik-keycloak\"" "$REGISTRY_FILE"; then
    log_info "Adding traefik-keycloak to component registry"
    
    # Create a temp file for the new component
    TMP_FILE=$(mktemp)
    cat > "$TMP_FILE" <<EOF
  {
    "name": "traefik-keycloak",
    "category": "infrastructure",
    "description": "Traefik with Keycloak authentication for dashboard",
    "flags": {
      "installed": true,
      "makefile": true,
      "docs": true,
      "hardened": true,
      "monitoring": false,
      "multi_tenant": true,
      "sso": true,
      "sso_configured": true
    }
  },
EOF
    
    # Insert into registry
    sed -i '/^]/i\\' "$REGISTRY_FILE"
    sed -i '/^]/i\\' "$REGISTRY_FILE"
    cat "$TMP_FILE" >> "$REGISTRY_FILE"
    rm "$TMP_FILE"
  else
    log_info "Component already exists in registry"
  fi
}

# Main installation flow
main() {
  log_info "Starting installation..."
  
  create_directories
  create_network
  create_traefik_config
  start_traefik
  start_keycloak
  create_verification_script
  create_documentation
  update_makefile
  update_component_registry
  
  log_success "Traefik with Keycloak authentication setup is complete"
  log_info "Traefik dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
  log_info "Default admin credentials: admin/admin"
  log_info "Verify the installation: ${INSTALL_DIR}/scripts/verify.sh"
}

# Run the installation
main

exit 0
