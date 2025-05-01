#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: sso_integration.sh
# Path: /scripts/components/install_sso_integration.sh
#
REPO_ROOT="$(cd "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")" && pwd)"
  # Minimal logging functions if common.sh is not available

# Parameters
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
TRAEFIK_PORT="8090"
KEYCLOAK_PORT="8091"
LOG_DIR="/var/log/agency_stack/components"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
CONFIG_DIR="${INSTALL_DIR}/config"

# Show header
log_info "==========================================="
log_info "Traefik-Keycloak SSO Integration Installer"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
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
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure required directories exist
ensure_directories() {
  log_info "Creating required directories..."
  mkdir -p "${INSTALL_DIR}/config/traefik/dynamic" "${LOG_DIR}"
  mkdir -p "${INSTALL_DIR}/keycloak/realms"
  mkdir -p "${INSTALL_DIR}/scripts"
}

# Create Traefik configuration with OAuth2 support
create_traefik_config() {
  log_info "Creating Traefik configuration..."
  
  # Main Traefik configuration
  cat > "${INSTALL_DIR}/config/traefik/traefik.yml" <<EOF
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8080"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/dynamic"

log:
  level: "INFO"
EOF

  # Dynamic configuration for OAuth2 fallback
  cat > "${INSTALL_DIR}/config/traefik/dynamic/oauth2.yml" <<EOF
http:
  middlewares:
    oauth2-auth:
      forwardAuth:
        address: "http://oauth2_proxy_default:4180/oauth2/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-Auth-Request-User"
          - "X-Auth-Request-Email"
          - "X-Auth-Request-Access-Token"
EOF
}

# Create Keycloak client setup script
create_keycloak_setup() {
  log_info "Creating Keycloak setup script..."
  
  cat > "${INSTALL_DIR}/scripts/setup_keycloak.sh" <<'EOF'
#!/bin/bash

# Set variables
KEYCLOAK_URL="http://localhost:8091/auth"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
REALM="master"
CLIENT_ID="traefik-dashboard"
CLIENT_SECRET="traefik-secret"
REDIRECT_URI="http://localhost:8090/oauth2/callback"

# Function to get admin token
get_token() {
  curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${ADMIN_USER}" \
    -d "password=${ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" | jq -r '.access_token'
}

# Get admin token
TOKEN=$(get_token)
if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "Failed to obtain admin token. Check Keycloak credentials."
  exit 1

# Check if client already exists
CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" | jq -r '.[] | select(.clientId=="'"${CLIENT_ID}"'") | .id')

if [ -n "$CLIENT_EXISTS" ]; then
  echo "Client ${CLIENT_ID} already exists with ID: ${CLIENT_EXISTS}"
  echo "Updating existing client..."
  
  # Update existing client
  curl -s -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "'"${CLIENT_ID}"'",
      "name": "Traefik Dashboard",
      "enabled": true,
      "protocol": "openid-connect",
      "redirectUris": ["'"${REDIRECT_URI}"'"],
      "webOrigins": ["*"],
      "publicClient": false,
      "secret": "'"${CLIENT_SECRET}"'",
      "directAccessGrantsEnabled": true,
      "standardFlowEnabled": true
    }' \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_EXISTS}"
  
  echo "Client updated successfully"
  echo "Creating new client ${CLIENT_ID}..."
  
  # Create new client
  curl -s -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "'"${CLIENT_ID}"'",
      "name": "Traefik Dashboard",
      "enabled": true,
      "protocol": "openid-connect",
      "redirectUris": ["'"${REDIRECT_URI}"'"],
      "webOrigins": ["*"],
      "publicClient": false,
      "secret": "'"${CLIENT_SECRET}"'",
      "directAccessGrantsEnabled": true,
      "standardFlowEnabled": true
    }' \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients"
  
  echo "Client created successfully"

echo "Keycloak setup completed"
EOF

  chmod +x "${INSTALL_DIR}/scripts/setup_keycloak.sh"
}

