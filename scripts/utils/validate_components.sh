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

# Add a status marker to the report
append_status_marker() {
  local status="$1"
  local message="$2"
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    echo -e "$status $message" >> "$REPORT_FILE"
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
  fi
  
  if [[ ! -f "$MAKEFILE" ]]; then
    log "ERROR" "Makefile not found at: $MAKEFILE"
    exit 1
  fi
}

# Get all components from registry - ensures unique component names
get_all_components() {
  if [[ -n "$CHECK_SPECIFIC" ]]; then
    echo "$CHECK_SPECIFIC"
    return
  fi
  
  log "INFO" "Parsing component registry: $REGISTRY_FILE" "$BLUE"
  
  # Use jq to extract component names from registry
  if ! command -v jq &> /dev/null; then
    log "ERROR" "jq not found - cannot parse registry" "$RED"
    echo "prerequisites traefik portainer peertube" # Fallback minimal list
    return 1
  fi
  
  # Extract unique component names and sort them
  local components
  components=$(jq -r '.components | to_entries[] | .value | to_entries[] | .key' "$REGISTRY_FILE" | sort -u)
  
  # Check if we got any components
  if [[ -z "$components" ]]; then
    log "WARNING" "No components found in registry, using fallback list" "$YELLOW"
    echo "prerequisites traefik portainer peertube" # Fallback minimal list
    return 1
  fi
  
  log "INFO" "Found $(echo "$components" | wc -l) components in registry" "$BLUE"
  echo "$components"
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
  append_to_report "#### Makefile Targets"
  
  # Required targets to check
  local targets=("$target_base" "$target_base-status" "$target_base-logs" "$target_base-restart")
  
  for target in "${targets[@]}"; do
    if grep -q "^$target:" "$MAKEFILE"; then
      if [[ "$VERBOSE" == "true" ]]; then
        log "SUCCESS" "Target ${BOLD}$target${NC} exists" "$GREEN"
      fi
      append_status_marker "✅" "Target \`$target\` exists"
    else
      log "ERROR" "Target ${BOLD}$target${NC} missing in Makefile" "$RED"
      append_status_marker "❌" "Target \`$target\` missing"
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
  local issues=0
  
  log "INFO" "Checking component script for ${BOLD}$component${NC}" "$CYAN"
  append_to_report "#### Component Script"
  
  # Check for script in components directory
  local script_name="install_${component}.sh"
  local script_path="$SCRIPT_DIR/$script_name"
  
  if [[ -f "$script_path" ]]; then
    log "SUCCESS" "Component script ${BOLD}$script_name${NC} found" "$GREEN"
    append_status_marker "✅" "Component script exists: \`$script_name\`"
    
    # Check for idempotence
    grep -q -E "already|exists|installed|idempotent|skip" "$script_path"
    if [[ $? -eq 0 ]]; then
      log "SUCCESS" "Script appears to implement idempotence" "$GREEN"
      append_status_marker "✅" "Script implements idempotence checks"
    else
      log "WARNING" "Script may not be idempotent" "$YELLOW"
      append_status_marker "⚠️" "Script may not implement proper idempotence"
      ((issues++))
    fi
  else
    log "ERROR" "Component script ${BOLD}$script_name${NC} not found" "$RED"
    append_status_marker "❌" "Component script \`$script_name\` not found"
    ((issues++))
  fi
  
  return $issues
}

# Check if component docs exist
check_component_docs() {
  local component="$1"
  local issues=0
  
  log "INFO" "Checking documentation for ${BOLD}$component${NC}" "$CYAN"
  append_to_report "#### Documentation"
  
  # Check for documentation file
  local doc_name="${component}.md"
  local doc_path="$DOCS_DIR/$doc_name"
  
  if [[ -f "$doc_path" ]]; then
    log "SUCCESS" "Documentation ${BOLD}$doc_name${NC} found" "$GREEN"
    append_status_marker "✅" "Documentation exists: \`$doc_name\`"
    
    # Check for recommended sections
    local expected_sections=("Installation" "Configuration" "Usage" "Troubleshooting")
    local missing_sections=()
    local has_all_sections=true
    
    for section in "${expected_sections[@]}"; do
      grep -qi "^#.*$section" "$doc_path" || grep -qi "^##.*$section" "$doc_path" || grep -qi "^###.*$section" "$doc_path"
      if [[ $? -ne 0 ]]; then
        missing_sections+=("$section")
        has_all_sections=false
      fi
    done
    
    if [[ "$has_all_sections" == "true" ]]; then
      log "SUCCESS" "Documentation contains all recommended sections" "$GREEN"
      append_status_marker "✅" "Documentation contains all recommended sections"
    else
      log "WARNING" "Documentation missing sections: ${missing_sections[*]}" "$YELLOW"
      append_status_marker "⚠️" "Documentation missing sections: ${missing_sections[*]}"
      ((issues++))
    fi
  else
    log "ERROR" "Documentation ${BOLD}$doc_name${NC} not found" "$RED"
    append_status_marker "❌" "Documentation \`$doc_name\` not found"
    ((issues++))
  fi
  
  return $issues
}

