#!/bin/bash
#
# Complete Traefik-Keycloak Integration Script
# This script finalizes the integration between Traefik and Keycloak
# for securing the Traefik dashboard with SSO authentication
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

# Parameters
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
TRAEFIK_PORT=8090
KEYCLOAK_PORT=8091
KEYCLOAK_INTERNAL_PORT=8080
TRAEFIK_INTERNAL_PORT=8000
COOKIE_SECRET="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
KEYCLOAK_CLIENT_SECRET="traefik-secret"

# Directories
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
CONFIG_DIR="${INSTALL_DIR}/config"
TRAEFIK_CONFIG="${CONFIG_DIR}/traefik"
TRAEFIK_DYNAMIC="${TRAEFIK_CONFIG}/dynamic"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/traefik-keycloak-integration.log"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

# Show script header
log_info "==========================================="
log_info "Completing Traefik-Keycloak Integration"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "TRAEFIK_PORT: ${TRAEFIK_PORT}"
log_info "KEYCLOAK_PORT: ${KEYCLOAK_PORT}"
log_info "==========================================="

# Verify prerequisites
verify_prerequisites() {
  log_info "Verifying prerequisites..."
  
  # Check if Traefik is running
  if ! docker ps | grep -q traefik_${CLIENT_ID}; then
    log_error "Traefik is not running. Please run install_traefik_with_keycloak.sh first."
    exit 1
  fi
  
  # Check if Keycloak is running
  if ! docker ps | grep -q keycloak_${CLIENT_ID}; then
    log_error "Keycloak is not running. Please run install_traefik_with_keycloak.sh first."
    exit 1
  fi
  
  # Check if we can access Keycloak
  KEYCLOAK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth" 2>/dev/null)
  if [[ "$KEYCLOAK_STATUS" != "200" && "$KEYCLOAK_STATUS" != "303" ]]; then
    log_error "Cannot access Keycloak (HTTP ${KEYCLOAK_STATUS}). Please check your installation."
    exit 1
  fi
  
  log_success "Prerequisites verified successfully"
}

# Configure Keycloak client
configure_keycloak_client() {
  log_info "Configuring Keycloak client for Traefik dashboard..."
  
  # Get admin token
  log_info "Getting Keycloak admin token..."
  TOKEN_RESPONSE=$(curl -s \
    -d "client_id=admin-cli" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    "http://localhost:${KEYCLOAK_PORT}/auth/realms/master/protocol/openid-connect/token")
  
  # Extract token
  TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
  
  if [[ -z "$TOKEN" ]]; then
    log_error "Failed to get Keycloak admin token."
    log_error "Response: ${TOKEN_RESPONSE}"
    exit 1
  fi
  
  log_success "Got admin token successfully"
  
  # Check if client already exists
  log_info "Checking if client already exists..."
  CLIENT_CHECK=$(curl -s \
    -H "Authorization: Bearer ${TOKEN}" \
    "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients" | grep -o '"clientId":"traefik-dashboard"')
  
  if [[ -n "$CLIENT_CHECK" ]]; then
    log_warning "Client 'traefik-dashboard' already exists in Keycloak"
    
    # Get client ID
    CLIENT_UUID=$(curl -s \
      -H "Authorization: Bearer ${TOKEN}" \
      "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients" | grep -oP '{"id":"[^"]*","clientId":"traefik-dashboard"' | grep -oP '{"id":"[^"]*' | sed 's/{"id":"//')
    
    # Update existing client
    log_info "Updating existing client..."
    curl -s -X PUT \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients/${CLIENT_UUID}" \
      -d '{
        "clientId": "traefik-dashboard",
        "name": "Traefik Dashboard",
        "enabled": true,
        "protocol": "openid-connect",
        "redirectUris": ["http://localhost:'"${TRAEFIK_PORT}"'/*"],
        "webOrigins": ["*"],
        "publicClient": false,
        "secret": "'"${KEYCLOAK_CLIENT_SECRET}"'"
      }'
  else
    # Create new client
    log_info "Creating new client 'traefik-dashboard'..."
    curl -s -X POST \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients" \
      -d '{
        "clientId": "traefik-dashboard",
        "name": "Traefik Dashboard",
        "enabled": true,
        "protocol": "openid-connect",
        "redirectUris": ["http://localhost:'"${TRAEFIK_PORT}"'/*"],
        "webOrigins": ["*"],
        "publicClient": false,
        "secret": "'"${KEYCLOAK_CLIENT_SECRET}"'"
      }'
  fi
  
  log_success "Keycloak client configured successfully"
}

