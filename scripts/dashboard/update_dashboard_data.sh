#!/bin/bash
# update_dashboard_data.sh - Generates dashboard data for AgencyStack
# https://stack.nerdofmouth.com
#
# This script collects service status and integration data into a single JSON file
# for the AgencyStack dashboard to display. It is designed to be run:
# - On demand via the dashboard UI
# - Automatically by cron
# - Manually via 'make dashboard-update'
#
# The output file is 'dashboard/services.json' which contains:
# - Service status (running/stopped)
# - Integration status (sso, email, monitoring, data-bridge)
# - Port assignments and conflict information
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
CONFIG_ENV="/opt/agency_stack/config.env"
DASHBOARD_DIR="/opt/agency_stack/dashboard"
SERVICE_STATUS_FILE="${DASHBOARD_DIR}/service_status.json"
DASHBOARD_DATA_FILE="${DASHBOARD_DIR}/dashboard_data.json"
INTEGRATION_STATE_DIR="/opt/agency_stack/integrations/state"
PORTS_FILE="/opt/agency_stack/ports/ports.json"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/dashboard_update-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
sudo mkdir -p "$DASHBOARD_DIR"

# Non-interactive mode flag
QUIET=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --quiet)
      QUIET=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  if [ "$QUIET" = false ]; then
    echo -e "$1"
  fi
  echo -e "$1" >> "$LOG_FILE"
}

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  log "${YELLOW}Warning: config.env not found, using default values${NC}"
  PRIMARY_DOMAIN="example.com"
fi

# Ensure service status exists
ensure_service_status() {
  log "${BLUE}Checking service status file...${NC}"
  
  if [ ! -f "$SERVICE_STATUS_FILE" ]; then
    log "${YELLOW}Service status file not found, generating...${NC}"
    # Use the service status generator if available
    if [ -f "/home/revelationx/CascadeProjects/foss-server-stack/scripts/generate_service_status.sh" ]; then
      bash "/home/revelationx/CascadeProjects/foss-server-stack/scripts/generate_service_status.sh"
    else
      log "${RED}Service status generator not found${NC}"
      # Create a basic empty service status file
      echo '{
  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "server": "'$(hostname)'",
  "domain": "'$PRIMARY_DOMAIN'",
  "services": []
}' | sudo tee "$SERVICE_STATUS_FILE" > /dev/null
    fi
  fi
}

# Get integration status
get_integration_status() {
  log "${BLUE}Collecting integration status...${NC}"
  
  # Create integration status structure
  local integration_status='{
    "sso": {
      "applied": false,
      "components": [],
      "last_updated": null
    },
    "email": {
      "applied": false,
      "components": [],
      "last_updated": null
    },
    "monitoring": {
      "applied": false,
      "components": [],
      "last_updated": null
    },
    "data-bridge": {
      "applied": false,
      "components": [],
      "last_updated": null
    }
  }'
  
  # Check each integration type
  for integration_type in sso email monitoring data-bridge; do
    local state_file="${INTEGRATION_STATE_DIR}/${integration_type}.state"
    
    if [ -f "$state_file" ]; then
      # Integration exists, parse the components
      local components="["
      local first=true
      local last_updated=""
      
      while IFS=: read -r component version timestamp details; do
        if [ "$first" = true ]; then
          first=false
        else
          components="$components,"
        fi
        
        components="$components{\"name\":\"$component\",\"version\":\"$version\",\"details\":\"$details\"}"
        
        # Keep track of the latest timestamp
        if [ -z "$last_updated" ] || [ "$timestamp" \> "$last_updated" ]; then
          last_updated="$timestamp"
        fi
      done < "$state_file"
      
      components="$components]"
      
      # Update the integration status
      integration_status=$(echo "$integration_status" | jq --arg type "$integration_type" \
                                                       --argjson components "$components" \
                                                       --arg timestamp "$last_updated" \
                                                       '.[$type].applied = true |
                                                         .[$type].components = $components |
                                                         .[$type].last_updated = $timestamp')
    fi
  done
  
  echo "$integration_status"
}

# Get port assignments
get_port_assignments() {
  log "${BLUE}Collecting port assignments...${NC}"
  
  if [ -f "$PORTS_FILE" ]; then
    # Read port conflicts from the ports file
    local ports_json=$(cat "$PORTS_FILE")
    
    # Check for potential conflicts
    local system_ports=$(ss -tuln | grep -o ':[0-9]*' | sed 's/://' | sort -n | uniq)
    local conflict_ports="[]"
    
    # Build a list of conflicts
    for port in $(echo "$ports_json" | jq -r '.ports_in_use | keys[]'); do
      if echo "$system_ports" | grep -q "^$port$"; then
        # This is a conflict with a system port
        local service=$(echo "$ports_json" | jq -r ".ports_in_use[\"$port\"].service")
        conflict_ports=$(echo "$conflict_ports" | jq --arg port "$port" --arg service "$service" '. += [{"port": $port, "service": $service, "type": "system"}]')
      else
        # Check for duplicate Docker mappings
        local count=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -o "0.0.0.0:$port" | wc -l)
        if [ "$count" -gt 1 ]; then
          local service=$(echo "$ports_json" | jq -r ".ports_in_use[\"$port\"].service")
          conflict_ports=$(echo "$conflict_ports" | jq --arg port "$port" --arg service "$service" '. += [{"port": $port, "service": $service, "type": "duplicate"}]')
        fi
      fi
    done
    
    # Return the ports json and conflicts
    echo "{\"ports\": $ports_json, \"conflicts\": $conflict_ports}"
  else
    # Return empty structure
    echo "{\"ports\": {\"updated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"ports_in_use\": {}}, \"conflicts\": []}"
  fi
}

# Generate dashboard data
generate_dashboard_data() {
  log "${BLUE}Generating dashboard data...${NC}"
  
  # Ensure service status file exists
  ensure_service_status
  
  # Get service status
  local service_status=$(cat "$SERVICE_STATUS_FILE")
  
  # Get integration status
  local integration_status=$(get_integration_status)
  
  # Get port assignments
  local port_assignments=$(get_port_assignments)
  
  # Combine everything into dashboard data
  local dashboard_data=$(echo "$service_status" | jq --argjson integration "$integration_status" \
                                                  --argjson ports "$port_assignments" \
                                                  '. += {"integration": $integration, "ports": $ports}')
  
  # Write dashboard data to file
  echo "$dashboard_data" | sudo tee "$DASHBOARD_DATA_FILE" > /dev/null
  
  # Also write to the scripts/dashboard directory for development
  if [ -d "/home/revelationx/CascadeProjects/foss-server-stack/scripts/dashboard" ]; then
    echo "$dashboard_data" > "/home/revelationx/CascadeProjects/foss-server-stack/scripts/dashboard/dashboard_data.json"
  fi
  
  log "${GREEN}Dashboard data generated at ${DASHBOARD_DATA_FILE}${NC}"
}

# Main function
main() {
  if [ "$QUIET" = false ]; then
    log "${MAGENTA}${BOLD}🔄 AgencyStack Dashboard Data Update${NC}"
    log "========================================================"
    log "$(date)"
    log "Server: $(hostname)"
    log ""
  fi
  
  # Generate dashboard data
  generate_dashboard_data
  
  if [ "$QUIET" = false ]; then
    log ""
    log "${GREEN}${BOLD}Dashboard data update complete!${NC}"
  fi
}

# Run main function
main
