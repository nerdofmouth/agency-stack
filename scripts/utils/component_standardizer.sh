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

# Define essential functions if they don't exist
if ! type ensure_directory_exists &>/dev/null; then
  ensure_directory_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      log_info "Created directory: $dir"
    fi
  }
fi

if ! type log_warning &>/dev/null; then
  log_warning() {
    echo -e "[WARNING] $*"
  }
fi

if ! type log_success &>/dev/null; then
  log_success() {
    echo -e "[SUCCESS] $*"
  }
fi

if ! type log_error &>/dev/null; then
  log_error() {
    echo -e "[ERROR] $*"
  }
fi

if ! type log_info &>/dev/null; then
  log_info() {
    echo -e "[INFO] $*"
  }
fi

# Display usage information
show_usage() {
  echo -e "${BOLD}AgencyStack Component Standardizer${NC}"
  echo "Standardizes component scripts to comply with Charter v1.0.3 requirements, including header and logging fixes (consolidated from charter_compliance_fix.sh)"
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

# Charter Compliance: Standardize script header and logging
fix_script_header() {
  local script="$1"
  local script_basename=$(basename "$script")
  # Create backup
  cp "$script" "${script}.bak"
  # Extract original script content without any header or sourcing logic (for preservation)
  local script_content
  local content_start_line
  content_start_line=$(grep -n -m 1 -E "^[^#].*$" "$script" | cut -d: -f1)
  awk -v start="$content_start_line" 'NR >= start &&
    !/SCRIPT_DIR=/ &&
    !/source.*common\.sh/ &&
    !/exit_with_warning_if_host/ &&
    !/^if.*common\.sh/ &&
    !/^else$/ &&
    !/^fi$/ &&
    !/log_info\(\)/ &&
    !/log_error\(\)/ &&
    !/log_warning\(\)/ &&
    !/log_success\(\)/' "$script" > "${script}.content"
  script_content=$(cat "${script}.content")
  rm "${script}.content"
  # Create standardized header
  cat > "$script" << EOL
#!/bin/bash
# AgencyStack Charter Compliance Standard Header
SCRIPT_DIR="\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
fi
exit_with_warning_if_host
# AgencyStack Component Installer: \${script_basename/install_/}
# Path: /scripts/components/\${script_basename}
#
EOL
  # Append original script content
  echo "$script_content" >> "$script"
  chmod +x "$script"
  log_success "✅ Standardized header for $script_basename with proper sourcing and host check"
}

# Charter Compliance: Check for standard logging
check_logging() {
  local script="$1"
  local script_basename=$(basename "$script")
  # Skip if already using standard logging
  if grep -q "log_info\|log_error\|log_warning\|log_success" "$script"; then
    # Check if it's reimplementing log functions
    if grep -q "log_info()\|log_error()\|log_warning()\|log_success()" "$script"; then
      log_warning "⚠️ Script $script_basename reimplements logging functions. This requires manual review."
      return 1
    else
      log_info "✓ Script $script_basename already uses standard logging"
      return 0
    fi
  fi
  log_warning "⚠️ Script $script_basename does not use standard logging functions. Manual review required."
  return 1
}

# Standardize script header (legacy alias for backward compatibility)
standardize_header() {
  fix_script_header "$1"
}

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
  local script="${REPO_ROOT}/scripts/components/install_${component}.sh"
  if [[ ! -f "$script" ]]; then
    log_error "Component script not found: $script"
    return 1
  fi
  log_info "Standardizing $component for Charter compliance..."
  create_backup "$script"
  # Charter compliance: fix header and check logging
  fix_script_header "$script"
  check_logging "$script"
  check_test_scripts "$component"
  check_env_example "$component"
  check_registry_entry "$component"
  check_component_docs "$component"
  create_missing_test_scripts "$component"
  create_missing_makefile_entries "$component"
  create_missing_documentation "$component"
  create_missing_registry_entry "$component"
  log_success "Component $component standardized."
}

# Process all components
standardize_all_components() {
  log_info "Standardizing all components for Charter compliance..."
  local components_dir="${REPO_ROOT}/scripts/components"
  local fixed_count=0
  local review_needed_count=0
  for script in "$components_dir"/install_*.sh; do
    local component_name
    component_name=$(basename "$script" | sed 's/^install_//;s/\.sh$//')
    create_backup "$script"
    fix_script_header "$script"
    check_logging "$script" || review_needed_count=$((review_needed_count+1))
    check_test_scripts "$component_name"
    check_env_example "$component_name"
    check_registry_entry "$component_name"
    check_component_docs "$component_name"
    create_missing_test_scripts "$component_name"
    create_missing_makefile_entries "$component_name"
    create_missing_documentation "$component_name"
    create_missing_registry_entry "$component_name"
    fixed_count=$((fixed_count+1))
    log_success "Component $component_name standardized."
  done
  log_success "✅ Fixed $fixed_count component scripts"
  if [[ $review_needed_count -gt 0 ]]; then
    log_warning "⚠️ $review_needed_count scripts need manual review for logging compliance."
  fi
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