# Update Traefik configuration for auth
update_traefik_config() {
  log_info "Updating Traefik dynamic configuration..."
  
  # Create updated auth.yml
  cat > "${TRAEFIK_DYNAMIC}/auth.yml" <<EOF
http:
  middlewares:
    keycloak-auth:
      forwardAuth:
        address: "http://traefik-forward-auth_${CLIENT_ID}:4181"
        authResponseHeaders:
          - "X-Forwarded-User"
          - "X-Forwarded-Email"
          - "X-Forwarded-Preferred-Username"
EOF
  
  log_success "Traefik configuration updated successfully"
}

# Add Forward Auth container
add_forward_auth() {
  log_info "Setting up Forward Auth container..."
  
  # Stop existing container if running
  docker stop traefik-forward-auth_${CLIENT_ID} 2>/dev/null || true
  docker rm traefik-forward-auth_${CLIENT_ID} 2>/dev/null || true
  
  # Create and start the container
  docker run -d --name traefik-forward-auth_${CLIENT_ID} \
    --network traefik-net-${CLIENT_ID} \
    -e "PROVIDERS_OIDC_ISSUER_URL=http://keycloak_${CLIENT_ID}:${KEYCLOAK_INTERNAL_PORT}/auth/realms/master" \
    -e "PROVIDERS_OIDC_CLIENT_ID=traefik-dashboard" \
    -e "PROVIDERS_OIDC_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}" \
    -e "SECRET=${COOKIE_SECRET}" \
    -e "AUTH_HOST=auth.${DOMAIN}" \
    -e "COOKIE_DOMAIN=${DOMAIN}" \
    -e "INSECURE_COOKIE=true" \
    -e "LOG_LEVEL=debug" \
    thomseddon/traefik-forward-auth:2
  
  # Check if container started
  if ! docker ps | grep -q traefik-forward-auth_${CLIENT_ID}; then
    log_error "Failed to start Forward Auth container"
    docker logs traefik-forward-auth_${CLIENT_ID}
    exit 1
  fi
  
  log_success "Forward Auth container started successfully"
}

# Update Traefik container
update_traefik_container() {
  log_info "Updating Traefik container with auth middleware..."
  
  # Get current container config
  CONTAINER_ID=$(docker ps -q -f "name=traefik_${CLIENT_ID}")
  
  if [[ -z "$CONTAINER_ID" ]]; then
    log_error "Traefik container not found"
    exit 1
  fi
  
  # Stop and remove current container
  log_info "Stopping current Traefik container..."
  docker stop traefik_${CLIENT_ID}
  docker rm traefik_${CLIENT_ID}
  
  # Start new container with updated config
  log_info "Starting new Traefik container with updated configuration..."
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
    --label "traefik.http.routers.dashboard.middlewares=keycloak-auth@file" \
    traefik:v2.10
  
  # Check if container started
  if ! docker ps | grep -q traefik_${CLIENT_ID}; then
    log_error "Failed to start Traefik container"
    docker logs traefik_${CLIENT_ID}
    exit 1
  fi
  
  log_success "Traefik container updated successfully"
}

# Create verification script
create_verification_script() {
  log_info "Creating final verification script..."
  
  cat > "${INSTALL_DIR}/scripts/verify_integration.sh" <<EOF
#!/bin/bash

# Final verification script for Traefik-Keycloak integration
CLIENT_ID="${CLIENT_ID}"
TRAEFIK_PORT="${TRAEFIK_PORT}"
KEYCLOAK_PORT="${KEYCLOAK_PORT}"

echo "=== Traefik-Keycloak Integration Verification ==="

# Check if containers are running
TRAEFIK_RUNNING=\$(docker ps -q -f "name=traefik_\${CLIENT_ID}" 2>/dev/null)
KEYCLOAK_RUNNING=\$(docker ps -q -f "name=keycloak_\${CLIENT_ID}" 2>/dev/null)
AUTH_RUNNING=\$(docker ps -q -f "name=traefik-forward-auth_\${CLIENT_ID}" 2>/dev/null)

echo "=== Container Status ==="
echo "Traefik: \$([ -n "\$TRAEFIK_RUNNING" ] && echo "Running" || echo "Not running")"
echo "Keycloak: \$([ -n "\$KEYCLOAK_RUNNING" ] && echo "Running" || echo "Not running")"
echo "Forward Auth: \$([ -n "\$AUTH_RUNNING" ] && echo "Running" || echo "Not running")"

# Check endpoints
TRAEFIK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" -L "http://localhost:\${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
KEYCLOAK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:\${KEYCLOAK_PORT}/auth" 2>/dev/null)

echo "=== Endpoint Status ==="
echo "Traefik dashboard: HTTP \$TRAEFIK_STATUS (should be 302 redirect to auth)"
echo "Keycloak: HTTP \$KEYCLOAK_STATUS"

# Check network
echo "=== Network Validation ==="
docker network inspect traefik-net-\${CLIENT_ID} | grep -q traefik_\${CLIENT_ID} && echo "✅ Traefik is on network" || echo "❌ Traefik is not on network"
docker network inspect traefik-net-\${CLIENT_ID} | grep -q keycloak_\${CLIENT_ID} && echo "✅ Keycloak is on network" || echo "❌ Keycloak is not on network"
docker network inspect traefik-net-\${CLIENT_ID} | grep -q traefik-forward-auth_\${CLIENT_ID} && echo "✅ Forward Auth is on network" || echo "❌ Forward Auth is not on network"

# Show access URLs
echo -e "\nAccess URLs:"
echo "- Traefik dashboard (requires auth): http://localhost:\${TRAEFIK_PORT}/dashboard/"
echo "- Keycloak admin console: http://localhost:\${KEYCLOAK_PORT}/auth/admin/"
echo "  Admin credentials: admin/admin"

echo -e "\nTo test the authentication flow, open the Traefik dashboard URL in a browser."
echo "You should be redirected to Keycloak for authentication."
echo -e "\nVerification complete."
EOF
  
  chmod +x "${INSTALL_DIR}/scripts/verify_integration.sh"
  
  log_success "Verification script created successfully"
}

