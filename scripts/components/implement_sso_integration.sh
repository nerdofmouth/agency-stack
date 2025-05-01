#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: implement_sso_integration.sh
# Path: /scripts/components/implement_sso_integration.sh
#
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${ROOT_DIR}/scripts/utils/log_helpers.sh"
source "${ROOT_DIR}/scripts/utils/keycloak_integration.sh"

# Variables
DOMAIN=""
CLIENT_ID="default"
ADMIN_EMAIL=""
COMPONENT=""
FRAMEWORK=""
COMPONENT_URL=""
FORCE=false
VERBOSE=false
LOG_DIR="/var/log/agency_stack/components"
KEYCLOAK_INTEGRATION_LOG="${LOG_DIR}/keycloak_sso_integration.log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}" 2>/dev/null || true

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak SSO Integration${NC}"
  echo -e "========================================"
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  --help                  Show this help message"
  echo -e "  --domain <domain>       Domain name for Keycloak (required)"
  echo -e "  --admin-email <email>   Admin email for notifications (required)"
  echo -e "  --client-id <id>        Client ID (default: 'default')"
  echo -e "  --component <name>      Component name to integrate (required)"
  echo -e "  --framework <name>      Framework type (nodejs, python, docker) (required)"
  echo -e "  --component-url <url>   Component URL for redirect URIs (required)"
  echo -e "  --force                 Force reinstallation if already exists"
  echo -e "  --verbose               Enable verbose output"
  echo -e ""
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  $0 --domain example.com --admin-email admin@example.com --component peertube --framework nodejs --component-url https://peertube.example.com"
  echo -e ""
}

# Parse arguments
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
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --component)
      COMPONENT="$2"
      shift
      shift
      ;;
    --framework)
      FRAMEWORK="$2"
      shift
      shift
      ;;
    --component-url)
      COMPONENT_URL="$2"
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
      echo -e "${RED}Unknown option: $1${NC}" >&2
      show_help
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: Domain name is required. Use --domain to specify it.${NC}" >&2
  show_help
  exit 1

if [ -z "$ADMIN_EMAIL" ]; then
  echo -e "${RED}Error: Admin email is required. Use --admin-email to specify it.${NC}" >&2
  show_help
  exit 1

if [ -z "$COMPONENT" ]; then
  echo -e "${RED}Error: Component name is required. Use --component to specify it.${NC}" >&2
  show_help
  exit 1

if [ -z "$FRAMEWORK" ]; then
  echo -e "${RED}Error: Framework type is required. Use --framework to specify it.${NC}" >&2
  show_help
  exit 1

if [ -z "$COMPONENT_URL" ]; then
  echo -e "${RED}Error: Component URL is required. Use --component-url to specify it.${NC}" >&2
  show_help
  exit 1

# Set up logging
if [ "$VERBOSE" = true ]; then
  set -x

# Helper function to check if component is SSO-enabled
is_sso_enabled() {
  local component="$1"
  local registry_file="/opt/agency_stack/repo/config/registry/component_registry.json"
  
  if [ ! -f "$registry_file" ]; then
    log_error "Component registry file not found: $registry_file"
    return 1
  fi
  
  # Get the section for this component - looking for both array and object formats
  # The component registry has evolved and may have either format
  local component_section=$(grep -A 30 "\"$component\"" "$registry_file" | grep -A 30 -B 5 "integration_status\|flags")
  
  if [ -z "$component_section" ]; then
    log_error "Component $component not found in registry"
    return 1
  fi
  
  # Check if SSO is enabled in this component
  if echo "$component_section" | grep -q "\"sso\": *true"; then
    log_info "Component $component is SSO-enabled"
    return 0
  else
    log_error "Component $component is not SSO-enabled in registry"
    return 1
  fi
}

# Helper function to update component registry to set sso_configured flag
update_sso_configured_flag() {
  local component="$1"
  local registry_file="${ROOT_DIR}/config/registry/component_registry.json"
  
  if [ ! -f "$registry_file" ]; then
    log_error "Component registry file not found: $registry_file"
    return 1
  fi
  
  # Create a backup of the registry file
  cp "$registry_file" "${registry_file}.bak"
  
  # Use jq to update the sso_configured flag if the component exists
  if command -v jq >/dev/null 2>&1; then
    jq --arg component "$component" '(.components[] | select(.name == $component) | .flags.sso_configured) = true' "$registry_file" > "${registry_file}.tmp"
    if [ $? -eq 0 ]; then
      mv "${registry_file}.tmp" "$registry_file"
      log_success "Updated SSO configuration flag for $component in component registry"
    else
      log_error "Failed to update component registry with jq"
      return 1
    fi
  else
    log_warning "jq not found, using sed to update registry (less reliable)"
    
    # Find the component section and update sso_configured flag
    sed -i "s/\"name\": \"$component\",/\"name\": \"$component\",\n          \"sso_configured\": true,/g" "$registry_file"
    
    if [ $? -eq 0 ]; then
      log_success "Updated SSO configuration flag for $component in component registry"
    else
      log_error "Failed to update component registry with sed"
      return 1
    fi
  fi
  
  return 0
}

