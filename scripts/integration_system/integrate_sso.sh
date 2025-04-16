#!/bin/bash
# integrate_sso.sh - Single Sign-On Integration for AgencyStack
# https://stack.nerdofmouth.com

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/integrate_common.sh"

# SSO Integration version
SSO_VERSION="1.0.1"

# Start logging
LOG_FILE="${INTEGRATION_LOG_DIR}/sso-${CURRENT_DATE}.log"
log "${MAGENTA}${BOLD}🔑 AgencyStack Single Sign-On Integration${NC}"
log "========================================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Get installed components
get_installed_components

# Check if Keycloak is installed
if ! is_component_installed "Keycloak"; then
  log "${YELLOW}Warning: Keycloak is not installed${NC}"
  log "Skipping SSO integration. Install Keycloak for SSO capabilities."
  exit 1
fi

# WordPress SSO Integration
integrate_wordpress_sso() {
  if ! is_component_installed "WordPress"; then
    log "${YELLOW}WordPress not installed, skipping WordPress SSO integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up WordPress Single Sign-On with Keycloak...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "sso" "WordPress"; then
    log "${GREEN}WordPress SSO integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the WordPress SSO integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping WordPress SSO integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Check for WordPress WP-CLI wrapper
  WP_CLI="/opt/agency_stack/wordpress/wp.sh"
  if [ ! -f "$WP_CLI" ]; then
    log "${YELLOW}Warning: WordPress CLI not available at ${WP_CLI}${NC}"
    log "Manual configuration will be required:"
    log "1. Install the miniOrange OIDC Client plugin"
    log "2. Configure it with your Keycloak server"
    record_integration "sso" "WordPress" "$SSO_VERSION" "Manual configuration required - WP-CLI not available"
    return 1
  fi
  
  # Install miniOrange OIDC plugin if not already installed
  if ! sudo $WP_CLI plugin is-installed miniorange-openid-connect-client; then
    log "${BLUE}Installing miniOrange OIDC plugin...${NC}"
    sudo $WP_CLI plugin install miniorange-openid-connect-client --activate
  elif ! sudo $WP_CLI plugin is-active miniorange-openid-connect-client; then
    log "${BLUE}Activating miniOrange OIDC plugin...${NC}"
    sudo $WP_CLI plugin activate miniorange-openid-connect-client
  fi
  
  # Create configuration guide
  log "${GREEN}✅ WordPress SSO plugin installed and activated${NC}"
  log "${YELLOW}Manual configuration steps required:${NC}"
  log "1. Go to WordPress Admin → Settings → miniOrange OIDC"
  log "2. Configure the following settings:"
  log "   - Display Name: Keycloak"
  log "   - Client ID: wordpress"
  log "   - Client Secret: (from Keycloak)"
  log "   - Scope: openid email profile"
  log "   - Authorization Endpoint: https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/auth"
  log "   - Token Endpoint: https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/token"
  log "   - User Info Endpoint: https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/userinfo"
  log "   - Enable 'Auto-redirect to Identity Provider'"
  
  # Record integration as applied
  record_integration "sso" "WordPress" "$SSO_VERSION" "OIDC SSO integration with Keycloak via miniOrange plugin"
  
  return 0
}

# ERPNext SSO Integration
integrate_erpnext_sso() {
  if ! is_component_installed "ERPNext"; then
    log "${YELLOW}ERPNext not installed, skipping ERPNext SSO integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up ERPNext Single Sign-On with Keycloak...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "sso" "ERPNext"; then
    log "${GREEN}ERPNext SSO integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the ERPNext SSO integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping ERPNext SSO integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Check for ERPNext bench tool
  BENCH_CLI="/opt/agency_stack/erpnext/bench.sh"
  if [ ! -f "$BENCH_CLI" ]; then
    log "${YELLOW}Warning: ERPNext bench not available at ${BENCH_CLI}${NC}"
    log "Manual configuration will be required for ERPNext SSO"
    record_integration "sso" "ERPNext" "$SSO_VERSION" "Manual configuration required - bench tool not available"
    return 1
  fi
  
  # Install ERPNext OAuth app if it doesn't exist already
  SITE_NAME="${ERPNEXT_SITE_NAME:-erp.${PRIMARY_DOMAIN}}"
  
  # Create OAuth configuration
  log "${BLUE}Configuring ERPNext for OAuth with Keycloak...${NC}"
  
  # Create OAuth Provider
  sudo $BENCH_CLI --site "$SITE_NAME" execute frappe.client.insert --args '{
    "doctype": "OAuth Provider Settings",
    "name": "Keycloak",
    "client_id": "erpnext",
    "client_secret": "erpnext-secret",
    "authorize_url": "https://'${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}'/auth/realms/agencystack/protocol/openid-connect/auth",
    "access_token_url": "https://'${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}'/auth/realms/agencystack/protocol/openid-connect/token",
    "redirect_url": "https://'${SITE_NAME}'/api/method/frappe.integrations.oauth2.callback",
    "api_endpoint": "https://'${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}'/auth/realms/agencystack/protocol/openid-connect/userinfo",
    "api_endpoint_args": {},
    "auth_url_data": {
      "response_type": "code",
      "scope": "openid email profile"
    }
  }'
  
  # Enable OAuth in ERPNext System Settings
  sudo $BENCH_CLI --site "$SITE_NAME" set-config -g enable_oauth "1"
  
  log "${GREEN}✅ ERPNext OAuth integration with Keycloak configured${NC}"
  log "${YELLOW}Manual configuration steps required:${NC}"
  log "1. In Keycloak admin console, create a new client with:"
  log "   - Client ID: erpnext"
  log "   - Client Protocol: openid-connect"
  log "   - Access Type: confidential"
  log "   - Valid Redirect URIs: https://${SITE_NAME}/api/method/frappe.integrations.oauth2.callback"
  log "2. Copy the client secret from Keycloak to ERPNext OAuth Provider Settings"
  
  # Record integration as applied
  record_integration "sso" "ERPNext" "$SSO_VERSION" "OAuth2 SSO integration with Keycloak"
  
  return 0
}

