#!/bin/bash
# test_keycloak_idp.sh - Test Keycloak Identity Providers
# https://stack.nerdofmouth.com
#
# This script tests the OAuth Identity Providers configured in Keycloak
# by validating their configuration and simulating authentication flows.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
KEYCLOAK_DIR="${CONFIG_DIR}/keycloak"
SECRETS_DIR="${CONFIG_DIR}/secrets/keycloak"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_test.log"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_test.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

VERBOSE=false
DOMAIN=""
CLIENT_ID=""
EXIT_CODE=0
SECURITY_ISSUES=0
WARNINGS=0

# Log function with levels
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  case "$level" in
    INFO)
      echo -e "[$timestamp] [INFO] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ] || [ -z "$3" ]; then
        echo -e "${BLUE}[INFO] $message${NC}"
      fi
      ;;
    WARN)
      echo -e "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
      echo -e "${YELLOW}[WARNING] $message${NC}"
      WARNINGS=$((WARNINGS + 1))
      ;;
    ERROR)
      echo -e "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
      echo -e "${RED}[ERROR] $message${NC}"
      EXIT_CODE=1
      ;;
    SECURITY)
      echo -e "[$timestamp] [SECURITY ISSUE] $message" >> "$LOG_FILE"
      echo -e "${RED}[SECURITY ISSUE] $message${NC}"
      SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
      ;;
    SUCCESS)
      echo -e "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
      echo -e "${GREEN}[SUCCESS] $message${NC}"
      ;;
    *)
      echo -e "[$timestamp] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ]; then
        echo -e "$message"
      fi
      ;;
  esac
}

# Security check function
check_security() {
  local check_name="$1"
  local check_result="$2"
  local success_message="$3"
  local failure_message="$4"
  
  if [ "$check_result" = true ]; then
    log "SUCCESS" "✅ $check_name: $success_message"
  else
    log "SECURITY" "❌ $check_name: $failure_message"
  fi
}

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak IdP Test${NC}"
  echo -e "================================="
  echo -e "This script tests the OAuth Identity Providers in Keycloak"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>       Keycloak domain (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id> Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--verbose${NC}               Show detailed output"
  echo -e "  ${BOLD}--help${NC}                  Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain auth.example.com --client-id acme"
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

# Welcome message
echo -e "${MAGENTA}${BOLD}Keycloak Identity Provider Test for ${DOMAIN}${NC}"
echo -e "======================================================="

# Test if jq is installed
if ! command -v jq &> /dev/null; then
  log "ERROR" "jq is not installed. Please install jq first:"
  echo -e "${CYAN}sudo apt-get install jq${NC}"
  exit 1
fi

# Test if curl is installed
if ! command -v curl &> /dev/null; then
  log "ERROR" "curl is not installed. Please install curl first:"
  echo -e "${CYAN}sudo apt-get install curl${NC}"
  exit 1
fi

# Check for TLS/SSL support in curl
if ! curl --version | grep -q "https"; then
  log "ERROR" "curl does not support HTTPS. Please install curl with SSL support"
  exit 1
fi

# Check if Keycloak is running
log "INFO" "Checking if Keycloak is running..."

# Use separate client ID for each tenant if provided
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="${CLIENT_ID}"
fi

# Get admin credentials from installation file
KEYCLOAK_DIR="/opt/agency_stack/keycloak/${DOMAIN}"
ADMIN_PASSWORD_FILE="${KEYCLOAK_DIR}/admin_password.txt"
KEYCLOAK_SECRETS="${SECRETS_DIR}/${DOMAIN}"

if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
  log "ERROR" "Admin password file not found. Cannot authenticate to Keycloak."
  log "INFO" "You may need to run a Keycloak installation first."
  exit 1
fi

ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")

# Check if Keycloak is accessible
log "INFO" "Testing connectivity to Keycloak..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/auth/")

if [ "$HTTP_STATUS" != "200" ]; then
  log "ERROR" "Keycloak is not accessible at https://${DOMAIN}/auth/ (HTTP Status: ${HTTP_STATUS})"
  log "INFO" "Please check if Keycloak is running and properly configured."
  exit 1
fi

log "SUCCESS" "Keycloak is running at https://${DOMAIN}/auth/"

