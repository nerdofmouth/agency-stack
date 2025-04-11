#!/bin/bash
# keycloak_oauth_status.sh - Collect Keycloak OAuth/IDP status for AgencyStack dashboard
# https://stack.nerdofmouth.com
#
# This script gathers information about configured OAuth Identity Providers in Keycloak
# and formats it for display in the AgencyStack dashboard.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-11

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Variables
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_dashboard.log"
DASHBOARD_DATA_FILE="${CONFIG_DIR}/dashboard/dashboard_data.json"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_dashboard.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

# Ensure log directories exist
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Parameters
DOMAIN=""
CLIENT_ID=""
JSON_OUTPUT=true
QUIET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    *)
      # Unknown argument
      echo "Unknown argument: $1"
      shift
      ;;
  esac
done

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  if [ "$QUIET" = false ]; then
    echo -e "$message"
  fi
  
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Get all domains with Keycloak installed
get_domains() {
  if [ -d "$KEYCLOAK_DIR" ]; then
    find "$KEYCLOAK_DIR" -maxdepth 1 -type d -not -path "$KEYCLOAK_DIR" -exec basename {} \;
  fi
}

# Get OAuth Identity Provider status for a domain
get_oauth_status() {
  local domain="$1"
  local client_id="$2"
  
  # Determine realm name
  local realm_name="agency"
  if [ -n "$client_id" ]; then
    realm_name="$client_id"
  fi
  
  # Check if Keycloak is running
  if ! docker ps --format '{{.Names}}' | grep -q "keycloak_${domain//[^a-zA-Z0-9_]/}"; then
    echo '{"running": false, "providers": []}'
    return
  fi
  
  # Get admin credentials
  local admin_user="admin"
  local admin_password=""
  
  if [ -f "${SECRETS_DIR}/${domain}/admin.env" ]; then
    source "${SECRETS_DIR}/${domain}/admin.env"
    admin_password="$KEYCLOAK_ADMIN_PASSWORD"
  else
    # Try to get from environment or use default
    admin_password="admin"
  fi
  
  # Get admin token
  local admin_token=$(curl -s -X POST "https://${domain}/auth/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_password}" \
    -d "grant_type=password" | jq -r .access_token)
  
  if [ -z "$admin_token" ] || [ "$admin_token" = "null" ]; then
    echo '{"running": true, "error": "Failed to authenticate", "providers": []}'
    return
  fi
  
  # Get Identity Providers
  local providers=$(curl -s -X GET "https://${domain}/auth/admin/realms/${realm_name}/identity-provider/instances" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -z "$providers" ] || [ "$providers" = "null" ]; then
    echo '{"running": true, "providers": []}'
    return
  fi
  
  # Format providers for dashboard
  local formatted_providers=$(echo "$providers" | jq '[.[] | {
    "id": .alias,
    "name": .displayName,
    "type": .providerId,
    "enabled": .enabled,
    "last_checked": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "status": if .enabled then "active" else "inactive" end
  }]')
  
  echo '{"running": true, "providers": '"$formatted_providers"'}'
}

# Main function
main() {
  log "INFO" "Starting Keycloak OAuth dashboard status collection"
  
  # If domain is provided, only check that domain
  if [ -n "$DOMAIN" ]; then
    local domains=("$DOMAIN")
  else
    # Get all domains with Keycloak installed
    readarray -t domains < <(get_domains)
  fi
  
  # Collect OAuth status for each domain
  local result='{"keycloak_oauth": {'
  local first=true
  
  for domain in "${domains[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      result="$result,"
    fi
    
    log "INFO" "Checking OAuth status for $domain"
    local status=$(get_oauth_status "$domain" "$CLIENT_ID")
    result="$result\"$domain\": $status"
  done
  
  result="$result}}"
  
  # Update dashboard data file
  if [ -f "$DASHBOARD_DATA_FILE" ]; then
    local dashboard_data=$(cat "$DASHBOARD_DATA_FILE")
    
    # Check if components key exists
    if echo "$dashboard_data" | jq -e '.components' > /dev/null; then
      # Add or update the security_identity key
      dashboard_data=$(echo "$dashboard_data" | jq --argjson oauth "$(echo "$result" | jq .keycloak_oauth)" '.components.security_identity = {"keycloak_oauth": $oauth}')
    else
      # Create components structure with security_identity
      dashboard_data=$(echo "$dashboard_data" | jq --argjson oauth "$(echo "$result" | jq .keycloak_oauth)" '. + {"components": {"security_identity": {"keycloak_oauth": $oauth}}}')
    fi
    
    # Write updated data back to file
    echo "$dashboard_data" | sudo tee "$DASHBOARD_DATA_FILE" > /dev/null
    log "INFO" "Updated dashboard data file"
  else
    # Create new dashboard data file
    log "INFO" "Creating new dashboard data file"
    echo "$result" | sudo tee "$DASHBOARD_DATA_FILE" > /dev/null
  fi
  
  # Output the result
  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result"
  fi
  
  log "INFO" "Finished Keycloak OAuth dashboard status collection"
}

# Run main function
main
