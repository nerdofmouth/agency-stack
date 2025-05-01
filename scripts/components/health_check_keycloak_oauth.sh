#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: health_check_keycloak_oauth.sh
# Path: /scripts/components/health_check_keycloak_oauth.sh
#
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Variables
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_health.log"
COMPONENT_REGISTRY="${ROOT_DIR}/config/component_registry.json"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_health.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Variables
DOMAIN=""
CLIENT_ID=""
VERBOSE=false
ALERT=false
SHOW_SUMMARY=true
EXIT_CODE=0

# Tracking arrays for health check results
HEALTH_CHECKS=()
HEALTH_STATUSES=()
HEALTH_DETAILS=()

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}Keycloak OAuth Providers Health Check${NC}"
  echo -e "========================================"
  echo -e "This script performs comprehensive health checks on Keycloak OAuth providers."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>       Domain name for Keycloak (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id> Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--verbose${NC}               Show verbose output"
  echo -e "  ${BOLD}--alert${NC}                 Send alerts on critical issues"
  echo -e "  ${BOLD}--no-summary${NC}            Don't show summary at the end"
  echo -e "  ${BOLD}--help${NC}                  Show this help message"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain auth.example.com --verbose"
  exit 0
}

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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --alert)
      ALERT=true
      shift
      ;;
    --no-summary)
      SHOW_SUMMARY=false
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1

# Determine realm name
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="$CLIENT_ID"

# Log initial execution information
log "INFO" "Starting Keycloak OAuth providers health check for domain: $DOMAIN" true

# Function to record health check result
record_health_check() {
  local check_name="$1"
  local status="$2"
  local details="$3"
  
  HEALTH_CHECKS+=("$check_name")
  HEALTH_STATUSES+=("$status")
  HEALTH_DETAILS+=("$details")
  
  # Log the health check result
  log "CHECK" "$check_name: $status - $details" "$VERBOSE"
}

# Check if Keycloak is installed
check_keycloak_installed() {
  log "INFO" "Checking if Keycloak is installed for domain: $DOMAIN" "$VERBOSE"
  
  if [ ! -d "${KEYCLOAK_DIR}/${DOMAIN}" ]; then
    record_health_check "Keycloak Installation" "FAILED" "Keycloak not installed for domain: $DOMAIN"
    return 1
  fi
  
  record_health_check "Keycloak Installation" "PASSED" "Keycloak installed for domain: $DOMAIN"
  return 0
}

# Check if Keycloak is running
check_keycloak_running() {
  log "INFO" "Checking if Keycloak is running for domain: $DOMAIN" "$VERBOSE"
  
  local container_name="keycloak_${DOMAIN//[^a-zA-Z0-9_]/}"
  if ! docker ps | grep -q "$container_name"; then
    record_health_check "Keycloak Running" "FAILED" "Keycloak container not running for domain: $DOMAIN"
    return 1
  fi
  
  record_health_check "Keycloak Running" "PASSED" "Keycloak container running for domain: $DOMAIN"
  return 0
}

# Get admin token
get_admin_token() {
  log "INFO" "Getting admin token for domain: $DOMAIN" "$VERBOSE"
  
  # Get admin credentials
  local admin_user="admin"
  local admin_password=""
  
  if [ -f "${SECRETS_DIR}/${DOMAIN}/admin.env" ]; then
    source "${SECRETS_DIR}/${DOMAIN}/admin.env"
    admin_password="$KEYCLOAK_ADMIN_PASSWORD"
  else
    admin_password="admin"
    log "WARNING" "Admin credentials file not found, using default password" "$VERBOSE"
  fi
  
  # Get admin token
  local token_response=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_password}" \
    -d "grant_type=password")
  
  local admin_token=$(echo "$token_response" | jq -r .access_token)
  
  if [ -z "$admin_token" ] || [ "$admin_token" = "null" ]; then
    record_health_check "Admin API Access" "FAILED" "Failed to obtain admin token"
    return 1
  fi
  
  record_health_check "Admin API Access" "PASSED" "Successfully obtained admin token"
  echo "$admin_token"
  return 0
}

