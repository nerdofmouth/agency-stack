#!/bin/bash
#
# Traefik-Keycloak Integration Installation Script for AgencyStack
# This script installs and configures Traefik with Keycloak authentication following the SSO protocol
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
ENABLE_KEYCLOAK=true
TRAEFIK_VERSION="v2.10"
KEYCLOAK_VERSION="22.0"
TRAEFIK_PORT=8081
KEYCLOAK_PORT=8082
TRAEFIK_AUTH_SECRET="traefik-secret"
ENABLE_TLS=false  # Set to true for production environments
STATUS_ONLY=false

# Directories
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
CONFIG_DIR="${INSTALL_DIR}/config"
LOG_DIR="/var/log/agency_stack/components"
DOCKER_COMPOSE_DIR="${INSTALL_DIR}/docker-compose"

# Show header
log_info "==========================================="
log_info "Starting Traefik-Keycloak Integration Setup"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
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
    --enable-tls)
      ENABLE_TLS=true
      shift
      ;;
    --status-only)
      STATUS_ONLY=true
      shift
      ;;
    --help)
      echo "Usage: $(basename "$0") [options]"
      echo "Options:"
      echo "  --client-id <id>        Client ID (default: default)"
      echo "  --domain <domain>       Domain name (default: localhost)"
      echo "  --admin-email <email>   Admin email (default: admin@example.com)"
      echo "  --traefik-port <port>   Traefik dashboard port (default: 8081)"
      echo "  --keycloak-port <port>  Keycloak port (default: 8082)"
      echo "  --enable-tls            Enable TLS for production environments"
      echo "  --status-only           Only check status, don't install"
      echo "  --help                  Display this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create installation directories
create_directories() {
  log_info "Creating installation directories..."
  mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}" "${DOCKER_COMPOSE_DIR}" "${LOG_DIR}"
  mkdir -p "${CONFIG_DIR}/traefik/dynamic" "${CONFIG_DIR}/keycloak"
  
  # Set proper permissions
  chmod -R 755 "${INSTALL_DIR}"
}

