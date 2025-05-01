#!/bin/bash
# component_standardizer.sh - Standardizes all component scripts to Charter v1.0.3 compliance
# Built following AgencyStack Charter v1.0.3 principles for repository integrity

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Check that we're running inside a container/VM
exit_with_warning_if_host "component_standardizer"

# Display usage information
show_usage() {
  echo -e "${BOLD}AgencyStack Component Standardizer${NC}"
  echo "Standardizes component scripts to comply with Charter v1.0.3 requirements"
  echo ""
  echo "Usage:"
  echo "  $(basename "$0") <component_name|--all> [options]"
  echo ""
  echo "Options:"
  echo "  --dry-run          Only report issues without fixing"
  echo "  --verbose          Show detailed standardization steps"
  echo "  --backup           Create backups of original files"
  echo "  --force            Force standardization even on already compliant scripts"
  echo "  --help             Show this help message"
  echo ""
  echo "Example:"
  echo "  $(basename "$0") traefik_with_keycloak"
  echo "  $(basename "$0") --all --verbose"
  echo ""
}

# Default options
DRY_RUN=false
VERBOSE=false
BACKUP=true
FORCE=false
COMPONENT_NAME=""
PROCESS_ALL=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --all) PROCESS_ALL=true ;;
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    --no-backup) BACKUP=false ;;
    --force) FORCE=true ;;
    --help) show_usage; exit 0 ;;
    -*) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    *) COMPONENT_NAME="$1" ;;
  esac
  shift
done

# Validate inputs
if [[ "$PROCESS_ALL" = "false" && -z "$COMPONENT_NAME" ]]; then
  log_error "Either a component name or --all option must be specified"
  show_usage
  exit 1
fi

