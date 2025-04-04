#!/bin/bash
# port_conflict_detector.sh - Detect and resolve port conflicts in AgencyStack
# https://stack.nerdofmouth.com
#
# This utility helps manage port allocations across all AgencyStack components:
#  - Detects port conflicts between containers
#  - Identifies port collisions with system services
#  - Suggests available ports when conflicts are found
#  - Updates ports.json registry with new allocations
#  - Can automatically remap ports in container configurations
#
# Usage:
#   ./port_conflict_detector.sh            # Interactive mode, checks and asks for remapping
#   ./port_conflict_detector.sh --dry-run  # Only detects conflicts without making changes
#   ./port_conflict_detector.sh --fix      # Automatically fix conflicts without prompting
#   ./port_conflict_detector.sh --scan     # Only scan and update ports.json, no conflict resolution
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
PORTS_DIR="/opt/agency_stack/ports"
PORTS_FILE="${PORTS_DIR}/ports.json"
DECISIONS_LOG="${PORTS_DIR}/decisions.log"
ENV_FILE="/opt/agency_stack/.env"
RESERVED_PORTS_MIN=1024
RESERVED_PORTS_MAX=65535
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/port_detection-$(date +%Y%m%d-%H%M%S).log"

# Create necessary directories
mkdir -p "$LOG_DIR"
sudo mkdir -p "$PORTS_DIR"
sudo chmod 755 "$PORTS_DIR"

# Parse command line arguments
DRY_RUN=false
AUTO_FIX=false
SCAN_ONLY=false
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      ;;
    --fix)
      AUTO_FIX=true
      ;;
    --scan)
      SCAN_ONLY=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Create ports.json if it doesn't exist
create_empty_ports_json() {
  if [ ! -f "$PORTS_FILE" ]; then
    log "${YELLOW}Creating empty ports.json file...${NC}"
    sudo bash -c "cat > '$PORTS_FILE'" << EOF
{
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "ports_in_use": {}
}
EOF
    log "${GREEN}Created empty ports.json file${NC}"
  fi
}

# Create decisions.log if it doesn't exist
create_empty_decisions_log() {
  if [ ! -f "$DECISIONS_LOG" ]; then
    log "${YELLOW}Creating empty decisions.log file...${NC}"
    sudo bash -c "cat > '$DECISIONS_LOG'" << EOF
# AgencyStack Port Reassignment Decisions Log
# Date: $(date)
# Format: [YYYY-MM-DD HH:MM:SS] [SERVICE] [OLD_PORT→NEW_PORT] [REASON]
# 
# This file tracks port reassignment decisions made by the port_conflict_detector.sh script
# to help maintain an audit trail of port changes.
#
EOF
    log "${GREEN}Created empty decisions.log file${NC}"
  fi
}

# Log a port decision
log_port_decision() {
  local service="$1"
  local old_port="$2"
  local new_port="$3"
  local reason="$4"
  
  local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$service] [$old_port→$new_port] [$reason]" | sudo tee -a "$DECISIONS_LOG" > /dev/null
}

# Check if a port is in use by the operating system
is_port_in_use_by_system() {
  local port="$1"
  if command -v ss &> /dev/null; then
    ss -tuln | grep -q ":$port "
    return $?
  elif command -v netstat &> /dev/null; then
    netstat -tuln | grep -q ":$port "
    return $?
  fi
  # If neither command is available, assume not in use
  return 1
}

# Parse ports.json file
parse_ports_json() {
  log "${BLUE}Parsing ports.json...${NC}"
  
  # Ensure ports.json exists
  create_empty_ports_json
  
  # Parse the ports in use
  local ports_in_use=$(jq -r '.ports_in_use | keys[]' "$PORTS_FILE" 2>/dev/null || echo "")
  log "${BLUE}Found $(echo "$ports_in_use" | wc -w) ports registered in ports.json${NC}"
  
  # Return the ports as space-separated list
  echo "$ports_in_use"
}

