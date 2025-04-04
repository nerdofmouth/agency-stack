#!/bin/bash
# integrate_common.sh - Common functions for AgencyStack integration
# https://stack.nerdofmouth.com

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
LOG_DIR="/var/log/agency_stack"
INTEGRATION_STATE_DIR="/opt/agency_stack/integrations/state"
INTEGRATION_LOG_DIR="/opt/agency_stack/integrations/logs"
INTEGRATION_DOC_DIR="/opt/agency_stack/integrations/docs"
CURRENT_DATE=$(date +%Y%m%d-%H%M%S)

# Ensure directories exist
mkdir -p "$LOG_DIR"
sudo mkdir -p "$INTEGRATION_STATE_DIR" "$INTEGRATION_LOG_DIR" "$INTEGRATION_DOC_DIR"
sudo chmod 755 "$INTEGRATION_STATE_DIR" "$INTEGRATION_LOG_DIR" "$INTEGRATION_DOC_DIR"

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo -e "${YELLOW}Warning: config.env not found, using default values${NC}"
  PRIMARY_DOMAIN="example.com"
fi

# Logging function
log() {
  local log_file="${INTEGRATION_LOG_DIR}/integration-${CURRENT_DATE}.log"
  echo -e "$1" | tee -a "$log_file"
}

# Check if an integration is already applied
integration_is_applied() {
  local integration_type="$1"
  local component="$2"
  local state_file="${INTEGRATION_STATE_DIR}/${integration_type}.state"
  
  if [ -f "$state_file" ]; then
    if grep -q "^${component}:" "$state_file"; then
      return 0 # Already applied
    fi
  fi
  return 1 # Not applied
}

# Record an integration as applied
record_integration() {
  local integration_type="$1"
  local component="$2"
  local version="$3"
  local details="$4"
  local state_file="${INTEGRATION_STATE_DIR}/${integration_type}.state"
  
  # Create or update the state record
  if [ -f "$state_file" ]; then
    # Update existing record if present
    if grep -q "^${component}:" "$state_file"; then
      sudo sed -i "s|^${component}:.*$|${component}:${version}:$(date -u +"%Y-%m-%dT%H:%M:%SZ"):${details}|" "$state_file"
    else
      # Append new record
      echo "${component}:${version}:$(date -u +"%Y-%m-%dT%H:%M:%SZ"):${details}" | sudo tee -a "$state_file" > /dev/null
    fi
  else
    # Create new state file
    echo "${component}:${version}:$(date -u +"%Y-%m-%dT%H:%M:%SZ"):${details}" | sudo tee "$state_file" > /dev/null
  fi
  
  # Update the documentation
  update_integration_docs "$integration_type" "$component" "$version" "$details"
  
  log "${GREEN}Recorded ${integration_type} integration for ${component} (v${version})${NC}"
}

# Update integration documentation
update_integration_docs() {
  local integration_type="$1"
  local component="$2"
  local version="$3"
  local details="$4"
  local doc_file="${INTEGRATION_DOC_DIR}/${integration_type}.md"
  
  # Create markdown document header if it doesn't exist
  if [ ! -f "$doc_file" ]; then
    echo "# AgencyStack ${integration_type^} Integration" | sudo tee "$doc_file" > /dev/null
    echo "" | sudo tee -a "$doc_file" > /dev/null
    echo "This document tracks ${integration_type} integrations applied to your AgencyStack components." | sudo tee -a "$doc_file" > /dev/null
    echo "" | sudo tee -a "$doc_file" > /dev/null
    echo "## Applied Integrations" | sudo tee -a "$doc_file" > /dev/null
    echo "" | sudo tee -a "$doc_file" > /dev/null
  fi
  
  # Check if component section exists
  if ! grep -q "### ${component}" "$doc_file"; then
    echo "### ${component}" | sudo tee -a "$doc_file" > /dev/null
    echo "" | sudo tee -a "$doc_file" > /dev/null
    echo "- **Version**: ${version}" | sudo tee -a "$doc_file" > /dev/null
    echo "- **Last Applied**: $(date)" | sudo tee -a "$doc_file" > /dev/null
    echo "- **Details**: ${details}" | sudo tee -a "$doc_file" > /dev/null
    echo "" | sudo tee -a "$doc_file" > /dev/null
  else
    # Update existing component section
    sudo sed -i "/^### ${component}/,/^### /c\\\
### ${component}\n\
\n\
- **Version**: ${version}\n\
- **Last Applied**: $(date)\n\
- **Details**: ${details}\n\
" "$doc_file"
  fi
  
  # Also update the main integrations documentation
  update_main_docs
}