# Create a backup of the file
create_backup() {
  local file="$1"
  if [[ "$BACKUP" = "true" ]]; then
    cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
    [[ "$VERBOSE" = "true" ]] && log_info "Created backup: ${file}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

# Check if the component has TDD Protocol compliant test scripts
check_test_scripts() {
  local component="$1"
  local components_dir="${REPO_ROOT}/scripts/components"
  local has_verify=false
  local has_test=false
  local has_integration=false
  
  [[ -f "${components_dir}/verify_${component}.sh" ]] && has_verify=true
  [[ -f "${components_dir}/test_${component}.sh" ]] && has_test=true
  [[ -f "${components_dir}/integration_test_${component}.sh" ]] && has_integration=true
  
  if [[ "$has_verify" == "false" || "$has_test" == "false" || "$has_integration" == "false" ]]; then
    log_warning "Component ${component} is missing required test scripts"
    return 1
  fi
  
  return 0
}

# Check for proper environment variable documentation
check_env_example() {
  local component="$1"
  local components_dir="${REPO_ROOT}/scripts/components"
  local env_example="${components_dir}/${component}.env.example"
  
  if [[ ! -f "$env_example" ]]; then
    log_warning "Component ${component} is missing .env.example file"
    return 1
  fi
  
  return 0
}

# Check component registry entry
check_registry_entry() {
  local component="$1"
  local registry_path="${REPO_ROOT}/component_registry.json"
  
  if [[ ! -f "$registry_path" ]]; then
    log_warning "Component registry not found"
    return 1
  fi
  
  if ! jq -e ".components[] | select(.name == \"${component}\")" "$registry_path" >/dev/null 2>&1; then
    log_warning "Component ${component} not found in registry"
    return 1
  fi
  
  return 0
}

# Check component documentation
check_component_docs() {
  local component="$1"
  local doc_path="${REPO_ROOT}/docs/pages/components/${component}.md"
  
  if [[ ! -f "$doc_path" ]]; then
    log_warning "Component ${component} is missing documentation"
    return 1
  fi
  
  return 0
}

# Standardize script header
standardize_header() {
  local file="$1"
  local component="$2"
  local tmp_file=$(mktemp)
  
  [[ "$VERBOSE" = "true" ]] && log_info "Standardizing header for ${file}"
  
  # Extract first line (shebang)
  head -n 1 "$file" > "$tmp_file"
  
  # Create standardized header
  cat >> "$tmp_file" << EOL

# AgencyStack Component Installer: ${component}
# Path: /scripts/components/$(basename "$file")
# 
# This script installs the ${component} component according to AgencyStack Charter v1.0.3
# All installation is containerized and follows repository-first principles
#
# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found"
  exit 1
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Check proper repository context
if [[ "\$0" != *"${REPO_ROOT}/scripts/"* ]]; then
  log_error "ERROR: This script must be run from the repository context"
  log_error "Run with: ${REPO_ROOT}/scripts/components/\$(basename "\$0")"
  exit 1
fi

EOL

  # Add the rest of the file, skipping existing header section
  awk 'BEGIN{skip=1; found_content=0} 
       /^# Source common utilities/,/exit_with_warning_if_host/ { if (skip) next }
       { if ($0 ~ /^[^#]/ && !found_content) { found_content=1; skip=0 } }
       found_content { print $0 }' "$file" >> "$tmp_file"
  
  # Copy if changes were made
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Standardized header in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file" && chmod +x "$file"
  fi
  
  rm "$tmp_file"
}

# Create test scripts if missing
create_missing_test_scripts() {
  local component="$1"
  local components_dir="${REPO_ROOT}/scripts/components"
  
  [[ "$VERBOSE" = "true" ]] && log_info "Checking test scripts for ${component}"
  
  # Use bootstrap_component.sh's create_test_scripts function to create missing test scripts
  if [[ -f "${SCRIPT_DIR}/bootstrap_component.sh" ]]; then
    source "${SCRIPT_DIR}/bootstrap_component.sh"
    export COMPONENT_NAME="$component"
    export COMPONENTS_DIR="$components_dir"
    
    # Only generate missing scripts
    if [[ ! -f "${components_dir}/verify_${component}.sh" ]] || \
       [[ ! -f "${components_dir}/test_${component}.sh" ]] || \
       [[ ! -f "${components_dir}/integration_test_${component}.sh" ]]; then
      
      log_info "Creating missing test scripts for ${component}"
      [[ "$DRY_RUN" = "false" ]] && create_test_scripts
    fi
  else
    log_warning "bootstrap_component.sh not found, cannot create missing test scripts"
  fi
}

# Create Makefile entries if missing
create_missing_makefile_entries() {
  local component="$1"
  local makefile_dir="${REPO_ROOT}/makefiles/components"
  local makefile="${makefile_dir}/${component}.mk"
  
  [[ "$VERBOSE" = "true" ]] && log_info "Checking Makefile entries for ${component}"
  
  # Check if makefile exists
  if [[ ! -f "$makefile" ]]; then
    log_warning "Makefile entries missing for ${component}"
    
    # Use bootstrap_component.sh's function to create makefile entries
    if [[ -f "${SCRIPT_DIR}/bootstrap_component.sh" ]]; then
      source "${SCRIPT_DIR}/bootstrap_component.sh"
      export COMPONENT_NAME="$component"
      export REPO_ROOT="$REPO_ROOT"
      
      log_info "Creating Makefile entries for ${component}"
      [[ "$DRY_RUN" = "false" ]] && create_makefile_entries
    else
      log_warning "bootstrap_component.sh not found, cannot create Makefile entries"
    fi
  fi
}

# Create component documentation if missing
create_missing_documentation() {
  local component="$1"
  local doc_dir="${REPO_ROOT}/docs/pages/components"
  local doc_file="${doc_dir}/${component}.md"
  
  [[ "$VERBOSE" = "true" ]] && log_info "Checking documentation for ${component}"
  
  # Check if documentation exists
  if [[ ! -f "$doc_file" ]]; then
    log_warning "Documentation missing for ${component}"
    
    # Use bootstrap_component.sh's function to create documentation
    if [[ -f "${SCRIPT_DIR}/bootstrap_component.sh" ]]; then
      source "${SCRIPT_DIR}/bootstrap_component.sh"
      export COMPONENT_NAME="$component"
      export REPO_ROOT="$REPO_ROOT"
      export COMPONENT_DESCRIPTION="$(grep -r "^# AgencyStack Component Installer: ${component}" "${REPO_ROOT}/scripts/components" | head -1 | cut -d':' -f3- | tr -d '\\n')"
      
      log_info "Creating documentation for ${component}"
      [[ "$DRY_RUN" = "false" ]] && create_documentation
    else
      log_warning "bootstrap_component.sh not found, cannot create documentation"
    fi
  fi
}

# Create component registry entry if missing
create_missing_registry_entry() {
  local component="$1"
  local registry_path="${REPO_ROOT}/component_registry.json"
  
  [[ "$VERBOSE" = "true" ]] && log_info "Checking registry entry for ${component}"
  
  # Check if component exists in registry
  if ! check_registry_entry "$component"; then
    log_warning "Registry entry missing for ${component}"
    
    # Use bootstrap_component.sh's function to update registry
    if [[ -f "${SCRIPT_DIR}/bootstrap_component.sh" ]]; then
      source "${SCRIPT_DIR}/bootstrap_component.sh"
      export COMPONENT_NAME="$component"
      export REPO_ROOT="$REPO_ROOT"
      export COMPONENT_DESCRIPTION="$(grep -r "^# AgencyStack Component Installer: ${component}" "${REPO_ROOT}/scripts/components" | head -1 | cut -d':' -f3- | tr -d '\\n')"
      
      log_info "Creating registry entry for ${component}"
      [[ "$DRY_RUN" = "false" ]] && update_component_registry
    else
      log_warning "bootstrap_component.sh not found, cannot update registry"
    fi
  fi
}

# Standardize a single component
standardize_component() {
  local component="$1"
  local install_script="${REPO_ROOT}/scripts/components/install_${component}.sh"
  
  if [[ ! -f "$install_script" ]]; then
    log_error "Component install script not found: $install_script"
    return 1
  fi
  
  log_info "Standardizing ${component}..."
  
  # First run basic syntax repair
  if [[ -f "${SCRIPT_DIR}/syntax_repair.sh" ]]; then
    "${SCRIPT_DIR}/syntax_repair.sh" "$component" $([ "$VERBOSE" = "true" ] && echo "--verbose") $([ "$DRY_RUN" = "true" ] && echo "--dry-run") $([ "$BACKUP" = "false" ] && echo "--no-backup")
  fi
  
  # Standardize header
  standardize_header "$install_script" "$component"
  
  # Check and create missing TDD Protocol test scripts
  create_missing_test_scripts "$component"
  
  # Check and create missing Makefile entries
  create_missing_makefile_entries "$component"
  
  # Check and create missing documentation
  create_missing_documentation "$component"
  
  # Check and create missing registry entry
  create_missing_registry_entry "$component"
  
  log_success "Completed standardization for ${component}"
}

# Process all components
standardize_all_components() {
  log_info "Standardizing all components..."
  
  find "${REPO_ROOT}/scripts/components" -name "install_*.sh" | while read -r script; do
    component=$(basename "$script" | sed 's/^install_//;s/\.sh$//')
    standardize_component "$component"
  done
  
  log_success "Completed standardization for all components"
}

# Main execution
if [[ "$PROCESS_ALL" = "true" ]]; then
  standardize_all_components
else
  standardize_component "$COMPONENT_NAME"
fi

# Record this run in the changelog
if [[ -f "${SCRIPT_DIR}/changelog_utils.sh" ]] && [[ "$DRY_RUN" = "false" ]]; then
  source "${SCRIPT_DIR}/changelog_utils.sh"
  log_agent_fix "component_standardizer" "Standardized component scripts according to Charter v1.0.3 and TDD Protocol"
fi

log_success "Component standardization completed successfully"