# Scan Docker containers for port mappings
scan_docker_containers() {
  log "${BLUE}Scanning Docker containers for port mappings...${NC}"
  
  # Get list of Docker containers
  local containers=$(docker ps --format '{{.Names}}' 2>/dev/null || echo "")
  
  if [ -z "$containers" ]; then
    log "${YELLOW}No Docker containers found${NC}"
    return
  fi
  
  log "${BLUE}Found $(echo "$containers" | wc -w) running containers${NC}"
  
  # Initialize ports json structure
  echo "{" > "$PORTS_FILE.new"
  echo '  "updated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "ports_in_use": {' >> "$PORTS_FILE.new"

  local first_port=true
  
  # Loop through each container
  for container in $containers; do
    # Skip containers that don't belong to AgencyStack
    if [[ ! "$container" =~ agency_stack && ! "$container" =~ AgencyStack ]]; then
      continue
    fi
    
    # Get port mappings for this container
    local port_mappings=$(docker port "$container" 2>/dev/null | awk '{print $3}' | grep -o '[0-9]*' | sort -n | uniq)
    
    if [ -z "$port_mappings" ]; then
      log "${YELLOW}No port mappings found for container $container${NC}"
      continue
    fi
    
    # Get service name from container name
    local service=$(echo "$container" | sed 's/agency_stack_//' | sed 's/-/_/g')
    
    # Add each port to the ports.json file
    for port in $port_mappings; do
      if [ "$first_port" = true ]; then
        first_port=false
      else
        echo ',' >> "$PORTS_FILE.new"
      fi
      
      echo '    "'$port'": {
      "service": "'$service'",
      "container": "'$container'",
      "assigned_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }' >> "$PORTS_FILE.new"
      
      log "${GREEN}Found port $port mapped to service $service (container $container)${NC}"
    done
  done
  
  # Close the JSON structure
  echo '
  }
}' >> "$PORTS_FILE.new"

  # Replace the old ports.json with the new one
  sudo mv "$PORTS_FILE.new" "$PORTS_FILE"
  
  log "${GREEN}Updated ports.json with current container port mappings${NC}"
}

# Find the next available port in a range
find_next_available_port() {
  local start_port="$1"
  local end_port="$2"
  local registered_ports="$3"
  
  # Default port range if not specified
  start_port=${start_port:-8000}
  end_port=${end_port:-9000}
  
  log "${BLUE}Finding next available port in range $start_port-$end_port...${NC}"
  
  for port in $(seq "$start_port" "$end_port"); do
    # Check if port is already registered
    if echo "$registered_ports" | grep -w "$port" > /dev/null; then
      continue
    fi
    
    # Check if port is in use by system
    if is_port_in_use_by_system "$port"; then
      log "${YELLOW}Port $port is in use by the system${NC}"
      continue
    fi
    
    # Found an available port
    log "${GREEN}Found available port: $port${NC}"
    echo "$port"
    return 0
  done
  
  log "${RED}No available ports found in range $start_port-$end_port${NC}"
  return 1
}