# Grafana SSO Integration
integrate_grafana_sso() {
  if ! is_component_installed "Grafana"; then
    log "${YELLOW}Grafana not installed, skipping Grafana SSO integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up Grafana Single Sign-On with Keycloak...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "sso" "Grafana"; then
    log "${GREEN}Grafana SSO integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the Grafana SSO integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping Grafana SSO integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Check if Grafana container is running
  if ! is_container_running "agency_stack_grafana"; then
    log "${YELLOW}Warning: Grafana container not running${NC}"
    log "Start Grafana before configuring SSO"
    return 1
  fi
  
  # Update Grafana configuration
  GRAFANA_CONFIG="/opt/agency_stack/grafana/grafana.ini"
  
  if [ ! -f "$GRAFANA_CONFIG" ]; then
    log "${YELLOW}Warning: Grafana configuration file not found at ${GRAFANA_CONFIG}${NC}"
    log "Manual configuration will be required for Grafana SSO"
    record_integration "sso" "Grafana" "$SSO_VERSION" "Manual configuration required - config file not found"
    return 1
  fi
  
  # Backup current config
  sudo cp "$GRAFANA_CONFIG" "${GRAFANA_CONFIG}.bak"
  
  # Add OAuth configuration
  log "${BLUE}Updating Grafana configuration for Keycloak SSO...${NC}"
  
  # Check if oauth section already exists
  if ! grep -q "^\[auth\.generic_oauth\]" "$GRAFANA_CONFIG"; then
    # Add OAuth section
    echo "" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "[auth.generic_oauth]" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "name = Keycloak" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "enabled = true" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "allow_sign_up = true" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "client_id = grafana" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "client_secret = grafana-secret" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "scopes = openid email profile" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "auth_url = https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/auth" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "token_url = https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/token" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "api_url = https://${KEYCLOAK_DOMAIN:-sso.${PRIMARY_DOMAIN}}/auth/realms/agencystack/protocol/openid-connect/userinfo" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
    echo "role_attribute_path = contains(roles[*], 'admin') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'" | sudo tee -a "$GRAFANA_CONFIG" > /dev/null
  else
    log "${YELLOW}OAuth configuration section already exists in Grafana config${NC}"
    log "Manual review and update may be required"
  fi
  
  # Restart Grafana
  log "${BLUE}Restarting Grafana to apply changes...${NC}"
  docker restart agency_stack_grafana
  
  log "${GREEN}✅ Grafana SSO integration with Keycloak configured${NC}"
  log "${YELLOW}Manual configuration steps required:${NC}"
  log "1. In Keycloak admin console, create a new client with:"
  log "   - Client ID: grafana"
  log "   - Client Protocol: openid-connect"
  log "   - Access Type: confidential"
  log "   - Valid Redirect URIs: https://${GRAFANA_DOMAIN:-grafana.${PRIMARY_DOMAIN}}/login/generic_oauth"
  log "2. Copy the client secret from Keycloak to Grafana configuration file"
  log "3. Update client_secret in ${GRAFANA_CONFIG}"
  
  # Record integration as applied
  record_integration "sso" "Grafana" "$SSO_VERSION" "OAuth2 SSO integration with Keycloak"
  
  return 0
}

# Main function
main() {
  log "${BLUE}Starting Single Sign-On integrations...${NC}"
  
  # Integrate WordPress with Keycloak
  integrate_wordpress_sso
  
  # Integrate ERPNext with Keycloak
  integrate_erpnext_sso
  
  # Integrate Grafana with Keycloak
  integrate_grafana_sso
  
  # Additional integrations can be added here
  
  # Generate integration report
  generate_integration_report
  
  log ""
  log "${GREEN}${BOLD}Single Sign-On integration complete!${NC}"
  log "See integration log for details: ${LOG_FILE}"
  log "See integration report for summary and recommended actions."
}

# Run main function
main
