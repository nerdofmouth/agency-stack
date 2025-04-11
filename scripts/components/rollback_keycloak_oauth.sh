#!/bin/bash
# rollback_keycloak_oauth.sh - Rollback Keycloak OAuth provider configurations
# https://stack.nerdofmouth.com
#
# This script provides rollback capabilities for Keycloak OAuth provider configurations.
# It follows the AgencyStack repository integrity policy by ensuring all changes
# are properly tracked and no direct modifications are made to remote VMs.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-11

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${SCRIPT_DIR}/../utils/common.sh"

# Variables
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_rollback.log"
BACKUP_DIR="${CONFIG_DIR}/backups/keycloak/oauth"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_oauth_rollback.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Variables
DOMAIN=""
CLIENT_ID=""
PROVIDER=""
DISABLE_ONLY=false
ALL_PROVIDERS=false
FORCE=false
VERBOSE=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}Keycloak OAuth Provider Rollback${NC}"
  echo -e "=================================="
  echo -e "This script provides rollback capabilities for Keycloak OAuth provider configurations."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>       Domain name for Keycloak (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id> Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--provider${NC} <provider>   Provider to rollback (google|github|apple|linkedin|microsoft)"
  echo -e "  ${BOLD}--all-providers${NC}         Rollback all OAuth providers"
  echo -e "  ${BOLD}--disable-only${NC}          Only disable provider(s), don't remove"
  echo -e "  ${BOLD}--force${NC}                 Skip confirmation prompts"
  echo -e "  ${BOLD}--verbose${NC}               Show verbose output"
  echo -e "  ${BOLD}--help${NC}                  Show this help message"
  echo -e ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  $0 --domain auth.example.com --provider google"
  echo -e "  $0 --domain auth.example.com --all-providers --disable-only"
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
    --provider)
      PROVIDER="$2"
      shift
      shift
      ;;
    --all-providers)
      ALL_PROVIDERS=true
      shift
      ;;
    --disable-only)
      DISABLE_ONLY=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
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
fi

if [ "$ALL_PROVIDERS" = "false" ] && [ -z "$PROVIDER" ]; then
  echo -e "${RED}Error: Either --provider or --all-providers is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Determine realm name
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="$CLIENT_ID"
fi

# Log initial execution information
log "INFO" "Starting Keycloak OAuth provider rollback for domain: $DOMAIN" true

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
    log "ERROR" "Failed to obtain admin token" true
    return 1
  fi
  
  log "INFO" "Successfully obtained admin token" "$VERBOSE"
  echo "$admin_token"
  return 0
}

# Backup provider configuration
backup_provider_config() {
  local provider="$1"
  local admin_token="$2"
  
  log "INFO" "Backing up $provider provider configuration" "$VERBOSE"
  
  # Create backup directory
  mkdir -p "${BACKUP_DIR}/${DOMAIN}/${REALM_NAME}"
  
  # Get provider configuration
  local provider_config=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider}" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -z "$provider_config" ] || [ "$provider_config" = "null" ]; then
    log "WARNING" "Provider $provider not found or no configuration to backup" "$VERBOSE"
    return 1
  fi
  
  # Save provider configuration
  local backup_file="${BACKUP_DIR}/${DOMAIN}/${REALM_NAME}/${provider}_$(date +%Y%m%d_%H%M%S).json"
  echo "$provider_config" > "$backup_file"
  log "INFO" "Backup saved to $backup_file" "$VERBOSE"
  
  # Get provider mappers
  local mappers=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider}/mappers" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -n "$mappers" ] && [ "$mappers" != "[]" ]; then
    # Save mappers configuration
    local mappers_file="${BACKUP_DIR}/${DOMAIN}/${REALM_NAME}/${provider}_mappers_$(date +%Y%m%d_%H%M%S).json"
    echo "$mappers" > "$mappers_file"
    log "INFO" "Mappers backup saved to $mappers_file" "$VERBOSE"
  fi
  
  return 0
}

# Disable provider
disable_provider() {
  local provider="$1"
  local admin_token="$2"
  
  log "INFO" "Disabling $provider provider" true
  
  # Get current provider configuration
  local provider_config=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider}" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -z "$provider_config" ] || [ "$provider_config" = "null" ]; then
    log "WARNING" "Provider $provider not found" true
    return 1
  fi
  
  # Backup current configuration
  backup_provider_config "$provider" "$admin_token"
  
  # Update configuration to disable provider
  local updated_config=$(echo "$provider_config" | jq '.enabled = false')
  
  # Update provider
  local http_status=$(curl -s -X PUT "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider}" \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d "$updated_config" \
    -o /dev/null -w "%{http_code}")
  
  if [ "$http_status" = "204" ]; then
    log "INFO" "Provider $provider successfully disabled" true
    return 0
  else
    log "ERROR" "Failed to disable provider $provider, HTTP status: $http_status" true
    return 1
  fi
}

