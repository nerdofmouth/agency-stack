#!/bin/bash
# keycloak_integration.sh - Utility script for integrating components with Keycloak SSO
#
# This script provides common functions for integrating AgencyStack components with Keycloak
# following the Alpha Phase Directives for SSO integration.
#
# Author: AgencyStack Team
# Date: 2025-04-10

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/log_helpers.sh"

# Constants
KEYCLOAK_CONFIG_DIR="/opt/agency_stack/keycloak"
KEYCLOAK_CLIENTS_DIR="/opt/agency_stack/keycloak/clients"
KEYCLOAK_LOG_DIR="/var/log/agency_stack/components"
KEYCLOAK_INTEGRATION_LOG="${KEYCLOAK_LOG_DIR}/keycloak_integration.log"

# Ensure the log directory exists
mkdir -p "${KEYCLOAK_LOG_DIR}" 2>/dev/null || true

# Check for required dependencies
check_dependencies() {
  log_info "Checking for required dependencies..."
  
  # Check for jq (required for JSON processing)
  if ! command -v jq &>/dev/null; then
    log_error "jq is not installed. Installing jq..."
    apt-get update && apt-get install -y jq || {
      log_error "Failed to install jq. Please install it manually with: sudo apt-get install jq"
      return 1
    }
  fi
  
  # Check for curl (required for API calls)
  if ! command -v curl &>/dev/null; then
    log_error "curl is not installed. Installing curl..."
    apt-get update && apt-get install -y curl || {
      log_error "Failed to install curl. Please install it manually with: sudo apt-get install curl"
      return 1
    }
  fi
  
  # Check for docker (required for Keycloak container)
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    log_info "You can install Docker with: sudo make docker"
    return 1
  fi
  
  log_success "All required dependencies are installed"
  return 0
}