# Update the main integrations.md file
update_main_docs() {
  local docs_dir="/home/revelationx/CascadeProjects/foss-server-stack/docs/pages"
  local md_file="${docs_dir}/integrations.md"
  
  # Create documentation directory if it doesn't exist
  mkdir -p "$docs_dir"
  
  # Create or update the main integration doc
  if [ ! -f "$md_file" ]; then
    echo "# AgencyStack Integrations" > "$md_file"
    echo "" >> "$md_file"
    echo "This document provides an overview of integrations between various AgencyStack components." >> "$md_file"
    echo "" >> "$md_file"
  fi
  
  # Gather all integration types from state files
  local integration_types=$(ls ${INTEGRATION_STATE_DIR}/*.state 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.state$//' | sort)
  
  # If no integrations found, note that
  if [ -z "$integration_types" ]; then
    if ! grep -q "No integrations have been applied yet" "$md_file"; then
      echo "## Available Integrations" > "$md_file.tmp"
      echo "" >> "$md_file.tmp"
      echo "No integrations have been applied yet. Use \`make integrate-components\` to configure component integrations." >> "$md_file.tmp"
      
      # Append rest of file after the header (if exists)
      if grep -q "^# AgencyStack Integrations" "$md_file"; then
        sed -e '1,/^# AgencyStack Integrations/d' -e '1,/^$/d' "$md_file" >> "$md_file.tmp"
      fi
      
      # Replace original file
      mv "$md_file.tmp" "$md_file"
    fi
    return
  fi
  
  # Create a temporary file for the updated content
  echo "# AgencyStack Integrations" > "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  echo "This document provides an overview of integrations between various AgencyStack components." >> "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  echo "## Applied Integrations" >> "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  
  # Process each integration type
  for int_type in $integration_types; do
    echo "### ${int_type^} Integration" >> "$md_file.tmp"
    echo "" >> "$md_file.tmp"
    
    # Get applied integrations for this type
    while IFS=: read -r component version timestamp details; do
      echo "#### ${component}" >> "$md_file.tmp"
      echo "" >> "$md_file.tmp"
      echo "- **Version**: ${version}" >> "$md_file.tmp"
      echo "- **Applied**: $(date -d @$(date -d "$timestamp" +%s) '+%Y-%m-%d %H:%M:%S')" >> "$md_file.tmp"
      echo "- **Details**: ${details}" >> "$md_file.tmp"
      echo "" >> "$md_file.tmp"
    done < "${INTEGRATION_STATE_DIR}/${int_type}.state"
    
    echo "" >> "$md_file.tmp"
  done
  
  # Add usage section
  echo "## Usage" >> "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  echo "To apply or update integrations, use the following commands:" >> "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  echo "- \`make integrate-components\` - Run all integrations" >> "$md_file.tmp"
  echo "- \`make integrate-sso\` - Single Sign-On integration" >> "$md_file.tmp"
  echo "- \`make integrate-email\` - Email system integration" >> "$md_file.tmp"
  echo "- \`make integrate-monitoring\` - Monitoring and logging integration" >> "$md_file.tmp"
  echo "- \`make integrate-data-bridge\` - Data exchange between components" >> "$md_file.tmp"
  echo "" >> "$md_file.tmp"
  
  # Replace original file
  mv "$md_file.tmp" "$md_file"
}

# Get installed components
get_installed_components() {
  INSTALLED_COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
  INSTALLED_COMPONENTS=()
  
  if [ -f "$INSTALLED_COMPONENTS_FILE" ]; then
    while IFS= read -r component; do
      INSTALLED_COMPONENTS+=("$component")
    done < "$INSTALLED_COMPONENTS_FILE"
    
    log "${BLUE}Detected installed components:${NC}"
    for component in "${INSTALLED_COMPONENTS[@]}"; do
      log "- $component"
    done
    log ""
  else
    log "${YELLOW}Warning: No installed components file found${NC}"
    log "Please install components first using 'make install'"
  fi
}

# Check if a component is installed
is_component_installed() {
  local component_name="$1"
  
  for component in "${INSTALLED_COMPONENTS[@]}"; do
    if [[ "$component" == *"$component_name"* ]]; then
      return 0 # Found
    fi
  done
  
  return 1 # Not found
}

# Check for Docker container
is_container_running() {
  local container_name="$1"
  
  if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
    return 0 # Running
  fi
  
  return 1 # Not running
}

# Generate integration report
generate_integration_report() {
  local report_file="${LOG_DIR}/integration_report-${CURRENT_DATE}.txt"
  
  log "${BLUE}Generating integration report...${NC}"
  
  echo "AgencyStack Integration Report" > "$report_file"
  echo "=============================" >> "$report_file"
  echo "Generated: $(date)" >> "$report_file"
  echo "Server: $(hostname)" >> "$report_file"
  echo "" >> "$report_file"
  
  echo "Applied Integrations:" >> "$report_file"
  echo "--------------------" >> "$report_file"
  
  for state_file in "${INTEGRATION_STATE_DIR}"/*.state; do
    if [ -f "$state_file" ]; then
      local int_type=$(basename "$state_file" .state)
      echo "* ${int_type^} Integration:" >> "$report_file"
      
      while IFS=: read -r component version timestamp details; do
        echo "  - ${component} (v${version})" >> "$report_file"
      done < "$state_file"
      
      echo "" >> "$report_file"
    fi
  done
  
  echo "Missing Integrations:" >> "$report_file"
  echo "-------------------" >> "$report_file"
  
  # Check for possible missing integrations
  if is_component_installed "WordPress" && is_component_installed "ERPNext"; then
    if ! integration_is_applied "data-bridge" "WordPress"; then
      echo "* WordPress ↔ ERPNext data bridge not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "WordPress" && is_component_installed "Keycloak"; then
    if ! integration_is_applied "sso" "WordPress"; then
      echo "* WordPress SSO with Keycloak not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "ERPNext" && is_component_installed "Keycloak"; then
    if ! integration_is_applied "sso" "ERPNext"; then
      echo "* ERPNext SSO with Keycloak not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "WordPress" && is_component_installed "Mailu"; then
    if ! integration_is_applied "email" "WordPress"; then
      echo "* WordPress email with Mailu not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "ERPNext" && is_component_installed "Mailu"; then
    if ! integration_is_applied "email" "ERPNext"; then
      echo "* ERPNext email with Mailu not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "WordPress" && is_component_installed "Loki"; then
    if ! integration_is_applied "monitoring" "WordPress"; then
      echo "* WordPress monitoring with Loki not configured" >> "$report_file"
    fi
  fi
  
  if is_component_installed "ERPNext" && is_component_installed "Loki"; then
    if ! integration_is_applied "monitoring" "ERPNext"; then
      echo "* ERPNext monitoring with Loki not configured" >> "$report_file"
    fi
  fi
  
  echo "" >> "$report_file"
  echo "Recommended Actions:" >> "$report_file"
  echo "-------------------" >> "$report_file"
  echo "Run 'make integrate-components' to apply all missing integrations." >> "$report_file"
  echo "Or run specific integration types:" >> "$report_file"
  echo "- make integrate-sso" >> "$report_file"
  echo "- make integrate-email" >> "$report_file"
  echo "- make integrate-monitoring" >> "$report_file"
  echo "- make integrate-data-bridge" >> "$report_file"
  
  log "${GREEN}Integration report generated: ${report_file}${NC}"
  return 0
}
