#!/bin/bash
# sso_status.sh - Check SSO integration status for Keycloak and connected services
# Part of the AgencyStack Alpha consolidation for client-ready TLS/SSO

# Exit on error
set -e
set -o pipefail

# Source utility functions
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/utils/common.sh" || { echo "Error: Could not source common utility functions" >&2; exit 1; }
source "${ROOT_DIR}/scripts/utils/logging.sh" || { echo "Error: Could not source logging utility functions" >&2; exit 1; }

# Initialize log file
COMPONENTS_LOG_DIR="/var/log/agency_stack/components"
mkdir -p "${COMPONENTS_LOG_DIR}"
LOG_FILE="${COMPONENTS_LOG_DIR}/sso_status.log"

# Default domain and options
DOMAIN="${DOMAIN:-}"
CLIENT_ID="${CLIENT_ID:-default}"
VERBOSE="${VERBOSE:-false}"
CHECK_REALM="${CHECK_REALM:-true}"
TIMEOUT=10
ERROR_COUNT=0

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Check SSO integration status for Keycloak and connected services"
  echo ""
  echo "Options:"
  echo "  --domain DOMAIN       Domain to check (required)"
  echo "  --client-id ID        Client ID for the realm (default: 'default')"
  echo "  --verbose             Enable verbose output"
  echo "  --no-realm-check      Skip realm configuration check"
  echo "  --help                Display this help message"
}

# Parse command-line arguments
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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --no-realm-check)
      CHECK_REALM=false
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Verify domain
if [[ -z "${DOMAIN}" ]]; then
  log_error "Domain is required"
  print_usage
  exit 1
fi

# Check if domain resolves (DNS check)
log_info "Checking DNS resolution for keycloak.${DOMAIN}..."
if ! host "keycloak.${DOMAIN}" &>/dev/null; then
  log_error "DNS resolution failed for keycloak.${DOMAIN} - check DNS configuration"
  ERROR_COUNT=$((ERROR_COUNT+1))
else
  log_success "DNS resolution successful for keycloak.${DOMAIN}"
fi

# Check Keycloak base availability
log_info "Checking Keycloak availability at keycloak.${DOMAIN}..."
KC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "https://keycloak.${DOMAIN}/" 2>/dev/null || echo "failed")

if [[ "${KC_STATUS}" == "failed" ]]; then
  log_error "Connection to Keycloak failed - check service status and firewall settings"
  ERROR_COUNT=$((ERROR_COUNT+1))
elif [[ "${KC_STATUS}" -eq 200 || "${KC_STATUS}" -eq 302 ]]; then
  log_success "Keycloak is available at keycloak.${DOMAIN} (status: ${KC_STATUS})"
else
  log_error "Keycloak is not properly responding at keycloak.${DOMAIN} (status: ${KC_STATUS})"
  ERROR_COUNT=$((ERROR_COUNT+1))
fi

# Check Keycloak realm
if [[ "${CHECK_REALM}" == "true" ]]; then
  log_info "Checking Keycloak realm '${CLIENT_ID}'..."
  
  # Check realm availability
  REALM_URL="https://keycloak.${DOMAIN}/realms/${CLIENT_ID}/.well-known/openid-configuration"
  REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "${REALM_URL}" 2>/dev/null || echo "failed")
  
  if [[ "${REALM_STATUS}" == "failed" ]]; then
    log_error "Connection to Keycloak realm endpoint failed - check configuration"
    ERROR_COUNT=$((ERROR_COUNT+1))
  elif [[ "${REALM_STATUS}" -eq 200 ]]; then
    log_success "Keycloak realm '${CLIENT_ID}' is properly configured"
    
    # Get and display realm details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
      REALM_INFO=$(curl -s "${REALM_URL}" 2>/dev/null || echo "{}")
      log_info "Realm configuration summary:"
      
      # Extract important values from the configuration
      ISSUER=$(echo "${REALM_INFO}" | grep -o '"issuer":"[^"]*"' | cut -d'"' -f4 || echo "Not found")
      AUTH_ENDPOINT=$(echo "${REALM_INFO}" | grep -o '"authorization_endpoint":"[^"]*"' | cut -d'"' -f4 || echo "Not found")
      TOKEN_ENDPOINT=$(echo "${REALM_INFO}" | grep -o '"token_endpoint":"[^"]*"' | cut -d'"' -f4 || echo "Not found")
      JWKS_URI=$(echo "${REALM_INFO}" | grep -o '"jwks_uri":"[^"]*"' | cut -d'"' -f4 || echo "Not found")
      
      log_info "  Issuer: ${ISSUER}"
      log_info "  Auth Endpoint: ${AUTH_ENDPOINT}"
      log_info "  Token Endpoint: ${TOKEN_ENDPOINT}"
      log_info "  JWKS URI: ${JWKS_URI}"
      
      # Check if any essential endpoints are missing
      if [[ "${ISSUER}" == "Not found" || "${AUTH_ENDPOINT}" == "Not found" || 
            "${TOKEN_ENDPOINT}" == "Not found" || "${JWKS_URI}" == "Not found" ]]; then
        log_warning "One or more essential OpenID Connect endpoints are missing"
        ERROR_COUNT=$((ERROR_COUNT+1))
      fi
    fi
    
    # Check token endpoint specifically
    if [[ -n "${TOKEN_ENDPOINT:-}" ]]; then
      TOKEN_URL="${TOKEN_ENDPOINT}"
    else
      TOKEN_URL="https://keycloak.${DOMAIN}/realms/${CLIENT_ID}/protocol/openid-connect/token"
    fi
    
    log_info "Testing OpenID Connect token endpoint..."
    TOKEN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "${TOKEN_URL}" 2>/dev/null || echo "failed")
    
    if [[ "${TOKEN_STATUS}" == "failed" ]]; then
      log_error "Connection to token endpoint failed - check service configuration"
      ERROR_COUNT=$((ERROR_COUNT+1))
    elif [[ "${TOKEN_STATUS}" -eq 200 || "${TOKEN_STATUS}" -eq 400 || "${TOKEN_STATUS}" -eq 401 ]]; then
      # 400/401 are expected for unauthorized token requests
      log_success "OpenID Connect token endpoint is properly configured (status: ${TOKEN_STATUS})"
    else
      log_warning "OpenID Connect token endpoint may not be properly configured (status: ${TOKEN_STATUS})"
      ERROR_COUNT=$((ERROR_COUNT+1))
    fi
  else
    log_warning "Keycloak realm '${CLIENT_ID}' is not properly configured (status: ${REALM_STATUS})"
    ERROR_COUNT=$((ERROR_COUNT+1))
  fi
