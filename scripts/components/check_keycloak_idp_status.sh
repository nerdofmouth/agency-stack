#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: check_keycloak_idp_status.sh
# Path: /scripts/components/check_keycloak_idp_status.sh
#

# Enforce containerization (prevent host contamination)

# check_keycloak_idp_status.sh
#
# This script checks the status of Keycloak OAuth Identity Providers
# and reports their configuration state.
#
# Part of AgencyStack | Security Components
#
# Usage:
#   ./check_keycloak_idp_status.sh --domain example.com [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_status.log"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_status.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"

DOMAIN=""
CLIENT_ID=""
VERBOSE=false
STATUS_ONLY=false
JSON_OUTPUT=false
SKIP_REGISTRY_UPDATE=false
PROVIDER_STATUS=()

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Log function with timestamp and level
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  case "$level" in
    INFO)
      echo -e "[$timestamp] [INFO] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO] $message${NC}"
      fi
      ;;
    WARN)
      echo -e "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
      echo -e "${YELLOW}[WARNING] $message${NC}"
      ;;
    ERROR)
      echo -e "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
      echo -e "${RED}[ERROR] $message${NC}"
      ;;
    SUCCESS)
      echo -e "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
      echo -e "${GREEN}[SUCCESS] $message${NC}"
      ;;
    DEBUG)
      echo -e "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ]; then
        echo -e "${GRAY}[DEBUG] $message${NC}"
      fi
      ;;
    *)
      echo -e "[$timestamp] $message" >> "$LOG_FILE"
      echo -e "$message"
      ;;
  esac
}

# Print help information
print_help() {
  cat << EOF
${CYAN}${BOLD}Keycloak OAuth Identity Provider Status Check${NC}

Usage: 
  ./check_keycloak_idp_status.sh --domain example.com [options]

Options:
  --domain DOMAIN      Domain for Keycloak (required)
  --client-id CLIENT   Client ID for multi-tenant setup (optional)
  --status-only        Only output overall status (no details)
  --json               Output results in JSON format
  --skip-registry      Skip updating the component registry
  --verbose            Show detailed output
  --help               Show this help message

Example:
  ./check_keycloak_idp_status.sh --domain keycloak.example.com --verbose

This script checks the status of OAuth Identity Providers configured in Keycloak.
EOF
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --status-only)
      STATUS_ONLY=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --skip-registry)
      SKIP_REGISTRY_UPDATE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      print_help
      exit 1
      ;;
  esac
done

# Check for required arguments
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}" >&2
  print_help
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  log "ERROR" "jq is not installed. Please install jq first:"
  echo -e "${CYAN}sudo apt-get install jq${NC}"
  exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  log "ERROR" "curl is not installed. Please install curl first:"
  echo -e "${CYAN}sudo apt-get install curl${NC}"
  exit 1
fi

log "INFO" "Checking Keycloak Identity Providers status for domain: ${DOMAIN}"

# Use separate client ID for each tenant if provided
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="${CLIENT_ID}"
  log "INFO" "Using client-specific realm: ${REALM_NAME}"
else
  log "INFO" "Using default realm: agency"
fi

# Get admin credentials from installation file
KEYCLOAK_DIR="/opt/agency_stack/keycloak/${DOMAIN}"
ADMIN_PASSWORD_FILE="${KEYCLOAK_DIR}/admin_password.txt"
if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
  log "ERROR" "Admin password file not found at ${ADMIN_PASSWORD_FILE}"
  log "INFO" "You may need to run a Keycloak installation first."
  
  if [ "$JSON_OUTPUT" = true ]; then
    echo '{"status":"error","message":"Admin password file not found","domain":"'${DOMAIN}'","idp_count":0}'
  elif [ "$STATUS_ONLY" = true ]; then
    echo "ERROR: Admin password file not found"
  fi
  exit 1
fi

ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")

# Check if Keycloak is accessible
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/auth/")

if [ "$HTTP_STATUS" != "200" ]; then
  log "ERROR" "Keycloak is not accessible at https://${DOMAIN}/auth/ (HTTP Status: ${HTTP_STATUS})"
  
  if [ "$JSON_OUTPUT" = true ]; then
    echo '{"status":"error","message":"Keycloak is not accessible","domain":"'${DOMAIN}'","http_status":'${HTTP_STATUS}',"idp_count":0}'
  elif [ "$STATUS_ONLY" = true ]; then
    echo "ERROR: Keycloak is not accessible (HTTP Status: ${HTTP_STATUS})"
  fi
  
  exit 1