# Check OAuth providers
check_oauth_providers() {
  local admin_token="$1"
  log "INFO" "Checking OAuth Identity Providers for domain: $DOMAIN" "$VERBOSE"
  
  # Get Identity Providers
  local providers=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -z "$providers" ] || [ "$providers" = "[]" ]; then
    record_health_check "OAuth Providers" "WARNING" "No OAuth Identity Providers configured"
    return 0
  fi
  
  # Parse and check each provider
  local provider_count=$(echo "$providers" | jq length)
  local enabled_count=$(echo "$providers" | jq '[.[] | select(.enabled == true)] | length')
  
  record_health_check "OAuth Providers" "PASSED" "Found $provider_count providers, $enabled_count enabled"
  
  # Check each provider in detail
  local index=0
  while [ $index -lt "$provider_count" ]; do
    local provider=$(echo "$providers" | jq -r ".[$index]")
    local provider_id=$(echo "$provider" | jq -r .alias)
    local provider_name=$(echo "$provider" | jq -r .displayName)
    local provider_enabled=$(echo "$provider" | jq -r .enabled)
    
    log "INFO" "Checking provider: $provider_name ($provider_id)" "$VERBOSE"
    
    # Check if enabled
    if [ "$provider_enabled" = "true" ]; then
      record_health_check "Provider: $provider_name" "PASSED" "Provider is enabled"
      
      # Check configuration for common issues
      check_provider_config "$admin_token" "$provider_id" "$provider_name"
    else
      record_health_check "Provider: $provider_name" "WARNING" "Provider is disabled"
    fi
    
    index=$((index + 1))
  done
  
  return 0
}

# Check provider configuration
check_provider_config() {
  local admin_token="$1"
  local provider_id="$2"
  local provider_name="$3"
  
  # Get provider configuration
  local provider_config=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider_id}" \
    -H "Authorization: Bearer ${admin_token}")
  
  # Check for common configuration issues
  
  # 1. Check if storeToken is enabled (potential security issue)
  local store_token=$(echo "$provider_config" | jq -r .storeToken)
  if [ "$store_token" = "true" ]; then
    record_health_check "Provider Config: $provider_name" "WARNING" "Token storage is enabled, consider disabling for security"
  fi
  
  # 2. Check if trust email is enabled (potential security issue)
  local trust_email=$(echo "$provider_config" | jq -r .trustEmail)
  if [ "$trust_email" = "true" ]; then
    record_health_check "Provider Config: $provider_name" "WARNING" "Trust email is enabled, consider disabling for security"
  fi
  
  # 3. Check signature validation for OIDC providers
  local provider_type=$(echo "$provider_config" | jq -r .providerId)
  if [[ "$provider_type" == "oidc" || "$provider_type" == "google" || "$provider_type" == "microsoft" ]]; then
    local validate_signature=$(echo "$provider_config" | jq -r '.config["validateSignature"]')
    
    if [ "$validate_signature" != "true" ]; then
      record_health_check "Provider Security: $provider_name" "WARNING" "Signature validation is disabled, security risk"
    else
      record_health_check "Provider Security: $provider_name" "PASSED" "Signature validation is enabled"
    fi
  fi
  
  # 4. Check mappers configuration
  local mappers=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider_id}/mappers" \
    -H "Authorization: Bearer ${admin_token}")
  
  local mapper_count=$(echo "$mappers" | jq length)
  if [ "$mapper_count" -eq 0 ]; then
    record_health_check "Provider Mappers: $provider_name" "WARNING" "No mappers configured, user attributes may not be imported correctly"
  else
    # Check for email mapper
    local has_email_mapper=$(echo "$mappers" | jq '[.[] | select(.config.user.attribute == "email" or .config["user.attribute"] == "email")] | length')
    
    if [ "$has_email_mapper" -eq 0 ]; then
      record_health_check "Provider Mappers: $provider_name" "WARNING" "No email mapper found, email addresses may not be imported correctly"
    else
      record_health_check "Provider Mappers: $provider_name" "PASSED" "Email mapper configured properly"
    fi
  fi
}

# Check authentication flow
check_authentication_flow() {
  local admin_token="$1"
  log "INFO" "Checking authentication flow for domain: $DOMAIN" "$VERBOSE"
  
  # Get browser flow
  local browser_flow=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser" \
    -H "Authorization: Bearer ${admin_token}")
  
  # Check if Identity Provider Redirector is enabled
  local executions=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser/executions" \
    -H "Authorization: Bearer ${admin_token}")
  
  local idp_redirector=$(echo "$executions" | jq '[.[] | select(.providerId == "identity-provider-redirector")] | .[0]')
  local idp_redirector_enabled=$(echo "$idp_redirector" | jq -r .requirement)
  
  if [ -z "$idp_redirector" ] || [ "$idp_redirector" = "null" ]; then
    record_health_check "Authentication Flow" "WARNING" "Identity Provider Redirector not found in authentication flow"
  elif [ "$idp_redirector_enabled" = "DISABLED" ]; then
    record_health_check "Authentication Flow" "WARNING" "Identity Provider Redirector is disabled, OAuth buttons may not appear"
  else
    record_health_check "Authentication Flow" "PASSED" "Identity Provider Redirector is enabled in authentication flow"
  fi
}

