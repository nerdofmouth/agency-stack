#!/bin/bash
# generate_secrets.sh - Secure secrets management for AgencyStack
# https://stack.nerdofmouth.com
#
# This script generates and manages secrets for AgencyStack.
# It creates strong, random passwords for all services and stores them securely.
# All secrets are stored in /opt/agency_stack/secrets/ with proper permissions.
#
# Usage: ./generate_secrets.sh [--rotate] [--client-id <client_id>] [--service <service_name>]
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
SECRETS_DIR="${CONFIG_DIR}/secrets"
CLIENTS_DIR="${CONFIG_DIR}/clients"
LOG_DIR="/var/log/agency_stack"
SECRETS_LOG="${LOG_DIR}/secrets.log"
ROTATE_MODE=false
CLIENT_ID=""
SERVICE_NAME=""

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Secrets Management${NC}"
echo -e "=================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --rotate)
      ROTATE_MODE=true
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --service)
      SERVICE_NAME="$2"
      shift
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Usage: $0 [--rotate] [--client-id <client_id>] [--service <service_name>]"
      exit 1
      ;;
  esac
done

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$SECRETS_LOG"

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Function to log actions
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$SECRETS_LOG"
  echo -e "$1"
}

# Function to generate a random password
generate_password() {
  local length=${1:-32}
  openssl rand -base64 "$length" | tr -d '\n' | cut -c1-"$length"
}

# Function to generate a random hex token
generate_hex_token() {
  local length=${1:-32}
  openssl rand -hex "$((length / 2))" | tr -d '\n'
}

# Function to check if a secret file exists
secret_exists() {
  local file="$1"
  [ -f "$file" ]
}

# Function to create a backup of a secret file
backup_secret() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
    log "${BLUE}Created backup of ${file}${NC}"
  fi
}

# Function to update an existing secret file
update_secret() {
  local file="$1"
  local key="$2"
  local value="$3"
  
  if [ -f "$file" ]; then
    # Check if key exists
    if grep -q "^${key}=" "$file"; then
      # Update existing key
      sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
    else
      # Add new key
      echo "${key}=\"${value}\"" >> "$file"
    fi
  else
    # Create new file
    echo "# Secrets file generated on $(date)" > "$file"
    echo "# IMPORTANT: Do not commit this file to version control!" >> "$file"
    echo "${key}=\"${value}\"" >> "$file"
  fi
  
  # Ensure proper permissions
  chmod 600 "$file"
}

# Generate main system secrets
generate_system_secrets() {
  log "${BLUE}Generating system-wide secrets...${NC}"
  
  SYSTEM_SECRETS="${SECRETS_DIR}/system.env"
  
  if secret_exists "$SYSTEM_SECRETS" && [ "$ROTATE_MODE" = false ]; then
    log "${YELLOW}System secrets already exist. Use --rotate to regenerate.${NC}"
  else
    if [ "$ROTATE_MODE" = true ]; then
      backup_secret "$SYSTEM_SECRETS"
      log "${BLUE}Rotating system secrets...${NC}"
    else
      log "${BLUE}Creating new system secrets...${NC}"
    fi
    
    # Keycloak admin credentials
    update_secret "$SYSTEM_SECRETS" "KEYCLOAK_ADMIN_PASSWORD" "$(generate_password 16)"
    
    # Database root passwords
    update_secret "$SYSTEM_SECRETS" "MYSQL_ROOT_PASSWORD" "$(generate_password 16)"
    update_secret "$SYSTEM_SECRETS" "POSTGRES_PASSWORD" "$(generate_password 16)"
    
    # Traefik Dashboard credentials
    update_secret "$SYSTEM_SECRETS" "TRAEFIK_DASHBOARD_USER" "admin"
    update_secret "$SYSTEM_SECRETS" "TRAEFIK_DASHBOARD_PASSWORD" "$(generate_password 16)"
    
    # JWT Secret for internal services
    update_secret "$SYSTEM_SECRETS" "JWT_SECRET" "$(generate_hex_token 64)"
    
    # Main backup encryption key
    update_secret "$SYSTEM_SECRETS" "RESTIC_PASSWORD" "$(generate_password 32)"
    
    log "${GREEN}System secrets generated and stored in ${SYSTEM_SECRETS}${NC}"
  fi
}

# Generate client-specific secrets
generate_client_secrets() {
  local client="$1"
  log "${BLUE}Generating secrets for client: ${client}...${NC}"
  
  CLIENT_SECRETS_DIR="${SECRETS_DIR}/${client}"
  mkdir -p "$CLIENT_SECRETS_DIR"
  chmod 700 "$CLIENT_SECRETS_DIR"
  
  CLIENT_SECRETS="${CLIENT_SECRETS_DIR}/secrets.env"
  
  if secret_exists "$CLIENT_SECRETS" && [ "$ROTATE_MODE" = false ]; then
    log "${YELLOW}Client secrets already exist for ${client}. Use --rotate to regenerate.${NC}"
  else
    if [ "$ROTATE_MODE" = true ]; then
      backup_secret "$CLIENT_SECRETS"
      log "${BLUE}Rotating client secrets for ${client}...${NC}"
    else
      log "${BLUE}Creating new client secrets for ${client}...${NC}"
    fi
    
    # Keycloak realm admin password
    update_secret "$CLIENT_SECRETS" "KEYCLOAK_REALM_ADMIN_PASSWORD" "$(generate_password 16)"
    
    # Database passwords for client services
    update_secret "$CLIENT_SECRETS" "WORDPRESS_DB_PASSWORD" "$(generate_password 16)"
    update_secret "$CLIENT_SECRETS" "ERPNEXT_DB_PASSWORD" "$(generate_password 16)"
    
    # Mailu admin password and secret key
    update_secret "$CLIENT_SECRETS" "MAILU_ADMIN_PASSWORD" "$(generate_password 16)"
    update_secret "$CLIENT_SECRETS" "MAILU_SECRET_KEY" "$(generate_password 32)"
    
    # Client-specific backup encryption key
    update_secret "$CLIENT_SECRETS" "RESTIC_PASSWORD" "$(generate_password 32)"
    
    # Client-specific API keys
    update_secret "$CLIENT_SECRETS" "API_KEY" "$(generate_hex_token 32)"
    
    log "${GREEN}Client secrets generated and stored in ${CLIENT_SECRETS}${NC}"
  }
}

