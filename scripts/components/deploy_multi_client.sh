#!/bin/bash
# Multi-Client AgencyStack Deployment Script
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Multi-Tenancy & Security
# - Idempotency & Automation

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Default configuration
BASE_DOMAIN="alpha.nerdofmouth.com"
ADMIN_EMAIL="admin@nerdofmouth.com"
LOG_DIR="/var/log/agency_stack"
CLIENT_DIR="/opt/agency_stack/clients"
ENABLE_KEYCLOAK="true"
ENABLE_CLOUD="true"
MULTI_TENANT="true"
FORCE="false"
DRY_RUN="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --base-domain)
      BASE_DOMAIN="$2"
      shift
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift
      ;;
    --force)
      FORCE="true"
      ;;
    --dry-run)
      DRY_RUN="true"
      ;;
    --disable-keycloak)
      ENABLE_KEYCLOAK="false"
      ;;
    --disable-cloud)
      ENABLE_CLOUD="false"
      ;;
    --disable-multi-tenant)
      MULTI_TENANT="false"
      ;;
    *)
      # Unknown option
      log_warning "Unknown option: $key"
      ;;
  esac
  shift
done

# Show configuration
log_info "==================================================="
log_info "Starting deploy_multi_client.sh"
log_info "BASE_DOMAIN: ${BASE_DOMAIN}"
log_info "ADMIN_EMAIL: ${ADMIN_EMAIL}"
log_info "ENABLE_KEYCLOAK: ${ENABLE_KEYCLOAK}"
log_info "ENABLE_CLOUD: ${ENABLE_CLOUD}"
log_info "MULTI_TENANT: ${MULTI_TENANT}"
log_info "DRY_RUN: ${DRY_RUN}"
log_info "==================================================="

# Set up component registry
ensure_directory "${LOG_DIR}/component_registry"
REGISTRY_FILE="${LOG_DIR}/component_registry/registry.json"

if [[ ! -f "${REGISTRY_FILE}" ]]; then
  log_info "Initializing component registry..."
  echo '{"components": {}, "clients": {}, "last_updated": ""}' > "${REGISTRY_FILE}"
fi

# Function to update component registry
update_registry() {
  local component="$1"
  local version="$2"
  local status="$3"
  local client_id="$4"
  
  if [[ -n "${client_id}" ]]; then
    log_info "Updating registry for ${component} (${version}) for client ${client_id}..."
    "${SCRIPT_DIR}/../utils/update_component_registry.sh" \
      --component "${component}" \
      --version "${version}" \
      --status "${status}" \
      --client "${client_id}"
  else
    log_info "Updating registry for ${component} (${version})..."
    "${SCRIPT_DIR}/../utils/update_component_registry.sh" \
      --component "${component}" \
      --version "${version}" \
      --status "${status}"
  fi
}

# Step 1: Deploy Traefik
deploy_traefik() {
  log_info "Deploying Traefik..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would deploy Traefik"
    return 0
  fi
  
  # Deploy Traefik with TLS and proper configuration
  TRAEFIK_DOMAIN="traefik.${BASE_DOMAIN}"
  
  make -C "${SCRIPT_DIR}/../../" traefik \
    DOMAIN="${TRAEFIK_DOMAIN}" \
    ADMIN_EMAIL="${ADMIN_EMAIL}" \
    $(if [[ "${FORCE}" == "true" ]]; then echo "FORCE=true"; fi)
  
  update_registry "traefik" "2.10" "active" ""
  
  log_success "Traefik deployment complete"
}

# Step 2: Deploy Keycloak
deploy_keycloak() {
  if [[ "${ENABLE_KEYCLOAK}" != "true" ]]; then
    log_info "Skipping Keycloak deployment (--disable-keycloak specified)"
    return 0
  fi
  
  log_info "Deploying Keycloak..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would deploy Keycloak"
    return 0
  fi
  
  # Deploy Keycloak with proper configuration
  KEYCLOAK_DOMAIN="auth.${BASE_DOMAIN}"
  
  make -C "${SCRIPT_DIR}/../../" keycloak \
    DOMAIN="${KEYCLOAK_DOMAIN}" \
    ADMIN_EMAIL="${ADMIN_EMAIL}" \
    $(if [[ "${FORCE}" == "true" ]]; then echo "FORCE=true"; fi)
  
  update_registry "keycloak" "22.0.1" "active" ""
  
  log_success "Keycloak deployment complete"
}

# Step 3: Deploy Portainer
deploy_portainer() {
  log_info "Deploying Portainer..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would deploy Portainer"
    return 0
  fi
  
  # Deploy Portainer with proper configuration
  PORTAINER_DOMAIN="manage.${BASE_DOMAIN}"
  
  make -C "${SCRIPT_DIR}/../../" portainer \
    DOMAIN="${PORTAINER_DOMAIN}" \
    ADMIN_EMAIL="${ADMIN_EMAIL}" \
    $(if [[ "${FORCE}" == "true" ]]; then echo "FORCE=true"; fi)
  
  update_registry "portainer" "2.19.0" "active" ""
  
  log_success "Portainer deployment complete"
}

