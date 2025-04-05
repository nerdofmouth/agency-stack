#!/bin/bash
# update_component_registry.sh - AgencyStack Component Registry Updater
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Maintains and updates the component registry and generates documentation
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# Strict error handling
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"
SUMMARY_FILE="${ROOT_DIR}/docs/pages/components/summary.md"
LOG_DIR="/var/log/agency_stack"
REGISTRY_LOG="${LOG_DIR}/registry_updates.log"

# Command line options
CHECK_MODE=false
UPDATE_COMPONENT=""
UPDATE_FLAG=""
UPDATE_VALUE=""
SHOW_SUMMARY=false

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${REGISTRY_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Component Registry Updater${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--check${NC}                      Check registry for inconsistencies"
  echo -e "  ${CYAN}--update-component${NC} <comp>    Component to update"
  echo -e "  ${CYAN}--update-flag${NC} <flag>         Flag to update (e.g., installed, hardened)"
  echo -e "  ${CYAN}--update-value${NC} <true|false>  New value for the flag"
  echo -e "  ${CYAN}--summary${NC}                    Show integration status summary"
  echo -e "  ${CYAN}--help${NC}                       Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --check"
  echo -e "  $0 --update-component peertube --update-flag hardened --update-value true"
  echo -e "  $0 --summary"
  exit 0
}

# Check if jq is installed
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    log "ERROR" "jq is not installed. Please install jq first."
    echo -e "${RED}Error: jq is not installed.${NC} Please install it with: apt-get install jq"
    exit 1
  fi
  
  if [ ! -f "${REGISTRY_FILE}" ]; then
    log "ERROR" "Component registry file not found: ${REGISTRY_FILE}"
    echo -e "${RED}Error: Component registry file not found.${NC}"
    exit 1
  fi
}

# Update the timestamp in the registry file
update_timestamp() {
  local timestamp=$(date -Iseconds)
  local temp_file=$(mktemp)
  
  jq --arg ts "$timestamp" '.last_updated = $ts' "${REGISTRY_FILE}" > "${temp_file}"
  mv "${temp_file}" "${REGISTRY_FILE}"
  
  log "INFO" "Updated registry timestamp: ${timestamp}"
}

# Check registry for inconsistencies
check_registry() {
  log "INFO" "Checking component registry for inconsistencies..."
  
  local issues_found=0
  local temp_file=$(mktemp)
  
  # Check that all components have all required flags
  for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
    for component in $(jq -r --arg cat "$category" '.components[$cat] | keys[]' "${REGISTRY_FILE}"); do
      # Check if all required flags are present
      for flag in installed hardened makefile sso dashboard logs docs auditable traefik_tls multi_tenant; do
        if ! jq -e --arg cat "$category" --arg comp "$component" --arg flag "$flag" '.components[$cat][$comp].integration_status[$flag] != null' "${REGISTRY_FILE}" > /dev/null; then
          echo -e "${YELLOW}Missing flag:${NC} ${flag} for component ${BOLD}${component}${NC} in category ${category}"
          issues_found=$((issues_found + 1))
          
          # Add the missing flag with default value false
          jq --arg cat "$category" --arg comp "$component" --arg flag "$flag" '.components[$cat][$comp].integration_status[$flag] = false' "${REGISTRY_FILE}" > "${temp_file}"
          mv "${temp_file}" "${REGISTRY_FILE}"
        fi
      done
    done
  done
  
  # Check for components in dashboard_data.json that might be missing from registry
  if [ -f "/opt/agency_stack/dashboard_data.json" ]; then
    local dashboard_components=$(jq -r '.components[].component' "/opt/agency_stack/dashboard_data.json" 2>/dev/null || echo "")
    
    if [ -n "$dashboard_components" ]; then
      for component in $dashboard_components; do
        local found=false
        
        for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
          if jq -e --arg cat "$category" --arg comp "$component" '.components[$cat][$comp] != null' "${REGISTRY_FILE}" > /dev/null; then
            found=true
            break
          fi
        done
        
        if [ "$found" = false ]; then
          echo -e "${YELLOW}Component in dashboard but not in registry:${NC} ${BOLD}${component}${NC}"
          issues_found=$((issues_found + 1))
        fi
      done
    fi
  fi
  
  if [ $issues_found -eq 0 ]; then
    echo -e "${GREEN}No issues found in component registry.${NC}"
  else
    echo -e "${YELLOW}Found ${issues_found} issues in component registry.${NC}"
  fi
  
  update_timestamp
}

