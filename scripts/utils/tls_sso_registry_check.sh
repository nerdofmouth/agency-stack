#!/bin/bash
# tls_sso_registry_check.sh - Validate component registry entries for TLS/SSO configuration
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
LOG_FILE="${COMPONENTS_LOG_DIR}/tls_sso_registry_check.log"

# Default options
VERBOSE="${VERBOSE:-false}"
REGISTRY_FILE="${ROOT_DIR}/component_registry.json"
FIX_ISSUES="${FIX_ISSUES:-false}"
ERROR_COUNT=0

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Validate component registry entries for TLS/SSO configuration"
  echo ""
  echo "Options:"
  echo "  --verbose             Enable verbose output"
  echo "  --fix-issues          Update registry entries with correct values (use with caution)"
  echo "  --registry FILE       Path to registry file (default: component_registry.json)"
  echo "  --help                Display this help message"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --fix-issues)
      FIX_ISSUES=true
      shift
      ;;
    --registry)
      REGISTRY_FILE="$2"
      shift 2
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

# Verify registry file exists
if [[ ! -f "${REGISTRY_FILE}" ]]; then
  log_error "Component registry file not found: ${REGISTRY_FILE}"
  exit 1
fi

log_info "Validating component registry entries for TLS/SSO configuration"
log_info "Using registry file: ${REGISTRY_FILE}"

# Identify all components with URLs
COMPONENTS_WITH_URLS=$(grep -o '"name": "[^"]*"' "${REGISTRY_FILE}" | cut -d '"' -f 4)
HTTPS_COUNT=0
HTTP_COUNT=0
SSO_COUNT=0
MISSING_SSO_COUNT=0
MISSING_TLS_COUNT=0

# Function to check and fix registry component
check_component() {
  local component="$1"
  local issues=0
  
  # Get component details
  local url=$(grep -A 10 "\"name\": \"${component}\"" "${REGISTRY_FILE}" | grep -o '"url": "[^"]*"' | head -1 | cut -d '"' -f 4 || echo "")
  local sso_flag=$(grep -A 10 "\"name\": \"${component}\"" "${REGISTRY_FILE}" | grep -o '"sso_configured": [^,}]*' | head -1 | cut -d ':' -f 2 | tr -d ' ' || echo "")
  local tls_flag=$(grep -A 10 "\"name\": \"${component}\"" "${REGISTRY_FILE}" | grep -o '"tls_enabled": [^,}]*' | head -1 | cut -d ':' -f 2 | tr -d ' ' || echo "")
  
  if [[ -z "${url}" ]]; then
    if [[ "${VERBOSE}" == "true" ]]; then
      log_info "Component ${component} has no URL defined"
    fi
    return 0
  fi
  
  # Check if URL uses HTTPS
  if [[ "${url}" == https://* ]]; then
    HTTPS_COUNT=$((HTTPS_COUNT + 1))
    
    # Check if tls_enabled flag is set correctly
    if [[ "${tls_flag}" != "true" ]]; then
      log_warning "Component ${component} uses HTTPS but tls_enabled flag is not set to true"
      MISSING_TLS_COUNT=$((MISSING_TLS_COUNT + 1))
      issues=$((issues + 1))
      
      # Fix if requested
      if [[ "${FIX_ISSUES}" == "true" ]]; then
        if grep -q "\"tls_enabled\":" "${REGISTRY_FILE}"; then
          # Update existing flag
          sed -i "s/\"tls_enabled\": [^,}]*/\"tls_enabled\": true/g" "${REGISTRY_FILE}"
          log_success "Updated tls_enabled flag for ${component}"
        else
          # No existing flag, would need more complex JSON manipulation
          log_warning "Could not add tls_enabled flag for ${component} - manual update required"
        fi
      fi
    fi
    
    # Check known SSO-capable components
    if [[ "${component}" == "keycloak" || "${component}" == "dashboard" || "${component}" == "wordpress" || 
          "${component}" == "peertube" || "${component}" == "gitea" || "${component}" == "chatwoot" ||
          "${component}" == "nextcloud" || "${component}" == "erpnext" || "${component}" == "cal" ]]; then
          
      # Check if sso_configured flag exists and is correct
      if [[ "${sso_flag}" == "true" ]]; then
        SSO_COUNT=$((SSO_COUNT + 1))
        if [[ "${VERBOSE}" == "true" ]]; then
          log_info "Component ${component} has SSO correctly configured in registry"
        fi
      else
        log_warning "SSO-capable component ${component} does not have sso_configured flag set to true"
        MISSING_SSO_COUNT=$((MISSING_SSO_COUNT + 1))
        issues=$((issues + 1))
        
        # Fix if requested
        if [[ "${FIX_ISSUES}" == "true" ]]; then
          if grep -q "\"sso_configured\":" "${REGISTRY_FILE}"; then
            # Update existing flag
            sed -i "s/\"sso_configured\": [^,}]*/\"sso_configured\": true/g" "${REGISTRY_FILE}"
            log_success "Updated sso_configured flag for ${component}"
          else
            # No existing flag, would need more complex JSON manipulation
            log_warning "Could not add sso_configured flag for ${component} - manual update required"
          fi
        fi
      fi
    fi
  else
    # Using HTTP
    HTTP_COUNT=$((HTTP_COUNT + 1))
    
    # Check if component should be using HTTPS (all components should in production)
    log_warning "Component ${component} uses HTTP instead of HTTPS: ${url}"
    issues=$((issues + 1))
  fi
  
  return $issues
}

# Process each component
TOTAL_ISSUES=0
for component in ${COMPONENTS_WITH_URLS}; do
  if [[ "${VERBOSE}" == "true" ]]; then
    log_info "Checking component: ${component}"
  fi
  
  check_component "${component}"
  COMP_ISSUES=$?
  TOTAL_ISSUES=$((TOTAL_ISSUES + COMP_ISSUES))
  
  if [[ $COMP_ISSUES -gt 0 ]]; then
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

# Output summary
log_info "TLS/SSO Registry validation summary:"
log_info "  Components with HTTPS URLs: ${HTTPS_COUNT}"
log_info "  Components with HTTP URLs: ${HTTP_COUNT}"
log_info "  Components with SSO configured: ${SSO_COUNT}"
log_info "  Components missing TLS flags: ${MISSING_TLS_COUNT}"
log_info "  Components missing SSO flags: ${MISSING_SSO_COUNT}"

if [[ $TOTAL_ISSUES -eq 0 ]]; then
  log_success "All registry entries are correctly configured for TLS/SSO"
  exit 0
else
  log_error "Found ${TOTAL_ISSUES} issues in ${ERROR_COUNT} components"
  if [[ "${FIX_ISSUES}" != "true" ]]; then
    log_info "Run with --fix-issues to automatically correct registry entries"
  fi
  exit 1
fi