# Update documentation
update_documentation() {
  log_info "Updating documentation..."
  
  DOC_FILE="${SCRIPT_DIR}/../../docs/pages/components/traefik-keycloak.md"
  
  if [ -f "$DOC_FILE" ]; then
    # Append updated information
    cat >> "$DOC_FILE" <<EOF

## Complete Integration with Authentication
The integration is now complete with:

- Traefik dashboard protected by Keycloak authentication
- Forward authentication middleware handling redirects
- Full SSO support via Keycloak

### Verification
To verify the complete integration:

\`\`\`bash
/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/scripts/verify_integration.sh
\`\`\`

### Authentication Flow
1. When accessing the Traefik dashboard, you'll be redirected to Keycloak for authentication
2. After successful login, you'll be redirected back to the dashboard
3. The session cookie will maintain your authentication state

### Troubleshooting
If authentication is not working:
- Check the logs of the forward-auth container: \`docker logs traefik-forward-auth_${CLIENT_ID}\`
- Verify network connectivity between containers
- Ensure the Keycloak client configuration is correct
EOF
  fi
  
  log_success "Documentation updated successfully"
}

# Create usage instructions
create_usage_instructions() {
  log_info "Creating usage instructions..."
  
  mkdir -p "${INSTALL_DIR}/docs"
  
  cat > "${INSTALL_DIR}/docs/usage.md" <<EOF
# Traefik with Keycloak Authentication - Usage Instructions

## Accessing the Traefik Dashboard

1. Open your browser and navigate to http://localhost:${TRAEFIK_PORT}/dashboard/
2. You will be redirected to the Keycloak authentication page
3. Log in with Keycloak credentials (default admin/admin)
4. After successful authentication, you will be redirected back to the Traefik dashboard

## Managing Keycloak Users

1. Access the Keycloak admin console at http://localhost:${KEYCLOAK_PORT}/auth/admin/
2. Log in with admin credentials (default admin/admin)
3. Navigate to "Users" section to manage users who can access the Traefik dashboard
4. Create new users or modify existing ones

## Troubleshooting

If you encounter issues with authentication:

1. Check the logs:
   \`\`\`
   docker logs traefik_${CLIENT_ID}
   docker logs keycloak_${CLIENT_ID}
   docker logs traefik-forward-auth_${CLIENT_ID}
   \`\`\`

2. Verify container status:
   \`\`\`
   /opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/scripts/verify_integration.sh
   \`\`\`

3. Restart the services if needed:
   \`\`\`
   docker restart traefik_${CLIENT_ID} keycloak_${CLIENT_ID} traefik-forward-auth_${CLIENT_ID}
   \`\`\`
EOF
  
  log_success "Usage instructions created successfully"
}

# Main function
main() {
  verify_prerequisites
  configure_keycloak_client
  update_traefik_config
  add_forward_auth
  update_traefik_container
  create_verification_script
  update_documentation
  create_usage_instructions
  
  log_success "Traefik-Keycloak integration completed successfully!"
  log_info "Access Traefik dashboard (requires authentication): http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Access Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
  log_info "Keycloak admin credentials: admin/admin"
  log_info "Verify the integration: ${INSTALL_DIR}/scripts/verify_integration.sh"
  log_info "Usage instructions: ${INSTALL_DIR}/docs/usage.md"
}

# Run main function
main

exit 0