# Update a specific flag for a component
update_component_flag() {
  local component="$1"
  local flag="$2"
  local value="$3"
  
  # Convert string to boolean
  if [[ "$value" != "true" && "$value" != "false" ]]; then
    log "ERROR" "Value must be 'true' or 'false'"
    echo -e "${RED}Error: Value must be 'true' or 'false'${NC}"
    exit 1
  fi
  
  local found=false
  local category=""
  
  # Find the component in the registry
  for cat in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
    if jq -e --arg cat "$cat" --arg comp "$component" '.components[$cat][$comp] != null' "${REGISTRY_FILE}" > /dev/null; then
      found=true
      category="$cat"
      break
    fi
  done
  
  if [ "$found" = false ]; then
    log "ERROR" "Component not found in registry: ${component}"
    echo -e "${RED}Error: Component not found in registry: ${component}${NC}"
    exit 1
  fi
  
  # Update the flag
  local temp_file=$(mktemp)
  jq --arg cat "$category" --arg comp "$component" --arg flag "$flag" --argjson value "$value" '.components[$cat][$comp].integration_status[$flag] = $value' "${REGISTRY_FILE}" > "${temp_file}"
  mv "${temp_file}" "${REGISTRY_FILE}"
  
  log "INFO" "Updated ${component} ${flag} = ${value}"
  echo -e "${GREEN}Updated ${BOLD}${component}${NC}${GREEN} ${flag} = ${value}${NC}"
  
  update_timestamp
}

