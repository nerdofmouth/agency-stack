#!/bin/bash
# keycloak_integration.sh - Keycloak integration utilities
# Part of the AgencyStack SSO Integration suite
#
# This file provides utility functions for:
# - Keycloak administration
# - Client management
# - Realm configuration
# - Token handling
# - Role mappings
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 10, 2025

# Strict error handling
set -eo pipefail

# Variables
KEYCLOAK_CONFIG_DIR="/opt/agency_stack/keycloak"
KEYCLOAK_SECRETS_DIR="/opt/agency_stack/secrets/keycloak"
COMPONENT_REGISTRY="/opt/agency_stack/config/registry/component_registry.json"

# Check for required dependencies
check_dependencies() {
  if ! command -v jq &>/dev/null; then
    log_error "jq is not installed. Please install it manually."
    return 1
  fi

  if ! command -v curl &>/dev/null; then
    log_error "curl is not installed. Please install it manually."
    return 1
  fi

  if ! command -v docker &>/dev/null; then
    log_error "docker is not installed. Please install it manually."
    return 1
  fi

  return 0
}

# Function to check if Keycloak is available
keycloak_is_available() {
  local domain="$1"
  local max_attempts=30
  local attempt=1
  local ready=false

  log_info "Checking if Keycloak is available for domain $domain..."

  # Check if keycloak is installed
  if [ ! -d "$KEYCLOAK_CONFIG_DIR" ]; then
    log_error "Keycloak directory not found at $KEYCLOAK_CONFIG_DIR"
    return 1
  fi

  # Check if domain-specific keycloak is installed
  if [ ! -d "$KEYCLOAK_CONFIG_DIR/$domain" ]; then
    log_error "Keycloak is not installed for domain $domain"
    return 1
  fi

  # Wait for Keycloak to be ready
  while [ $attempt -lt $max_attempts ]; do
    log_info "Waiting for Keycloak to be ready... ($attempt/$max_attempts)"
    
    # Try both legacy and new Keycloak health endpoints - Keycloak 21.x no longer uses /auth path
    if curl -s -f -k -o /dev/null -w '%{http_code}' "https://$domain/health" | grep -q 200 || \
       curl -s -f -k -o /dev/null -w '%{http_code}' "https://$domain/auth/health" | grep -q 200 || \
       curl -s -f -k -o /dev/null -w '%{http_code}' "https://$domain/admin/" | grep -q 200 || \
       curl -s -f -k -o /dev/null -w '%{http_code}' "https://$domain/" | grep -q 200; then
      ready=true
      break
    fi
    
    sleep 5
    attempt=$((attempt + 1))
  done

  if [ "$ready" = false ]; then
    log_error "Keycloak health endpoint not responding after $max_attempts attempts."
    return 1
  fi

  log_success "Keycloak is available for domain $domain"
  return 0
}