# Check for HTTP to HTTPS redirect
log "INFO" "Testing HTTP to HTTPS redirect..."
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{redirect_url}" "http://${DOMAIN}/auth/")
if [[ "$HTTP_REDIRECT" == https://* ]]; then
  log "SUCCESS" "HTTP to HTTPS redirect is working properly"
else
  log "WARN" "HTTP to HTTPS redirect not detected. This could be a security issue."
fi

# Get admin token for Keycloak API
log "INFO" "Authenticating to Keycloak API..."
ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  log "ERROR" "Failed to authenticate to Keycloak API"
  log "WARN" "This could be due to incorrect admin credentials or API issues."
  
  # Try one more time with increased timeout
  log "INFO" "Retrying with increased timeout..."
  sleep 5
  ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')
  
  if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    log "ERROR" "Failed to authenticate to Keycloak API after retry"
    exit 1
  fi
fi

log "SUCCESS" "Successfully authenticated to Keycloak API"

# Validate token is a proper JWT
if [[ ! "$ADMIN_TOKEN" =~ ^[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+$ ]]; then
  log "ERROR" "Admin token does not appear to be a valid JWT"
  exit 1
fi

# Check if realm exists
log "INFO" "Checking if realm '${REALM_NAME}' exists..."
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
      log "INFO" "Please check your Keycloak configuration."
      exit 1
    fi
  else
    log "INFO" "Please check your Keycloak configuration."
    exit 1
  fi
fi

log "SUCCESS" "Realm '${REALM_NAME}' exists"

# Get realm settings for security checks
log "INFO" "Retrieving realm settings for security validation..."
REALM_SETTINGS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")

# Security checks on realm settings
echo -e "\n${CYAN}${BOLD}Performing Security Checks on Realm:${NC}"
echo -e "-----------------------------------------"

# Check SSL Required
SSL_REQUIRED=$(echo "$REALM_SETTINGS" | jq -r '.sslRequired')
check_security "SSL Required" \
  [[ "$SSL_REQUIRED" == "external" || "$SSL_REQUIRED" == "all" ]] \
  "SSL required setting is properly configured as '$SSL_REQUIRED'" \
  "SSL required setting is set to '$SSL_REQUIRED', should be 'external' or 'all'"

# Check Brute Force Protection
BRUTE_FORCE=$(echo "$REALM_SETTINGS" | jq -r '.bruteForceProtected')
check_security "Brute Force Protection" \
  [[ "$BRUTE_FORCE" == "true" ]] \
  "Brute force protection is enabled" \
  "Brute force protection is disabled"

# Check Access Token Lifespan
ACCESS_TOKEN_LIFESPAN=$(echo "$REALM_SETTINGS" | jq -r '.accessTokenLifespan')
check_security "Access Token Lifespan" \
  [[ "$ACCESS_TOKEN_LIFESPAN" -le 300 ]] \
  "Access token lifespan is properly set to $(($ACCESS_TOKEN_LIFESPAN / 60)) minutes" \
  "Access token lifespan is set to $(($ACCESS_TOKEN_LIFESPAN / 60)) minutes, which is more than recommended 5 minutes"

# Get list of identity providers
log "INFO" "Getting identity providers from realm '${REALM_NAME}'..."
IDP_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances")

# Check if any IDPs exist
IDP_COUNT=$(echo "$IDP_RESPONSE" | jq -r 'if type=="array" then length else 0 end')
if [ "$IDP_COUNT" -eq 0 ]; then
  log "WARN" "No identity providers configured in this realm"
  log "INFO" "To configure OAuth providers, run install_keycloak.sh with --enable-oauth-* flags"
  exit 1
fi

log "SUCCESS" "Found ${IDP_COUNT} identity providers"

# Security checks for each IdP configuration
echo -e "\n${CYAN}${BOLD}Validating Identity Provider Configurations:${NC}"
echo -e "--------------------------------------------"

# Function to test an identity provider with security checks
test_idp() {
  local alias="$1"
  local provider_id="$2"
  local display_name="$3"
  local enabled="$4"
  local idp_config="$5"
  
  echo -e "\n${BLUE}Testing ${display_name} (${provider_id}) IdP...${NC}"
  
  # Check if enabled
  if [ "$enabled" != "true" ]; then
    log "WARN" "Provider is disabled. Limited testing will be performed."
  fi
  
  # Load expected values for this provider type
  local expected_scope=""
  local discovery_url=""
  case "$provider_id" in
    google)
      expected_scope="openid email profile"
      discovery_url="https://accounts.google.com/.well-known/openid-configuration"
      ;;
    github)
      expected_scope="user:email"
      discovery_url=""
      ;;
    apple)
      expected_scope="email name"
      discovery_url="https://appleid.apple.com/.well-known/openid-configuration"
      ;;
  esac
  
  # Check for proper settings
  # Check validateSignature
  local validate_signature=$(echo "$idp_config" | jq -r '.config.validateSignature')
  check_security "${display_name} Signature Validation" \
    [[ "$validate_signature" == "true" || -z "$validate_signature" ]] \
    "Signature validation is properly enabled" \
    "Signature validation is disabled, which is a security risk"
  
  # Check for correct scope
  if [ -n "$expected_scope" ]; then
    local scope=$(echo "$idp_config" | jq -r '.config.defaultScope // ""')
    if [[ "$scope" != *"$expected_scope"* ]]; then
      log "WARN" "The scope for ${display_name} may be misconfigured. Expected: ${expected_scope}, Found: ${scope}"
    else
      log "SUCCESS" "Scope properly configured for ${display_name}"
    fi
  fi
  
  # Check for storeToken (should generally be false)
  local store_token=$(echo "$idp_config" | jq -r '.storeToken')
  check_security "${display_name} Token Storage" \
    [[ "$store_token" == "false" ]] \
    "Token storage is properly disabled" \
    "Token storage is enabled, which may pose a security risk"
  
  # Check if the login URL works
  echo -e "  ${CYAN}Testing login redirect...${NC}"
  LOGIN_URL="https://${DOMAIN}/auth/realms/${REALM_NAME}/broker/${alias}/endpoint"
  LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$LOGIN_URL")
  
  # Most providers will redirect to their login page, resulting in various status codes
  # We just check that it's not a server error (5xx)
  if [[ "$LOGIN_STATUS" -lt 500 ]]; then
    log "SUCCESS" "Login redirect works (HTTP Status: ${LOGIN_STATUS})"
  else
    log "ERROR" "Login redirect failed (HTTP Status: ${LOGIN_STATUS})"
  fi
  
  # Test the discovery URL for OAuth providers if available
  if [ -n "$discovery_url" ]; then
    echo -e "  ${CYAN}Testing discovery URL: ${discovery_url}...${NC}"
    DISCOVERY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$discovery_url")
    if [ "$DISCOVERY_STATUS" = "200" ]; then
      log "SUCCESS" "Discovery endpoint accessible"
      
      # Fetch discovery document and check key claims
      DISCOVERY_DOC=$(curl -s "$discovery_url")
      if echo "$DISCOVERY_DOC" | jq -e '.jwks_uri, .authorization_endpoint, .token_endpoint' > /dev/null; then
        log "SUCCESS" "Discovery document contains expected endpoints"
      else
        log "WARN" "Discovery document may be missing required endpoints"
      fi
    else
      log "ERROR" "Discovery endpoint not accessible (HTTP Status: ${DISCOVERY_STATUS})"
    fi
  fi
  
  # Check client credentials
  echo -e "  ${CYAN}Checking client credentials configuration...${NC}"
  local client_id=$(echo "$idp_config" | jq -r '.config.clientId')
  local client_secret=$(echo "$idp_config" | jq -r '.config.clientSecret')
  
  if [ -z "$client_id" ] || [ "$client_id" = "null" ]; then
    log "ERROR" "Client ID is not configured for ${display_name}"
  else
    # Check if client ID looks valid (minimum length check)
    if [ ${#client_id} -lt 10 ]; then
      log "WARN" "Client ID for ${display_name} seems suspiciously short (length: ${#client_id})"
    else
      log "SUCCESS" "Client ID is configured for ${display_name}"
    fi
  fi
  
  if [ -z "$client_secret" ] || [ "$client_secret" = "null" ]; then
    log "ERROR" "Client Secret is not configured for ${display_name}"
  else
    # Check if client secret looks valid (minimum length for security)
    if [ ${#client_secret} -lt 16 ]; then
      log "SECURITY" "Client Secret for ${display_name} may be too short (less than 16 chars)"
    else
      log "SUCCESS" "Client Secret is properly configured for ${display_name}"
    fi
  fi
  
  # Check if credentials are securely stored
  if [ -f "${SECRETS_DIR}/${DOMAIN}/${alias}_oauth.env" ]; then
    # Check file permissions
    local file_perms=$(stat -c "%a" "${SECRETS_DIR}/${DOMAIN}/${alias}_oauth.env")
    if [ "$file_perms" = "600" ]; then
      log "SUCCESS" "Credentials are stored securely with correct permissions (600)"
    else
      log "SECURITY" "Credential file has incorrect permissions: ${file_perms}, should be 600"
    fi
  else
    log "WARN" "No secure credential storage found for ${display_name}"
  fi
  
  # Check for mappers (email mapper is crucial)
  echo -e "  ${CYAN}Checking identity provider mappers...${NC}"
  local mappers=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}/mappers")
  
  local email_mapper=$(echo "$mappers" | jq -r '[.[] | select(.config.user.attribute=="email" or .config.userAttribute=="email")] | length')
  if [ "$email_mapper" -gt 0 ]; then
    log "SUCCESS" "Email mapper properly configured"
  else
    log "WARN" "No email mapper found. This may cause issues with user identification."
  fi
  
  log "SUCCESS" "${display_name} IdP test completed"
}

# Loop through each IdP and test it
echo "$IDP_RESPONSE" | jq -c 'if type=="array" then .[] else empty end' | while read -r idp; do
  alias=$(echo "$idp" | jq -r '.alias')
  provider_id=$(echo "$idp" | jq -r '.providerId')
  display_name=$(echo "$idp" | jq -r '.displayName')
  enabled=$(echo "$idp" | jq -r '.enabled')
  
  test_idp "$alias" "$provider_id" "$display_name" "$enabled" "$idp"
done

# Check for authentication flows using identity providers
echo -e "\n${BLUE}Checking authentication flows...${NC}"
AUTH_FLOWS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows")

BROWSER_FLOW=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/authentication/flows/browser/executions")

IDENTITY_PROVIDER_AUTH=$(echo "$BROWSER_FLOW" | jq -r '[.[] | select(.displayName=="Identity Provider Redirector" or .providerId=="identity-provider-redirector")] | length')

if [ "$IDENTITY_PROVIDER_AUTH" -gt 0 ]; then
  log "SUCCESS" "Identity Provider Redirector is configured in the authentication flow"
else
  log "WARN" "Identity Provider Redirector is not configured in the authentication flow. Social login buttons may not appear."
fi

# Check for client configurations
echo -e "\n${BLUE}Checking for clients that can use these identity providers...${NC}"
CLIENTS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/clients")

CLIENT_COUNT=$(echo "$CLIENTS" | jq -r 'length')
echo -e "${GREEN}Found ${CLIENT_COUNT} clients in realm '${REALM_NAME}'${NC}"

# Check compatibility of clients with OIDC
COMPATIBLE_CLIENTS=0
NON_COMPATIBLE_CLIENTS=0

# List clients with standard flow enabled (which can use IDPs)
echo -e "\n${CYAN}${BOLD}Compatible Clients:${NC}"
echo -e "------------------"
echo "$CLIENTS" | jq -c '.[] | select(.standardFlowEnabled == true)' | while read -r client; do
  client_id=$(echo "$client" | jq -r '.clientId')
  client_protocol=$(echo "$client" | jq -r '.protocol // "unknown"')
  
  if [ "$client_protocol" = "openid-connect" ]; then
    echo -e "${GREEN}✅ ${client_id} - Protocol: ${client_protocol}${NC}"
    COMPATIBLE_CLIENTS=$((COMPATIBLE_CLIENTS + 1))
  else
    echo -e "${YELLOW}⚠️ ${client_id} - Protocol: ${client_protocol} (not OIDC)${NC}"
    NON_COMPATIBLE_CLIENTS=$((NON_COMPATIBLE_CLIENTS + 1))
  fi
done

if [ $COMPATIBLE_CLIENTS -eq 0 ]; then
  log "WARN" "No OIDC-compatible clients found. This may indicate an issue with IDPs."
fi

# Check for direct client OAuth settings that bypass Keycloak
echo -e "\n${CYAN}${BOLD}Direct OAuth Checks:${NC}"
echo -e "------------------"
echo "$CLIENTS" | jq -c '.[]' | while read -r client; do
  client_id=$(echo "$client" | jq -r '.clientId')
  redirect_uris=$(echo "$client" | jq -r '.redirectUris[]? // ""')
  
  # Look for signs of direct OAuth integration (bypassing Keycloak)
  if [[ "$redirect_uris" == *"google"* || "$redirect_uris" == *"github"* || "$redirect_uris" == *"apple"* || 
        "$redirect_uris" == *"callback"* || "$redirect_uris" == *"oauth"* ]]; then
    log "SECURITY" "Client '${client_id}' appears to have direct OAuth integration URIs: ${redirect_uris}"
    log "INFO" "Direct OAuth integration bypasses Keycloak and should be removed."
  fi
done

# Check for realm login page
echo -e "\n${BLUE}Testing realm login page...${NC}"
LOGIN_URL="https://${DOMAIN}/auth/realms/${REALM_NAME}/protocol/openid-connect/auth?client_id=account-console&redirect_uri=https://${DOMAIN}/auth/realms/${REALM_NAME}/account/&response_type=code"
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$LOGIN_URL")

if [ "$LOGIN_STATUS" = "200" ]; then
  log "SUCCESS" "Login page is accessible"
  
  # Check if the login page HTML contains references to identity providers
  LOGIN_HTML=$(curl -s "$LOGIN_URL")
  if echo "$LOGIN_HTML" | grep -q "identity-provider"; then
    log "SUCCESS" "Login page contains identity provider buttons"
  else
    log "WARN" "Login page does not appear to show identity provider buttons"
  fi
  
  echo -e "${CYAN}You can manually test the login flow at:${NC}"
  echo -e "${CYAN}${LOGIN_URL}${NC}"
else
  log "ERROR" "Login page is not accessible (HTTP Status: ${LOGIN_STATUS})"
fi

# Final report
echo -e "\n${GREEN}${BOLD}Keycloak Identity Provider Tests Completed${NC}"
echo -e "Realm: ${CYAN}${REALM_NAME}${NC}"
echo -e "Admin Console: ${CYAN}https://${DOMAIN}/auth/admin/${NC}"

echo -e "\n${CYAN}${BOLD}Summary:${NC}"
echo -e "--------"
echo -e "Security Issues: ${RED}${SECURITY_ISSUES}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"

# Component registry check
echo -e "\n${BLUE}Checking component registry...${NC}"
if [ -f "${ROOT_DIR}/config/registry/component_registry.json" ]; then
  OAUTH_IDP_CONFIGURED=$(jq -r '.components.security.keycloak.integration_status.oauth_idp_configured // "false"' "${ROOT_DIR}/config/registry/component_registry.json")
  
  if [ "$OAUTH_IDP_CONFIGURED" = "true" ]; then
    log "SUCCESS" "Component registry has oauth_idp_configured flag set correctly"
  else
    log "WARN" "Component registry does not have oauth_idp_configured flag set to true"
    
    # Update the registry if IDPs were found and testing was successful
    if [ $IDP_COUNT -gt 0 ] && [ $EXIT_CODE -eq 0 ]; then
      if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
        echo -e "${BLUE}Updating component registry...${NC}"
        ${ROOT_DIR}/scripts/utils/update_component_registry.sh --update-component keycloak --update-flag oauth_idp_configured --update-value true
        echo -e "${GREEN}✅ Component registry updated${NC}"
      fi
    fi
  fi
else
  log "WARN" "Component registry file not found"
fi

# Exit with appropriate code
if [ $SECURITY_ISSUES -gt 0 ]; then
  echo -e "\n${RED}${BOLD}⚠️ Security issues detected! Please address them before deploying to production.${NC}"
  exit 2
elif [ $EXIT_CODE -ne 0 ]; then
  echo -e "\n${RED}${BOLD}❌ Tests completed with errors.${NC}"
  exit $EXIT_CODE
else
  echo -e "\n${GREEN}${BOLD}✅ All tests completed successfully!${NC}"
  exit 0
fi