fi

# Check dashboard SSO integration
log_info "Checking dashboard SSO integration..."
DASHBOARD_URL="https://${DOMAIN}/dashboard/"
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "${DASHBOARD_URL}" 2>/dev/null || echo "failed")

if [[ "${DASHBOARD_STATUS}" == "failed" ]]; then
  log_error "Connection to dashboard failed - check service configuration"
  ERROR_COUNT=$((ERROR_COUNT+1))
elif [[ "${DASHBOARD_STATUS}" -eq 200 || "${DASHBOARD_STATUS}" -eq 302 ]]; then
  log_success "Dashboard is available and should be SSO-enabled (status: ${DASHBOARD_STATUS})"
  
  # Check for SSO redirection
  REDIRECT_URL=$(curl -s -I "${DASHBOARD_URL}" 2>/dev/null | grep -i "Location:" | head -1 | cut -d' ' -f2- | tr -d '\r' || echo "")
  if [[ "${REDIRECT_URL}" == *"keycloak"* || "${REDIRECT_URL}" == *"auth/realms"* ]]; then
    log_success "Dashboard correctly redirects to Keycloak SSO login"
  else
    log_warning "Dashboard does not appear to redirect to Keycloak SSO (redirect: ${REDIRECT_URL:-none})"
    ERROR_COUNT=$((ERROR_COUNT+1))
  fi
else
  log_warning "Dashboard may not be properly configured (status: ${DASHBOARD_STATUS})"
  ERROR_COUNT=$((ERROR_COUNT+1))
fi

# Check registry for SSO-enabled services
REGISTRY_FILE="${ROOT_DIR}/component_registry.json"
if [[ ! -f "${REGISTRY_FILE}" ]]; then
  log_error "Component registry file not found: ${REGISTRY_FILE}"
  ERROR_COUNT=$((ERROR_COUNT+1))
  exit 1
fi

log_info "Checking SSO integration for services in registry..."
SSO_SERVICES=$(grep -B 5 '"sso_configured": true' "${REGISTRY_FILE}" | grep -o '"name": "[^"]*"' | cut -d '"' -f 4)

if [[ -z "${SSO_SERVICES}" ]]; then
  log_warning "No SSO-configured services found in component registry"
  ERROR_COUNT=$((ERROR_COUNT+1))
else
  log_success "Found the following SSO-configured services:"
  SERVICE_COUNT=0
  AVAILABLE_COUNT=0
  
  for service in ${SSO_SERVICES}; do
    SERVICE_COUNT=$((SERVICE_COUNT+1))
    log_info "- ${service}"
    
    # Get service URL if available
    SERVICE_URL=$(grep -A 10 "\"name\": \"${service}\"" "${REGISTRY_FILE}" | grep -o '"url": "[^"]*"' | head -1 | cut -d '"' -f 4)
    if [[ -n "${SERVICE_URL}" ]]; then
      SERVICE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m ${TIMEOUT} "${SERVICE_URL}" 2>/dev/null || echo "failed")
      if [[ "${SERVICE_STATUS}" == "failed" ]]; then
        log_warning "  Connection to service failed at ${SERVICE_URL}"
      elif [[ "${SERVICE_STATUS}" -eq 200 || "${SERVICE_STATUS}" -eq 302 ]]; then
        log_success "  Service is available at ${SERVICE_URL} (status: ${SERVICE_STATUS})"
        AVAILABLE_COUNT=$((AVAILABLE_COUNT+1))
        
        # Check for SSO redirection if verbose
        if [[ "${VERBOSE}" == "true" ]]; then
          REDIRECT_URL=$(curl -s -I "${SERVICE_URL}" 2>/dev/null | grep -i "Location:" | head -1 | cut -d' ' -f2- | tr -d '\r' || echo "")
          if [[ "${REDIRECT_URL}" == *"keycloak"* || "${REDIRECT_URL}" == *"auth/realms"* ]]; then
            log_success "  Service correctly redirects to Keycloak SSO login"
          else
            log_info "  Service redirect: ${REDIRECT_URL:-none}"
          fi
        fi
      else
        log_warning "  Service may not be properly configured at ${SERVICE_URL} (status: ${SERVICE_STATUS})"
      fi
    else
      log_warning "  No URL found for service in registry"
    fi
  done
  
  log_info "${AVAILABLE_COUNT} of ${SERVICE_COUNT} SSO-enabled services are available"
fi

# Final check results
if [[ $ERROR_COUNT -eq 0 ]]; then
  log_success "All SSO integration checks passed successfully"
  exit 0
else
  log_error "SSO integration checks found ${ERROR_COUNT} issue(s)"
  exit 1
fi