log "SUCCESS" "Keycloak is running at https://${DOMAIN}/auth/"

# Get admin token for Keycloak API
log "INFO" "Authenticating to Keycloak API..."
ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  log "ERROR" "Failed to authenticate to Keycloak API"
  
  # Try one more time with increased timeout
  log "INFO" "Retrying with increased timeout..."
  sleep 3
  ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')
  
  if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    log "ERROR" "Failed to authenticate to Keycloak API after retry"
    
    if [ "$JSON_OUTPUT" = true ]; then
      echo '{"status":"error","message":"Failed to authenticate to Keycloak API","domain":"'${DOMAIN}'","idp_count":0}'
    elif [ "$STATUS_ONLY" = true ]; then
      echo "ERROR: Failed to authenticate to Keycloak API"
    fi
    
    exit 1
  fi

log "SUCCESS" "Successfully authenticated to Keycloak API"

# Check if realm exists
REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")

if [ "$REALM_STATUS" != "200" ]; then
  log "ERROR" "Realm '${REALM_NAME}' does not exist (HTTP Status: ${REALM_STATUS})"
  
  if [ -n "$CLIENT_ID" ]; then
    log "INFO" "Falling back to default 'agency' realm..."
    REALM_NAME="agency"
    
    # Check if default realm exists
    REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")
    
    if [ "$REALM_STATUS" != "200" ]; then
      log "ERROR" "Default realm 'agency' does not exist either (HTTP Status: ${REALM_STATUS})"
      
      if [ "$JSON_OUTPUT" = true ]; then
        echo '{"status":"error","message":"Realm not found","domain":"'${DOMAIN}'","realm":"'${REALM_NAME}'","idp_count":0}'
      elif [ "$STATUS_ONLY" = true ]; then
        echo "ERROR: Realm not found"
      fi
      
      exit 1
    fi
  else
    if [ "$JSON_OUTPUT" = true ]; then
      echo '{"status":"error","message":"Realm not found","domain":"'${DOMAIN}'","realm":"'${REALM_NAME}'","idp_count":0}'
    elif [ "$STATUS_ONLY" = true ]; then
      echo "ERROR: Realm not found"
    fi
    
    exit 1
  fi

log "SUCCESS" "Realm '${REALM_NAME}' exists"

# Get list of identity providers
log "INFO" "Getting identity providers from realm '${REALM_NAME}'..."
IDP_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances")

if [ "$?" -ne 0 ]; then
  log "ERROR" "Failed to retrieve identity providers"
  
  if [ "$JSON_OUTPUT" = true ]; then
    echo '{"status":"error","message":"Failed to retrieve identity providers","domain":"'${DOMAIN}'","realm":"'${REALM_NAME}'","idp_count":0}'
  elif [ "$STATUS_ONLY" = true ]; then
    echo "ERROR: Failed to retrieve identity providers"
  fi
  
  exit 1

# Check if any IDPs exist
IDP_COUNT=$(echo "$IDP_RESPONSE" | jq -r 'if type=="array" then length else 0 end')

if [ "$IDP_COUNT" -eq 0 ]; then
  log "WARN" "No identity providers configured in realm '${REALM_NAME}'"
  
  if [ "$JSON_OUTPUT" = true ]; then
    echo '{"status":"warning","message":"No identity providers configured","domain":"'${DOMAIN}'","realm":"'${REALM_NAME}'","idp_count":0}'
  elif [ "$STATUS_ONLY" = true ]; then
    echo "WARNING: No identity providers configured"
  fi
  
  if [ "$SKIP_REGISTRY_UPDATE" = false ]; then
    log "INFO" "Updating component registry - setting oauth_idp_configured to false"
    ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value false
  fi
  
  exit 0
fi

log "SUCCESS" "Found ${IDP_COUNT} identity providers"

# Initialize JSON output
if [ "$JSON_OUTPUT" = true ]; then
  JSON_PROVIDERS="["

# Check each identity provider
echo -e "\n${CYAN}${BOLD}Configured Identity Providers:${NC}"
echo -e "--------------------------"

CONFIGURED_PROVIDERS=()
ENABLED_PROVIDERS=0
DISABLED_PROVIDERS=0
GOOGLE_CONFIGURED=false
GITHUB_CONFIGURED=false
APPLE_CONFIGURED=false