# Step 4: Deploy PeaceFestival USA WordPress
deploy_peacefestivalusa() {
  log_info "Deploying PeaceFestival USA WordPress..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would deploy PeaceFestival USA WordPress"
    return 0
  fi
  
  # Set client-specific configuration
  CLIENT_ID="peacefestivalusa"
  DOMAIN="${CLIENT_ID}.${BASE_DOMAIN}"
  
  # Create /opt directories if they don't exist
  ensure_directory "${CLIENT_DIR}/${CLIENT_ID}"
  
  # Copy production environment file if it doesn't exist
  if [[ ! -f "${CLIENT_DIR}/${CLIENT_ID}/.env" ]]; then
    if [[ -f "${SCRIPT_DIR}/../../clients/${CLIENT_ID}/.env.production" ]]; then
      log_info "Copying production environment configuration..."
      cp "${SCRIPT_DIR}/../../clients/${CLIENT_ID}/.env.production" "${CLIENT_DIR}/${CLIENT_ID}/.env"
    else
      log_warning "Production environment file not found, using default template"
      cp "${SCRIPT_DIR}/../../clients/${CLIENT_ID}/.env.example" "${CLIENT_DIR}/${CLIENT_ID}/.env"
      
      # Update domain in .env file
      sed -i "s/DOMAIN=.*/DOMAIN=${DOMAIN}/" "${CLIENT_DIR}/${CLIENT_ID}/.env"
    fi
  fi
  
  # Copy docker-compose.yml if it doesn't exist
  if [[ ! -f "${CLIENT_DIR}/${CLIENT_ID}/docker-compose.yml" ]]; then
    log_info "Copying docker-compose configuration..."
    cp "${SCRIPT_DIR}/../../clients/${CLIENT_ID}/docker-compose.yml" "${CLIENT_DIR}/${CLIENT_ID}/docker-compose.yml"
  fi
  
  # Deploy WordPress with client-specific flags
  make -C "${SCRIPT_DIR}/../../" peacefestivalusa-wordpress \
    DOMAIN="${DOMAIN}" \
    ADMIN_EMAIL="admin@${CLIENT_ID}.com" \
    $(if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then echo "--enable-keycloak"; fi) \
    $(if [[ "${ENABLE_CLOUD}" == "true" ]]; then echo "--enable-cloud"; fi) \
    $(if [[ "${MULTI_TENANT}" == "true" ]]; then echo "--multi-tenant"; fi) \
    $(if [[ "${FORCE}" == "true" ]]; then echo "FORCE=true"; fi)
  
  update_registry "wordpress" "6.4" "active" "${CLIENT_ID}"
  
  log_success "PeaceFestival USA WordPress deployment complete"
}

# Step 5: Run post-deployment tests
run_tests() {
  log_info "Running post-deployment tests..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would run post-deployment tests"
    return 0
  fi
  
  # Test PeaceFestival USA WordPress
  log_info "Testing PeaceFestival USA WordPress deployment..."
  PEACEFESTIVAL_DOMAIN="peacefestivalusa.${BASE_DOMAIN}"
  
  # Use Puppeteer for testing (via MCP)
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
      "task": "validation",
      "client_id": "peacefestivalusa",
      "component": "wordpress",
      "validation_type": "deployment",
      "validation_url": "https://'${PEACEFESTIVAL_DOMAIN}'"
    }' \
    http://localhost:3000/puppeteer > "${LOG_DIR}/clients/peacefestivalusa/validation.log"
  
  log_success "Post-deployment tests complete"
}

# Step 6: Generate deployment summary
generate_summary() {
  log_info "Generating deployment summary..."
  
  # Create summary file
  SUMMARY_FILE="${LOG_DIR}/multi_client_deployment_$(date +%Y%m%d%H%M%S).log"
  ensure_directory "$(dirname "${SUMMARY_FILE}")"
  
  cat > "${SUMMARY_FILE}" << EOL
# AgencyStack Multi-Client Deployment Summary
Date: $(date)
Base Domain: ${BASE_DOMAIN}
Admin Email: ${ADMIN_EMAIL}

## Deployed Components

| Component | Version | Status | Domain |
|-----------|---------|--------|--------|
| Traefik | 2.10 | Active | traefik.${BASE_DOMAIN} |
$(if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then echo "| Keycloak | 22.0.1 | Active | auth.${BASE_DOMAIN} |"; fi)
| Portainer | 2.19.0 | Active | manage.${BASE_DOMAIN} |

## Deployed Clients

| Client | Components | Domain |
|--------|------------|--------|
| peacefestivalusa | WordPress 6.4, MariaDB 10.11 | peacefestivalusa.${BASE_DOMAIN} |

## Deployment Flags

- Keycloak SSO: $(if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)
- Cloud Storage: $(if [[ "${ENABLE_CLOUD}" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)
- Multi-Tenant Mode: $(if [[ "${MULTI_TENANT}" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)

## Next Steps

1. Verify all deployed services are accessible
2. Configure DNS records for all domains
3. Set up regular backups
4. Configure monitoring and alerting

Generated by AgencyStack Deployment System
Following AgencyStack Charter v1.0.3 principles
EOL
  
  log_success "Deployment summary generated at ${SUMMARY_FILE}"
  
  # Output summary path
  echo ""
  echo "Deployment Summary: ${SUMMARY_FILE}"
  echo ""
}

# Main execution sequence
if [[ "${DRY_RUN}" == "true" ]]; then
  log_info "Running in DRY RUN mode - no changes will be made"
fi

# Step 1: Infrastructure components
deploy_traefik
if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
  deploy_keycloak
fi
deploy_portainer

# Step 2: Client-specific components
deploy_peacefestivalusa

# Step 3: Post-deployment
run_tests
generate_summary

log_success "Multi-client AgencyStack deployment completed successfully"
exit 0
