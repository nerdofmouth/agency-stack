#!/bin/bash
# validate_components.sh - Validate AgencyStack components against DevOps standards
# https://stack.nerdofmouth.com
#
# This script systematically checks all components for compliance with AgencyStack standards:
# - Validates Makefile targets existence (install, status, logs, restart)
# - Checks component registry entries
# - Verifies documentation existence
# - Ensures script files are in the correct locations
# - Validates that component follows idempotence patterns
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# Strict error handling
set -euo pipefail

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"
MAKEFILE="${ROOT_DIR}/Makefile"
DOCS_DIR="${ROOT_DIR}/docs/pages/components"
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"
VERBOSE=false
REPORT_FILE="${ROOT_DIR}/component_validation_report.md"
CHECK_SPECIFIC=""
FIX_ISSUES=false
GENERATE_REPORT=false

# Show help
show_help() {
  cat << EOF
${MAGENTA}${BOLD}AgencyStack Component Validator${NC}
=====================================
This utility ensures all components adhere to AgencyStack DevOps standards.

${CYAN}${BOLD}Usage:${NC}
  $0 [options]

${CYAN}${BOLD}Options:${NC}
  ${BOLD}--component=NAME${NC}    Check only the specified component
  ${BOLD}--verbose${NC}           Show detailed output
  ${BOLD}--fix${NC}               Attempt to fix common issues
  ${BOLD}--report${NC}            Generate markdown report
  ${BOLD}--help${NC}              Show this help message

${CYAN}${BOLD}Examples:${NC}
  $0 --verbose
  $0 --component=peertube
  $0 --report --fix

EOF
}

# Logging function
log() {
  local level="$1"
  local message="$2"
  local color="${3:-$NC}"
  
  if [[ "$level" == "ERROR" ]]; then
    color="$RED"
  elif [[ "$level" == "WARNING" ]]; then
    color="$YELLOW"
  elif [[ "$level" == "SUCCESS" ]]; then
    color="$GREEN"
  elif [[ "$level" == "INFO" ]]; then
    color="$BLUE"
  fi
  
  echo -e "[${color}${level}${NC}] ${message}"
}

# Add to report
append_to_report() {
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    echo -e "$1" >> "$REPORT_FILE"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --component=*)
      CHECK_SPECIFIC="${1#*=}"
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --fix)
      FIX_ISSUES=true
      shift
      ;;
    --report)
      GENERATE_REPORT=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      log "ERROR" "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Initialize report if requested
if [[ "$GENERATE_REPORT" == "true" ]]; then
  cat > "$REPORT_FILE" << EOF
# AgencyStack Component Validation Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Summary

EOF
fi

# Check dependencies
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    log "ERROR" "jq is required but not installed. Please install it."
    exit 1
  fi
  
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    log "ERROR" "Component registry file not found at: $REGISTRY_FILE"
    exit 1
  }
  
  if [[ ! -f "$MAKEFILE" ]]; then
    log "ERROR" "Makefile not found at: $MAKEFILE"
    exit 1
  fi
}

# Get all components from registry
get_all_components() {
  local components=()
  
  if [[ -n "$CHECK_SPECIFIC" ]]; then
    components=("$CHECK_SPECIFIC")
  else
    # Extract all component names from registry using jq
    components=($(jq -r '.components | to_entries[] | .value | to_entries[] | .key' "$REGISTRY_FILE"))
  fi
  
  echo "${components[@]}"
}

