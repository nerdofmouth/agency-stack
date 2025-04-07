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
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"
DOCS_DIR="${ROOT_DIR}/docs/pages/components"
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

# Function to strip ANSI color codes from a string
strip_ansi_colors() {
  echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Get all components from registry - ensures unique component names
get_all_components() {
  if [[ -n "$CHECK_SPECIFIC" ]]; then
    echo "$CHECK_SPECIFIC"
    return
  fi
  
  log "INFO" "Parsing component registry: $REGISTRY_FILE" "$BLUE"
  
  # Use python for more reliable parsing
  if command -v python3 &> /dev/null; then
    python3 -c "
import json
import sys

try:
    with open('$REGISTRY_FILE', 'r') as f:
        data = json.load(f)
    
    components = []
    for category in data['components']:
        for comp in data['components'][category]:
            components.append(comp)
    
    print('\n'.join(sorted(components)))
except Exception as e:
    print(f'Error: {str(e)}', file=sys.stderr)
    sys.exit(1)
"
    return
  fi
  
  # Fallback to jq if python not available
  if command -v jq &> /dev/null; then
    jq -r '.components | to_entries[] | .value | to_entries[] | .key' "$REGISTRY_FILE" | sort -u
    return
  fi
  
  # Fallback to hard-coded list if both python and jq not available
  log "ERROR" "Neither python3 nor jq found - cannot parse registry" "$RED"
  echo "prerequisites traefik portainer peertube wordpress" # Fallback minimal list
  return 1
}

# Filter invalid component names
filter_invalid_component() {
  local component=$(strip_ansi_colors "$1")
  
  # Check if component name contains invalid characters for filenames/targets
  if [[ "$component" == *"/"* ]] || [[ "$component" == *":"* ]] || [[ "$component" == "["* ]]; then
    log "WARNING" "Skipping invalid component name: $component" "$YELLOW"
    return 1
  fi
  
  # Check if component name is a reserved word or non-descriptive
  if [[ "$component" == "component" ]] || [[ "$component" == "Parsing" ]] || [[ "$component" == "INFO" ]]; then
    log "WARNING" "Skipping reserved/generic name: $component" "$YELLOW"
    return 1
  fi
  
  return 0
}

# Check if makefile targets exist for component
check_makefile_targets() {
  local component=$(strip_ansi_colors "$1")
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
  local component=$(strip_ansi_colors "$1")
  local issues=0
  
  log "INFO" "Checking component script for ${BOLD}$component${NC}" "$CYAN"
  append_to_report "#### Component Script"
  
  # Check for script in components directory
  local script_name="install_${component}.sh"
  local script_path="$COMPONENTS_DIR/$script_name"
  
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
  local component=$(strip_ansi_colors "$1")
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
  local component=$(strip_ansi_colors "$1")
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

# Add repair capabilities
fix_component_script() {
  local component=$(strip_ansi_colors "$1")
  
  if [[ ! -f "${COMPONENTS_DIR}/install_${component}.sh" ]]; then
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "INFO" "Creating script template for ${component}..." "$BLUE"
      
      mkdir -p "${COMPONENTS_DIR}"
      
      # Create script template
      cat > "${COMPONENTS_DIR}/install_${component}.sh" << EOF
#!/bin/bash
# install_${component}.sh - Installation script for ${component}
#
# This script installs and configures ${component} for AgencyStack
# following the component installation conventions.
#
# Author: AgencyStack Team
# Date: $(date '+%Y-%m-%d')

set -e

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
CLIENT_ID="\${CLIENT_ID:-default}"
DOMAIN="\${DOMAIN:-localhost}"
ADMIN_EMAIL="\${ADMIN_EMAIL:-admin@example.com}"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/\${CLIENT_ID}/${component}"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="\${LOG_DIR}/${component}.log"

log_info "Starting ${component} installation..."

# Ensure directories exist
log_cmd "Creating installation directories..."
mkdir -p "\${INSTALL_DIR}"
mkdir -p "\${LOG_DIR}"

# Installation logic
# [COMPONENT-SPECIFIC INSTALLATION STEPS GO HERE]

log_success "${component} installation completed successfully!"
EOF
      
      # Make executable
      chmod +x "${COMPONENTS_DIR}/install_${component}.sh"
      
      append_to_report "- Created installation script template for \`${component}\`"
      log "SUCCESS" "Created installation script template for ${component}" "$GREEN"
      return 0
    else
      log "WARNING" "Script does not exist but fix mode is not enabled" "$YELLOW"
      return 1
    fi
  fi
  
  log "INFO" "Script for ${component} already exists" "$BLUE"
  return 0
}

# Fix missing documentation
fix_component_docs() {
  local component=$(strip_ansi_colors "$1")
  
  if [[ ! -f "${DOCS_DIR}/${component}.md" ]]; then
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "INFO" "Creating documentation template for ${component}..." "$BLUE"
      
      mkdir -p "${DOCS_DIR}"
      
      # Get description from registry if possible
      local description=""
      if command -v jq &> /dev/null; then
        description=$(jq -r --arg comp "$component" '.components | to_entries[] | .value | to_entries[] | select(.key == $comp) | .value.description' "$REGISTRY_FILE")
      fi
      
      if [[ -z "$description" ]]; then
        description="${component} component"
      fi
      
      # Create documentation template
      cat > "${DOCS_DIR}/${component}.md" << EOF
# ${component^}

## Overview
${description}

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the \`install_${component}.sh\` script, which can be executed using:

\`\`\`bash
make ${component}
\`\`\`

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- \`/var/log/agency_stack/components/${component}.log\`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| \`make ${component}\` | Install ${component} |
| \`make ${component}-status\` | Check status of ${component} |
| \`make ${component}-logs\` | View ${component} logs |
| \`make ${component}-restart\` | Restart ${component} services |
EOF
      
      append_to_report "- Created documentation template for \`${component}\`"
      log "SUCCESS" "Created documentation template for ${component}" "$GREEN"
      return 0
    else
      log "WARNING" "Documentation does not exist but fix mode is not enabled" "$YELLOW"
      return 1
    fi
  fi
  
  log "INFO" "Documentation for ${component} already exists" "$BLUE"
  return 0
}

# Fix missing makefile targets
fix_makefile_targets() {
  local component=$(strip_ansi_colors "$1")
  local target_base="$component"
  local generated_file="${ROOT_DIR}/makefile_targets.generated"
  
  # Generate targets if needed
  if ! grep -q "^${target_base}:" "$MAKEFILE"; then
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "INFO" "Generating Makefile targets for ${component}..." "$BLUE"
      
      # Create or append to the generated targets file
      cat >> "$generated_file" << EOF

# ${component} component targets
${target_base}:
	@echo "🔧 Installing ${component}..."
	@\$(SCRIPTS_DIR)/components/install_${component}.sh --domain \$(DOMAIN) --admin-email \$(ADMIN_EMAIL) \$(if \$(VERBOSE),--verbose,)

${target_base}-status:
	@echo "🔍 Checking ${component} status..."
	@if [ -f "\$(SCRIPTS_DIR)/components/status_${component}.sh" ]; then \\
		\$(SCRIPTS_DIR)/components/status_${component}.sh; \\
	else \\
		echo "Status script not found. Checking service..."; \\
		systemctl status ${component} 2>/dev/null || docker ps -a | grep ${component} || echo "${component} status check not implemented"; \\
	fi

${target_base}-logs:
	@echo "📜 Viewing ${component} logs..."
	@if [ -f "/var/log/agency_stack/components/${component}.log" ]; then \\
		tail -n 50 "/var/log/agency_stack/components/${component}.log"; \\
	else \\
		echo "Log file not found. Trying alternative sources..."; \\
		journalctl -u ${component} 2>/dev/null || docker logs ${component}-\$(CLIENT_ID) 2>/dev/null || echo "No logs found for ${component}"; \\
	fi

${target_base}-restart:
	@echo "🔄 Restarting ${component}..."
	@if [ -f "\$(SCRIPTS_DIR)/components/restart_${component}.sh" ]; then \\
		\$(SCRIPTS_DIR)/components/restart_${component}.sh; \\
	else \\
		echo "Restart script not found. Trying standard methods..."; \\
		systemctl restart ${component} 2>/dev/null || \\
		docker restart ${component}-\$(CLIENT_ID) 2>/dev/null || \\
		echo "${component} restart not implemented"; \\
	fi

${target_base}-test:
	@echo "🧪 Testing ${component}..."
	@if [ -f "\$(SCRIPTS_DIR)/components/test_${component}.sh" ]; then \\
		\$(SCRIPTS_DIR)/components/test_${component}.sh; \\
	else \\
		echo "Test script not found. Basic health check..."; \\
		\$(MAKE) ${target_base}-status; \\
	fi
EOF
      
      append_to_report "- Generated Makefile targets for \`${component}\`"
      log "SUCCESS" "Generated Makefile targets for ${component}" "$GREEN"
      log "INFO" "To apply targets: cat ${generated_file} >> ${MAKEFILE}" "$BLUE"
      return 0
    else
      log "WARNING" "Makefile targets missing but fix mode is not enabled" "$YELLOW"
      return 1
    fi
  fi
  
  log "INFO" "Makefile targets for ${component} already exist" "$BLUE"
  return 0
}

# Enhanced validate_component function to include fixes
validate_component() {
  local component=$(strip_ansi_colors "$1")
  local issues=0
  local fixed=0
  
  # Skip invalid component names
  if ! filter_invalid_component "$component"; then
    log "INFO" "Skipping validation for invalid component: $component" "$CYAN"
    return 0
  fi
  
  # Start component section in report
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    append_to_report "## ${component}"
  fi
  
  log "INFO" "Validating component: ${component}" "$BOLD$BLUE"
  
  # Check and fix component script
  if ! check_component_script "$component"; then
    ((issues++))
    if [[ "$FIX_ISSUES" == "true" ]]; then
      fix_component_script "$component"
      ((fixed++))
    fi
  fi
  
  # Check and fix component docs
  if ! check_component_docs "$component"; then
    ((issues++))
    if [[ "$FIX_ISSUES" == "true" ]]; then
      fix_component_docs "$component"
      ((fixed++))
    fi
  fi
  
  # Check and fix makefile targets
  if ! check_makefile_targets "$component"; then
    ((issues++))
    if [[ "$FIX_ISSUES" == "true" ]]; then
      fix_makefile_targets "$component"
      ((fixed++))
    fi
  fi
  
  # Check registry entry
  if ! check_registry_entry "$component"; then
    ((issues++))
    # For now, we don't fix registry entries automatically
    # Would need additional logic to determine proper category, etc.
  fi
  
  # Report on the issues
  if [[ $issues -eq 0 ]]; then
    log "SUCCESS" "$component passed all validation checks" "$GREEN"
    if [[ "$GENERATE_REPORT" == "true" ]]; then
      add_component_to_report "$component" "success"
    fi
  elif [[ $fixed -eq $issues ]]; then
    log "SUCCESS" "$component had $issues issues, all fixed automatically" "$GREEN"
    if [[ "$GENERATE_REPORT" == "true" ]]; then
      add_component_to_report "$component" "fixed"
    fi
  else
    log "WARNING" "$component had $issues issues, $fixed fixed, $((issues - fixed)) remaining" "$YELLOW"
    if [[ "$GENERATE_REPORT" == "true" ]]; then
      add_component_to_report "$component" "partial"
    fi
  fi
  
  return $((issues - fixed))
}

# Enhanced validate_components function
validate_components() {
  local all_components
  local total_components=0
  local passed_components=0
  local fixed_components=0
  local failed_components=0
  
  check_dependencies
  
  all_components=$(get_all_components)
  
  if [[ "$FIX_ISSUES" == "true" ]]; then
    log "INFO" "Validation running in FIX mode - will attempt to repair issues" "$BOLD$BLUE"
  fi
  
  for component in $all_components; do
    total_components=$((total_components+1))
    
    if validate_component "$component"; then
      passed_components=$((passed_components+1))
    else
      failed_components=$((failed_components+1))
    fi
    
    echo ""  # Add spacing between components
  done
  
  # Print summary
  log "INFO" "===== Validation Summary =====" "$BOLD$BLUE"
  log "INFO" "Total components: ${total_components}" "$BLUE"
  log "INFO" "Passed validation: ${passed_components}" "$GREEN"
  log "INFO" "Failed validation: ${failed_components}" "$RED"
  
  # Add summary to report
  if [[ "$GENERATE_REPORT" == "true" ]]; then
    append_to_report "## Summary"
    append_to_report "- **Total components**: ${total_components}"
    append_to_report "- **Passed validation**: ${passed_components}"
    append_to_report "- **Failed validation**: ${failed_components}"
    
    if [[ "$FIX_ISSUES" == "true" && -f "${ROOT_DIR}/makefile_targets.generated" ]]; then
      append_to_report "## Applying Fixes"
      append_to_report "To apply all generated Makefile targets:"
      append_to_report "```bash"
      append_to_report "cat ${ROOT_DIR}/makefile_targets.generated >> ${MAKEFILE}"
      append_to_report "```"
    fi
    
    log "SUCCESS" "Report generated: ${REPORT_FILE}" "$GREEN"
  fi
  
  if [[ "$failed_components" -gt 0 ]]; then
    if [[ "$FIX_ISSUES" == "true" ]]; then
      log "WARNING" "Some issues could not be fixed automatically" "$YELLOW"
      log "INFO" "Review the report and apply manual fixes" "$BLUE"
    else
      log "INFO" "Run with --fix to attempt automatic repairs" "$BLUE"
    fi
    return 1
  fi
  
  log "SUCCESS" "All components passed validation!" "$GREEN"
  return 0
}

# Add component to report with appropriate status markers
add_component_to_report() {
  local component="$1"
  local status="$2"
  
  if [[ "$status" == "success" ]]; then
    append_status_marker "✅" "${component} passed all validation checks"
  elif [[ "$status" == "fixed" ]]; then
    append_status_marker "✅" "${component} had issues, all fixed automatically"
  elif [[ "$status" == "partial" ]]; then
    append_status_marker "⚠️" "${component} had issues, some remain unfixed"
  else
    append_status_marker "❌" "${component} failed validation"
  fi
}

# Run validation
validate_components
exit $?