# Generate markdown summary from registry
generate_summary() {
  log "INFO" "Generating component integration summary..."
  
  # Get current date
  local current_date=$(date "+%B %d, %Y")
  local last_updated=$(jq -r '.last_updated' "${REGISTRY_FILE}")
  
  # Start writing the summary file
  cat > "${SUMMARY_FILE}" << EOF
---
layout: default
title: Component Integration Status - AgencyStack Documentation
---

# AgencyStack Component Integration Status

This document provides a comprehensive overview of all components in the AgencyStack ecosystem and their integration status. It is automatically generated from the authoritative \`component_registry.json\` file.

Last updated: ${current_date}

## Integration Status Legend

Each component is evaluated against the following integration criteria:

| Criteria | Description |
|----------|-------------|
| **Installed** | Installation is complete and tested |
| **Hardened** | System is validated with idempotent operation and proper flags |
| **Makefile** | Component has proper Makefile support |
| **SSO** | Integrated with Keycloak SSO where applicable |
| **Dashboard** | Registered in dashboard and dashboard_data.json |
| **Logs** | Writes component-specific logs to the log system |
| **Docs** | Has proper entries in components.md, ports.md, etc. |
| **Auditable** | Properly handled by audit/tracking system |
| **Traefik TLS** | Has proper reverse proxy config with TLS |
| **Multi-tenant** | Supports client-aware installation or usage patterns |

EOF
  
  # Variables for statistics
  local total_components=0
  local fully_integrated=0
  local partially_integrated=0
  local needs_attention=0
  
  # Process each category
  for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}" | sort); do
    # Get the human-readable category name
    local category_name=""
    case "$category" in
      "infrastructure") category_name="Core Infrastructure" ;;
      "business") category_name="Business Applications" ;;
      "content") category_name="Content Management" ;;
      "security") category_name="Security & Identity" ;;
      "communication") category_name="Email & Communication" ;;
      "monitoring") category_name="Monitoring & Observability" ;;
      *) category_name="${category^}" ;;
    esac
    
    # Add category header
    echo -e "## ${category_name}\n" >> "${SUMMARY_FILE}"
    
    # Add table header
    echo -e "| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |" >> "${SUMMARY_FILE}"
    echo -e "|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|" >> "${SUMMARY_FILE}"
    
    # Process each component in the category
    for component in $(jq -r --arg cat "$category" '.components[$cat] | keys[]' "${REGISTRY_FILE}" | sort); do
      total_components=$((total_components + 1))
      
      # Get component details
      local name=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].name' "${REGISTRY_FILE}")
      local version=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].version' "${REGISTRY_FILE}")
      
      # Get integration flags
      local installed=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.installed' "${REGISTRY_FILE}")
      local hardened=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.hardened' "${REGISTRY_FILE}")
      local makefile=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.makefile' "${REGISTRY_FILE}")
      local sso=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.sso' "${REGISTRY_FILE}")
      local dashboard=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.dashboard' "${REGISTRY_FILE}")
      local logs=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.logs' "${REGISTRY_FILE}")
      local docs=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.docs' "${REGISTRY_FILE}")
      local auditable=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.auditable' "${REGISTRY_FILE}")
      local traefik_tls=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.traefik_tls' "${REGISTRY_FILE}")
      local multi_tenant=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status.multi_tenant' "${REGISTRY_FILE}")
      
      # Convert boolean values to checkmarks or X
      installed=$([ "$installed" = "true" ] && echo "✅" || echo "❌")
      hardened=$([ "$hardened" = "true" ] && echo "✅" || echo "❌")
      makefile=$([ "$makefile" = "true" ] && echo "✅" || echo "❌")
      sso=$([ "$sso" = "true" ] && echo "✅" || echo "❌")
      dashboard=$([ "$dashboard" = "true" ] && echo "✅" || echo "❌")
      logs=$([ "$logs" = "true" ] && echo "✅" || echo "❌")
      docs=$([ "$docs" = "true" ] && echo "✅" || echo "❌")
      auditable=$([ "$auditable" = "true" ] && echo "✅" || echo "❌")
      traefik_tls=$([ "$traefik_tls" = "true" ] && echo "✅" || echo "❌")
      multi_tenant=$([ "$multi_tenant" = "true" ] && echo "✅" || echo "❌")
      
      # Check if fully integrated (all true)
      local all_flags=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(.value) | all' "${REGISTRY_FILE}")
      if [ "$all_flags" = "true" ]; then
        fully_integrated=$((fully_integrated + 1))
      else
        partially_integrated=$((partially_integrated + 1))
        
        # Check if needs attention (more than 2 false flags)
        local false_count=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(select(.value == false)) | length' "${REGISTRY_FILE}")
        if [ "$false_count" -ge 2 ]; then
          needs_attention=$((needs_attention + 1))
        fi
      fi
      
      # Add component row to table
      echo -e "| **${name}** | ${version} | ${installed} | ${hardened} | ${makefile} | ${sso} | ${dashboard} | ${logs} | ${docs} | ${auditable} | ${traefik_tls} | ${multi_tenant} |" >> "${SUMMARY_FILE}"
    done
    
    # Add empty line after category
    echo -e "\n" >> "${SUMMARY_FILE}"
  done
  
  # Add integration completion status section
  cat >> "${SUMMARY_FILE}" << EOF
## Integration Completion Status

### Overall Status

- **Total Components**: ${total_components}
- **Fully Integrated Components**: ${fully_integrated} ($(( fully_integrated * 100 / total_components ))%)
- **Partially Integrated Components**: ${partially_integrated} ($(( partially_integrated * 100 / total_components ))%)
- **Components Needing Attention**: ${needs_attention} ($(( needs_attention * 100 / total_components ))%)

### Integration Areas Needing Attention
EOF
  
  # List components needing attention
  local attention_list=""
  for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
    for component in $(jq -r --arg cat "$category" '.components[$cat] | keys[]' "${REGISTRY_FILE}"); do
      local false_count=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(select(.value == false)) | length' "${REGISTRY_FILE}")
      if [ "$false_count" -ge 2 ]; then
        local name=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].name' "${REGISTRY_FILE}")
        local missing_flags=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(select(.value == false)) | map(.key) | join(", ")' "${REGISTRY_FILE}")
        attention_list="${attention_list}\n1. **${name}**: Needs ${missing_flags}"
      fi
    done
  done
  
  if [ -n "$attention_list" ]; then
    echo -e "${attention_list}" >> "${SUMMARY_FILE}"
  else
    echo -e "\nNo components currently need attention. All components are fully or nearly fully integrated." >> "${SUMMARY_FILE}"
  fi
  
  # Add instructions for updating
  cat >> "${SUMMARY_FILE}" << EOF

## How to Update this Document

This document is automatically generated from the \`component_registry.json\` file. To update component status:

1. Edit the \`/config/registry/component_registry.json\` file
2. Run the component registry update utility
3. Commit the changes to the repository

Please do not edit this document directly as changes will be overwritten.
EOF
  
  log "INFO" "Generated component integration summary at ${SUMMARY_FILE}"
  echo -e "${GREEN}Generated component integration summary at ${SUMMARY_FILE}${NC}"
}

# Show component integration summary
show_summary() {
  local fully_integrated=$(jq -r '[.components[][] | select([.integration_status[]] | all)] | length' "${REGISTRY_FILE}")
  local total_components=$(jq -r '[.components[][]] | length' "${REGISTRY_FILE}")
  local partially_integrated=$((total_components - fully_integrated))
  
  echo -e "${BOLD}${MAGENTA}AgencyStack Component Integration Summary${NC}"
  echo -e "----------------------------------------"
  echo -e "${BOLD}Total Components:${NC} ${total_components}"
  echo -e "${BOLD}Fully Integrated:${NC} ${fully_integrated} ($(( fully_integrated * 100 / total_components ))%)"
  echo -e "${BOLD}Partially Integrated:${NC} ${partially_integrated} ($(( partially_integrated * 100 / total_components ))%)"
  echo
  
  # List components by integration status
  echo -e "${BOLD}${GREEN}Fully Integrated Components:${NC}"
  for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
    for component in $(jq -r --arg cat "$category" '.components[$cat] | keys[]' "${REGISTRY_FILE}"); do
      local all_flags=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(.value) | all' "${REGISTRY_FILE}")
      if [ "$all_flags" = "true" ]; then
        local name=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].name' "${REGISTRY_FILE}")
        echo -e "  • ${name}"
      fi
    done
  done
  
  echo
  echo -e "${BOLD}${YELLOW}Components Needing Attention:${NC}"
  local found_attention=false
  for category in $(jq -r '.components | keys[]' "${REGISTRY_FILE}"); do
    for component in $(jq -r --arg cat "$category" '.components[$cat] | keys[]' "${REGISTRY_FILE}"); do
      local false_count=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(select(.value == false)) | length' "${REGISTRY_FILE}")
      if [ "$false_count" -ge 2 ]; then
        local name=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].name' "${REGISTRY_FILE}")
        local missing_flags=$(jq -r --arg cat "$category" --arg comp "$component" '.components[$cat][$comp].integration_status | to_entries | map(select(.value == false)) | map(.key) | join(", ")' "${REGISTRY_FILE}")
        echo -e "  • ${name} (Missing: ${missing_flags})"
        found_attention=true
      fi
    done
  done
  
  if [ "$found_attention" = false ]; then
    echo -e "  No components currently need immediate attention"
  fi
  
  echo
  echo -e "For a detailed view, see: ${SUMMARY_FILE}"
}

# Process command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --check)
      CHECK_MODE=true
      shift
      ;;
    --update-component)
      UPDATE_COMPONENT="$2"
      shift
      shift
      ;;
    --update-flag)
      UPDATE_FLAG="$2"
      shift
      shift
      ;;
    --update-value)
      UPDATE_VALUE="$2"
      shift
      shift
      ;;
    --summary)
      SHOW_SUMMARY=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check dependencies
check_dependencies

# Process the requested operation
if [ "$CHECK_MODE" = true ]; then
  check_registry
elif [ -n "$UPDATE_COMPONENT" ] && [ -n "$UPDATE_FLAG" ] && [ -n "$UPDATE_VALUE" ]; then
  update_component_flag "$UPDATE_COMPONENT" "$UPDATE_FLAG" "$UPDATE_VALUE"
elif [ "$SHOW_SUMMARY" = true ]; then
  show_summary
else
  echo -e "${YELLOW}No operation specified. Generating summary by default.${NC}"
  generate_summary
fi

# Always regenerate the summary file
generate_summary

exit 0
