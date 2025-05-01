#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: traefik_registry_ai_dashboard.sh
# Path: /scripts/components/traefik_registry_ai_dashboard.sh
#

# Enforce containerization (prevent host contamination)


# Setup Traefik configuration
setup_traefik() {
  log "INFO" "Setting up Traefik configuration..."
  
  # Check if Traefik is already set up
  TRAEFIK_ENABLED=$(grep -c "traefik.enable=true" "${DOCKER_DIR}/docker-compose.yml" || echo "0")
  
  if [ "$TRAEFIK_ENABLED" -eq "0" ]; then
    log "WARN" "Traefik labels not found in docker-compose.yml. Please ensure Traefik is properly configured."
  else
    log "INFO" "Traefik configuration is set up in docker-compose.yml"
  fi
  
  # Check if the domain is properly configured
  if [ -z "$DOMAIN" ]; then
    log "WARN" "Domain is not set. Please ensure you set the --domain flag."
  else
    log "INFO" "Domain is set to: $DOMAIN"
    log "INFO" "AI Dashboard will be accessible at: https://ai.$DOMAIN"
  fi
}

# Update component registry
update_component_registry() {
  log "INFO" "Updating component registry..."
  
  # Define the registry file path
  REGISTRY_FILE="${ROOT_DIR}/config/registry/component_registry.json"
  
  # Check if the registry file exists
  if [ ! -f "$REGISTRY_FILE" ]; then
    log "ERROR" "Component registry file not found at: $REGISTRY_FILE"
    return 1
  fi
  
  # Generate a temporary file with the updated registry
  TMP_FILE=$(mktemp)
  
  # Check if AI Dashboard is already in the registry
  if grep -q "\"name\": \"AI Dashboard\"" "$REGISTRY_FILE"; then
    log "INFO" "AI Dashboard already exists in the component registry. Updating..."
    
    # Using jq to update the existing entry
    cat "$REGISTRY_FILE" | jq '(.components[] | select(.name == "AI Dashboard")).port = '$PORT' | 
                             (.components[] | select(.name == "AI Dashboard")).hardened = true |
                             (.components[] | select(.name == "AI Dashboard")).multi_tenant = true |
                             (.components[] | select(.name == "AI Dashboard")).sso_ready = false |
                             (.components[] | select(.name == "AI Dashboard")).monitoring_enabled = true |
                             (.components[] | select(.name == "AI Dashboard")).description = "Dashboard for managing AI services including LangChain and Ollama, with features for testing prompts and configuring LLMs."' > "$TMP_FILE"
  else
    log "INFO" "Adding AI Dashboard to the component registry..."
    
    # Using jq to append a new component
    cat "$REGISTRY_FILE" | jq '.components += [{
      "name": "AI Dashboard",
      "category": "AI",
      "port": '$PORT',
      "hardened": true,
      "multi_tenant": true,
      "sso_ready": false,
      "monitoring_enabled": true,
      "description": "Dashboard for managing AI services including LangChain and Ollama, with features for testing prompts and configuring LLMs."
    }]' > "$TMP_FILE"
  fi
  
  # Update the registry file
  mv "$TMP_FILE" "$REGISTRY_FILE"
  
  log "SUCCESS" "Component registry updated successfully"
}