# Function to get Keycloak admin credentials
get_keycloak_admin_credentials() {
  local domain="$1"
  local credentials_file="$KEYCLOAK_SECRETS_DIR/$domain/admin.env"
  
  if [ ! -f "$credentials_file" ]; then
    log_error "Keycloak admin credentials file not found: $credentials_file"
    return 1
  fi
  
  source "$credentials_file"
  
  if [ -z "$KEYCLOAK_ADMIN" ] || [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    log_error "Keycloak admin credentials not found in $credentials_file"
    return 1
  fi
  
  echo "KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD"
  return 0
}

# Function to get Keycloak admin token
get_keycloak_admin_token() {
  local domain="$1"
  local credentials=$(get_keycloak_admin_credentials "$domain")
  
  if [ -z "$credentials" ]; then
    log_error "Failed to get Keycloak admin credentials"
    return 1
  fi
  
  eval "$credentials"
  
  local token_response=$(curl -s -X POST \
    -d "client_id=admin-cli" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    "https://$domain/realms/master/protocol/openid-connect/token")
  
  if [ -z "$token_response" ] || echo "$token_response" | grep -q "error"; then
    log_error "Failed to obtain Keycloak admin token: $token_response"
    return 1
  fi
  
  local access_token=$(echo "$token_response" | jq -r '.access_token')
  
  if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
    log_error "Failed to parse Keycloak admin token"
    return 1
  fi
  
  echo "$access_token"
  return 0
}

# Function to check if realm exists
keycloak_realm_exists() {
  local domain="$1"
  local realm="$2"
  local token="${3:-$(get_keycloak_admin_token "$domain")}"
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for realm check"
    return 1
  fi
  
  local response=$(curl -s -k -o /dev/null -w '%{http_code}' "https://$domain/admin/realms/$realm" \
    -H "Authorization: Bearer $token")
  
  [ "$response" = "200" ]
}

# Function to create a realm
keycloak_create_realm() {
  local domain="$1"
  local realm="$2"
  local realm_name="${3:-$realm}"
  local token="${4:-$(get_keycloak_admin_token "$domain")}"
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for creating realm"
    return 1
  fi
  
  local realm_json='{
    "realm": "'$realm_name'",
    "enabled": true,
    "displayName": "'$realm_name'",
    "displayNameHtml": "<div class=\"kc-logo-text\"><span>'$realm_name'</span></div>",
    "sslRequired": "external",
    "registrationAllowed": false,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "resetPasswordAllowed": true,
    "editUsernameAllowed": false,
    "bruteForceProtected": true
  }'
  
  local response=$(curl -s -k -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$realm_json" \
    "https://$domain/admin/realms")
  
  if [ -n "$response" ] && echo "$response" | grep -q "error"; then
    log_error "Failed to create realm $realm: $response"
    return 1
  fi
  
  log_success "Created realm: $realm"
  return 0
}

# Function to check if client exists
keycloak_client_exists() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="${4:-$(get_keycloak_admin_token "$domain")}"
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for client check"
    return 1
  fi
  
  local response=$(curl -s -k "https://$domain/admin/realms/$realm/clients?clientId=$client_id" \
    -H "Authorization: Bearer $token")
  
  echo "$response" | grep -q "\"clientId\":\"$client_id\""
}

# Function to delete a client
keycloak_delete_client() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="${4:-$(get_keycloak_admin_token "$domain")}"
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for client deletion"
    return 1
  fi
  
  # Get client UUID
  local client_uuid=$(keycloak_get_client_id "$domain" "$realm" "$client_id" "$token")
  
  if [ -z "$client_uuid" ]; then
    log_error "Failed to get UUID for client $client_id"
    return 1
  fi
  
  # Delete the client
  local response=$(curl -s -k -X DELETE "https://$domain/admin/realms/$realm/clients/$client_uuid" \
    -H "Authorization: Bearer $token")
  
  if [ $? -ne 0 ]; then
    log_error "Failed to delete client $client_id"
    return 1
  fi
  
  log_success "Successfully deleted client $client_id"
  return 0
}

# Function to get client ID (UUID)
keycloak_get_client_id() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="${4:-$(get_keycloak_admin_token "$domain")}"
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for getting client ID"
    return 1
  fi
  
  # Get list of clients
  local response=$(curl -s -k "https://$domain/admin/realms/$realm/clients?clientId=$client_id" \
    -H "Authorization: Bearer $token")
  
  if [ -z "$response" ] || echo "$response" | grep -q "error"; then
    log_error "Failed to get clients list"
    return 1
  fi
  
  # Extract UUID from response
  local uuid=$(echo "$response" | grep -o "\"id\":\"[^\"]*\"" | head -1 | cut -d'"' -f4)
  
  if [ -z "$uuid" ]; then
    log_error "Client $client_id not found"
    return 1
  fi
  
  echo "$uuid"
  return 0
}