# Check if component is in registry
check_registry_entry() {
  local component="$1"
  local issues=0
  
  log "INFO" "Checking registry entry for ${BOLD}$component${NC}" "$CYAN"
  append_to_report "#### Registry Entry"
  
  # Check if component is in registry
  if jq --version &> /dev/null; then
    jq -e ".components|to_entries[].value|to_entries[]|select(.key==\"$component\")" "$REGISTRY_FILE" &> /dev/null
    if [[ $? -eq 0 ]]; then
      log "SUCCESS" "Component ${BOLD}$component${NC} found in registry" "$GREEN"
      append_status_marker "✅" "Component registered in component_registry.json"
    else
      log "ERROR" "Component ${BOLD}$component${NC} not found in registry" "$RED"
      append_status_marker "❌" "Component not found in component_registry.json"
      ((issues++))
    fi
  else
    log "ERROR" "jq not found - cannot parse registry" "$RED"
    append_status_marker "❌" "Registry check failed - jq not available"
    ((issues++))
  fi
  
  return $issues
}

validate_component() {
  local component="$1"
  local component_issues=0
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    append_to_report "\n### ${component^}\n"
  fi
  
  echo -e "\n${MAGENTA}${BOLD}Validating component: $component${NC}\n"
  
  # Run all checks, capturing the result of each
  check_makefile_targets "$component"; local result=$?
  component_issues=$((component_issues + result))
  
  check_component_script "$component"; local result=$?
  component_issues=$((component_issues + result))
  
  check_component_docs "$component"; local result=$?
  component_issues=$((component_issues + result))
  
  check_registry_entry "$component"; local result=$?
  component_issues=$((component_issues + result))
  
  if [[ $component_issues -eq 0 ]]; then
    log "SUCCESS" "${BOLD}$component${NC} passed all validation checks!" "$GREEN"
    echo "✅ $component: All checks passed" >> "$TEMP_RESULTS_FILE"
    return 0
  else
    log "WARNING" "${BOLD}$component${NC} has $component_issues issues to address" "$YELLOW"
    echo "❌ $component: $component_issues issues found" >> "$TEMP_RESULTS_FILE"
    return $component_issues
  fi
}

# Main function to validate components
validate_components() {
  check_dependencies
  
  # Create a temporary file to store results
  TEMP_RESULTS_FILE=$(mktemp)
  
  # Get all components as a newline-separated list
  local components_list
  components_list=$(get_all_components)
  
  # Convert to array
  readarray -t components <<< "$components_list"
  local total_components=${#components[@]}
  
  log "INFO" "Starting validation of ${BOLD}$total_components${NC} components" "$BLUE"
  append_to_report "Validating $total_components components"
  
  if [[ "$VERBOSE" == "true" ]]; then
    log "INFO" "Components to validate: ${components[*]}" "$BLUE"
  fi
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    append_to_report "\n## Component Details\n"
  fi
  
  local valid_components=0
  local total_issues=0
  local exit_code=0
  
  # Process each component
  for component in "${components[@]}"; do
    # Skip empty component names
    [[ -z "$component" ]] && continue
    
    # Skip log messages that might have been captured
    [[ "$component" == *"[INFO]"* ]] && continue
    
    validate_component "$component"
    local component_status=$?
    
    if [[ $component_status -eq 0 ]]; then
      ((valid_components++))
    else
      total_issues=$((total_issues + component_status))
      exit_code=1
    fi
    
    echo -e "\n${BLUE}${BOLD}----------------------------------------${NC}\n"
  done
  
  # Add summary to report and display final results
  local summary="✅ Valid components: $valid_components/$total_components | ❌ Issues found: $total_issues"
  
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    sed -i "4i$summary" "$REPORT_FILE"
    
    # Add a quick reference section for the make alpha-check command to use
    append_to_report "\n## Component Status Summary\n"
    cat "$TEMP_RESULTS_FILE" >> "$REPORT_FILE"
    
    log "INFO" "Report generated at ${BOLD}$REPORT_FILE${NC}" "$BLUE"
  fi
  
  echo -e "\n${MAGENTA}${BOLD}Validation Complete${NC}\n"
  echo -e "$summary"
  
  cat "$TEMP_RESULTS_FILE"
  
  # Clean up
  rm -f "$TEMP_RESULTS_FILE"
  
  return $exit_code
}

# Run validation
validate_components
exit $?
