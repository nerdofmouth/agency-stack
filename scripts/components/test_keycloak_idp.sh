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
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_test.log"
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
  echo -e "${RED}Error: jq is not installed. Please install jq first:${NC}"
  echo -e "${CYAN}sudo apt-get install jq${NC}"
  exit 1
fi

# Check if Keycloak is running
echo -e "${BLUE}Checking if Keycloak is running...${NC}"

# Use separate client ID for each tenant if provided
REALM_NAME="agency"
if [ -n "$CLIENT_ID" ]; then
  REALM_NAME="${CLIENT_ID}"
fi

# Get admin credentials from installation file
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
echo -e "${BLUE}Getting identity providers from realm '${REALM_NAME}'...${NC}"
IDP_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances")

# Check if any IDPs exist
IDP_COUNT=$(echo "$IDP_RESPONSE" | jq -r 'if type=="array" then length else 0 end')
if [ "$IDP_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️ No identity providers configured in this realm${NC}"
  echo -e "${BLUE}To configure OAuth providers, run install_keycloak.sh with --enable-oauth-* flags${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found ${IDP_COUNT} identity providers${NC}"

# Test each IDP
echo -e "\n${CYAN}${BOLD}Testing Identity Providers:${NC}"
echo -e "--------------------------"

# Function to test an identity provider
test_idp() {
  local alias="$1"
  local provider_id="$2"
  local display_name="$3"
  local enabled="$4"
  
  echo -e "\n${BLUE}Testing ${display_name} (${provider_id}) IdP...${NC}"
  
  # Check if enabled
  if [ "$enabled" != "true" ]; then
    echo -e "${YELLOW}⚠️ Provider is disabled. Skipping tests.${NC}"
    return
  fi
  
  # Check if well-known configuration is accessible for this provider
  echo -e "  ${CYAN}Testing well-known configuration...${NC}"
  WELLKNOWN_URL="https://${DOMAIN}/auth/realms/${REALM_NAME}/broker/${alias}/endpoint/.well-known/openid-configuration"
  WELLKNOWN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$WELLKNOWN_URL")
  
  if [ "$WELLKNOWN_STATUS" = "200" ]; then
    echo -e "  ${GREEN}✅ Well-known endpoint accessible${NC}"
  else
    echo -e "  ${YELLOW}⚠️ Well-known endpoint not accessible (HTTP Status: ${WELLKNOWN_STATUS})${NC}"
    # This is expected for some providers like GitHub that don't expose a well-known endpoint
  fi
  
  # Check if the login URL works
  echo -e "  ${CYAN}Testing login redirect...${NC}"
  LOGIN_URL="https://${DOMAIN}/auth/realms/${REALM_NAME}/broker/${alias}/endpoint"
  LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$LOGIN_URL")
  
  # Most providers will redirect to their login page, resulting in various status codes
  # We just check that it's not a server error (5xx)
  if [[ "$LOGIN_STATUS" -lt 500 ]]; then
    echo -e "  ${GREEN}✅ Login redirect works (HTTP Status: ${LOGIN_STATUS})${NC}"
  else
    echo -e "  ${RED}❌ Login redirect failed (HTTP Status: ${LOGIN_STATUS})${NC}"
  fi
  
  # Test the discovery URL for OAuth providers
  # This varies by provider type
  case "$provider_id" in
    google)
      echo -e "  ${CYAN}Testing Google discovery URL...${NC}"
      DISCOVERY_URL="https://accounts.google.com/.well-known/openid-configuration"
      DISCOVERY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DISCOVERY_URL")
      if [ "$DISCOVERY_STATUS" = "200" ]; then
        echo -e "  ${GREEN}✅ Google discovery endpoint accessible${NC}"
      else
        echo -e "  ${RED}❌ Google discovery endpoint not accessible (HTTP Status: ${DISCOVERY_STATUS})${NC}"
      fi
      ;;
    github)
      echo -e "  ${CYAN}Testing GitHub API...${NC}"
      GITHUB_API="https://api.github.com"
      GITHUB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GITHUB_API")
      if [ "$GITHUB_STATUS" = "200" ]; then
        echo -e "  ${GREEN}✅ GitHub API accessible${NC}"
      else
        echo -e "  ${RED}❌ GitHub API not accessible (HTTP Status: ${GITHUB_STATUS})${NC}"
      fi
      ;;
    apple)
      echo -e "  ${CYAN}Testing Apple discovery URL...${NC}"
      APPLE_URL="https://appleid.apple.com/.well-known/openid-configuration"
      APPLE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APPLE_URL")
      if [ "$APPLE_STATUS" = "200" ]; then
        echo -e "  ${GREEN}✅ Apple discovery endpoint accessible${NC}"
      else
        echo -e "  ${RED}❌ Apple discovery endpoint not accessible (HTTP Status: ${APPLE_STATUS})${NC}"
      fi
      ;;
    *)
      echo -e "  ${YELLOW}⚠️ No specific tests available for provider type: ${provider_id}${NC}"
      ;;
  esac
  
  # Check if clientId and clientSecret are set (we don't show the actual values for security)
  echo -e "  ${CYAN}Checking configuration...${NC}"
  CONFIG=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/identity-provider/instances/${alias}")
  
  # Check for clientId (don't output the actual value)
  if [ "$(echo "$CONFIG" | jq -r '.config.clientId')" != "null" ] && [ "$(echo "$CONFIG" | jq -r '.config.clientId')" != "" ]; then
    echo -e "  ${GREEN}✅ Client ID is configured${NC}"
  else
    echo -e "  ${RED}❌ Client ID is not configured${NC}"
  fi
  
  # Check for clientSecret (don't output the actual value)
  if [ "$(echo "$CONFIG" | jq -r '.config.clientSecret')" != "null" ] && [ "$(echo "$CONFIG" | jq -r '.config.clientSecret')" != "" ]; then
    echo -e "  ${GREEN}✅ Client Secret is configured${NC}"
  else
    echo -e "  ${RED}❌ Client Secret is not configured${NC}"
  fi
  
  echo -e "  ${GREEN}✅ ${display_name} IdP test completed${NC}"
}