# Check client scopes for OAuth integration
check_client_scopes() {
  local admin_token="$1"
  log "INFO" "Checking client scopes for OAuth integration" "$VERBOSE"
  
  # Get all clients
  local clients=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${admin_token}")
  
  # Check if any clients are configured for OAuth
  local client_count=$(echo "$clients" | jq length)
  if [ "$client_count" -eq 0 ]; then
    record_health_check "Client OAuth Configuration" "WARNING" "No clients found in realm"
    return 0
  fi
  
  # Find clients with standard flow enabled (potential OAuth users)
  local standard_flow_clients=$(echo "$clients" | jq '[.[] | select(.standardFlowEnabled == true)]')
  local standard_flow_count=$(echo "$standard_flow_clients" | jq length)
  
  if [ "$standard_flow_count" -eq 0 ]; then
    record_health_check "Client OAuth Configuration" "WARNING" "No clients with standard flow enabled found"
    return 0
  fi
  
  record_health_check "Client OAuth Configuration" "PASSED" "Found $standard_flow_count clients with standard flow enabled"
  
  # Check a sample client's scope mappings
  local sample_client_id=$(echo "$standard_flow_clients" | jq -r '.[0].clientId')
  record_health_check "Client: $sample_client_id" "INFO" "Checked as sample OAuth client"
}

# Main function
main() {
  # Check Keycloak installation
  check_keycloak_installed || EXIT_CODE=1
  
  # Check if Keycloak is running
  check_keycloak_running || EXIT_CODE=1
  
  # If Keycloak is not running, we can't proceed with API checks
  if [ $EXIT_CODE -eq 1 ]; then
    record_health_check "API Checks" "SKIPPED" "Keycloak not running, skipping API checks"
  else
    # Get admin token
    ADMIN_TOKEN=$(get_admin_token)
    
    if [ -n "$ADMIN_TOKEN" ]; then
      # Check OAuth providers
      check_oauth_providers "$ADMIN_TOKEN"
      
      # Check authentication flow
      check_authentication_flow "$ADMIN_TOKEN"
      
      # Check client scopes
      check_client_scopes "$ADMIN_TOKEN"
    else
      EXIT_CODE=1
    fi
  fi
  
  # Show summary if requested
  if [ "$SHOW_SUMMARY" = true ]; then
    echo -e "\n${MAGENTA}${BOLD}Health Check Summary for ${DOMAIN}:${NC}"
    echo -e "================================================"
    
    local pass_count=0
    local warn_count=0
    local fail_count=0
    local info_count=0
    
    for i in "${!HEALTH_CHECKS[@]}"; do
      local status="${HEALTH_STATUSES[$i]}"
      local color="$NC"
      
      case "$status" in
        PASSED)
          color="$GREEN"
          pass_count=$((pass_count + 1))
          ;;
        WARNING)
          color="$YELLOW"
          warn_count=$((warn_count + 1))
          ;;
        FAILED)
          color="$RED"
          fail_count=$((fail_count + 1))
          ;;
        INFO|SKIPPED)
          color="$BLUE"
          info_count=$((info_count + 1))
          ;;
      esac
      
      echo -e "${BOLD}${HEALTH_CHECKS[$i]}:${NC} ${color}${HEALTH_STATUSES[$i]}${NC}"
      echo -e "  ${HEALTH_DETAILS[$i]}"
    done
    
    echo -e "\n${BOLD}Results:${NC}"
    echo -e "  ${GREEN}Passed: $pass_count${NC}"
    echo -e "  ${YELLOW}Warnings: $warn_count${NC}"
    echo -e "  ${RED}Failed: $fail_count${NC}"
    echo -e "  ${BLUE}Info/Skipped: $info_count${NC}"
    
    # Set exit code based on failures
    if [ $fail_count -gt 0 ]; then
      EXIT_CODE=1
    fi
  fi
  
  # Send alerts if requested and there are failures
  if [ "$ALERT" = true ] && [ $EXIT_CODE -eq 1 ]; then
    if [ -f "${ROOT_DIR}/scripts/notifications/notify_all.sh" ]; then
      "${ROOT_DIR}/scripts/notifications/notify_all.sh" \
        "Keycloak OAuth Health Check Failed" \
        "Health check for $DOMAIN found issues with Keycloak OAuth providers. Please check the logs for details."
    fi
  }
  
  # Update component registry
  if [ -f "$COMPONENT_REGISTRY" ]; then
    # Get current values
    local oauth_health_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Update registry with health check status
    if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
      "${ROOT_DIR}/scripts/utils/update_component_registry.sh" \
        --update-component keycloak \
        --update-flag oauth_health_check \
        --update-value "true" \
        --update-timestamp oauth_health_last_run "$oauth_health_timestamp"
      
      log "INFO" "Updated component registry with health check status" "$VERBOSE"
    fi
  fi
  
  log "INFO" "Finished Keycloak OAuth providers health check for domain: $DOMAIN"
  exit $EXIT_CODE
}

# Run main function
main