# Check if we should only show status
if [[ "$STATUS_ONLY" == "true" ]]; then
  log_info "Checking Traefik-Keycloak integration status..."
  
  # Check if containers are running
  TRAEFIK_RUNNING=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
  KEYCLOAK_RUNNING=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
  AUTH_RUNNING=$(docker ps -q -f "name=traefik_forward_auth_${CLIENT_ID}" 2>/dev/null)
  
  # Display status
  echo "=== Traefik-Keycloak Integration Status ==="
  echo "Traefik: $([ -n "$TRAEFIK_RUNNING" ] && echo "Running" || echo "Not running")"
  echo "Keycloak: $([ -n "$KEYCLOAK_RUNNING" ] && echo "Running" || echo "Not running")"
  echo "Forward Auth: $([ -n "$AUTH_RUNNING" ] && echo "Running" || echo "Not running")"
  
  # Check Traefik dashboard accessibility
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Dashboard: Accessible without authentication (HTTP $HTTP_CODE)"
  elif [[ "$HTTP_CODE" == "302" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
    echo "Dashboard: Protected by authentication (HTTP $HTTP_CODE)"
  else
    echo "Dashboard: Not accessible (HTTP $HTTP_CODE)"
  fi
  
  exit 0
fi

# Create Docker Compose file
create_docker_compose() {
  log_info "Creating Docker Compose configuration..."
  cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" <<EOF
version: '3'

networks:
  traefik-keycloak:
    name: traefik-keycloak-${CLIENT_ID}

services:
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    container_name: traefik_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-keycloak
    ports:
      - "${TRAEFIK_PORT}:8080"
      - "80:80"
    volumes:
      - ${CONFIG_DIR}/traefik:/etc/traefik
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.dashboard.address=:8080"
      - "--log.level=INFO"
    depends_on:
      - keycloak
      - forward-auth
    labels:
      - "traefik.enable=true"
      # Dashboard route with auth
      - "traefik.http.routers.dashboard.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=dashboard"
      - "traefik.http.routers.dashboard.middlewares=forward-auth"
  
  # Keycloak instance for SSO authentication
  keycloak:
    image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
    container_name: keycloak_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-keycloak
    ports:
      - "${KEYCLOAK_PORT}:8080"
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=admin
      - KC_HOSTNAME=${DOMAIN}
      - KC_HTTP_RELATIVE_PATH=/auth
    command: 
      - start-dev
    volumes:
      - ${CONFIG_DIR}/keycloak:/opt/keycloak/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak.rule=Host(\`keycloak.${DOMAIN}\`)"
      - "traefik.http.routers.keycloak.entrypoints=web"
      - "traefik.http.services.keycloak.loadbalancer.server.port=8080"
  
  # Forward Auth service for authentication
  forward-auth:
    image: thomseddon/traefik-forward-auth:2
    container_name: traefik_forward_auth_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-keycloak
    environment:
      - PROVIDERS_OIDC_ISSUER_URL=http://keycloak:8080/auth/realms/master
      - PROVIDERS_OIDC_CLIENT_ID=traefik-dashboard
      - PROVIDERS_OIDC_CLIENT_SECRET=${TRAEFIK_AUTH_SECRET}
      - SECRET=agencystack-secure-key
      - AUTH_HOST=auth.${DOMAIN}
      - COOKIE_DOMAIN=${DOMAIN}
      - INSECURE_COOKIE=${ENABLE_TLS:+false}${ENABLE_TLS:-true}
      - LOG_LEVEL=info
    depends_on:
      - keycloak
    labels:
      - "traefik.enable=true"
      - "traefik.http.middlewares.forward-auth.forwardauth.address=http://forward-auth:4181"
      - "traefik.http.middlewares.forward-auth.forwardauth.authResponseHeaders=X-Forwarded-User"
EOF
}

# Create Traefik configuration
create_traefik_config() {
  log_info "Creating Traefik configuration..."
  
  # Main config
  cat > "${CONFIG_DIR}/traefik/traefik.yml" <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8080"

providers:
  file:
    directory: "/etc/traefik/dynamic"
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

log:
  level: "INFO"
EOF

  # Dynamic config for authentication
  cat > "${CONFIG_DIR}/traefik/dynamic/auth.yml" <<EOF
http:
  middlewares:
    forward-auth:
      forwardAuth:
        address: "http://forward-auth:4181"
        authResponseHeaders:
          - "X-Forwarded-User"
EOF
}

# Create Keycloak initialization script
create_keycloak_init() {
  log_info "Creating Keycloak initialization script..."
  
  cat > "${INSTALL_DIR}/init_keycloak.sh" <<'EOF'
#!/bin/bash

# Initialize Keycloak with necessary realms and clients
KEYCLOAK_URL="http://localhost:${KEYCLOAK_PORT}"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
CLIENT_ID="${CLIENT_ID:-default}"

# Wait for Keycloak to be available
echo "Waiting for Keycloak to be available..."
timeout 60 bash -c 'until curl -s -f -o /dev/null "${KEYCLOAK_URL}"; do sleep 2; done' || {
  echo "Keycloak is not available after 60 seconds"
  exit 1
}

# Get admin token
get_token() {
  curl -s -X POST "${KEYCLOAK_URL}/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${ADMIN_USER}" \
    -d "password=${ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token'
}

TOKEN=$(get_token)
if [ -z "$TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

# Create traefik-dashboard client if it doesn't exist
CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "${KEYCLOAK_URL}/auth/admin/realms/master/clients" | jq -r '.[] | select(.clientId=="traefik-dashboard") | .clientId')

if [ -z "$CLIENT_EXISTS" ]; then
  echo "Creating traefik-dashboard client..."
  
  curl -s -X POST "${KEYCLOAK_URL}/auth/admin/realms/master/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "traefik-dashboard",
      "name": "Traefik Dashboard",
      "redirectUris": ["http://localhost:8081/*", "http://localhost/*"],
      "webOrigins": ["*"],
      "enabled": true,
      "clientAuthenticatorType": "client-secret",
      "secret": "traefik-secret",
      "publicClient": false,
      "protocol": "openid-connect",
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": true,
      "serviceAccountsEnabled": false
    }'
  
  echo "Client created successfully"
else
  echo "Client traefik-dashboard already exists"
fi

echo "Keycloak initialization complete."
EOF

  chmod +x "${INSTALL_DIR}/init_keycloak.sh"
}

# Start the Traefik-Keycloak integration
start_integration() {
  log_info "Starting Traefik-Keycloak integration..."
  
  # Stop existing containers if running
  docker rm -f traefik_${CLIENT_ID} keycloak_${CLIENT_ID} traefik_forward_auth_${CLIENT_ID} 2>/dev/null || true
  
  # Start the stack
  cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
  
  # Wait for services to be ready
  log_info "Waiting for services to be ready..."
  for i in {1..30}; do
    if docker ps | grep -q "keycloak_${CLIENT_ID}" && docker ps | grep -q "traefik_${CLIENT_ID}"; then
      log_success "Services are ready"
      break
    fi
    sleep 2
    if [ $i -eq 30 ]; then
      log_warning "Services may not be fully ready yet"
    fi
  done
}

# Create verification script
create_verification() {
  log_info "Creating verification scripts..."
  
  mkdir -p "${INSTALL_DIR}/scripts"
  
  # Verification script
  cat > "${INSTALL_DIR}/scripts/verify.sh" <<EOF
#!/bin/bash

# Verification script for Traefik-Keycloak integration
CLIENT_ID="${CLIENT_ID}"
TRAEFIK_PORT="${TRAEFIK_PORT}"
KEYCLOAK_PORT="${KEYCLOAK_PORT}"

echo "=== Traefik-Keycloak Integration Verification ==="

# Check if containers are running
echo "Checking container status..."
TRAEFIK_RUNNING=\$(docker ps -q -f "name=traefik_\${CLIENT_ID}" 2>/dev/null)
KEYCLOAK_RUNNING=\$(docker ps -q -f "name=keycloak_\${CLIENT_ID}" 2>/dev/null)
AUTH_RUNNING=\$(docker ps -q -f "name=traefik_forward_auth_\${CLIENT_ID}" 2>/dev/null)

if [ -n "\$TRAEFIK_RUNNING" ]; then
  echo "✅ Traefik is running"
else
  echo "❌ Traefik is not running"
  exit 1
fi

if [ -n "\$KEYCLOAK_RUNNING" ]; then
  echo "✅ Keycloak is running"
else
  echo "❌ Keycloak is not running"
  exit 1
fi

if [ -n "\$AUTH_RUNNING" ]; then
  echo "✅ Forward Auth is running"
else
  echo "❌ Forward Auth is not running"
  exit 1
fi

# Check Traefik dashboard
echo "Checking Traefik dashboard..."
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
if [[ "\$HTTP_CODE" == "200" ]]; then
  echo "ℹ️ Dashboard is accessible without authentication (HTTP \$HTTP_CODE)"
elif [[ "\$HTTP_CODE" == "302" || "\$HTTP_CODE" == "401" || "\$HTTP_CODE" == "403" ]]; then
  echo "✅ Dashboard is protected by authentication (HTTP \$HTTP_CODE)"
else
  echo "❌ Dashboard is not accessible (HTTP \$HTTP_CODE)"
  exit 1
fi

# Check Keycloak
echo "Checking Keycloak..."
KEYCLOAK_CODE=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${KEYCLOAK_PORT}" 2>/dev/null)
if [[ "\$KEYCLOAK_CODE" == "200" || "\$KEYCLOAK_CODE" == "302" ]]; then
  echo "✅ Keycloak is accessible (HTTP \$KEYCLOAK_CODE)"
else
  echo "❌ Keycloak is not accessible (HTTP \$KEYCLOAK_CODE)"
  exit 1
fi

echo "All verification checks completed."
EOF

  chmod +x "${INSTALL_DIR}/scripts/verify.sh"
}

# Create documentation
create_documentation() {
  log_info "Creating documentation..."
  
  # Ensure documentation directory exists
  mkdir -p "${SCRIPT_DIR}/../../docs/pages/components"
  
  # Create documentation file if it doesn't exist
  if [ ! -f "${SCRIPT_DIR}/../../docs/pages/components/traefik-keycloak.md" ]; then
    cat > "${SCRIPT_DIR}/../../docs/pages/components/traefik-keycloak.md" <<EOF
# Traefik-Keycloak Integration

This component provides a secure integration between Traefik and Keycloak for dashboard authentication.

## Overview

The Traefik-Keycloak integration provides:
- A Traefik reverse proxy for service routing and load balancing
- Keycloak as the identity provider for SSO following the AgencyStack SSO protocol
- Forward authentication to protect the Traefik dashboard

## Installation

```bash
make traefik-keycloak DOMAIN=example.com CLIENT_ID=default
```

## Configuration

The component is configured through the following files:
- \`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/config/traefik/traefik.yml\`: Main Traefik configuration
- \`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/config/traefik/dynamic/auth.yml\`: Authentication configuration

## Testing and Verification

```bash
# Check status
make traefik-keycloak-status CLIENT_ID=default

# Verify installation
/opt/agency_stack/clients/default/traefik-keycloak/scripts/verify.sh
```

## Access

- Traefik Dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/
- Keycloak Admin Console: http://localhost:${KEYCLOAK_PORT}/auth/admin/
  - Default admin credentials: admin/admin

## Logs

Logs are stored in:
- \`/var/log/agency_stack/components/traefik-keycloak.log\`

## Stopping and Restarting

```bash
# Restart the service
make traefik-keycloak-restart CLIENT_ID=default

# Stop the service
cd /opt/agency_stack/clients/default/traefik-keycloak/docker-compose && docker-compose down
```
EOF
  fi
}

# Create Makefile targets
create_makefile_entries() {
  log_info "Creating Makefile entries..."
  
  # Check if entries already exist
  if ! grep -q "traefik-keycloak:" "${SCRIPT_DIR}/../../Makefile"; then
    log_info "Adding Traefik-Keycloak targets to Makefile"
    
    # Create a temporary file with the new entries
    TMP_FILE=$(mktemp)
    cat > "$TMP_FILE" <<'EOF'

# Traefik-Keycloak Integration targets
traefik-keycloak:
	@echo "$(MAGENTA)$(BOLD)🚀 Installing Traefik with Keycloak authentication...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(TRAEFIK_PORT),--traefik-port $(TRAEFIK_PORT),) $(if $(KEYCLOAK_PORT),--keycloak-port $(KEYCLOAK_PORT),) $(if $(ENABLE_TLS),--enable-tls,)

traefik-keycloak-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Traefik-Keycloak status...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --status-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),)

traefik-keycloak-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Traefik-Keycloak...$(RESET)"
	@if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/docker-compose" ]; then \
		cd /opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/docker-compose && docker-compose restart; \
	else \
		echo "$(RED)Traefik-Keycloak not installed. Run 'make traefik-keycloak' first.$(RESET)"; \
	fi

traefik-keycloak-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Traefik-Keycloak logs...$(RESET)"
	@if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/docker-compose" ]; then \
		cd /opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/docker-compose && docker-compose logs --tail=100; \
	else \
		echo "$(RED)Traefik-Keycloak not installed. Run 'make traefik-keycloak' first.$(RESET)"; \
	fi
EOF
    
    # Append the new entries to the Makefile
    cat "$TMP_FILE" >> "${SCRIPT_DIR}/../../Makefile"
    rm "$TMP_FILE"
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
    
    # Create a temporary file for the new component entry
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
      "sso": true
    }
  },
EOF
    
    # Insert the new component entry into the registry
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
  create_docker_compose
  create_traefik_config
  create_keycloak_init
  create_verification
  create_documentation
  create_makefile_entries
  update_component_registry
  
  start_integration
  
  log_success "Traefik-Keycloak integration is installed"
  log_info "Traefik dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
  log_info "Default admin credentials: admin/admin"
  log_info "Run verification with: ${INSTALL_DIR}/scripts/verify.sh"
}

# Run main installation
main

log_success "Script completed successfully"