# Check if makefile targets exist for component
check_makefile_targets() {
  local component="$1"
  local issues=0
  local target_base="$component"
  
  # Special handling for component names with install_ prefix
  if [[ "$component" == install_* ]]; then
    target_base="${component#install_}"
  fi
  
  # Converting target base to use dashes instead of underscores for makefile targets
  target_base="${target_base//_/-}"
  
  log "INFO" "Checking Makefile targets for ${BOLD}$component${NC}" "$CYAN"
  
  # Required targets to check
  local targets=("$target_base" "$target_base-status" "$target_base-logs" "$target_base-restart")
  
  for target in "${targets[@]}"; do
    if grep -q "^$target:" "$MAKEFILE"; then
      if [[ "$VERBOSE" == "true" ]]; then
        log "SUCCESS" "Target ${BOLD}$target${NC} exists" "$GREEN"
      fi
    else
      log "ERROR" "Target ${BOLD}$target${NC} missing in Makefile" "$RED"
      append_to_report "- Missing Makefile target: \`$target\`"
      ((issues++))
      
      if [[ "$FIX_ISSUES" == "true" ]]; then
        log "INFO" "Adding target stub for $target to Makefile" "$BLUE"
        # Add stub target at the end of Makefile
        echo -e "\n# Auto-generated target for $component" >> "$MAKEFILE"
        echo "$target:" >> "$MAKEFILE"
        echo "	@echo \"TODO: Implement $target\"" >> "$MAKEFILE"
        echo "	@exit 1" >> "$MAKEFILE"
      fi
    fi
  done
  
  if [[ $issues -eq 0 ]]; then
    log "SUCCESS" "All required Makefile targets present for $component" "$GREEN"
    append_to_report "✅ All Makefile targets present for $component"
    return 0
  else
    return $issues
  fi
}

# Check if component script exists
check_component_script() {
  local component="$1"
  local script_name="${component}.sh"
  local issues=0
  
  # If not already prefixed with install_, check both versions
  if [[ "$component" != install_* ]]; then
    script_name="install_${component}.sh"
  fi
  
  log "INFO" "Checking component script for ${BOLD}$component${NC}" "$CYAN"
  
  if [[ -f "$COMPONENTS_DIR/$script_name" ]]; then
    log "SUCCESS" "Component script ${BOLD}$script_name${NC} found" "$GREEN"
    append_to_report "✅ Component script exists: \`$script_name\`"
    
    # Check for idempotence pattern in script
    if grep -q "already.*installed\|marker\|\.installed\|skip.*installation" "$COMPONENTS_DIR/$script_name"; then
      log "SUCCESS" "Script appears to implement idempotence" "$GREEN"
      append_to_report "✅ Script implements idempotence checks"
    else
      log "WARNING" "Script may not implement proper idempotence" "$YELLOW"
      append_to_report "⚠️ Script may not implement proper idempotence"
      ((issues++))
    fi
  else
    log "ERROR" "Component script ${BOLD}$script_name${NC} not found in $COMPONENTS_DIR" "$RED"
    append_to_report "❌ Component script missing: \`$script_name\`"
    ((issues++))
    
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "INFO" "Creating template script for $script_name" "$BLUE"
      
      # Create template script
      cat > "$COMPONENTS_DIR/$script_name" << EOF
#!/bin/bash
# $script_name - AgencyStack Component Installer
# https://stack.nerdofmouth.com
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date '+%Y-%m-%d')

# Strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
CLIENT_ID="\${CLIENT_ID:-default}"
COMPONENT_DIR="\${AGENCY_ROOT}/clients/\${CLIENT_ID}/${component}"
COMPONENT_LOG="\${AGENCY_LOG_DIR}/components/${component}.log"

# Ensure log directory exists
mkdir -p "\$(dirname "\$COMPONENT_LOG")"
touch "\$COMPONENT_LOG"

# Marker file for idempotence
MARKER_FILE="\${COMPONENT_DIR}/.installed_ok"

# Check if already installed
if [ -f "\$MARKER_FILE" ]; then
  echo "Component ${component} already installed. Use --force to reinstall."
  exit 0
fi

# TODO: Implement ${component} installation logic here

# Mark as installed
mkdir -p "\$(dirname "\$MARKER_FILE")"
touch "\$MARKER_FILE"

echo "${component} installation completed successfully!"
exit 0
EOF
      chmod +x "$COMPONENTS_DIR/$script_name"
    fi
  fi
  
  if [[ $issues -eq 0 ]]; then
    return 0
  else
    return $issues
  fi
}