# Remove provider
remove_provider() {
  local provider="$1"
  local admin_token="$2"
  
  log "INFO" "Removing $provider provider" true
  
  # Backup current configuration
  backup_provider_config "$provider" "$admin_token"
  
  # Delete provider
  local http_status=$(curl -s -X DELETE "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${provider}" \
    -H "Authorization: Bearer ${admin_token}" \
    -o /dev/null -w "%{http_code}")
  
  if [ "$http_status" = "204" ]; then
    log "INFO" "Provider $provider successfully removed" true
    return 0
  else
    log "ERROR" "Failed to remove provider $provider, HTTP status: $http_status" true
    return 1
  fi
}

# Get all providers
get_all_providers() {
  local admin_token="$1"
  
  log "INFO" "Getting all OAuth providers" "$VERBOSE"
  
  # Get Identity Providers
  local providers=$(curl -s -X GET "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances" \
    -H "Authorization: Bearer ${admin_token}")
  
  if [ -z "$providers" ] || [ "$providers" = "[]" ]; then
    log "WARNING" "No OAuth Identity Providers configured" "$VERBOSE"
    return 1
  fi
  
  # Extract provider aliases
  local provider_aliases=$(echo "$providers" | jq -r '.[].alias')
  echo "$provider_aliases"
  return 0
}

# Process providers
process_providers() {
  local admin_token=$(get_admin_token)
  if [ -z "$admin_token" ]; then
    log "ERROR" "Failed to authenticate, cannot proceed with rollback" true
    exit 1
  fi
  
  if [ "$ALL_PROVIDERS" = "true" ]; then
    local providers=$(get_all_providers "$admin_token")
    if [ -z "$providers" ]; then
      log "WARNING" "No providers found to rollback" true
      exit 0
    fi
    
    log "INFO" "Rolling back all providers: $providers" true
    
    # Confirm before proceeding
    if [ "$FORCE" = "false" ]; then
      echo -e "${YELLOW}Warning: This will rollback all OAuth providers for domain $DOMAIN${NC}"
      echo -e "Providers to be affected: $providers"
      if [ "$DISABLE_ONLY" = "true" ]; then
        echo -e "Action: Disable only"
      else
        echo -e "Action: Remove completely"
      fi
      
      read -p "Do you want to continue? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Rollback canceled by user" true
        exit 0
      fi
    fi
    
    # Process each provider
    for provider in $providers; do
      if [ "$DISABLE_ONLY" = "true" ]; then
        disable_provider "$provider" "$admin_token"
      else
        remove_provider "$provider" "$admin_token"
      fi
    done
  else
    log "INFO" "Rolling back provider: $PROVIDER" true
    
    # Confirm before proceeding
    if [ "$FORCE" = "false" ]; then
      echo -e "${YELLOW}Warning: This will rollback OAuth provider $PROVIDER for domain $DOMAIN${NC}"
      if [ "$DISABLE_ONLY" = "true" ]; then
        echo -e "Action: Disable only"
      else
        echo -e "Action: Remove completely"
      fi
      
      read -p "Do you want to continue? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Rollback canceled by user" true
        exit 0
      fi
    fi
    
    if [ "$DISABLE_ONLY" = "true" ]; then
      disable_provider "$PROVIDER" "$admin_token"
    else
      remove_provider "$PROVIDER" "$admin_token"
    fi
  fi
}

# Update component registry after rollback
update_registry() {
  log "INFO" "Updating component registry after rollback" "$VERBOSE"
  
  if [ -f "${ROOT_DIR}/scripts/utils/update_keycloak_registry.sh" ]; then
    bash "${ROOT_DIR}/scripts/utils/update_keycloak_registry.sh"
    log "INFO" "Component registry updated successfully" "$VERBOSE"
  else
    log "WARNING" "Could not update component registry, script not found" "$VERBOSE"
  fi
}

# Main function
main() {
  # Process providers
  process_providers
  
  # Update component registry
  update_registry
  
  log "INFO" "Keycloak OAuth provider rollback completed for domain: $DOMAIN" true
  
  # Recommend follow-up actions
  echo -e "\n${CYAN}Recommended follow-up actions:${NC}"
  echo -e "1. Run 'make keycloak-oauth-health DOMAIN=$DOMAIN' to verify the rollback"
  echo -e "2. Run 'make dashboard-update-oauth' to update the dashboard with current status"
  echo -e "3. Run 'make keycloak-restart DOMAIN=$DOMAIN' if you encounter any issues"
}

# Run main function
main