# Generate service-specific secrets
generate_service_secrets() {
  local service="$1"
  local client="$2"
  
  # Define the secrets directory
  local SECRETS_PATH
  if [ -n "$client" ]; then
    SECRETS_PATH="${SECRETS_DIR}/${client}/services"
    mkdir -p "$SECRETS_PATH"
    chmod 700 "$SECRETS_PATH"
  else
    SECRETS_PATH="${SECRETS_DIR}/services"
    mkdir -p "$SECRETS_PATH"
    chmod 700 "$SECRETS_PATH"
  fi
  
  local SERVICE_SECRETS="${SECRETS_PATH}/${service}.env"
  
  log "${BLUE}Generating secrets for service: ${service}${NC}"
  
  if secret_exists "$SERVICE_SECRETS" && [ "$ROTATE_MODE" = false ]; then
    log "${YELLOW}Service secrets already exist for ${service}. Use --rotate to regenerate.${NC}"
    return
  fi
  
  if [ "$ROTATE_MODE" = true ]; then
    backup_secret "$SERVICE_SECRETS"
    log "${BLUE}Rotating service secrets for ${service}...${NC}"
  else
    log "${BLUE}Creating new service secrets for ${service}...${NC}"
  fi
  
  case "$service" in
    keycloak)
      update_secret "$SERVICE_SECRETS" "KEYCLOAK_ADMIN_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "KEYCLOAK_DB_PASSWORD" "$(generate_password 16)"
      ;;
    wordpress)
      update_secret "$SERVICE_SECRETS" "WORDPRESS_DB_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_AUTH_KEY" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_SECURE_AUTH_KEY" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_LOGGED_IN_KEY" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_NONCE_KEY" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_AUTH_SALT" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_SECURE_AUTH_SALT" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_LOGGED_IN_SALT" "$(generate_hex_token 64)"
      update_secret "$SERVICE_SECRETS" "WORDPRESS_NONCE_SALT" "$(generate_hex_token 64)"
      ;;
    erpnext)
      update_secret "$SERVICE_SECRETS" "ERPNEXT_DB_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "ERPNEXT_ADMIN_PASSWORD" "$(generate_password 16)"
      ;;
    mailu)
      update_secret "$SERVICE_SECRETS" "MAILU_ADMIN_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "MAILU_SECRET_KEY" "$(generate_password 32)"
      ;;
    grafana)
      update_secret "$SERVICE_SECRETS" "GRAFANA_ADMIN_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "GRAFANA_SECRET_KEY" "$(generate_hex_token 32)"
      ;;
    traefik)
      update_secret "$SERVICE_SECRETS" "TRAEFIK_DASHBOARD_USER" "admin"
      update_secret "$SERVICE_SECRETS" "TRAEFIK_DASHBOARD_PASSWORD" "$(generate_password 16)"
      ;;
    *)
      update_secret "$SERVICE_SECRETS" "${service^^}_PASSWORD" "$(generate_password 16)"
      update_secret "$SERVICE_SECRETS" "${service^^}_SECRET_KEY" "$(generate_hex_token 32)"
      ;;
  esac
  
  log "${GREEN}Service secrets generated and stored in ${SERVICE_SECRETS}${NC}"
}

# Main function
main() {
  # Generate system-wide secrets
  if [ -z "$CLIENT_ID" ] && [ -z "$SERVICE_NAME" ]; then
    generate_system_secrets
  fi
  
  # Generate client-specific secrets
  if [ -n "$CLIENT_ID" ]; then
    # Check if client directory exists
    if [ ! -d "${CLIENTS_DIR}/${CLIENT_ID}" ]; then
      log "${YELLOW}Warning: Client directory does not exist. Creating client directory...${NC}"
      mkdir -p "${CLIENTS_DIR}/${CLIENT_ID}"
    fi
    
    generate_client_secrets "$CLIENT_ID"
    
    # Generate service-specific secrets if requested
    if [ -n "$SERVICE_NAME" ]; then
      generate_service_secrets "$SERVICE_NAME" "$CLIENT_ID"
    fi
  fi
  
  # Generate service-specific secrets (without client)
  if [ -n "$SERVICE_NAME" ] && [ -z "$CLIENT_ID" ]; then
    generate_service_secrets "$SERVICE_NAME"
  fi
  
  # Set permissions correctly for the deploy user
  if getent passwd deploy > /dev/null; then
    chown -R deploy:deploy "$SECRETS_DIR"
    log "${BLUE}Set ownership of secrets directory to deploy user${NC}"
  else
    log "${YELLOW}Warning: deploy user does not exist. Secrets directory ownership not changed.${NC}"
  fi
  
  # Final message
  echo -e "\n${GREEN}${BOLD}Secret generation complete!${NC}"
  echo -e "All secrets are stored in ${SECRETS_DIR}"
  echo -e "Ensure appropriate permissions and backup these secrets securely."
  
  if [ "$ROTATE_MODE" = true ]; then
    echo -e "\n${YELLOW}Note: You may need to restart services to apply the new secrets.${NC}"
  fi
}

# Run main function
main

exit 0