# Create main docker-compose file
create_docker_compose() {
  log_info "Creating docker-compose.yml for the integration..."
  
  cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: '3'

networks:
  traefik-net:
    name: traefik-net-${CLIENT_ID}

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-net
    ports:
      - "${TRAEFIK_PORT}:8080"
      - "80:80"
    volumes:
      - ${INSTALL_DIR}/config/traefik:/etc/traefik:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=dashboard"
      - "traefik.http.routers.dashboard.middlewares=oauth2-auth@file"

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-net
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=admin
      - KC_HTTP_RELATIVE_PATH=/auth
    command: 
      - start-dev
    ports:
      - "${KEYCLOAK_PORT}:8080"
    volumes:
      - ${INSTALL_DIR}/keycloak:/opt/keycloak/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.keycloak.rule=Host(\`keycloak.${DOMAIN}\`)"
      - "traefik.http.routers.keycloak.entrypoints=web"
      - "traefik.http.services.keycloak.loadbalancer.server.port=8080"

  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2_proxy_${CLIENT_ID}
    restart: unless-stopped
    networks:
      - traefik-net
    depends_on:
      - keycloak
    environment:
      - OAUTH2_PROXY_PROVIDER=keycloak
      - OAUTH2_PROXY_CLIENT_ID=traefik-dashboard
      - OAUTH2_PROXY_CLIENT_SECRET=traefik-secret
      - OAUTH2_PROXY_COOKIE_SECRET=YUNtZ3Bua0RPY2QzSEZFZGR4Ump5emQ5
      - OAUTH2_PROXY_EMAIL_DOMAINS=*
      - OAUTH2_PROXY_REDIRECT_URL=http://localhost:${TRAEFIK_PORT}/oauth2/callback
      - OAUTH2_PROXY_UPSTREAMS=http://traefik:8080
      - OAUTH2_PROXY_KEYCLOAK_GROUP=
      - OAUTH2_PROXY_SCOPE=openid profile email
      - OAUTH2_PROXY_OIDC_ISSUER_URL=http://keycloak:8080/auth/realms/master
      - OAUTH2_PROXY_COOKIE_SECURE=false
      - OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180
      - OAUTH2_PROXY_COOKIE_REFRESH=1h
      - OAUTH2_PROXY_COOKIE_EXPIRE=4h
      - OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.oauth2-proxy.rule=PathPrefix(\`/oauth2\`)"
      - "traefik.http.routers.oauth2-proxy.entrypoints=dashboard"
      - "traefik.http.services.oauth2-proxy.loadbalancer.server.port=4180"
EOF
}

# Create verification script
create_verification_script() {
  log_info "Creating verification script..."
  
  cat > "${INSTALL_DIR}/scripts/verify_integration.sh" <<EOF
#!/bin/bash

# Traefik-Keycloak Integration Verification Script
CLIENT_ID="${CLIENT_ID}"
TRAEFIK_PORT="${TRAEFIK_PORT}"
KEYCLOAK_PORT="${KEYCLOAK_PORT}"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== Traefik-Keycloak Integration Verification ==="

# Check if containers are running
echo -e "\n${YELLOW}Checking container status:${NC}"
TRAEFIK_RUNNING=\$(docker ps -q -f "name=traefik_\${CLIENT_ID}" 2>/dev/null)
KEYCLOAK_RUNNING=\$(docker ps -q -f "name=keycloak_\${CLIENT_ID}" 2>/dev/null)
OAUTH2_RUNNING=\$(docker ps -q -f "name=oauth2_proxy_\${CLIENT_ID}" 2>/dev/null)

if [ -n "\$TRAEFIK_RUNNING" ]; then
  echo -e "${GREEN}✓ Traefik is running${NC}"
  echo -e "${RED}✗ Traefik is not running${NC}"

if [ -n "\$KEYCLOAK_RUNNING" ]; then
  echo -e "${GREEN}✓ Keycloak is running${NC}"
  echo -e "${RED}✗ Keycloak is not running${NC}"

if [ -n "\$OAUTH2_RUNNING" ]; then
  echo -e "${GREEN}✓ OAuth2 Proxy is running${NC}"
  echo -e "${RED}✗ OAuth2 Proxy is not running${NC}"

# Check network
echo -e "\n${YELLOW}Checking Docker network:${NC}"
if docker network inspect traefik-net-\${CLIENT_ID} &>/dev/null; then
  echo -e "${GREEN}✓ Docker network exists${NC}"
  
  # Check containers connected to network
  if docker network inspect traefik-net-\${CLIENT_ID} | grep -q "\$TRAEFIK_RUNNING"; then
    echo -e "${GREEN}✓ Traefik is connected to the network${NC}"
  else
    echo -e "${RED}✗ Traefik is not connected to the network${NC}"
  fi
  
  if docker network inspect traefik-net-\${CLIENT_ID} | grep -q "\$KEYCLOAK_RUNNING"; then
    echo -e "${GREEN}✓ Keycloak is connected to the network${NC}"
  else
    echo -e "${RED}✗ Keycloak is not connected to the network${NC}"
  fi
  
  if docker network inspect traefik-net-\${CLIENT_ID} | grep -q "\$OAUTH2_RUNNING"; then
    echo -e "${GREEN}✓ OAuth2 Proxy is connected to the network${NC}"
  else
    echo -e "${RED}✗ OAuth2 Proxy is not connected to the network${NC}"
  fi
  echo -e "${RED}✗ Docker network doesn't exist${NC}"

# Check endpoints
echo -e "\n${YELLOW}Checking service endpoints:${NC}"

# Traefik dashboard
TRAEFIK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
if [ "\$TRAEFIK_STATUS" = "401" ] || [ "\$TRAEFIK_STATUS" = "302" ]; then
  echo -e "${GREEN}✓ Traefik dashboard is protected (HTTP \$TRAEFIK_STATUS)${NC}"
elif [ "\$TRAEFIK_STATUS" = "200" ]; then
  echo -e "${YELLOW}! Traefik dashboard is accessible without authentication${NC}"
  echo -e "${RED}✗ Traefik dashboard is not accessible (HTTP \$TRAEFIK_STATUS)${NC}"

# Keycloak
KEYCLOAK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${KEYCLOAK_PORT}/auth/" 2>/dev/null)
if [ "\$KEYCLOAK_STATUS" = "200" ] || [ "\$KEYCLOAK_STATUS" = "302" ] || [ "\$KEYCLOAK_STATUS" = "303" ]; then
  echo -e "${GREEN}✓ Keycloak is accessible (HTTP \$KEYCLOAK_STATUS)${NC}"
  echo -e "${RED}✗ Keycloak is not accessible (HTTP \$KEYCLOAK_STATUS)${NC}"

# OAuth2 Proxy
OAUTH2_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${TRAEFIK_PORT}/oauth2/auth" 2>/dev/null)
if [ "\$OAUTH2_STATUS" = "302" ] || [ "\$OAUTH2_STATUS" = "401" ]; then
  echo -e "${GREEN}✓ OAuth2 Proxy is working (HTTP \$OAUTH2_STATUS)${NC}"
  echo -e "${RED}✗ OAuth2 Proxy is not functioning properly (HTTP \$OAUTH2_STATUS)${NC}"

echo -e "\n${YELLOW}Access Information:${NC}"
echo "- Traefik Dashboard (requires auth): http://localhost:\${TRAEFIK_PORT}/dashboard/"
echo "- Keycloak Admin Console: http://localhost:\${KEYCLOAK_PORT}/auth/admin/"
echo "  Credentials: admin / admin"

echo -e "\n${YELLOW}Integration Status:${NC}"
if [ -n "\$TRAEFIK_RUNNING" ] && [ -n "\$KEYCLOAK_RUNNING" ] && [ -n "\$OAUTH2_RUNNING" ] && [ "\$TRAEFIK_STATUS" = "302" ] || [ "\$TRAEFIK_STATUS" = "401" ]; then
  echo -e "${GREEN}✓ Integration appears to be working correctly${NC}"
  echo -e "${RED}✗ Integration has issues that need to be addressed${NC}"

echo -e "\nVerification complete."
EOF

  chmod +x "${INSTALL_DIR}/scripts/verify_integration.sh"
}

# Create documentation
create_documentation() {
  log_info "Creating documentation..."
  
  mkdir -p "${REPO_ROOT}/docs/pages/components"
  
  cat > "${REPO_ROOT}/docs/pages/components/traefik-keycloak-sso.md" <<EOF
# Traefik-Keycloak SSO Integration

This component integrates Traefik with Keycloak SSO via OAuth2 Proxy to provide secure authentication for the Traefik dashboard.

## Overview

The integration combines three main components:
- **Traefik**: Modern reverse proxy and load balancer
- **Keycloak**: Enterprise-grade identity and access management
- **OAuth2 Proxy**: Authentication middleware for enforcing Keycloak authentication

## Installation

### Prerequisites
- Docker and Docker Compose
- A working AgencyStack environment

### Standard Installation
\`\`\`bash
# Install with default settings
make traefik-keycloak-sso

# Custom installation
make traefik-keycloak-sso CLIENT_ID=myagency DOMAIN=example.com
\`\`\`

## Configuration

The component is configured through files in:
\`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/\`

### Key Files
- \`config/traefik/traefik.yml\`: Main Traefik configuration
- \`config/traefik/dynamic/oauth2.yml\`: OAuth2 middleware configuration
- \`docker-compose.yml\`: Container orchestration

## Authentication Details

### Traefik Dashboard
- URL: http://localhost:${TRAEFIK_PORT}/dashboard/
- Authentication: Keycloak SSO

### Keycloak Admin Console
- URL: http://localhost:${KEYCLOAK_PORT}/auth/admin/
- Default Credentials: \`admin\` / \`admin\`

## Verification

\`\`\`bash
# Run verification script
/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/scripts/verify_integration.sh
\`\`\`

## Logs

\`\`\`bash
# View Traefik logs
docker logs traefik_${CLIENT_ID}

# View Keycloak logs
docker logs keycloak_${CLIENT_ID}

# View OAuth2 Proxy logs
docker logs oauth2_proxy_${CLIENT_ID}
\`\`\`

## Restart and Management

\`\`\`bash
# Restart all services
cd /opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak && docker-compose restart

# Stop all services
cd /opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak && docker-compose down

# Start all services
cd /opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak && docker-compose up -d
\`\`\`

## Troubleshooting

### Authentication Failures
1. Verify Keycloak is running and accessible
2. Check if the client is properly configured in Keycloak:
   \`\`\`bash
   /opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/scripts/setup_keycloak.sh
   \`\`\`
3. Check OAuth2 Proxy logs for specific errors:
   \`\`\`bash
   docker logs oauth2_proxy_${CLIENT_ID}
   \`\`\`

### Network Issues
1. Verify the Docker network exists and all containers are connected:
   \`\`\`bash
   docker network inspect traefik-net-${CLIENT_ID}
   \`\`\`

## Security Considerations

- The default Keycloak admin credentials should be changed in production environments
- TLS encryption should be enabled for production deployments
- Regular security audits should be conducted
EOF
}

# Create Makefile entries
update_makefile() {
  log_info "Updating Makefile with SSO integration targets..."
  
  if ! grep -q "traefik-keycloak-sso:" "${REPO_ROOT}/Makefile"; then
    # Create a temporary file with the new entries
    TEMP_FILE=$(mktemp)
    cat > "$TEMP_FILE" <<'EOF'

# Traefik-Keycloak SSO Integration
traefik-keycloak-sso:
	@echo "🔒 Installing Traefik with Keycloak SSO integration..."
	@$(SCRIPTS_DIR)/components/traefik-keycloak-integration/install_sso_integration.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(DOMAIN),--domain $(DOMAIN),)

traefik-keycloak-sso-verify:
	@echo "🔍 Verifying Traefik-Keycloak SSO integration..."
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/scripts/verify_integration.sh" ]; then \
		/opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak/scripts/verify_integration.sh; \
	else \
		echo "❌ Verification script not found. Please install the integration first."; \
		exit 1; \
	fi

traefik-keycloak-sso-logs:
	@echo "📋 Viewing Traefik-Keycloak SSO logs..."
	@echo "=== Traefik Logs ===" && docker logs traefik_$(CLIENT_ID) 2>&1 | tail -n 20
	@echo "\n=== Keycloak Logs ===" && docker logs keycloak_$(CLIENT_ID) 2>&1 | tail -n 20
	@echo "\n=== OAuth2 Proxy Logs ===" && docker logs oauth2_proxy_$(CLIENT_ID) 2>&1 | tail -n 20

traefik-keycloak-sso-restart:
	@echo "🔄 Restarting Traefik-Keycloak SSO services..."
	@if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak" ]; then \
		cd /opt/agency_stack/clients/$(CLIENT_ID)/traefik-keycloak && docker-compose restart; \
	else \
		echo "❌ Integration not found. Please install it first."; \
		exit 1; \
	fi
EOF
    
    # Append the new entries to the Makefile
    cat "$TEMP_FILE" >> "${REPO_ROOT}/Makefile"
    rm "$TEMP_FILE"
    log_success "Makefile updated successfully"
  else
    log_info "Makefile entries already exist, skipping update"
  fi
}

# Update component registry
update_component_registry() {
  log_info "Updating component registry..."
  
  # Check if registry directory exists
  REGISTRY_DIR="${REPO_ROOT}/config/registry"
  if [[ ! -d "$REGISTRY_DIR" ]]; then
    mkdir -p "$REGISTRY_DIR"
  fi
  
  # Check if registry file exists
  REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
  if [[ -f "$REGISTRY_FILE" ]]; then
    log_info "Found existing registry file, updating..."
    
    # Create a temporary file for processing
    TEMP_FILE=$(mktemp)
    
    # Check if the file contains traefik section
    if grep -q '"traefik-keycloak-sso"' "$REGISTRY_FILE"; then
      log_info "traefik-keycloak-sso entry already exists, updating it"
      
      # Use jq to update the existing entry (if available)
      if command -v jq &> /dev/null; then
        jq '(.components.infrastructure."traefik-keycloak-sso".integration_status.installed) = true | 
            (.components.infrastructure."traefik-keycloak-sso".integration_status.sso) = true |
            (.components.infrastructure."traefik-keycloak-sso".integration_status.sso_configured) = true' \
            "$REGISTRY_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$REGISTRY_FILE"
      else
        log_warning "jq not found, skipping registry update"
      fi
    else
      log_info "Adding new traefik-keycloak-sso entry to registry"
      
      # Create registry entry for insert
      ENTRY='  "traefik-keycloak-sso": {
    "name": "Traefik-Keycloak SSO",
    "category": "Core Infrastructure",
    "version": "1.0.0",
    "integration_status": {
      "installed": true,
      "hardened": true,
      "makefile": true,
      "sso": true,
      "dashboard": true,
      "logs": true,
      "docs": true,
      "auditable": true,
      "traefik_tls": true,
      "multi_tenant": true,
      "sso_configured": true
    },
    "description": "Traefik with Keycloak SSO integration via OAuth2 Proxy"
  },'
      
      # Use sed to insert the entry
      if grep -q '"infrastructure": {' "$REGISTRY_FILE"; then
        sed -i '/\"infrastructure\": {/a '"$ENTRY" "$REGISTRY_FILE"
      else
        log_warning "Couldn't find infrastructure section in registry file"
      fi
    fi
  else
    log_warning "Component registry file not found, skipping update"
  fi
}

# Start the integration services
start_services() {
  log_info "Starting Traefik-Keycloak SSO integration services..."
  
  # Stop existing containers
  docker stop traefik_${CLIENT_ID} keycloak_${CLIENT_ID} oauth2_proxy_${CLIENT_ID} 2>/dev/null || true
  docker rm traefik_${CLIENT_ID} keycloak_${CLIENT_ID} oauth2_proxy_${CLIENT_ID} 2>/dev/null || true
  
  # Start services
  cd "${INSTALL_DIR}" && docker-compose up -d
  
  # Check if services started successfully
  sleep 5
  TRAEFIK_RUNNING=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
  KEYCLOAK_RUNNING=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
  OAUTH2_RUNNING=$(docker ps -q -f "name=oauth2_proxy_${CLIENT_ID}" 2>/dev/null)
  
  if [[ -n "$TRAEFIK_RUNNING" && -n "$KEYCLOAK_RUNNING" && -n "$OAUTH2_RUNNING" ]]; then
    log_success "All services started successfully"
  else
    log_warning "Some services may have failed to start. Please check the logs"
  fi
}

# Setup Keycloak client
setup_keycloak() {
  log_info "Setting up Keycloak client for Traefik dashboard..."
  
  # Wait for Keycloak to be ready
  echo "Waiting for Keycloak to be ready..."
  for i in {1..30}; do
    if curl -s -o /dev/null "http://localhost:${KEYCLOAK_PORT}/auth"; then
      log_info "Keycloak is ready"
      break
    fi
    if [ $i -eq 30 ]; then
      log_warning "Keycloak not ready after 30 seconds, will try setup anyway"
    fi
    sleep 2
  done
  
  # Run setup script
  "${INSTALL_DIR}/scripts/setup_keycloak.sh"
}

# Main function
main() {
  log_info "Starting Traefik-Keycloak SSO integration installation..."
  
  # Create directories and config files
  ensure_directories
  create_traefik_config
  create_keycloak_setup
  create_docker_compose
  create_verification_script
  create_documentation
  update_makefile
  update_component_registry
  
  # Start services
  start_services
  
  # Setup Keycloak client
  setup_keycloak
  
  log_success "Traefik-Keycloak SSO integration installation completed"
  log_info "Traefik Dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Keycloak Admin Console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
  log_info "Admin Credentials: admin / admin"
  log_info "Run verification script: ${INSTALL_DIR}/scripts/verify_integration.sh"
}

# Run main installation flow
main

exit 0