# Process each identity provider
echo "$IDP_RESPONSE" | jq -c '.[]' | while read -r idp; do
  alias=$(echo "$idp" | jq -r '.alias')
  provider_id=$(echo "$idp" | jq -r '.providerId')
  display_name=$(echo "$idp" | jq -r '.displayName')
  enabled=$(echo "$idp" | jq -r '.enabled')
  
  # Track which providers are configured
  case "$provider_id" in
    google)
      GOOGLE_CONFIGURED=true
      ;;
    github)
      GITHUB_CONFIGURED=true
      ;;
    apple)
      APPLE_CONFIGURED=true
      ;;
  esac
  
  CONFIGURED_PROVIDERS+=("$provider_id")
  
  # Get provider configuration details
  provider_config=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}")
  
  # Get client ID and validate credential storage
  client_id=$(echo "$provider_config" | jq -r '.config.clientId // ""')
  client_secret_exists=$(echo "$provider_config" | jq -r 'if .config.clientSecret and .config.clientSecret != "" and .config.clientSecret != "**********" then "true" else "false" end')
  secret_file_exists="false"
  secret_file_secure="false"
  
  if [ -f "${SECRETS_DIR}/${DOMAIN}/${alias}_oauth.env" ]; then
    secret_file_exists="true"
    file_perms=$(stat -c "%a" "${SECRETS_DIR}/${DOMAIN}/${alias}_oauth.env")
    if [ "$file_perms" = "600" ]; then
      secret_file_secure="true"
    fi
  fi
  
  # Get mapper count
  mapper_count=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}/mappers" | jq -r 'length')
  
  # Build provider status object for display
  status_icon=""
  status_color=""
  provider_status="unknown"
  
  if [ "$enabled" = "true" ]; then
    # Provider is enabled, now check if it's properly configured
    if [ -n "$client_id" ] && [ "$client_id" != "null" ] && [ "$client_secret_exists" = "true" ]; then
      status_icon="✅"
      status_color="${GREEN}"
      provider_status="active"
      ENABLED_PROVIDERS=$((ENABLED_PROVIDERS + 1))
    else
      status_icon="⚠️"
      status_color="${YELLOW}"
      provider_status="misconfigured"
    fi
  else
    status_icon="❌"
    status_color="${RED}"
    provider_status="disabled"
    DISABLED_PROVIDERS=$((DISABLED_PROVIDERS + 1))
  fi
  
  # Logging and output
  if [ "$STATUS_ONLY" = false ]; then
    echo -e "${status_color}${status_icon} ${display_name} (${provider_id})${NC}"
    echo -e "   Alias: ${alias}"
    echo -e "   Enabled: ${enabled}"
    echo -e "   Client ID Configured: $( [ -n "$client_id" ] && [ "$client_id" != "null" ] && echo "Yes" || echo "No" )"
    echo -e "   Client Secret: $( [ "$client_secret_exists" = "true" ] && echo "Configured" || echo "Not configured" )"
    echo -e "   Secure Storage: $( [ "$secret_file_exists" = "true" ] && [ "$secret_file_secure" = "true" ] && echo "Yes (600)" || echo "No" )"
    echo -e "   Mappers: ${mapper_count}"
  fi
  
  # Add to JSON output if requested
  if [ "$JSON_OUTPUT" = true ]; then
    provider_json='{
      "alias": "'$alias'",
      "provider_id": "'$provider_id'",
      "display_name": "'$display_name'",
      "enabled": '$enabled',
      "client_id_configured": '$( [ -n "$client_id" ] && [ "$client_id" != "null" ] && echo "true" || echo "false" )',
      "client_secret_configured": '$client_secret_exists',
      "secure_storage": '$( [ "$secret_file_exists" = "true" ] && [ "$secret_file_secure" = "true" ] && echo "true" || echo "false" )',
      "mapper_count": '$mapper_count',
      "status": "'$provider_status'"
    }'
    
    # Add to the array
    JSON_PROVIDERS="${JSON_PROVIDERS}${provider_json},"
  fi
  
  # Store in PROVIDER_STATUS array
  PROVIDER_STATUS+=("$provider_id:$provider_status")
done

# Remove trailing comma from JSON array if present
if [ "$JSON_OUTPUT" = true ]; then
  JSON_PROVIDERS="${JSON_PROVIDERS%,}]"

# Check authentication flows
AUTH_FLOWS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows")

BROWSER_FLOW=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser/executions")

IDENTITY_PROVIDER_AUTH=$(echo "$BROWSER_FLOW" | jq -r '[.[] | select(.displayName=="Identity Provider Redirector" or .providerId=="identity-provider-redirector")] | length')

