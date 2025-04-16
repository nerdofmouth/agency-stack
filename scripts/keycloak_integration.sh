#!/bin/bash
# keycloak_integration.sh - Integrate AgencyStack components with Keycloak SSO
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
KEYCLOAK_CONFIG_DIR="/opt/agency_stack/keycloak"
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/keycloak_integration-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if Keycloak is installed
check_keycloak() {
  if ! grep -q "Keycloak" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    log "${RED}Error: Keycloak is not installed${NC}"
    log "Please install Keycloak first using 'make install' and selecting component #25"
    return 1
  fi
  
  # Source config.env for Keycloak settings
  if [ -f "$CONFIG_ENV" ]; then
    source "$CONFIG_ENV"
  else
    log "${RED}Error: config.env not found${NC}"
    return 1
  fi
  
  # Check for necessary Keycloak variables
  if [ -z "$KEYCLOAK_DOMAIN" ] || [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    log "${RED}Error: Keycloak configuration is incomplete${NC}"
    log "Please ensure KEYCLOAK_DOMAIN and KEYCLOAK_ADMIN_PASSWORD are set in config.env"
    return 1
  fi
  
  # Check if Keycloak is running
  if ! docker ps | grep -q "keycloak" && ! docker ps | grep -q "agency_stack_keycloak"; then
    log "${RED}Error: Keycloak container is not running${NC}"
    log "Please start Keycloak first: docker-compose -f /opt/agency_stack/keycloak/docker-compose.yml up -d"
    return 1
  fi
  
  # Try to access Keycloak
  if ! curl -s -o /dev/null -w "%{http_code}" "https://${KEYCLOAK_DOMAIN}/auth/" | grep -q "200\|301\|302"; then
    log "${RED}Error: Cannot access Keycloak at https://${KEYCLOAK_DOMAIN}/auth/${NC}"
    log "Please check that Keycloak is properly configured and running"
    return 1
  fi
  
  return 0
}

# Function to get Keycloak token
get_keycloak_token() {
  local response=$(curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://${KEYCLOAK_DOMAIN}/auth/realms/master/protocol/openid-connect/token")
  
  echo "$response" | grep -o '"access_token":"[^"]*"' | awk -F':' '{print $2}' | tr -d '"'
}

# Function to create AgencyStack realm if it doesn't exist
create_realm() {
  log "${BLUE}Creating AgencyStack realm in Keycloak...${NC}"
  
  local token=$1
  local realm_exists=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack")
  
  # If realm doesn't exist, create it
  if echo "$realm_exists" | grep -q "not found"; then
    local response=$(curl -s -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "realm": "agencystack",
        "enabled": true,
        "displayName": "AgencyStack",
        "displayNameHtml": "<div class=\"kc-logo-text\"><span>AgencyStack</span></div>",
        "bruteForceProtected": true,
        "loginTheme": "keycloak",
        "accessTokenLifespan": 300,
        "ssoSessionIdleTimeout": 1800,
        "ssoSessionMaxLifespan": 36000,
        "offlineSessionIdleTimeout": 2592000,
        "accessCodeLifespan": 60,
        "accessCodeLifespanUserAction": 300,
        "accessCodeLifespanLogin": 1800,
        "notBefore": 0,
        "revokeRefreshToken": false,
        "refreshTokenMaxReuse": 0,
        "verifyEmail": false,
        "resetPasswordAllowed": true,
        "loginWithEmailAllowed": true,
        "duplicateEmailsAllowed": false,
        "editUsernameAllowed": false,
        "roles": {
          "realm": [
            {"name": "admin", "description": "Administrator role"},
            {"name": "editor", "description": "Editor role"},
            {"name": "viewer", "description": "Viewer role"}
          ]
        }
      }' \
      "https://${KEYCLOAK_DOMAIN}/auth/admin/realms")
    
    if [ $? -eq 0 ]; then
      log "${GREEN}✅ AgencyStack realm created successfully${NC}"
      return 0
    else
      log "${RED}❌ Failed to create AgencyStack realm${NC}"
      log "Response: $response"
      return 1
    fi
  else
    log "${YELLOW}AgencyStack realm already exists${NC}"
    return 0
  fi
}

# Create initial admin user in the realm
create_admin_user() {
  log "${BLUE}Creating initial admin user in AgencyStack realm...${NC}"
  
  local token=$1
  local admin_exists=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/users?username=admin")
  
  # If admin doesn't exist, create it
  if echo "$admin_exists" | grep -q '^\[\]$'; then
    # Generate a random password for the admin user
    local admin_password=$(openssl rand -base64 12)
    
    local response=$(curl -s -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "username": "admin",
        "email": "admin@'${PRIMARY_DOMAIN}'",
        "enabled": true,
        "emailVerified": true,
        "firstName": "Agency",
        "lastName": "Admin",
        "credentials": [
          {
            "type": "password",
            "value": "'${admin_password}'",
            "temporary": false
          }
        ],
        "attributes": {
          "roles": ["admin"]
        }
      }' \
      "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/users")
    
    if [ $? -eq 0 ]; then
      log "${GREEN}✅ Admin user created successfully${NC}"
      log "${CYAN}Username: admin${NC}"
      log "${CYAN}Password: ${admin_password}${NC}"
      log "${CYAN}Please save this password as it won't be shown again${NC}"
      
      # Add to config.env
      if ! grep -q "KEYCLOAK_ADMIN_USER" "$CONFIG_ENV"; then
        echo -e "\n# Keycloak AgencyStack Admin User" >> "$CONFIG_ENV"
        echo "KEYCLOAK_ADMIN_USER=admin" >> "$CONFIG_ENV"
        echo "KEYCLOAK_ADMIN_PASSWORD=${admin_password}" >> "$CONFIG_ENV"
      fi
      
      return 0
    else
      log "${RED}❌ Failed to create admin user${NC}"
      log "Response: $response"
      return 1
    fi
  else
    log "${YELLOW}Admin user already exists in AgencyStack realm${NC}"
    return 0
  fi
}

# Function to create Grafana client
create_grafana_client() {
  log "${BLUE}Creating Grafana client in Keycloak...${NC}"
  
  local token=$1
  local client_exists=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/clients?clientId=grafana")
  
  # If client doesn't exist, create it
  if echo "$client_exists" | grep -q '^\[\]$'; then
    # Generate client secret
    local client_secret=$(openssl rand -hex 16)
    
    local response=$(curl -s -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "clientId": "grafana",
        "name": "Grafana",
        "description": "Grafana monitoring dashboard",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "secret": "'${client_secret}'",
        "redirectUris": [
          "https://'${GRAFANA_DOMAIN}'/login/generic_oauth"
        ],
        "webOrigins": [
          "https://'${GRAFANA_DOMAIN}'"
        ],
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": false,
        "publicClient": false,
        "frontchannelLogout": false,
        "protocol": "openid-connect",
        "attributes": {
          "saml.assertion.signature": "false",
          "saml.force.post.binding": "false",
          "saml.multivalued.roles": "false",
          "saml.encrypt": "false",
          "saml.server.signature": "false",
          "saml.server.signature.keyinfo.ext": "false",
          "exclude.session.state.from.auth.response": "false",
          "saml_force_name_id_format": "false",
          "saml.client.signature": "false",
          "tls.client.certificate.bound.access.tokens": "false",
          "saml.authnstatement": "false",
          "display.on.consent.screen": "false",
          "saml.onetimeuse.condition": "false"
        },
        "protocolMappers": [
          {
            "name": "roles",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-realm-role-mapper",
            "consentRequired": false,
            "config": {
              "multivalued": "true",
              "userinfo.token.claim": "true",
              "id.token.claim": "true",
              "access.token.claim": "true",
              "claim.name": "roles",
              "jsonType.label": "String"
            }
          }
        ]
      }' \
      "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/clients")
    
    if [ $? -eq 0 ]; then
      log "${GREEN}✅ Grafana client created successfully${NC}"
      
      # Add to config.env
      if ! grep -q "KEYCLOAK_GRAFANA_SECRET" "$CONFIG_ENV"; then
        echo -e "\n# Keycloak Grafana Integration" >> "$CONFIG_ENV"
        echo "KEYCLOAK_GRAFANA_CLIENT=grafana" >> "$CONFIG_ENV"
        echo "KEYCLOAK_GRAFANA_SECRET=${client_secret}" >> "$CONFIG_ENV"
      fi
      
      return 0
    else
      log "${RED}❌ Failed to create Grafana client${NC}"
      log "Response: $response"
      return 1
    fi
  else
    log "${YELLOW}Grafana client already exists in AgencyStack realm${NC}"
    return 0
  fi
}

# Function to create Traefik Forward Auth client
create_traefik_client() {
  log "${BLUE}Creating Traefik Forward Auth client in Keycloak...${NC}"
  
  local token=$1
  local client_exists=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/clients?clientId=traefik-auth")
  
  # If client doesn't exist, create it
  if echo "$client_exists" | grep -q '^\[\]$'; then
    # Generate client secret
    local client_secret=$(openssl rand -hex 16)
    # Generate cookie secret
    local cookie_secret=$(openssl rand -hex 16)
    
    local response=$(curl -s -X POST \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{
        "clientId": "traefik-auth",
        "name": "Traefik Forward Auth",
        "description": "Authentication for AgencyStack services via Traefik",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "secret": "'${client_secret}'",
        "redirectUris": [
          "https://_oauth_provider.${PRIMARY_DOMAIN}/_oauth",
          "https://auth.${PRIMARY_DOMAIN}/_oauth"
        ],
        "webOrigins": [
          "+"
        ],
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": false,
        "publicClient": false,
        "frontchannelLogout": false,
        "protocol": "openid-connect",
        "attributes": {
          "saml.assertion.signature": "false",
          "saml.force.post.binding": "false",
          "saml.multivalued.roles": "false",
          "saml.encrypt": "false",
          "saml.server.signature": "false",
          "saml.server.signature.keyinfo.ext": "false",
          "exclude.session.state.from.auth.response": "false",
          "saml_force_name_id_format": "false",
          "saml.client.signature": "false",
          "tls.client.certificate.bound.access.tokens": "false",
          "saml.authnstatement": "false",
          "display.on.consent.screen": "false",
          "saml.onetimeuse.condition": "false"
        }
      }' \
      "https://${KEYCLOAK_DOMAIN}/auth/admin/realms/agencystack/clients")
    
    if [ $? -eq 0 ]; then
      log "${GREEN}✅ Traefik Forward Auth client created successfully${NC}"
      
      # Add to config.env
      if ! grep -q "KEYCLOAK_TRAEFIK_SECRET" "$CONFIG_ENV"; then
        echo -e "\n# Keycloak Traefik Integration" >> "$CONFIG_ENV"
        echo "KEYCLOAK_TRAEFIK_CLIENT=traefik-auth" >> "$CONFIG_ENV"
        echo "KEYCLOAK_TRAEFIK_SECRET=${client_secret}" >> "$CONFIG_ENV"
        echo "TRAEFIK_COOKIE_SECRET=${cookie_secret}" >> "$CONFIG_ENV"
      fi
      
      return 0
    else
      log "${RED}❌ Failed to create Traefik Forward Auth client${NC}"
      log "Response: $response"
      return 1
    fi
  else
    log "${YELLOW}Traefik Forward Auth client already exists in AgencyStack realm${NC}"
    return 0
  fi
}

# Detect installed components and offer integration
detect_components() {
  local installed_file="/opt/agency_stack/installed_components.txt"
  local token=$1
  
  if [ ! -f "$installed_file" ]; then
    log "${RED}Error: No installed components found${NC}"
    return 1
  fi
  
  log "${BLUE}Detecting installed components for Keycloak integration...${NC}"
  
  # Check for Grafana
  if grep -q "Grafana" "$installed_file"; then
    log "${CYAN}Grafana detected${NC}"
    create_grafana_client "$token"
    
    # Update Grafana configuration
    update_grafana_config
  fi
  
  # Check for other components in the future
  # if grep -q "ComponentName" "$installed_file"; then
  #   log "${CYAN}ComponentName detected${NC}"
  #   create_component_client "$token"
  # fi
  
  # Setup traefik-forward-auth container for general use
  setup_traefik_forward_auth "$token"
}

# Update Grafana configuration to use Keycloak
update_grafana_config() {
  log "${BLUE}Updating Grafana configuration for Keycloak authentication...${NC}"
  
  local grafana_conf="/opt/agency_stack/grafana/docker-compose.yml"
  
  if [ ! -f "$grafana_conf" ]; then
    log "${YELLOW}Grafana configuration not found, skipping...${NC}"
    return 1
  fi
  
  # Backup original configuration
  cp "$grafana_conf" "${grafana_conf}.bak"
  
  # Add Keycloak OAuth configuration
  sed -i '/GF_INSTALL_PLUGINS/a\\      - GF_AUTH_GENERIC_OAUTH_ENABLED=true\n      - GF_AUTH_GENERIC_OAUTH_NAME=Keycloak\n      - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana\n      - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${KEYCLOAK_GRAFANA_SECRET}\n      - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/auth\n      - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/token\n      - GF_AUTH_GENERIC_OAUTH_API_URL=https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/userinfo\n      - GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true\n      - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(roles[*], '\''admin'\'') && '\''Admin'\'' || contains(roles[*], '\''editor'\'') && '\''Editor'\'' || '\''Viewer'\''' "$grafana_conf"
  
  # Remove Traefik basic auth middleware
  sed -i '/traefik.http.routers.grafana.middlewares/d' "$grafana_conf"
  sed -i '/traefik.http.middlewares.grafana-auth.basicauth.users/d' "$grafana_conf"
  
  # Restart Grafana
  log "${BLUE}Restarting Grafana to apply new configuration...${NC}"
  (cd "/opt/agency_stack/grafana" && docker-compose up -d)
  
  if [ $? -eq 0 ]; then
    log "${GREEN}✅ Grafana reconfigured to use Keycloak authentication${NC}"
    log "${CYAN}Grafana is now accessible at: https://${GRAFANA_DOMAIN}${NC}"
    log "${CYAN}Use your Keycloak AgencyStack realm credentials to log in${NC}"
  else
    log "${RED}❌ Failed to restart Grafana${NC}"
    log "Please check the logs: docker logs agency_stack_grafana"
    
    # Restore backup
    log "${YELLOW}Restoring original configuration...${NC}"
    mv "${grafana_conf}.bak" "$grafana_conf"
    (cd "/opt/agency_stack/grafana" && docker-compose up -d)
  fi
}

# Setup Traefik Forward Auth for general use
setup_traefik_forward_auth() {
  log "${BLUE}Setting up Traefik Forward Auth for AgencyStack services...${NC}"
  
  local auth_dir="/opt/agency_stack/traefik-auth"
  mkdir -p "$auth_dir"
  
  # Create docker-compose.yml
  cat > "${auth_dir}/docker-compose.yml" << EOL
version: '3'

services:
  traefik-forward-auth:
    image: thomseddon/traefik-forward-auth:latest
    container_name: agency_stack_traefik_auth
    restart: unless-stopped
    environment:
      - PROVIDERS_OIDC_ISSUER_URL=https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack
      - PROVIDERS_OIDC_CLIENT_ID=traefik-auth
      - PROVIDERS_OIDC_CLIENT_SECRET=${KEYCLOAK_TRAEFIK_SECRET}
      - SECRET=${TRAEFIK_COOKIE_SECRET}
      - AUTH_HOST=auth.${PRIMARY_DOMAIN}
      - COOKIE_DOMAIN=${PRIMARY_DOMAIN}
      - LOG_LEVEL=debug
      - LIFETIME=43200
      - DEFAULT_ACTION=auth
      - DEFAULT_PROVIDER=oidc
    networks:
      - traefik-public
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:4181/_ping"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    labels:
      - traefik.enable=true
      - traefik.http.routers.traefik-auth.rule=Host(\`auth.${PRIMARY_DOMAIN}\`)
      - traefik.http.routers.traefik-auth.entrypoints=websecure
      - traefik.http.routers.traefik-auth.tls=true
      - traefik.http.routers.traefik-auth.tls.certresolver=letsencrypt
      - traefik.http.services.traefik-auth.loadbalancer.server.port=4181

networks:
  traefik-public:
    external: true
EOL
  
  # Start the container
  (cd "$auth_dir" && docker-compose up -d)
  
  if [ $? -eq 0 ]; then
    log "${GREEN}✅ Traefik Forward Auth setup complete${NC}"
    log "${CYAN}You can now use the 'keycloak-auth@docker' middleware in your Traefik configurations${NC}"
    
    # Add Traefik Forward Auth middleware to Traefik configuration
    local traefik_dir="/opt/agency_stack/traefik"
    if [ -d "$traefik_dir" ]; then
      # Create middleware configuration
      cat > "${traefik_dir}/conf.d/keycloak-auth.toml" << EOL
[http.middlewares]
  [http.middlewares.keycloak-auth.forwardAuth]
    address = "http://agency_stack_traefik_auth:4181"
    authResponseHeaders = ["X-Forwarded-User"]
    
  # Create chain middleware to ensure proper ordering
  [http.middlewares.auth-chain.chain]
    middlewares = ["keycloak-auth", "auth-headers"]
    
  # Add response headers for security
  [http.middlewares.auth-headers.headers]
    frameDeny = true
    sslRedirect = true
    browserXssFilter = true
    contentTypeNosniff = true
    forceSTSHeader = true
    stsIncludeSubdomains = true
    stsPreload = true
    stsSeconds = 31536000
EOL
      
      # Reload Traefik
      docker kill -s HUP agency_stack_traefik 2>/dev/null || true
      
      log "${GREEN}✅ Traefik configuration updated with Keycloak middleware${NC}"
    fi
  else
    log "${RED}❌ Failed to start Traefik Forward Auth${NC}"
    log "Please check the logs: docker logs agency_stack_traefik_auth"
  fi
}

# Main function
main() {
  log "${MAGENTA}${BOLD}🔐 AgencyStack Keycloak Integration${NC}"
  log "========================================"
  log "$(date)"
  log "Server: $(hostname)"
  log ""
  
  # Check if Keycloak is installed
  check_keycloak
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  # Get Keycloak admin token
  log "${BLUE}Authenticating with Keycloak...${NC}"
  local token=$(get_keycloak_token)
  
  if [ -z "$token" ]; then
    log "${RED}Error: Failed to authenticate with Keycloak${NC}"
    log "Please check your KEYCLOAK_ADMIN_PASSWORD in config.env"
    exit 1
  fi
  
  # Create realm
  create_realm "$token"
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  # Create admin user
  create_admin_user "$token"
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  # Create Traefik client
  create_traefik_client "$token"
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  # Detect installed components and offer integration
  detect_components "$token"
  
  log ""
  log "${GREEN}${BOLD}✅ Keycloak integration complete!${NC}"
  log "${CYAN}You can now use Keycloak for authentication across AgencyStack components${NC}"
}

# Run main function
main
