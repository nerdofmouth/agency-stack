#!/bin/bash
# charter_compliance_fix.sh
# Automatically fixes common Charter compliance issues in component scripts
# Following the AgencyStack Charter v1.0.3 principles for repository integrity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPONENTS_DIR="${REPO_ROOT}/scripts/components"

# Source common utilities (with fallback if not available)
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  # Fallback logging (this script must work even if common.sh isn't available)
  log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
  log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
  log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1"; }
  log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
fi

# Function to completely rewrite script header with proper Charter compliance
fix_script_header() {
  local script="$1"
  local script_basename=$(basename "$script")
  
  # Create backup
  cp "$script" "${script}.bak"
  
  # Extract original script content without any header or sourcing logic (for preservation)
  local script_content
  
  # First, identify the real code start (after all the sourcing/logging boilerplate)
  local content_start_line
  content_start_line=$(grep -n -m 1 -E "^[^#].*$" "$script" | cut -d: -f1)
  
  # Extract just the meaningful script content - skipping all sourcing conditionals
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
  cat > "${script}" << EOL
#!/bin/bash

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: ${script_basename/install_/}
# Path: /scripts/components/${script_basename}
#
EOL

  # Append original script content
  echo "$script_content" >> "${script}"
  
  # Make executable
  chmod +x "${script}"
  
  log_success "✅ Standardized header for $script_basename with proper sourcing and host check"
}

# Function to check if script has proper logging
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

# Main function to process all component scripts
fix_all_components() {
  log_info "🔍 Starting Charter compliance fixes for all components..."
  
  local fixed_count=0
  local review_needed_count=0
  
  find "${COMPONENTS_DIR}" -name "*.sh" | while read -r script; do
    script_basename=$(basename "$script")
    log_info "Processing $script_basename..."
    
    # 1. Fix the script header (includes sourcing and host check)
    fix_script_header "$script"
    
    # 2. Check logging (mark for review if needed)
    if ! check_logging "$script"; then
      review_needed_count=$((review_needed_count + 1))
    else
      fixed_count=$((fixed_count + 1))
    fi
  done
  
  log_success "✅ Fixed $fixed_count component scripts"
  log_warning "⚠️ $review_needed_count scripts need manual review"
  log_info "Run 'make post-commit-check' to verify fixes"
}

# Process a single component by name
fix_component() {
  local component_name="$1"
  local script="${COMPONENTS_DIR}/install_${component_name}.sh"
  
  if [[ ! -f "$script" ]]; then
    log_error "❌ Component script not found: $script"
    return 1
  fi
  
  log_info "🔍 Starting Charter compliance fixes for ${component_name}..."
  
  # 1. Fix the script header (includes sourcing and host check)
  fix_script_header "$script"
  
  # 2. Check logging
  check_logging "$script"
  
  log_info "Run 'make post-commit-check' to verify fixes"
}

# Print usage information
print_usage() {
  echo "Usage: $0 [OPTION]"
  echo "Automatically fix common Charter compliance issues in component scripts"
  echo
  echo "Options:"
  echo "  --all                 Fix all component scripts"
  echo "  --component NAME      Fix a specific component"
  echo "  --help                Display this help and exit"
  echo
  echo "Examples:"
  echo "  $0 --all                # Fix all component scripts"
  echo "  $0 --component traefik  # Fix only the traefik component"
}

# Process command line arguments
if [[ $# -eq 0 ]]; then
  print_usage
  exit 1
fi

case "$1" in
  --all)
    fix_all_components
    ;;
  --component)
    if [[ -z "$2" ]]; then
      log_error "❌ Component name is required"
      print_usage
      exit 1
    fi
    fix_component "$2"
    ;;
  --help)
    print_usage
    exit 0
    ;;
  *)
    log_error "❌ Unknown option: $1"
    print_usage
    exit 1
    ;;
esac