AUTH_FLOW_CONFIGURED=false
if [ "$IDENTITY_PROVIDER_AUTH" -gt 0 ]; then
  AUTH_FLOW_CONFIGURED=true
fi

# Summary information
echo -e "\n${CYAN}${BOLD}Identity Provider Summary:${NC}"
echo -e "-------------------------"
echo -e "Domain: ${DOMAIN}"
echo -e "Realm: ${REALM_NAME}"
echo -e "Total IDPs: ${IDP_COUNT}"
echo -e "Enabled IDPs: ${ENABLED_PROVIDERS}"
echo -e "Disabled IDPs: ${DISABLED_PROVIDERS}"
echo -e "Auth Flow Configured: $( [ "$AUTH_FLOW_CONFIGURED" = true ] && echo "Yes" || echo "No" )"
echo -e "Provider Types: ${CONFIGURED_PROVIDERS[*]}"

# Check OAuth providers
echo -e "\n${CYAN}${BOLD}OAuth Providers:${NC}"
echo -e "---------------"
echo -e "Google: $( [ "$GOOGLE_CONFIGURED" = true ] && echo "${GREEN}Configured${NC}" || echo "${GRAY}Not configured${NC}" )"
echo -e "GitHub: $( [ "$GITHUB_CONFIGURED" = true ] && echo "${GREEN}Configured${NC}" || echo "${GRAY}Not configured${NC}" )"
echo -e "Apple: $( [ "$APPLE_CONFIGURED" = true ] && echo "${GREEN}Configured${NC}" || echo "${GRAY}Not configured${NC}" )"

# Check for standard security configs
echo -e "\n${CYAN}${BOLD}Security Checks:${NC}"
echo -e "---------------"

# Get realm settings for security checks
REALM_SETTINGS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")

# SSL required check
SSL_REQUIRED=$(echo "$REALM_SETTINGS" | jq -r '.sslRequired')
if [[ "$SSL_REQUIRED" == "external" || "$SSL_REQUIRED" == "all" ]]; then
  echo -e "${GREEN}✅ SSL Required: ${SSL_REQUIRED}${NC}"
else
  echo -e "${RED}❌ SSL Required: ${SSL_REQUIRED} (should be 'external' or 'all')${NC}"
fi

# Brute force protection
BRUTE_FORCE=$(echo "$REALM_SETTINGS" | jq -r '.bruteForceProtected')
if [[ "$BRUTE_FORCE" == "true" ]]; then
  echo -e "${GREEN}✅ Brute Force Protection: Enabled${NC}"
else
  echo -e "${RED}❌ Brute Force Protection: Disabled${NC}"
fi

# Determine overall status
OVERALL_STATUS="success"
if [ $IDP_COUNT -eq 0 ]; then
  OVERALL_STATUS="warning"
  log "WARN" "No identity providers are configured"
elif [ $ENABLED_PROVIDERS -eq 0 ]; then
  OVERALL_STATUS="warning"
  log "WARN" "No identity providers are enabled"
fi

# Update component registry
if [ "$SKIP_REGISTRY_UPDATE" = false ]; then
  if [ $IDP_COUNT -gt 0 ] && [ $ENABLED_PROVIDERS -gt 0 ]; then
    log "INFO" "Updating component registry - setting oauth_idp_configured to true"
    ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true
  else
    log "INFO" "Updating component registry - setting oauth_idp_configured to false"
    ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value false
  fi
fi

# Output results in requested format
if [ "$JSON_OUTPUT" = true ]; then
  # Construct JSON object
  echo '{
    "status": "'$OVERALL_STATUS'",
    "domain": "'$DOMAIN'",
    "realm": "'$REALM_NAME'",
    "idp_count": '$IDP_COUNT',
    "enabled_providers": '$ENABLED_PROVIDERS',
    "disabled_providers": '$DISABLED_PROVIDERS',
    "auth_flow_configured": '$AUTH_FLOW_CONFIGURED',
    "google_configured": '$GOOGLE_CONFIGURED',
    "github_configured": '$GITHUB_CONFIGURED',
    "apple_configured": '$APPLE_CONFIGURED',
    "security": {
      "ssl_required": "'$SSL_REQUIRED'",
      "brute_force_protected": '$BRUTE_FORCE'
    },
    "providers": '$JSON_PROVIDERS'
  }'
elif [ "$STATUS_ONLY" = true ]; then
  echo "$OVERALL_STATUS"
fi

log "INFO" "Keycloak Identity Provider status check completed"
exit 0
