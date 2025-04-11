#!/bin/bash
# check_keycloak_idp_status.sh - Check status of Keycloak Identity Providers
# https://stack.nerdofmouth.com
#
# This script checks the status of OAuth Identity Providers in Keycloak
# and reports their configuration state.
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
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_status.log"
VERBOSE=false
DOMAIN=""
CLIENT_ID=""

# Log function
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] $message" >> "$LOG_FILE"
  if [ "$VERBOSE" = true ]; then
    echo -e "$message"
  fi
}

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak IdP Status${NC}"
  echo -e "=================================="
  echo -e "This script checks the status of Identity Providers in Keycloak"
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
echo -e "${MAGENTA}${BOLD}Keycloak Identity Provider Status for ${DOMAIN}${NC}"
echo -e "==========================================================="

# Check if Keycloak is running
echo -e "${BLUE}Checking if Keycloak is running...${NC}"

# Use separate client ID for each tenant if provided
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="${CLIENT_ID}"
fi

# Get admin credentials - this assumes admin password is saved in a consistent location after installation
KEYCLOAK_DIR="/opt/agency_stack/keycloak/${DOMAIN}"
ADMIN_PASSWORD_FILE="${KEYCLOAK_DIR}/admin_password.txt"

if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
  echo -e "${RED}Admin password file not found. Cannot authenticate to Keycloak.${NC}"
  echo -e "${YELLOW}You may need to run a Keycloak installation first.${NC}"
  exit 1
fi

ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")

# Check if Keycloak is accessible
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/auth/")

if [ "$HTTP_STATUS" != "200" ]; then
  echo -e "${RED}❌ Keycloak is not accessible at https://${DOMAIN}/auth/ (HTTP Status: ${HTTP_STATUS})${NC}"
  echo -e "${YELLOW}Please check if Keycloak is running and properly configured.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Keycloak is running at https://${DOMAIN}/auth/${NC}"

# Get admin token for Keycloak API
echo -e "${BLUE}Authenticating to Keycloak API...${NC}"
ADMIN_TOKEN=$(curl -s -X POST "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=${ADMIN_PASSWORD}" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo -e "${RED}❌ Failed to authenticate to Keycloak API${NC}"
  echo -e "${YELLOW}This could be due to incorrect admin credentials or API issues.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Successfully authenticated to Keycloak API${NC}"

# Check if realm exists
REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")

if [ "$REALM_STATUS" != "200" ]; then
  echo -e "${RED}❌ Realm '${REALM_NAME}' does not exist (HTTP Status: ${REALM_STATUS})${NC}"
  
  if [ -n "$CLIENT_ID" ]; then
    echo -e "${YELLOW}Falling back to default 'agency' realm...${NC}"
    REALM_NAME="agency"
    
    # Check if default realm exists
    REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}")
    
    if [ "$REALM_STATUS" != "200" ]; then
      echo -e "${RED}❌ Default realm 'agency' does not exist either (HTTP Status: ${REALM_STATUS})${NC}"
      echo -e "${YELLOW}Please check your Keycloak configuration.${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}Please check your Keycloak configuration.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}✅ Realm '${REALM_NAME}' exists${NC}"

# Get list of identity providers
echo -e "${BLUE}Checking identity providers in realm '${REALM_NAME}'...${NC}"
IDP_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances")

# Check for expected OAuth providers
echo -e "${CYAN}${BOLD}Configured Identity Providers:${NC}"
echo -e "---------------------------------"

# Create a prettier formatted list of IDPs with status details
echo "$IDP_RESPONSE" | jq -r 'if type=="array" then .[] else empty end | {alias, displayName, providerId, enabled}' | \
  jq -r '. | "\(.displayName) (\(.providerId)) - Status: \(if .enabled == true then "ENABLED" else "DISABLED" end)"' | \
  while read -r line; do
    if [[ $line == *"Status: ENABLED"* ]]; then
      echo -e "  ${GREEN}✅ $line${NC}"
    else
      echo -e "  ${YELLOW}⚠️ $line${NC}"
    fi
  done

# If no IDPs found
if [ "$(echo "$IDP_RESPONSE" | jq -r 'if type=="array" then length else 0 end')" = "0" ]; then
  echo -e "${YELLOW}⚠️ No identity providers configured in this realm${NC}"
  echo -e "${BLUE}To configure OAuth providers, run install_keycloak.sh with --enable-oauth-* flags:${NC}"
  echo -e "  ${CYAN}--enable-oauth-google${NC}  Enable Google login"
  echo -e "  ${CYAN}--enable-oauth-github${NC}  Enable GitHub login"
  echo -e "  ${CYAN}--enable-oauth-apple${NC}   Enable Apple login"
fi

# Check specifically for common providers
google_exists=$(echo "$IDP_RESPONSE" | jq -r '.[] | select(.providerId == "google") | .providerId')
github_exists=$(echo "$IDP_RESPONSE" | jq -r '.[] | select(.providerId == "github") | .providerId')
apple_exists=$(echo "$IDP_RESPONSE" | jq -r '.[] | select(.providerId == "apple") | .providerId')

echo -e "\n${CYAN}${BOLD}Summary:${NC}"
echo -e "--------"
[[ -n "$google_exists" ]] && echo -e "${GREEN}✅ Google OAuth configured${NC}" || echo -e "${YELLOW}❌ Google OAuth not configured${NC}"
[[ -n "$github_exists" ]] && echo -e "${GREEN}✅ GitHub OAuth configured${NC}" || echo -e "${YELLOW}❌ GitHub OAuth not configured${NC}"
[[ -n "$apple_exists" ]] && echo -e "${GREEN}✅ Apple OAuth configured${NC}" || echo -e "${YELLOW}❌ Apple OAuth not configured${NC}"

# Check component registry flag
echo -e "\n${BLUE}Checking component registry...${NC}"
OAUTH_IDP_CONFIGURED=$(jq -r '.components.security.keycloak.integration_status.oauth_idp_configured' "${ROOT_DIR}/config/registry/component_registry.json" 2>/dev/null || echo "false")

if [ "$OAUTH_IDP_CONFIGURED" == "true" ]; then
  echo -e "${GREEN}✅ Component registry has oauth_idp_configured flag set to true${NC}"
elif [[ -n "$google_exists" || -n "$github_exists" || -n "$apple_exists" ]]; then
  echo -e "${YELLOW}⚠️ OAuth providers detected but component registry flag not set${NC}"
  echo -e "${BLUE}Updating component registry...${NC}"
  
  if [ -f "${ROOT_DIR}/scripts/utils/update_component_registry.sh" ]; then
    "${ROOT_DIR}/scripts/utils/update_component_registry.sh" --update-component keycloak --update-flag oauth_idp_configured --update-value true >> "$LOG_FILE" 2>&1
    echo -e "${GREEN}✅ Component registry updated${NC}"
  else
    echo -e "${RED}❌ Component registry utility not found${NC}"
  fi
else
  echo -e "${YELLOW}⚠️ Component registry has oauth_idp_configured flag set to false${NC}"
fi

# Final message
echo -e "\n${GREEN}${BOLD}Keycloak Identity Provider Status Check Completed${NC}"
echo -e "Realm: ${CYAN}${REALM_NAME}${NC}"
echo -e "Admin Console: ${CYAN}https://${DOMAIN}/auth/admin/${NC}"

exit 0