# Function to check if Keycloak is available
check_keycloak_available() {
  local domain="$1"
  local max_attempts=30
  local attempt=1
  local ready=false

  log_info "Checking if Keycloak is available for domain $domain..."

  # Check if keycloak is installed
  if [ ! -d /opt/agency_stack/keycloak ]; then
    log_error "Keycloak directory not found at /opt/agency_stack/keycloak"
    log_info "You can install Keycloak with: make install-keycloak DOMAIN=$domain ADMIN_EMAIL=$admin_email"
    return 1
  fi

  # Check if domain-specific keycloak is installed
  if [ ! -d "/opt/agency_stack/keycloak/$domain" ]; then
    log_error "Keycloak is not installed for domain $domain"
    log_info "You can install Keycloak with: make install-keycloak DOMAIN=$domain ADMIN_EMAIL=$admin_email"
    return 1
  fi

  # Wait for Keycloak to be ready
  while [ $attempt -lt $max_attempts ]; do
    log_info "Waiting for Keycloak to be ready... ($attempt/$max_attempts)"
    
    # Try both legacy and new Keycloak health endpoints
    if curl -s -f -o /dev/null -w '%{http_code}' "https://$domain/health" | grep -q 200 || \
       curl -s -f -o /dev/null -w '%{http_code}' "https://$domain/auth/health" | grep -q 200 || \
       curl -s -f -o /dev/null -w '%{http_code}' "https://$domain/admin/" | grep -q 200; then
      ready=true
      break
    fi
    
    sleep 5
    attempt=$((attempt + 1))
  done

  if [ "$ready" = false ]; then
    log_error "Keycloak health endpoint not responding after $max_attempts attempts."
    return 1
  fi

  log_success "Keycloak is available for domain $domain"
  return 0
}

# Check for prerequisites before proceeding
log_info "Checking prerequisites for SSO integration..."

# Validate Keycloak is properly installed
if ! check_keycloak_available "$DOMAIN"; then
  log_error "Keycloak is not available for domain $DOMAIN. Please install and start Keycloak first."
  log_info "You can install Keycloak with: make install-keycloak DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL"
  exit 1

# Check if component is SSO-enabled
if ! is_sso_enabled "$COMPONENT"; then
  log_error "Component $COMPONENT is not marked as SSO-enabled in the component registry. Set 'sso: true' in the registry first."
  exit 1

# Check if Keycloak is installed and running
log_info "Checking if Keycloak is available for domain $DOMAIN..."
if ! check_keycloak_available "$DOMAIN"; then
  log_error "Keycloak is not available for domain $DOMAIN. Please install and start Keycloak first."
  log_info "You can install Keycloak with: make install-keycloak DOMAIN=$DOMAIN ADMIN_EMAIL=$ADMIN_EMAIL"
  exit 1

# Check for required dependencies
if ! check_dependencies; then
  log_error "Missing required dependencies for Keycloak SSO integration."
  exit 1

# Integrate component with Keycloak
log_info "Integrating $COMPONENT with Keycloak SSO on domain $DOMAIN..."
if ! integrate_with_keycloak "$DOMAIN" "$COMPONENT" "$FRAMEWORK" "$COMPONENT_URL"; then
  log_error "Failed to integrate $COMPONENT with Keycloak SSO."
  exit 1

# Update component registry to set sso_configured flag
log_info "Updating component registry to mark $COMPONENT as SSO-configured..."
if ! update_sso_configured_flag "$COMPONENT"; then
  log_warning "Failed to update component registry. Please manually set 'sso_configured: true' for $COMPONENT in the registry."

log_success "Successfully integrated $COMPONENT with Keycloak SSO on domain $DOMAIN"
echo -e "${GREEN}✅ $COMPONENT has been integrated with Keycloak SSO${NC}"
echo -e "${CYAN}Credentials are stored in: /opt/agency_stack/keycloak/clients/${COMPONENT}_${DOMAIN}.env${NC}"
echo -e "${CYAN}Integration code is available in: /opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT}/keycloak/${NC}"
echo -e ""
echo -e "${YELLOW}Important: To complete the integration, you need to:${NC}"
echo -e "1. Add the SSO configuration to your component's configuration files"
echo -e "2. Restart the component with: make ${COMPONENT}-restart"
echo -e "3. Verify the SSO integration is working correctly"
echo -e ""

exit 0
