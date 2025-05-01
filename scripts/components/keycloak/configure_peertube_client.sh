#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: configure_peertube_client.sh
# Path: /scripts/components/configure_peertube_client.sh
#
set -eo pipefail

# Source common utilities
ROOT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "${ROOT_DIR}/scripts/utils/keycloak_integration.sh" || { echo "Error: Could not source Keycloak integration utilities" >&2; exit 1; }

# Variables
DOMAIN=""
CLIENT_ID="default"
FORCE=false
PEERTUBE_CLIENT_SECRET=$(openssl rand -hex 16)
KEYCLOAK_CONFIG_DIR="/opt/agency_stack/keycloak"
VERBOSE=false

# Show usage information
show_help() {
  echo -e "${MAGENTA}${BOLD}PeerTube Keycloak Client Configuration${NC}"
  echo -e "========================================"
  echo -e "This script configures a Keycloak client for PeerTube SSO integration."
  echo -e ""
  echo -e "Usage:"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "Options:"
  echo -e "  --help                  Show this help message"
  echo -e "  --domain <domain>       Domain name for Keycloak (required)"
  echo -e "  --client-id <id>        Client ID (default: 'default')"
  echo -e "  --force                 Force reconfiguration if already exists"
  echo -e "  --verbose               Enable verbose output"
  echo -e ""
  echo -e "Example:"
  echo -e "  $0 --domain example.com --client-id default --force"
  echo -e ""
}

# Process command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --help)
      show_help
      exit 0
      ;;
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
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      log_error "Unknown option: $key"
      show_help
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$DOMAIN" ]; then
  log_error "Domain name is required. Use --domain <domain>"
  show_help
  exit 1

# Main function to configure PeerTube client in Keycloak
configure_peertube_client() {
  log_info "Starting PeerTube Keycloak client configuration for domain: $DOMAIN"

  # Check if Keycloak is available
  if ! keycloak_is_available "$DOMAIN"; then
    log_error "Keycloak is not available for domain $DOMAIN. Please install and start Keycloak first."
    log_info "You can install Keycloak with: make install-keycloak DOMAIN=$DOMAIN"
    exit 1
  fi

  # Get Keycloak admin token
  local admin_token=$(get_keycloak_admin_token "$DOMAIN")
  if [ -z "$admin_token" ]; then
    log_error "Failed to obtain Keycloak admin token"
    exit 1
  fi

  # Check if realm exists, create if it doesn't
  if ! realm_exists "$DOMAIN" "$CLIENT_ID" "$admin_token"; then
    log_info "Creating realm: $CLIENT_ID"
    create_realm "$DOMAIN" "$CLIENT_ID" "$admin_token"
  fi

  # Check if client already exists
  if client_exists "$DOMAIN" "$CLIENT_ID" "peertube" "$admin_token" && [ "$FORCE" != "true" ]; then
    log_warning "PeerTube client already exists in realm $CLIENT_ID. Use --force to reconfigure."
    return 0
  elif client_exists "$DOMAIN" "$CLIENT_ID" "peertube" "$admin_token"; then
    log_info "Removing existing PeerTube client"
    delete_client "$DOMAIN" "$CLIENT_ID" "peertube" "$admin_token"
  fi

  # Create client from template
  log_info "Creating PeerTube client in Keycloak"
  
  # Replace variables in template
  local client_config_template="${SCRIPT_DIR}/clients/peertube-client.json"
  local client_config="/tmp/peertube-client-$DOMAIN.json"
  
  if [ ! -f "$client_config_template" ]; then
    log_error "Client configuration template not found: $client_config_template"
    exit 1
  fi
  
  # Replace variables in template
  cat "$client_config_template" | \
    sed "s/\${DOMAIN}/$DOMAIN/g" | \
    sed "s/\${PEERTUBE_CLIENT_SECRET}/$PEERTUBE_CLIENT_SECRET/g" > "$client_config"
    
  # Create client
  create_client_from_file "$DOMAIN" "$CLIENT_ID" "$client_config" "$admin_token"
  
  # Get client ID from Keycloak
  local client_uuid=$(get_client_id "$DOMAIN" "$CLIENT_ID" "peertube" "$admin_token")
  
  # Create role mappers
  log_info "Creating role mappers for PeerTube client"
  create_role_mapper "$DOMAIN" "$CLIENT_ID" "$client_uuid" "admin" "Admin" "$admin_token"
  create_role_mapper "$DOMAIN" "$CLIENT_ID" "$client_uuid" "user" "User" "$admin_token"
  create_role_mapper "$DOMAIN" "$CLIENT_ID" "$client_uuid" "moderator" "Moderator" "$admin_token"
  
  # Update PeerTube configuration if installed
  log_info "Updating PeerTube configuration for SSO"
  update_peertube_config
  
  log_success "PeerTube client configured successfully in Keycloak"
  
  echo ""
  echo -e "${CYAN}PeerTube SSO Integration Details:${NC}"
  echo -e "${CYAN}-----------------------------${NC}"
  echo -e "${CYAN}Realm:${NC} $CLIENT_ID"
  echo -e "${CYAN}Client ID:${NC} peertube"
  echo -e "${CYAN}Client Secret:${NC} $PEERTUBE_CLIENT_SECRET"
  echo -e "${CYAN}Redirect URI:${NC} https://peertube.$DOMAIN/*"
  echo ""
  
  # Save client secret for future reference
  mkdir -p "/opt/agency_stack/secrets/keycloak/$DOMAIN/"
  echo "PEERTUBE_CLIENT_SECRET=$PEERTUBE_CLIENT_SECRET" > "/opt/agency_stack/secrets/keycloak/$DOMAIN/peertube.env"
  
  log_info "Client secret saved to: /opt/agency_stack/secrets/keycloak/$DOMAIN/peertube.env"
}

# Function to update PeerTube configuration for SSO
update_peertube_config() {
  local peertube_dir="/opt/agency_stack/clients/$CLIENT_ID/peertube_data"
  
  if [ ! -d "$peertube_dir" ]; then
    log_warning "PeerTube installation not found. Configuration will be applied during installation."
    return 0
  fi
  
  # Create config directory if it doesn't exist
  mkdir -p "$peertube_dir/config/production.yaml.d"
  
  # Create OAuth configuration
  log_info "Creating PeerTube OAuth configuration"
  cat > "$peertube_dir/config/production.yaml.d/oauth.yaml" << EOF
oauth2:
  silent_authentication: true
  default_update_role: "User"
  trusted_browsers: []
  providers:
    - name: 'keycloak'
      display_name: 'Sign in with SSO'
      open_id_configuration_url: 'https://$DOMAIN/realms/$CLIENT_ID/.well-known/openid-configuration'
      client_id: 'peertube'
      client_secret: '$PEERTUBE_CLIENT_SECRET'
      scope: 'openid email profile'
      additional_params:
        prompt: 'login'
EOF
  
  # Restart PeerTube if running
  if docker ps | grep -q "peertube_${CLIENT_ID}"; then
    log_info "Restarting PeerTube to apply configuration changes"
    docker restart "peertube_${CLIENT_ID}"
  fi
}

# Execute main function
configure_peertube_client