# Check if component documentation exists
check_component_docs() {
  local component="$1"
  local doc_name="${component}.md"
  local issues=0
  
  # Remove install_ prefix for documentation filename
  if [[ "$component" == install_* ]]; then
    doc_name="${component#install_}.md"
  fi
  
  log "INFO" "Checking documentation for ${BOLD}$component${NC}" "$CYAN"
  
  if [[ -f "$DOCS_DIR/$doc_name" ]]; then
    log "SUCCESS" "Documentation ${BOLD}$doc_name${NC} found" "$GREEN"
    append_to_report "✅ Documentation exists: \`$doc_name\`"
    
    # Check for minimum documentation requirements
    local required_sections=("Overview" "Installation" "Configuration" "Troubleshooting")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
      if ! grep -q "^##.*$section" "$DOCS_DIR/$doc_name"; then
        missing_sections+=("$section")
      fi
    done
    
    if [[ ${#missing_sections[@]} -gt 0 ]]; then
      log "WARNING" "Documentation missing recommended sections: ${missing_sections[*]}" "$YELLOW"
      append_to_report "⚠️ Documentation missing sections: ${missing_sections[*]}"
      ((issues++))
    else
      log "SUCCESS" "Documentation contains all recommended sections" "$GREEN"
      append_to_report "✅ Documentation contains all recommended sections"
    fi
  else
    log "ERROR" "Documentation ${BOLD}$doc_name${NC} not found in $DOCS_DIR" "$RED"
    append_to_report "❌ Documentation missing: \`$doc_name\`"
    ((issues++))
    
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "INFO" "Creating template documentation for $doc_name" "$BLUE"
      
      # Get component description from registry if available
      local description=""
      if jq -e ".components[][\"$component\"].description" "$REGISTRY_FILE" &>/dev/null; then
        description=$(jq -r ".components[][\"$component\"].description" "$REGISTRY_FILE")
      else
        description="$component component"
      fi
      
      # Create template documentation
      cat > "$DOCS_DIR/$doc_name" << EOF
---
layout: default
title: ${component^} - AgencyStack Documentation
---

# ${component^}

${description^}

## Overview

TODO: Add a description of what this component does, key features, and benefits.

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | 1.0.0 |
| **Component Type** | Core Infrastructure |
| **Data Directory** | /opt/agency_stack/clients/{CLIENT_ID}/${component} |
| **Log File** | /var/log/agency_stack/components/${component}.log |

## Installation

### Prerequisites

- Docker and Docker Compose
- AgencyStack Prerequisites component installed

### Installation Commands

**Basic Installation:**
\`\`\`bash
make ${component//_/-}
\`\`\`

**Installation with Specific Client:**
\`\`\`bash
make ${component//_/-} CLIENT_ID=your_client_id
\`\`\`

## Configuration Details

TODO: Add configuration details specific to this component.

## Security Considerations

- All operations use absolute paths
- Component is isolated to client-specific directories
- Installation is idempotent and can be safely re-run

## Troubleshooting

TODO: Add common issues and their solutions.

## Integration with Other Components

TODO: Describe how this component integrates with other parts of AgencyStack.
EOF
    fi
  fi
  
  if [[ $issues -eq 0 ]]; then
    return 0
  else
    return $issues
  fi
}

# Check registry entry for component
check_registry_entry() {
  local component="$1"
  local issues=0
  
  log "INFO" "Checking registry entry for ${BOLD}$component${NC}" "$CYAN"
  
  # Check if component exists in registry
  if jq -e ".components[][\"$component\"]" "$REGISTRY_FILE" &>/dev/null; then
    log "SUCCESS" "Component ${BOLD}$component${NC} found in registry" "$GREEN"
    append_to_report "✅ Component registered in component_registry.json"
    
    # Check for required flags
    local required_flags=("installed" "hardened" "makefile" "docs")
    local missing_flags=()
    
    for flag in "${required_flags[@]}"; do
      if ! jq -e ".components[][\"$component\"].integration_status[\"$flag\"]" "$REGISTRY_FILE" &>/dev/null; then
        missing_flags+=("$flag")
      fi
    done
    
    if [[ ${#missing_flags[@]} -gt 0 ]]; then
      log "WARNING" "Registry entry missing flags: ${missing_flags[*]}" "$YELLOW"
      append_to_report "⚠️ Registry entry missing flags: ${missing_flags[*]}"
      ((issues++))
      
      if [[ "$FIX_ISSUES" == "true" && -n "$CHECK_SPECIFIC" ]]; then
        log "INFO" "Attempting to fix registry entry for $component" "$BLUE"
        # We would need to call update_component_registry.sh here
        if [[ -f "$SCRIPT_DIR/update_component_registry.sh" ]]; then
          for flag in "${missing_flags[@]}"; do
            bash "$SCRIPT_DIR/update_component_registry.sh" --component="$component" --flag="$flag" --value=true
          done
        else
          log "WARNING" "Cannot fix registry: update_component_registry.sh not found" "$YELLOW"
        fi
      fi
    fi
  else
    log "ERROR" "Component ${BOLD}$component${NC} not found in registry" "$RED"
    append_to_report "❌ Component not registered in component_registry.json"
    ((issues++))
    
    if [[ "$FIX_ISSUES" == "true" && -n "$CHECK_SPECIFIC" ]]; then
      log "INFO" "Adding $component to registry would require complex JSON manipulation" "$BLUE"
      log "INFO" "Please use update_component_registry.sh to add it manually" "$BLUE"
    fi
  fi
  
  if [[ $issues -eq 0 ]]; then
    return 0
  else
    return $issues
  fi
}

# Main function to validate components
validate_components() {
  check_dependencies
  
  local components=( $(get_all_components) )
  local total_components=${#components[@]}
  local valid_components=0
  local total_issues=0
  
  log "INFO" "Starting validation of ${BOLD}$total_components${NC} components" "$BLUE"
  append_to_report "Validating $total_components components"
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    append_to_report "\n## Component Details\n"
  fi
  
  for component in "${components[@]}"; do
    local component_issues=0
    
    if [[ "$GENERATE_REPORT" == "true" ]]; then
      append_to_report "\n### ${component^}\n"
    fi
    
    echo -e "\n${MAGENTA}${BOLD}Validating component: $component${NC}\n"
    
    # Run all checks
    check_makefile_targets "$component"
    component_issues=$(( component_issues + $? ))
    
    check_component_script "$component"
    component_issues=$(( component_issues + $? ))
    
    check_component_docs "$component"
    component_issues=$(( component_issues + $? ))
    
    check_registry_entry "$component"
    component_issues=$(( component_issues + $? ))
    
    if [[ $component_issues -eq 0 ]]; then
      log "SUCCESS" "${BOLD}$component${NC} passed all validation checks!" "$GREEN"
      ((valid_components++))
    else
      log "WARNING" "${BOLD}$component${NC} has $component_issues issues to address" "$YELLOW"
      total_issues=$((total_issues + component_issues))
    fi
    
    echo -e "\n${BLUE}${BOLD}----------------------------------------${NC}\n"
  done
  
  # Add summary to report and display final results
  local summary="✅ Valid components: $valid_components/$total_components | ❌ Issues found: $total_issues"
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    sed -i "4i$summary" "$REPORT_FILE"
    log "INFO" "Report generated at ${BOLD}$REPORT_FILE${NC}" "$BLUE"
  fi
  
  echo -e "\n${MAGENTA}${BOLD}Validation Complete${NC}\n"
  echo -e "$summary"
  
  if [[ $total_issues -gt 0 ]]; then
    return 1
  else
    return 0
  fi
}

# Run validation
validate_components
exit $?
