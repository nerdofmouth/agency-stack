#!/bin/bash
# integrate_components.sh - Main Integration Controller for AgencyStack
# https://stack.nerdofmouth.com

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/integrate_common.sh"

# Variables
LOG_FILE="${INTEGRATION_LOG_DIR}/integration-${CURRENT_DATE}.log"
INTEGRATION_VERSION="2.0.0"

# Start logging
log "${MAGENTA}${BOLD}🔄 AgencyStack Component Integration${NC}"
log "========================================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Non-interactive mode flag
AUTO_MODE=false

# Integration type flag
INTEGRATION_TYPE="all"

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    --type=*)
      INTEGRATION_TYPE="${arg#*=}"
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Create integration system directory structure
setup_integration_system() {
  log "${BLUE}Setting up integration system directory structure...${NC}"
  
  # Create state and logs directories
  sudo mkdir -p "$INTEGRATION_STATE_DIR" "$INTEGRATION_LOG_DIR" "$INTEGRATION_DOC_DIR"
  sudo chmod 755 "$INTEGRATION_STATE_DIR" "$INTEGRATION_LOG_DIR" "$INTEGRATION_DOC_DIR"
  
  log "${GREEN}Integration system directory structure created${NC}"
}

# Run the integration
run_integration() {
  local integration_type="$1"
  local script_path="${SCRIPT_DIR}/integrate_${integration_type}.sh"
  
  if [ -f "$script_path" ]; then
    log "${BLUE}Running ${integration_type} integration...${NC}"
    
    # Pass auto mode flag if set
    if [ "$AUTO_MODE" = true ]; then
      bash "$script_path" --auto
    else
      bash "$script_path"
    fi
    
    log "${GREEN}${integration_type^} integration completed${NC}"
  else
    log "${RED}Error: Integration script not found for ${integration_type}${NC}"
    return 1
  fi
  
  return 0
}

# Main function
main() {
  log "${BLUE}Starting AgencyStack component integration...${NC}"
  
  # Setup integration system
  setup_integration_system
  
  # Get installed components
  get_installed_components
  
  # Run integrations based on type
  case "$INTEGRATION_TYPE" in
    "sso")
      run_integration "sso"
      ;;
    "email")
      run_integration "email"
      ;;
    "monitoring")
      run_integration "monitoring"
      ;;
    "data-bridge")
      run_integration "data_bridge"
      ;;
    "all")
      log "${BLUE}Running all integrations...${NC}"
      
      # Run each integration in sequence
      run_integration "sso"
      run_integration "email"
      run_integration "monitoring"
      run_integration "data_bridge"
      ;;
    *)
      log "${RED}Error: Unknown integration type: ${INTEGRATION_TYPE}${NC}"
      log "Valid types: sso, email, monitoring, data-bridge, all"
      exit 1
      ;;
  esac
  
  # Generate integration report
  generate_integration_report
  
  log ""
  log "${GREEN}${BOLD}Component integration complete!${NC}"
  log "See integration logs for details"
  log "Integration report generated: ${LOG_DIR}/integration_report-${CURRENT_DATE}.txt"
}

# Run main function
main
