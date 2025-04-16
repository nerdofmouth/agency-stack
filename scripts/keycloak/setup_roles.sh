#!/bin/bash
# setup_roles.sh - Set up default roles for Keycloak realm
# https://stack.nerdofmouth.com
#
# This script creates default roles for a Keycloak realm:
# - realm_admin: Full administrative access to the realm
# - editor: Can edit content but not manage users/roles
# - viewer: Read-only access to content
#
# Usage: ./setup_roles.sh <client_id>
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
CONFIG_DIR="/opt/agency_stack"
CLIENTS_DIR="${CONFIG_DIR}/clients"
SECRETS_DIR="${CONFIG_DIR}/secrets"
CONFIG_ENV="${CONFIG_DIR}/config.env"
LOG_DIR="/var/log/agency_stack"
CLIENT_LOGS_DIR="${LOG_DIR}/clients"

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak Role Setup${NC}"
  echo -e "=================================="
  echo -e "This script creates default roles for a Keycloak realm:"
  echo -e "  - realm_admin: Full administrative access to the realm"
  echo -e "  - editor: Can edit content but not manage users/roles" 
  echo -e "  - viewer: Read-only access to content"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 <client_id>"
  echo -e ""
  echo -e "${CYAN}Arguments:${NC}"
  echo -e "  ${BOLD}client_id${NC}        Unique identifier for the client"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 acme"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - The script must be run as root or with sudo"
  echo -e "  - Client must already exist (created with create-client.sh)"
  echo -e "  - Keycloak must be running and accessible" 
  exit 0
}

# Process command-line arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
  show_help
fi

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak Role Setup${NC}"
echo -e "=================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
  echo -e "${YELLOW}Usage: $0 <client_id>${NC}"
  echo -e "Example: $0 acme"
  echo -e "Use $0 --help for more information"
  exit 1
fi

CLIENT_ID="$1"

# Check if client exists
if [ ! -d "${CLIENTS_DIR}/${CLIENT_ID}" ]; then
  echo -e "${RED}Error: Client ${CLIENT_ID} not found${NC}"
  echo -e "Create the client first with: make create-client CLIENT_ID=${CLIENT_ID} CLIENT_NAME=\"Client Name\" CLIENT_DOMAIN=example.com"
  exit 1
fi

# Source client configuration
CLIENT_ENV="${CLIENTS_DIR}/${CLIENT_ID}/client.env"
if [ -f "$CLIENT_ENV" ]; then
  source "$CLIENT_ENV"
else
  echo -e "${RED}Error: Client configuration not found at ${CLIENT_ENV}${NC}"
  echo -e "Please ensure the client configuration file exists and is properly formatted"
  exit 1
fi

# Source client secrets
CLIENT_SECRETS="${SECRETS_DIR}/${CLIENT_ID}/secrets.env"
if [ -f "$CLIENT_SECRETS" ]; then
  source "$CLIENT_SECRETS"
else
  echo -e "${RED}Error: Client secrets not found at ${CLIENT_SECRETS}${NC}"
  echo -e "Please ensure the client secrets file exists and is properly formatted"
  exit 1
fi

# Source main config for Keycloak URL
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
fi

# Set default Keycloak URL if not found in config
KEYCLOAK_URL=${KEYCLOAK_URL:-"http://localhost:8080"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}

echo -e "${BLUE}Setting up roles for client realm: ${CYAN}${CLIENT_ID}${NC}"

# Create log file for Keycloak operations
KEYCLOAK_LOG="${CLIENT_LOGS_DIR}/${CLIENT_ID}/keycloak.log"
mkdir -p "$(dirname "$KEYCLOAK_LOG")"
touch "$KEYCLOAK_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$KEYCLOAK_LOG"
  echo -e "$1"
}