# Check if Keycloak is installed and available
keycloak_is_available() {
  local domain="$1"
  local site_name=${domain//./_}

  # Check if the Keycloak container is running
  if ! docker ps --format '{{.Names}}' | grep -q "keycloak_${site_name}"; then
    log_error "Keycloak is not running for domain ${domain}. Please install and start Keycloak first."
    return 1
  fi

  # Attempt to check Keycloak health endpoint via curl to /auth/health
  local max_attempts=30
  local attempt=0
  local is_ready=false

  log_info "Checking Keycloak availability..."
  while [ $attempt -lt $max_attempts ]; do
    if curl -s -f -o /dev/null -w "%{http_code}" "https://${domain}/health" 2>/dev/null | grep -q "200"; then
      is_ready=true
      break
    fi
    
    attempt=$((attempt + 1))
    log_info "Waiting for Keycloak to be ready... (${attempt}/${max_attempts})"
    sleep 5
  done

  if [ "$is_ready" = false ]; then
    log_error "Keycloak health endpoint not responding after ${max_attempts} attempts."
    return 1
  fi

  log_success "Keycloak is available for domain ${domain}"
  return 0
}

# Check if a realm exists in Keycloak
keycloak_realm_exists() {
  local domain="$1"
  local realm="$2"
  local site_name=${domain//./_}
  local keycloak_container="keycloak_${site_name}"

  # Get auth token for admin
  local admin_user="admin"
  local admin_password=$(grep KEYCLOAK_ADMIN_PASSWORD "/opt/agency_stack/secrets/keycloak/${domain}.env" | cut -d= -f2)
  
  if [ -z "$admin_password" ]; then
    log_error "Could not retrieve Keycloak admin password for domain ${domain}"
    return 1
  fi

  # Get auth token
  local token=$(docker exec $keycloak_container curl -s -X POST \
    "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${admin_user}" \
    -d "password=${admin_password}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

  if [ -z "$token" ] || [ "$token" = "null" ]; then
    log_error "Failed to obtain Keycloak admin token for domain ${domain}"
    return 1
  fi

  # Check if realm exists
  local realm_exists=$(docker exec $keycloak_container curl -s \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/auth/admin/realms" | jq -r --arg realm "$realm" '.[] | select(.realm == $realm) | .realm')

  if [ -z "$realm_exists" ]; then
    log_info "Realm '${realm}' does not exist in Keycloak for domain ${domain}"
    return 1
  fi

  log_success "Realm '${realm}' exists in Keycloak for domain ${domain}"
  return 0
}

# Create a Keycloak realm if it doesn't exist
keycloak_create_realm() {
  local domain="$1"
  local realm="$2"
  local display_name="$3"
  local site_name=${domain//./_}
  local keycloak_container="keycloak_${site_name}"

  # Check if realm already exists
  if keycloak_realm_exists "$domain" "$realm"; then
    log_info "Realm '${realm}' already exists in Keycloak for domain ${domain}"
    return 0
  fi

  # Get auth token for admin
  local admin_user="admin"
  local admin_password=$(grep KEYCLOAK_ADMIN_PASSWORD "/opt/agency_stack/secrets/keycloak/${domain}.env" | cut -d= -f2)
  
  if [ -z "$admin_password" ]; then
    log_error "Could not retrieve Keycloak admin password for domain ${domain}"
    return 1
  fi

  # Get auth token
  local token=$(docker exec $keycloak_container curl -s -X POST \
    "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${admin_user}" \
    -d "password=${admin_password}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

  if [ -z "$token" ] || [ "$token" = "null" ]; then
    log_error "Failed to obtain Keycloak admin token for domain ${domain}"
    return 1
  fi

  # Create realm
  local realm_json=$(cat <<EOF
{
  "realm": "${realm}",
  "enabled": true,
  "displayName": "${display_name}",
  "displayNameHtml": "<div class='kc-logo-text'><span>${display_name}</span></div>",
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true
}
EOF
)

  local create_result=$(docker exec $keycloak_container curl -s -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "${realm_json}" \
    "http://localhost:8080/auth/admin/realms")

  if [[ "$create_result" == *"Conflict"* ]] || [[ "$create_result" == *"already exists"* ]]; then
    log_warning "Realm '${realm}' already exists in Keycloak for domain ${domain}"
    return 0
  elif [ -n "$create_result" ]; then
    log_error "Failed to create realm '${realm}' in Keycloak for domain ${domain}: ${create_result}"
    return 1
  fi

  log_success "Created realm '${realm}' in Keycloak for domain ${domain}"
  return 0
}

# Register a client in Keycloak
keycloak_register_client() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local client_name="$4"
  local redirect_uris="$5"
  local site_name=${domain//./_}
  local keycloak_container="keycloak_${site_name}"

  # Get auth token for admin
  local admin_user="admin"
  local admin_password=$(grep KEYCLOAK_ADMIN_PASSWORD "/opt/agency_stack/secrets/keycloak/${domain}.env" | cut -d= -f2)
  
  if [ -z "$admin_password" ]; then
    log_error "Could not retrieve Keycloak admin password for domain ${domain}"
    return 1
  fi

  # Get auth token
  local token=$(docker exec $keycloak_container curl -s -X POST \
    "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${admin_user}" \
    -d "password=${admin_password}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

  if [ -z "$token" ] || [ "$token" = "null" ]; then
    log_error "Failed to obtain Keycloak admin token for domain ${domain}"
    return 1
  fi

  # Check if client already exists
  local client_exists=$(docker exec $keycloak_container curl -s \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/auth/admin/realms/${realm}/clients" | jq -r --arg client_id "$client_id" '.[] | select(.clientId == $client_id) | .clientId')

  if [ -n "$client_exists" ]; then
    log_info "Client '${client_id}' already exists in realm '${realm}' for domain ${domain}"
    
    # Extract the existing client's ID
    local existing_client_id=$(docker exec $keycloak_container curl -s \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/auth/admin/realms/${realm}/clients" | jq -r --arg client_id "$client_id" '.[] | select(.clientId == $client_id) | .id')
    
    # Update the client with new redirect URIs
    local client_update_json=$(cat <<EOF
{
  "clientId": "${client_id}",
  "name": "${client_name}",
  "enabled": true,
  "redirectUris": ${redirect_uris},
  "webOrigins": ["*"],
  "publicClient": false,
  "protocol": "openid-connect",
  "directAccessGrantsEnabled": true
}
EOF
)

    local update_result=$(docker exec $keycloak_container curl -s -X PUT \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "${client_update_json}" \
      "http://localhost:8080/auth/admin/realms/${realm}/clients/${existing_client_id}")

    if [ -n "$update_result" ] && [ "$update_result" != "{}" ]; then
      log_error "Failed to update client '${client_id}' in realm '${realm}' for domain ${domain}: ${update_result}"
      return 1
    fi

    log_success "Updated client '${client_id}' in realm '${realm}' for domain ${domain}"

    # Get client secret and return it
    local client_secret=$(docker exec $keycloak_container curl -s \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/auth/admin/realms/${realm}/clients/${existing_client_id}/client-secret" | jq -r '.value')

    echo "$client_secret"
    return 0
  fi

  # Create client
  local client_json=$(cat <<EOF
{
  "clientId": "${client_id}",
  "name": "${client_name}",
  "enabled": true,
  "redirectUris": ${redirect_uris},
  "webOrigins": ["*"],
  "publicClient": false,
  "protocol": "openid-connect",
  "directAccessGrantsEnabled": true
}
EOF
)

  local create_result=$(docker exec $keycloak_container curl -s -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "${client_json}" \
    "http://localhost:8080/auth/admin/realms/${realm}/clients")

  if [ -n "$create_result" ] && [ "$create_result" != "{}" ]; then
    log_error "Failed to create client '${client_id}' in realm '${realm}' for domain ${domain}: ${create_result}"
    return 1
  fi

  log_success "Created client '${client_id}' in realm '${realm}' for domain ${domain}"

  # Get the client's ID
  local new_client_id=$(docker exec $keycloak_container curl -s \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/auth/admin/realms/${realm}/clients" | jq -r --arg client_id "$client_id" '.[] | select(.clientId == $client_id) | .id')

  # Get client secret and return it
  local client_secret=$(docker exec $keycloak_container curl -s \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/auth/admin/realms/${realm}/clients/${new_client_id}/client-secret" | jq -r '.value')

  echo "$client_secret"
  return 0
}

# Store Keycloak client credentials for a component
store_keycloak_credentials() {
  local domain="$1"
  local component="$2"
  local client_id="$3"
  local client_secret="$4"
  local realm="$5"

  # Ensure directory exists
  mkdir -p "${KEYCLOAK_CLIENTS_DIR}" 2>/dev/null || true
  
  # Create credentials file
  cat > "${KEYCLOAK_CLIENTS_DIR}/${component}_${domain}.env" <<EOF
# Keycloak client credentials for ${component} on ${domain}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE

KEYCLOAK_REALM=${realm}
KEYCLOAK_CLIENT_ID=${client_id}
KEYCLOAK_CLIENT_SECRET=${client_secret}
KEYCLOAK_HOST=${domain}
KEYCLOAK_URL=https://${domain}/auth
EOF

  # Secure the file
  chmod 600 "${KEYCLOAK_CLIENTS_DIR}/${component}_${domain}.env"
  
  log_success "Stored Keycloak client credentials for ${component} on ${domain}"
  return 0
}

# Generate Keycloak integration code for various frameworks
generate_keycloak_integration_code() {
  local component="$1"
  local framework="$2"
  local domain="$3"
  local client_id="$4"
  local client_secret="$5"
  local realm="$6"
  
  local config_dir="/opt/agency_stack/clients/default/${component}/keycloak"
  mkdir -p "$config_dir" 2>/dev/null || true
  
  case "$framework" in
    nodejs)
      cat > "${config_dir}/integration.js" <<EOF
// Keycloak SSO integration for ${component}
// Generated on $(date +"%Y-%m-%d %H:%M:%S")

const session = require('express-session');
const Keycloak = require('keycloak-connect');

const keycloakConfig = {
  realm: '${realm}',
  'auth-server-url': 'https://${domain}/auth',
  'ssl-required': 'external',
  resource: '${client_id}',
  'confidential-port': 0,
  'bearer-only': false,
  'public-client': false,
  'verify-token-audience': true,
  credentials: {
    secret: '${client_secret}'
  }
};

const initKeycloak = (app) => {
  // Session setup
  app.use(session({
    secret: '${client_secret}',
    resave: false,
    saveUninitialized: true,
    cookie: { secure: true }
  }));

  // Initialize Keycloak
  const keycloak = new Keycloak({ store: memoryStore }, keycloakConfig);
  app.use(keycloak.middleware());

  return keycloak;
};

module.exports = { initKeycloak };
EOF
      ;;
    python)
      cat > "${config_dir}/integration.py" <<EOF
# Keycloak SSO integration for ${component}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")

from flask_oidc import OpenIDConnect
import os

# Keycloak configuration
keycloak_config = {
    'SECRET_KEY': '${client_secret}',
    'OIDC_CLIENT_SECRETS': '${config_dir}/client_secrets.json',
    'OIDC_ID_TOKEN_COOKIE_SECURE': True,
    'OIDC_REQUIRE_VERIFIED_EMAIL': False,
    'OIDC_USER_INFO_ENABLED': True,
    'OIDC_SCOPES': ['openid', 'email', 'profile'],
    'OIDC_INTROSPECTION_AUTH_METHOD': 'client_secret_post'
}

# Create client secrets file
with open('${config_dir}/client_secrets.json', 'w') as f:
    f.write('''{
  "web": {
    "issuer": "https://${domain}/auth/realms/${realm}",
    "auth_uri": "https://${domain}/auth/realms/${realm}/protocol/openid-connect/auth",
    "client_id": "${client_id}",
    "client_secret": "${client_secret}",
    "redirect_uris": ["*"],
    "userinfo_uri": "https://${domain}/auth/realms/${realm}/protocol/openid-connect/userinfo",
    "token_uri": "https://${domain}/auth/realms/${realm}/protocol/openid-connect/token",
    "token_introspection_uri": "https://${domain}/auth/realms/${realm}/protocol/openid-connect/token/introspect"
  }
}''')

def init_keycloak(app):
    """Initialize Keycloak integration with a Flask app"""
    for key, value in keycloak_config.items():
        app.config[key] = value
    
    oidc = OpenIDConnect(app)
    return oidc
EOF
      ;;
    docker)
      cat > "${config_dir}/integration.env" <<EOF
# Keycloak SSO integration for ${component}
# Generated on $(date +"%Y-%m-%d %H:%M:%S")

KEYCLOAK_REALM=${realm}
KEYCLOAK_URL=https://${domain}/auth
KEYCLOAK_CLIENT_ID=${client_id}
KEYCLOAK_CLIENT_SECRET=${client_secret}
KEYCLOAK_PUBLIC_KEY=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
EOF
      ;;
    *)
      log_warning "No integration template available for framework '${framework}'"
      return 1
      ;;
  esac
  
  log_success "Generated Keycloak integration code for ${component} using ${framework} framework"
  return 0
}

# Main integration function
integrate_with_keycloak() {
  local domain="$1"
  local component="$2"
  local framework="$3"
  local component_url="$4"
  
  # Check if Keycloak is available
  if ! keycloak_is_available "$domain"; then
    log_error "Keycloak is not available for domain ${domain}. SSO integration failed."
    return 1
  fi
  
  # Check for required dependencies
  if ! check_dependencies; then
    log_error "Missing required dependencies. Please install them first."
    return 1
  fi
  
  # Create a realm for this client if needed
  local realm="${component}"
  local display_name="${component^}"
  
  if ! keycloak_create_realm "$domain" "$realm" "$display_name"; then
    log_error "Failed to create realm for ${component} on domain ${domain}. SSO integration failed."
    return 1
  fi
  
  # Register client
  local client_id="${component}"
  local client_name="${component^} Service"
  local redirect_uris="[\"${component_url}/*\"]"
  
  local client_secret=$(keycloak_register_client "$domain" "$realm" "$client_id" "$client_name" "$redirect_uris")
  
  if [ -z "$client_secret" ]; then
    log_error "Failed to register client for ${component} on domain ${domain}. SSO integration failed."
    return 1
  fi
  
  # Store credentials
  if ! store_keycloak_credentials "$domain" "$component" "$client_id" "$client_secret" "$realm"; then
    log_error "Failed to store credentials for ${component} on domain ${domain}. SSO integration failed."
    return 1
  fi
  
  # Generate integration code
  if ! generate_keycloak_integration_code "$component" "$framework" "$domain" "$client_id" "$client_secret" "$realm"; then
    log_warning "Failed to generate integration code for ${component} on domain ${domain}."
  fi
  
  log_success "Successfully integrated ${component} with Keycloak SSO on domain ${domain}"
  return 0
}

# Export functions
export -f keycloak_is_available
export -f keycloak_realm_exists
export -f keycloak_create_realm
export -f keycloak_register_client
export -f store_keycloak_credentials
export -f generate_keycloak_integration_code
export -f integrate_with_keycloak
export -f check_dependencies
