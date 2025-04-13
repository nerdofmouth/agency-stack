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
realm_exists() {
  local domain="$1"
  local realm="$2"
  local token="$3"
  
  local response=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://$domain/admin/realms/$realm")
  
  if [ -z "$response" ] || echo "$response" | grep -q "error"; then
    return 1
  fi
  
  return 0
}

# Function to create a realm
create_realm() {
  local domain="$1"
  local realm="$2"
  local token="$3"
  
  local realm_json='{
    "realm": "'$realm'",
    "enabled": true,
    "displayName": "'$realm'",
    "displayNameHtml": "<div class=\"kc-logo-text\"><span>'$realm'</span></div>",
    "sslRequired": "external",
    "registrationAllowed": false,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "resetPasswordAllowed": true,
    "editUsernameAllowed": false,
    "bruteForceProtected": true
  }'
  
  local response=$(curl -s -X POST \
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
client_exists() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="$4"
  
  local response=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://$domain/admin/realms/$realm/clients?clientId=$client_id")
  
  if [ -z "$response" ] || echo "$response" | grep -q "error" || [ "$response" = "[]" ]; then
    return 1
  fi
  
  return 0
}

# Function to delete a client
delete_client() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="$4"
  
  # Get client UUID
  local client_uuid=$(get_client_id "$domain" "$realm" "$client_id" "$token")
  
  if [ -z "$client_uuid" ]; then
    log_error "Failed to get UUID for client $client_id"
    return 1
  fi
  
  local response=$(curl -s -X DELETE \
    -H "Authorization: Bearer $token" \
    "https://$domain/admin/realms/$realm/clients/$client_uuid")
  
  if [ -n "$response" ] && echo "$response" | grep -q "error"; then
    log_error "Failed to delete client $client_id: $response"
    return 1
  fi
  
  log_success "Deleted client: $client_id"
  return 0
}

# Function to get client ID (UUID)
get_client_id() {
  local domain="$1"
  local realm="$2"
  local client_id="$3"
  local token="$4"
  
  local response=$(curl -s -X GET \
    -H "Authorization: Bearer $token" \
    "https://$domain/admin/realms/$realm/clients?clientId=$client_id")
  
  if [ -z "$response" ] || echo "$response" | grep -q "error" || [ "$response" = "[]" ]; then
    log_error "Client $client_id not found"
    return 1
  fi
  
  local uuid=$(echo "$response" | jq -r '.[0].id')
  
  if [ -z "$uuid" ] || [ "$uuid" = "null" ]; then
    log_error "Failed to parse client UUID"
    return 1
  fi
  
  echo "$uuid"
  return 0
}

# Function to create client from file
create_client_from_file() {
  local domain="$1"
  local realm="$2"
  local client_file="$3"
  local token="$4"
  
  if [ ! -f "$client_file" ]; then
    log_error "Client configuration file not found: $client_file"
    return 1
  fi
  
  local client_json=$(cat "$client_file")
  
  local response=$(curl -s -X POST \
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
create_role_mapper() {
  local domain="$1"
  local realm="$2"
  local client_uuid="$3"
  local role_name="$4"
  local role_display_name="$5"
  local token="$6"
  
  # Create role
  local role_json='{
    "name": "'$role_name'",
    "description": "'$role_display_name' role for PeerTube",
    "composite": false,
    "clientRole": true
  }'
  
  local response=$(curl -s -X POST \
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
update_sso_configured() {
  local component="$1"
  
  if [ -z "$component" ]; then
    log_error "Component name is required"
    return 1
  fi
  
  local registry_file="/opt/agency_stack/repo/config/registry/component_registry.json"
  
  if [ ! -f "$registry_file" ]; then
    log_error "Component registry file not found: $registry_file"
    return 1
  fi
  
  # Create a backup of the registry file
  cp "$registry_file" "${registry_file}.bak"
  
  # Use jq to update the sso_configured flag
  if command -v jq >/dev/null 2>&1; then
    # Find the path to the component
    local component_path=$(jq -r "path(.components[][\"$component\"]) | .[0], .[1]" "$registry_file")
    
    if [ -z "$component_path" ] || [ "$component_path" = "null" ]; then
      log_error "Component $component not found in registry"
      return 1
    fi
    
    # Update the sso_configured flag
    jq "(.components.${component_path}.integration_status.sso_configured) = true" "$registry_file" > "${registry_file}.tmp"
    if [ $? -eq 0 ]; then
      mv "${registry_file}.tmp" "$registry_file"
      log_success "Updated component registry for $component - marked SSO as configured"
    else
      log_error "Failed to update component registry"
      return 1
    fi
  else
    log_error "jq is required to update component registry"
    return 1
  fi
  
  return 0
}