# Get access token for Keycloak admin
log "${BLUE}Authenticating with Keycloak...${NC}"
ADMIN_TOKEN=$(curl -s \
  -d "client_id=admin-cli" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  "${KEYCLOAK_URL}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
  log "${RED}Error: Failed to authenticate with Keycloak${NC}"
  echo -e "Please check your Keycloak admin credentials and try again"
  exit 1
fi

log "${GREEN}Authentication successful${NC}"

# Check if realm exists
log "${BLUE}Checking if realm ${CLIENT_ID} exists...${NC}"
REALM_EXISTS=$(curl -s \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}" | jq -r '.realm')

if [ -z "$REALM_EXISTS" ] || [ "$REALM_EXISTS" == "null" ]; then
  log "${YELLOW}Realm ${CLIENT_ID} does not exist. Creating...${NC}"
  
  # Create realm
  REALM_JSON="${CLIENTS_DIR}/${CLIENT_ID}/keycloak/realm.json"
  if [ -f "$REALM_JSON" ]; then
    curl -s \
      -X POST \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d @"$REALM_JSON" \
      "${KEYCLOAK_URL}/auth/admin/realms"
  else
    # Create basic realm if JSON not found
    curl -s \
      -X POST \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"realm\":\"${CLIENT_ID}\",\"enabled\":true,\"displayName\":\"${CLIENT_NAME}\"}" \
      "${KEYCLOAK_URL}/auth/admin/realms"
  fi
  
  if [ $? -ne 0 ]; then
    log "${RED}Error: Failed to create realm${NC}"
    echo -e "Please check your Keycloak configuration and try again"
    exit 1
  fi
  
  log "${GREEN}Realm created successfully${NC}"
fi

# Create roles

# Function to create a role
create_role() {
  local realm="$1"
  local role_name="$2"
  local role_description="$3"
  
  log "${BLUE}Creating role: ${role_name}${NC}"
  
  # Check if role exists
  ROLE_EXISTS=$(curl -s \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KEYCLOAK_URL}/auth/admin/realms/${realm}/roles/${role_name}" | jq -r '.name')
  
  if [ -n "$ROLE_EXISTS" ] && [ "$ROLE_EXISTS" != "null" ]; then
    log "${YELLOW}Role ${role_name} already exists. Updating...${NC}"
    
    # Update existing role
    curl -s \
      -X PUT \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${role_name}\",\"description\":\"${role_description}\"}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${realm}/roles/${role_name}"
  else
    # Create new role
    curl -s \
      -X POST \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${role_name}\",\"description\":\"${role_description}\"}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${realm}/roles"
  fi
  
  if [ $? -ne 0 ]; then
    log "${RED}Error: Failed to create/update role ${role_name}${NC}"
    echo -e "Please check your Keycloak configuration and try again"
    return 1
  fi
  
  log "${GREEN}Role ${role_name} created/updated successfully${NC}"
  return 0
}

# Create standard roles
create_role "${CLIENT_ID}" "realm_admin" "Full administrative access to the realm"
create_role "${CLIENT_ID}" "editor" "Can edit content but not manage users/roles"
create_role "${CLIENT_ID}" "viewer" "Read-only access to content"

# Create realm admin user if specified in client config
if [ -n "$CLIENT_ADMIN_USER" ] && [ -n "$CLIENT_ADMIN_PASSWORD" ]; then
  log "${BLUE}Creating realm admin user: ${CLIENT_ADMIN_USER}${NC}"
  
  # Check if user exists
  USER_EXISTS=$(curl -s \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users?username=${CLIENT_ADMIN_USER}" | jq -r '.[0].username')
  
  USER_ID=""
  
  if [ -n "$USER_EXISTS" ] && [ "$USER_EXISTS" != "null" ]; then
    log "${YELLOW}User ${CLIENT_ADMIN_USER} already exists. Updating...${NC}"
    
    # Get user ID
    USER_ID=$(curl -s \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users?username=${CLIENT_ADMIN_USER}" | jq -r '.[0].id')
    
    # Update existing user
    curl -s \
      -X PUT \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"${CLIENT_ADMIN_USER}\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Realm\",\"lastName\":\"Admin\"}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users/${USER_ID}"
  else
    # Create new user
    curl -s \
      -X POST \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"${CLIENT_ADMIN_USER}\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Realm\",\"lastName\":\"Admin\"}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users"
    
    # Get user ID of newly created user
    USER_ID=$(curl -s \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users?username=${CLIENT_ADMIN_USER}" | jq -r '.[0].id')
  fi
  
  # Set password for user
  if [ -n "$USER_ID" ]; then
    curl -s \
      -X PUT \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"password\",\"value\":\"${CLIENT_ADMIN_PASSWORD}\",\"temporary\":false}" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users/${USER_ID}/reset-password"
    
    # Assign realm_admin role to user
    curl -s \
      -X POST \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "[{\"id\":\"$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles/realm_admin" | jq -r '.id')\",\"name\":\"realm_admin\"}]" \
      "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/users/${USER_ID}/role-mappings/realm"
    
    log "${GREEN}User ${CLIENT_ADMIN_USER} created/updated and assigned realm_admin role${NC}"
  else
    log "${RED}Error: Failed to create/update user ${CLIENT_ADMIN_USER}${NC}"
    echo -e "Please check your client configuration and try again"
  fi
fi

# Add composite roles
log "${BLUE}Setting up composite roles...${NC}"

# Get role IDs
ADMIN_ROLE_ID=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles/realm_admin" | jq -r '.id')
EDITOR_ROLE_ID=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles/editor" | jq -r '.id')
VIEWER_ROLE_ID=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles/viewer" | jq -r '.id')

# Make realm_admin a composite role that includes editor
curl -s \
  -X POST \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[{\"id\":\"${EDITOR_ROLE_ID}\",\"name\":\"editor\"}]" \
  "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles-by-id/${ADMIN_ROLE_ID}/composites"

# Make editor a composite role that includes viewer
curl -s \
  -X POST \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[{\"id\":\"${VIEWER_ROLE_ID}\",\"name\":\"viewer\"}]" \
  "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles-by-id/${EDITOR_ROLE_ID}/composites"

# Setup client scopes for default applications
log "${BLUE}Setting up client scopes for default applications...${NC}"

# Function to get client ID by name
get_client_id() {
  local realm="$1"
  local client_name="$2"
  
  curl -s \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KEYCLOAK_URL}/auth/admin/realms/${realm}/clients" | jq -r ".[] | select(.clientId == \"${client_name}\") | .id"
}

# Array of default client applications
declare -a CLIENT_APPS=("wordpress" "erpnext" "grafana" "account")

# Setup each client app
for app in "${CLIENT_APPS[@]}"; do
  # Get client ID
  CLIENT_APP_ID=$(get_client_id "${CLIENT_ID}" "${app}")
  
  if [ -n "$CLIENT_APP_ID" ]; then
    log "${BLUE}Setting up roles for client app: ${app}${NC}"
    
    # Add realm roles to client scope
    for role in "realm_admin" "editor" "viewer"; do
      # Get role ID
      ROLE_ID=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/roles/${role}" | jq -r '.id')
      
      # Add role to client scope
      curl -s \
        -X POST \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "[{\"id\":\"${ROLE_ID}\",\"name\":\"${role}\"}]" \
        "${KEYCLOAK_URL}/auth/admin/realms/${CLIENT_ID}/clients/${CLIENT_APP_ID}/scope-mappings/realm"
    done
    
    log "${GREEN}Client app ${app} roles set up successfully${NC}"
  else
    log "${YELLOW}Client app ${app} not found in realm${NC}"
  fi
done

log "${GREEN}${BOLD}Keycloak role setup completed for client ${CLIENT_ID}!${NC}"
exit 0