# Function to create client from file
keycloak_create_client_from_file() {
  local domain="$1"
  local realm="$2"
  local client_file="$3"
  local token="${4:-$(get_keycloak_admin_token "$domain")}"
  
  if [ ! -f "$client_file" ]; then
    log_error "Client configuration file not found: $client_file"
    return 1
  fi
  
  local client_json=$(cat "$client_file")
  
  local response=$(curl -s -k -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$client_json" \
    "https://$domain/admin/realms/$realm/clients")
  
  if [ -n "$response" ] && echo "$response" | grep -q "error"; then
    log_error "Failed to create client: $response"
    return 1
  fi
  
  log_success "Created client from file: $client_file"
  return 0
}

# Function to create role mapper
keycloak_create_role_mapper() {
  local domain="$1"
  local realm="$2"
  local client_uuid="$3"
  local role_name="$4"
  local role_display_name="$5"
  local token="${6:-$(get_keycloak_admin_token "$domain")}"
  
  # Create role
  local role_json='{
    "name": "'$role_name'",
    "description": "'$role_display_name' role for PeerTube",
    "composite": false,
    "clientRole": true
  }'
  
  local response=$(curl -s -k -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$role_json" \
    "https://$domain/admin/realms/$realm/clients/$client_uuid/roles")
  
  if [ -n "$response" ] && echo "$response" | grep -q "error"; then
    log_error "Failed to create role $role_name: $response"
    return 1
  fi
  
  log_success "Created role: $role_name"
  return 0
}

# Function to update component registry for SSO configuration
keycloak_update_sso_configured() {
  local component="$1"
  
  if [ -z "$component" ]; then
    log_error "Component name is required for updating SSO configuration"
    return 1
  fi
  
  # Check if component registry exists
  if [ ! -f "${COMPONENT_REGISTRY}" ]; then
    log_warning "Component registry not found at ${COMPONENT_REGISTRY}"
    return 0
  fi
  
  # Update component registry with SSO configuration status
  if command -v jq &>/dev/null; then
    # Use jq to update the registry if available
    if ! jq --arg component "$component" '.components[$component].sso_configured = true' "${COMPONENT_REGISTRY}" > "${COMPONENT_REGISTRY}.tmp"; then
      log_error "Failed to update component registry for $component"
      return 1
    fi
    mv "${COMPONENT_REGISTRY}.tmp" "${COMPONENT_REGISTRY}"
  else
    # Simple sed replacement if jq is not available
    if ! sed -i "s/\"${component}\":{/\"${component}\":{\"sso_configured\":true,/g" "${COMPONENT_REGISTRY}"; then
      log_warning "Failed to update component registry for $component using sed"
    fi
  fi
  
  log_success "Updated component registry for $component with SSO configuration status"
  return 0
}

# Function to register a client with Keycloak
keycloak_register_client() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local client_name="$4"
  local redirect_uris="$5"
  local token=$(get_keycloak_admin_token "$domain")
  
  if [ -z "$token" ]; then
    log_error "Failed to obtain admin token for registering client"
    return 1
  fi
  
  # Check if client already exists
  if keycloak_client_exists "$domain" "$realm" "$client_id" "$token"; then
    log_info "Client $client_id already exists, updating configuration"
    keycloak_delete_client "$domain" "$realm" "$client_id" "$token"
  fi
  
  # Generate a client secret
  local client_secret=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
  
  # Create client JSON
  local client_json='{
    "clientId": "'"$client_id"'",
    "name": "'"$client_name"'",
    "description": "AgencyStack auto-generated client for '"$client_name"'",
    "enabled": true,
    "redirectUris": '"$redirect_uris"',
    "clientAuthenticatorType": "client-secret",
    "secret": "'"$client_secret"'",
    "publicClient": false,
    "protocol": "openid-connect",
    "attributes": {
      "pkce.code.challenge.method": "S256"
    }
  }'
  
  # Create the client in Keycloak
  local response=$(curl -s -k -X POST "https://$domain/admin/realms/$realm/clients" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$client_json")
  
  if [ $? -ne 0 ]; then
    log_error "Failed to create client $client_id in Keycloak"
    return 1
  fi
  
  log_success "Successfully registered client $client_id with Keycloak"
  echo "$client_secret"
  return 0
}

# Export functions
export -f keycloak_is_available
export -f get_keycloak_admin_credentials
export -f get_keycloak_admin_token
export -f keycloak_realm_exists
export -f keycloak_create_realm
export -f keycloak_client_exists
export -f keycloak_delete_client
export -f keycloak_get_client_id
export -f keycloak_create_client_from_file
export -f keycloak_create_role_mapper
export -f keycloak_update_sso_configured
export -f keycloak_register_client
