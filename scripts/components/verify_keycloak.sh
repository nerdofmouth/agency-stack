#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: verify_keycloak.sh
# Path: /scripts/components/verify_keycloak.sh
#

# Enforce containerization (prevent host contamination)

# verify_keycloak.sh - Simple validation for Keycloak status and OAuth configuration
# Following the AgencyStack repository integrity policy

set -e

# Hardcoded logging functions

# Default settings
DOMAIN=""
CLIENT_ID="default"
VERBOSE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain=*)
      DOMAIN="${1#*=}"
      shift
      ;;
    --domain)
      if [[ "$2" != "" ]]; then
        DOMAIN="$2"
        shift 2
      else
        log_error "Missing value for --domain option"
        exit 1
      fi
      ;;
    --client-id=*)
      CLIENT_ID="${1#*=}"
      shift
      ;;
    --client-id)
      if [[ "$2" != "" ]]; then
        CLIENT_ID="$2"
        shift 2
      else
        log_error "Missing value for --client-id option"
        exit 1
      fi
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --domain DOMAIN         Domain name for Keycloak instance"
      echo "  --client-id CLIENT_ID   Client ID (default: default)"
      echo "  --verbose               Show verbose output"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if domain is provided
if [[ -z "$DOMAIN" ]]; then
  log_error "No domain specified. Use --domain option."
  exit 1

log_info "==================================================="
log_info "Starting verify_keycloak.sh"
log_info "CLIENT_ID: $CLIENT_ID"
log_info "DOMAIN: $DOMAIN"
log_info "==================================================="

# Verify Keycloak container is running
log_info "Checking Keycloak container status..."
if docker ps | grep -q "keycloak_${DOMAIN}"; then
  log_success "Keycloak container is running"
  log_error "Keycloak container is not running"
  exit 1

# Verify Keycloak is responsive
log_info "Checking Keycloak admin console accessibility..."
if curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/auth/" | grep -q "200\|301\|302"; then
  log_success "Keycloak admin console is accessible"
  log_error "Keycloak admin console is not accessible"
  # Not failing here as it might be a proxy issue

# Check component registry
log_info "Checking component registry..."
if [ -f "/opt/agency_stack/config/component_registry.json" ]; then
  if grep -q "oauth_providers" "/opt/agency_stack/config/component_registry.json"; then
    log_success "Keycloak OAuth providers registered in component registry"
    
    # Count OAuth providers
    PROVIDER_COUNT=$(grep -o "enabled.*true" "/opt/agency_stack/config/component_registry.json" | wc -l)
    log_info "Found ${PROVIDER_COUNT} enabled OAuth providers in registry"
  else
    log_error "Keycloak OAuth providers not found in component registry"
  fi
  log_error "Component registry not found"

# Display docker logs for troubleshooting
if [ "$VERBOSE" = true ]; then
  log_info "Recent Keycloak container logs:"
  docker logs --tail 20 "keycloak_${DOMAIN}"

log_success "Verification completed"
