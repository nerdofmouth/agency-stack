#!/bin/bash
# update_keycloak_registry.sh - Update component registry with Keycloak OAuth capabilities
# https://stack.nerdofmouth.com
#
# This script updates the component registry with Keycloak OAuth capabilities and status.
# Following AgencyStack repository integrity policy, it ensures all changes are properly tracked.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-11

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${SCRIPT_DIR}/common.sh"

# Variables
COMPONENT_REGISTRY="${ROOT_DIR}/config/component_registry.json"
TEMP_FILE=$(mktemp)
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/registry_update.log"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/registry_update.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

# Check if component registry exists
if [ ! -f "$COMPONENT_REGISTRY" ]; then
  echo -e "${RED}Error: Component registry not found at $COMPONENT_REGISTRY${NC}"
  exit 1
fi

# Log function
log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" >> "$LOG_FILE"
  echo -e "$1"
}

# Function to update Keycloak in component registry
update_keycloak_registry() {
  log "INFO: Updating Keycloak in component registry"
  
  # Create timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Read current registry
  local registry=$(cat "$COMPONENT_REGISTRY")
  
  # Check if keycloak exists
  if echo "$registry" | jq -e '.components[] | select(.name == "keycloak")' > /dev/null; then
    log "INFO: Keycloak found in registry, updating..."
    
    # Update flags for Keycloak
    registry=$(echo "$registry" | jq --arg ts "$timestamp" '
      (.components[] | select(.name == "keycloak")).flags.oauth_providers = true |
      (.components[] | select(.name == "keycloak")).flags.oauth_dashboard = true |
      (.components[] | select(.name == "keycloak")).flags.oauth_health_check = true |
      (.components[] | select(.name == "keycloak")).flags.multi_tenant = true |
      (.components[] | select(.name == "keycloak")).flags.hardened = true |
      (.components[] | select(.name == "keycloak")).flags.monitoring = true |
      (.components[] | select(.name == "keycloak")).flags.sso = true |
      (.components[] | select(.name == "keycloak")).last_updated = $ts
    ')
    
    # Check for metadata section, create if doesn't exist
    if ! echo "$registry" | jq -e '(.components[] | select(.name == "keycloak")).metadata' > /dev/null; then
      registry=$(echo "$registry" | jq '
        (.components[] | select(.name == "keycloak")).metadata = {}
      ')
    fi
    
    # Update OAuth providers in metadata
    registry=$(echo "$registry" | jq '
      (.components[] | select(.name == "keycloak")).metadata.oauth_providers = {
        "google": {
          "enabled": true,
          "supported": true,
          "scopes": "openid profile email"
        },
        "github": {
          "enabled": true,
          "supported": true,
          "scopes": "user:email"
        },
        "apple": {
          "enabled": true,
          "supported": true,
          "scopes": "name email"
        },
        "linkedin": {
          "enabled": true, 
          "supported": true,
          "scopes": "r_liteprofile r_emailaddress"
        },
        "microsoft": {
          "enabled": true,
          "supported": true,
          "scopes": "openid profile email"
        }
      }
    ')
  else
    log "INFO: Keycloak not found in registry, adding..."
    
    # Create Keycloak component
    local keycloak_component=$(cat <<EOF
{
  "name": "keycloak",
  "category": "security_identity",
  "description": "Open Source Identity and Access Management",
  "version": "latest",
  "flags": {
    "installed": true,
    "makefile": true,
    "docs": true,
    "hardened": true,
    "monitoring": true,
    "multi_tenant": true,
    "sso": true,
    "oauth_providers": true,
    "oauth_dashboard": true,
    "oauth_health_check": true
  },
  "metadata": {
    "oauth_providers": {
      "google": {
        "enabled": true,
        "supported": true,
        "scopes": "openid profile email"
      },
      "github": {
        "enabled": true,
        "supported": true,
        "scopes": "user:email"
      },
      "apple": {
        "enabled": true,
        "supported": true,
        "scopes": "name email"
      },
      "linkedin": {
        "enabled": true, 
        "supported": true,
        "scopes": "r_liteprofile r_emailaddress"
      },
      "microsoft": {
        "enabled": true,
        "supported": true,
        "scopes": "openid profile email"
      }
    }
  },
  "last_updated": "$timestamp"
}
EOF
)
    
    # Add to registry
    registry=$(echo "$registry" | jq --argjson component "$keycloak_component" '.components += [$component]')
  fi
  
  # Write updated registry back to file
  echo "$registry" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  
  log "INFO: Component registry updated successfully"
}

# Main function
main() {
  log "INFO: Starting component registry update for Keycloak OAuth"
  
  # Backup current registry
  local backup_dir="${ROOT_DIR}/config/registry/backups"
  mkdir -p "$backup_dir"
  cp "$COMPONENT_REGISTRY" "${backup_dir}/component_registry_$(date +%Y%m%d_%H%M%S).json"
  
  # Update Keycloak in registry
  update_keycloak_registry
  
  log "INFO: Completed component registry update for Keycloak OAuth"
}

# Run main function
main