# Detect port conflicts
detect_port_conflicts() {
  log "${BLUE}Detecting port conflicts...${NC}"
  
  # Parse existing ports.json
  local registered_ports=$(parse_ports_json)
  
  # Dictionary to track port usage
  declare -A port_usage
  
  # Add registered ports to dictionary
  for port in $registered_ports; do
    local service=$(jq -r ".ports_in_use[\"$port\"].service" "$PORTS_FILE" 2>/dev/null)
    port_usage["$port"]="$service"
  done
  
  # Check system ports
  local conflicts_found=false
  for port in $registered_ports; do
    # Skip checking system ports if they're above the reserved threshold
    if [ "$port" -gt "$RESERVED_PORTS_MIN" ]; then
      if is_port_in_use_by_system "$port"; then
        local service="${port_usage[$port]}"
        log "${RED}❌ CONFLICT: Port $port used by service $service is also in use by the system${NC}"
        conflicts_found=true
        
        # Suggest alternative port
        if [ "$AUTO_FIX" = true ] || [ "$DRY_RUN" = false ]; then
          local new_port=$(find_next_available_port 8000 9000 "$registered_ports")
          if [ -n "$new_port" ]; then
            log "${GREEN}✅ SOLUTION: Reassign service $service from port $port to port $new_port${NC}"
            
            if [ "$DRY_RUN" = false ] && [ "$AUTO_FIX" = true ]; then
              reassign_port "$service" "$port" "$new_port" "System conflict"
            elif [ "$DRY_RUN" = false ]; then
              log "${YELLOW}Would you like to apply this port reassignment? (y/n)${NC}"
              read -r apply_reassignment
              if [[ "$apply_reassignment" =~ ^[Yy]$ ]]; then
                reassign_port "$service" "$port" "$new_port" "System conflict"
              fi
            fi
          else
            log "${RED}❌ ERROR: Could not find an available port for reassignment${NC}"
          fi
        fi
      fi
    fi
  done
  
  # Check for duplicate Docker port mappings
  local docker_ports=$(docker ps --format '{{.Ports}}' | grep -o '0.0.0.0:[0-9]*' | sed 's/0.0.0.0://' | sort -n | uniq)
  
  for port in $docker_ports; do
    local count=$(docker ps --format '{{.Ports}}' | grep -o "0.0.0.0:$port" | wc -l)
    if [ "$count" -gt 1 ]; then
      log "${RED}❌ CONFLICT: Port $port is mapped to $count different containers${NC}"
      conflicts_found=true
      
      # Get container names using this port
      local containers=$(docker ps --format '{{.Names}}\t{{.Ports}}' | grep "0.0.0.0:$port" | cut -f1)
      log "${YELLOW}⚠️ Containers using port $port:${NC}"
      for container in $containers; do
        log "   - $container"
      done
      
      # If fixing conflicts, reassign all but the first container
      if [ "$AUTO_FIX" = true ] || [ "$DRY_RUN" = false ]; then
        # Get first container (we'll keep this one)
        local first_container=$(echo "$containers" | head -n1)
        log "${GREEN}✅ Keeping port $port for container $first_container${NC}"
        
        # Reassign the rest
        local remaining_containers=$(echo "$containers" | tail -n +2)
        for container in $remaining_containers; do
          # Get service name from container
          local service=$(echo "$container" | sed 's/agency_stack_//' | sed 's/-/_/g')
          
          # Find an available port
          local new_port=$(find_next_available_port 8000 9000 "$registered_ports")
          
          if [ -n "$new_port" ]; then
            log "${GREEN}✅ SOLUTION: Reassign service $service from port $port to port $new_port${NC}"
            
            if [ "$DRY_RUN" = false ] && [ "$AUTO_FIX" = true ]; then
              reassign_port "$service" "$port" "$new_port" "Container port collision"
            elif [ "$DRY_RUN" = false ]; then
              log "${YELLOW}Would you like to apply this port reassignment? (y/n)${NC}"
              read -r apply_reassignment
              if [[ "$apply_reassignment" =~ ^[Yy]$ ]]; then
                reassign_port "$service" "$port" "$new_port" "Container port collision"
              fi
            fi
          else
            log "${RED}❌ ERROR: Could not find an available port for reassignment${NC}"
          fi
        done
      fi
    fi
  done
  
  if [ "$conflicts_found" = false ]; then
    log "${GREEN}✅ No port conflicts detected${NC}"
  fi
  
  return 0
}

# Reassign a port
reassign_port() {
  local service="$1"
  local old_port="$2"
  local new_port="$3"
  local reason="$4"
  
  log "${BLUE}Reassigning $service from port $old_port to port $new_port${NC}"
  
  # Update ports.json
  local temp_file=$(mktemp)
  
  # Create new port entry and update old one
  jq --arg service "$service" \
     --arg old_port "$old_port" \
     --arg new_port "$new_port" \
     --arg container "agency_stack_$service" \
     --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '.ports_in_use[$new_port] = {
        "service": $service,
        "container": $container,
        "assigned_at": $timestamp,
        "reassigned_from": $old_port
      } | del(.ports_in_use[$old_port])' "$PORTS_FILE" > "$temp_file"
  
  # Update the ports.json file
  sudo mv "$temp_file" "$PORTS_FILE"
  
  # Log the decision
  log_port_decision "$service" "$old_port" "$new_port" "$reason"
  
  # Update relevant configuration files
  update_service_config "$service" "$old_port" "$new_port"
  
  log "${GREEN}✅ Service $service successfully reassigned from port $old_port to port $new_port${NC}"
}