# Loop through each IdP and test it
echo "$IDP_RESPONSE" | jq -c 'if type=="array" then .[] else empty end' | while read -r idp; do
  alias=$(echo "$idp" | jq -r '.alias')
  provider_id=$(echo "$idp" | jq -r '.providerId')
  display_name=$(echo "$idp" | jq -r '.displayName')
  enabled=$(echo "$idp" | jq -r '.enabled')
  
  test_idp "$alias" "$provider_id" "$display_name" "$enabled"
done

# Check for Keycloak clients that can use these IDPs
echo -e "\n${BLUE}Checking for clients that can use these identity providers...${NC}"
CLIENTS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "https://${DOMAIN}/auth/admin/realms/${REALM_NAME}/clients")

CLIENT_COUNT=$(echo "$CLIENTS" | jq -r 'length')
echo -e "${GREEN}Found ${CLIENT_COUNT} clients in realm '${REALM_NAME}'${NC}"

# List clients with standard flow enabled (which can use IDPs)
echo -e "\n${CYAN}${BOLD}Compatible Clients:${NC}"
echo -e "------------------"
echo "$CLIENTS" | jq -r '.[] | select(.standardFlowEnabled == true) | .clientId' | while read -r client_id; do
  echo -e "${GREEN}✅ ${client_id}${NC}"
done

# Check for default login page
echo -e "\n${BLUE}Testing realm login page...${NC}"
LOGIN_URL="https://${DOMAIN}/auth/realms/${REALM_NAME}/protocol/openid-connect/auth?client_id=account-console&redirect_uri=https://${DOMAIN}/auth/realms/${REALM_NAME}/account/&response_type=code"
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$LOGIN_URL")

if [ "$LOGIN_STATUS" = "200" ]; then
  echo -e "${GREEN}✅ Login page is accessible${NC}"
  echo -e "${CYAN}You can manually test the login flow at:${NC}"
  echo -e "${CYAN}${LOGIN_URL}${NC}"
else
  echo -e "${RED}❌ Login page is not accessible (HTTP Status: ${LOGIN_STATUS})${NC}"
fi

# Final message
echo -e "\n${GREEN}${BOLD}Keycloak Identity Provider Tests Completed${NC}"
echo -e "Realm: ${CYAN}${REALM_NAME}${NC}"
echo -e "Admin Console: ${CYAN}https://${DOMAIN}/auth/admin/${NC}"

exit 0