# Update service configuration
update_service_config() {
  local service="$1"
  local old_port="$2"
  local new_port="$3"
  
  log "${BLUE}Updating configuration for service $service...${NC}"
  
  # Update .env file if it exists
  if [ -f "$ENV_FILE" ]; then
    # Convert service name to uppercase for environment variable
    local env_var="PORT_$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    
    # Check if variable exists in .env
    if grep -q "^$env_var=" "$ENV_FILE"; then
      # Update existing variable
      sudo sed -i "s/^$env_var=.*/$env_var=$new_port/" "$ENV_FILE"
      log "${GREEN}✅ Updated $env_var in .env file${NC}"
    else
      # Add new variable
      echo "$env_var=$new_port" | sudo tee -a "$ENV_FILE" > /dev/null
      log "${GREEN}✅ Added $env_var to .env file${NC}"
    fi
  else
    log "${YELLOW}⚠️ .env file not found, creating it${NC}"
    echo "PORT_$(echo "$service" | tr '[:lower:]' '[:upper:]' | tr '-' '_')=$new_port" | sudo tee "$ENV_FILE" > /dev/null
  fi
  
  # Check for service-specific docker-compose file
  local compose_file="/home/revelationx/CascadeProjects/foss-server-stack/docker-compose.$service.yml"
  if [ -f "$compose_file" ]; then
    log "${BLUE}Updating docker-compose file for $service...${NC}"
    
    # Create backup
    sudo cp "$compose_file" "$compose_file.bak"
    
    # Update port mapping in the compose file
    # This is a basic sed replace, more complex services might need a different approach
    sudo sed -i "s/- \"$old_port:/- \"$new_port:/" "$compose_file"
    sudo sed -i "s/- $old_port:/- $new_port:/" "$compose_file"
    
    log "${GREEN}✅ Updated port in $compose_file${NC}"
    log "${YELLOW}⚠️ NOTE: You'll need to restart the service to apply the new port configuration${NC}"
  else
    log "${YELLOW}⚠️ No docker-compose file found for service $service${NC}"
  fi
}

# Main function
main() {
  log "${MAGENTA}${BOLD}🔍 AgencyStack Port Conflict Detector${NC}"
  log "========================================================"
  log "$(date)"
  log "Server: $(hostname)"
  log ""
  
  if [ "$DRY_RUN" = true ]; then
    log "${YELLOW}Running in dry-run mode. No changes will be made.${NC}"
  fi
  
  if [ "$AUTO_FIX" = true ]; then
    log "${YELLOW}Running in auto-fix mode. Conflicts will be resolved automatically.${NC}"
  fi
  
  if [ "$SCAN_ONLY" = true ]; then
    log "${YELLOW}Running in scan-only mode. Only updating ports.json, no conflict resolution.${NC}"
  fi
  
  # Create necessary files if they don't exist
  create_empty_ports_json
  create_empty_decisions_log
  
  # Scan Docker containers for port mappings
  scan_docker_containers
  
  # If not in scan-only mode, detect and resolve conflicts
  if [ "$SCAN_ONLY" = false ]; then
    detect_port_conflicts
  fi
  
  log ""
  log "${GREEN}${BOLD}Port conflict detection complete!${NC}"
  log "Port registry updated: $PORTS_FILE"
  log "Port decisions log: $DECISIONS_LOG"
  
  if [ "$DRY_RUN" = false ] && [ "$SCAN_ONLY" = false ]; then
    log "${YELLOW}⚠️ IMPORTANT: If any ports were reassigned, you will need to restart the affected services.${NC}"
  fi
}

# Run main function
main
