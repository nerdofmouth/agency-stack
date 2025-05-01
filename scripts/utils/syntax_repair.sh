#!/bin/bash
# syntax_repair.sh - Repairs syntax issues from automated Charter compliance fixes
# Follows AgencyStack Charter v1.0.3 principles for repository integrity

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
exit_with_warning_if_host "syntax_repair"

# Display usage information
show_usage() {
  echo -e "${BOLD}AgencyStack Syntax Repair Utility${NC}"
  echo "Repairs syntax issues in component scripts following Charter compliance modifications"
  echo ""
  echo "Usage:"
  echo "  $(basename "$0") <component_name|--all> [options]"
  echo ""
  echo "Options:"
  echo "  --dry-run          Only report issues without fixing"
  echo "  --verbose          Show detailed repair steps"
  echo "  --backup           Create backups of original files"
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
COMPONENT_NAME=""
FIX_ALL=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --all) FIX_ALL=true ;;
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    --no-backup) BACKUP=false ;;
    --help) show_usage; exit 0 ;;
    -*) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    *) COMPONENT_NAME="$1" ;;
  esac
  shift
done

# Validate inputs
if [[ "$FIX_ALL" = "false" && -z "$COMPONENT_NAME" ]]; then
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

# Fix missing if-fi brackets
fix_missing_brackets() {
  local file="$1"
  local tmp_file=$(mktemp)
  
  [[ "$VERBOSE" = "true" ]] && log_info "Scanning for missing if-fi brackets in $file"
  
  # Look for missing closing 'fi' statements
  # Pattern: 'if' statement without matching 'fi'
  awk '
  BEGIN { balance = 0; last_if_line = 0; fixed = 0 }
  
  /^[[:space:]]*if[[:space:]]/ { 
    balance++; 
    last_if_line = NR; 
  }
  
  /^[[:space:]]*fi[[:space:]]*$/ { 
    balance--; 
  }
  
  {
    print $0;
  }
  
  END { 
    for (i = 0; i < balance; i++) {
      print "fi";
      fixed++;
    }
    if (fixed > 0) {
      print "# Syntax repair: Added " fixed " missing fi statements" > "/dev/stderr";
    }
  }' "$file" > "$tmp_file"
  
  # Copy if changes were made
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Fixed missing 'fi' statements in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
  fi
  
  rm "$tmp_file"
}

# Fix duplicate log function implementations
fix_duplicate_log_functions() {
  local file="$1"
  local tmp_file=$(mktemp)

  [[ "$VERBOSE" = "true" ]] && log_info "Scanning for duplicate log function implementations in $file"

  # Remove duplicate log function implementations
  grep -v "log_info()\|log_error()\|log_warning()\|log_success()" "$file" > "$tmp_file"
  
  # Copy if changes were made
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Removed duplicate log function implementations in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
  fi

  # Fix case where log functions were commented out incorrectly
  tmp_file=$(mktemp)
  sed -E 's/^[[:space:]]*# Source common utilities\n[[:space:]]*echo "[^"]+"/# Source common utilities/' "$file" > "$tmp_file"
  
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Fixed commented out log functions in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
  fi
  
  rm "$tmp_file"
}

# Fix duplicated blocks of code
fix_duplicated_blocks() {
  local file="$1"
  local tmp_file=$(mktemp)
  
  [[ "$VERBOSE" = "true" ]] && log_info "Scanning for duplicated code blocks in $file"
  
  # Remove duplicated exit_with_warning_if_host lines
  awk '
  BEGIN { seen_exit_check = 0 }
  
  /# Enforce containerization/ { 
    if (seen_exit_check == 0) {
      print $0;
      seen_exit_check = 1;
    } else {
      print "# Duplicate containerization check removed by syntax_repair.sh";
    }
    next;
  }
  
  /exit_with_warning_if_host/ { 
    if (seen_exit_check == 1) {
      print $0;
      seen_exit_check = 2;
    } else if (seen_exit_check == 2) {
      print "# Duplicate exit_with_warning_if_host call removed by syntax_repair.sh";
      next;
    }
  }
  
  { print $0; }
  ' "$file" > "$tmp_file"
  
  # Copy if changes were made
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Fixed duplicated exit_with_warning_if_host calls in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
  fi
  
  rm "$tmp_file"
  
  # Fix duplicated component documentation headers
  tmp_file=$(mktemp)
  awk '
  BEGIN { seen_header = 0 }
  
  /# AgencyStack Component Installer:/ { 
    if (seen_header == 0) {
      print $0;
      seen_header = 1;
    } else {
      print "# Duplicate component header removed by syntax_repair.sh";
      next;
    }
  }
  
  /# Path: \/scripts\/components\// { 
    if (seen_header == 1) {
      print $0;
      seen_header = 2;
    } else if (seen_header >= 2) {
      print "# Duplicate path info removed by syntax_repair.sh";
      next;
    }
  }
  
  { print $0; }
  ' "$file" > "$tmp_file"
  
  # Copy if changes were made
  if ! cmp -s "$file" "$tmp_file"; then
    log_success "Fixed duplicated component documentation headers in $file"
    create_backup "$file"
    [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
  fi
  
  rm "$tmp_file"
}

# Fix missing brackets (if without fi)
fix_traefik_keycloak_issue() {
  local file="$1"
  
  if [[ "$(basename "$file")" == "install_traefik_with_keycloak.sh" ]]; then
    [[ "$VERBOSE" = "true" ]] && log_info "Applying specific fixes for install_traefik_with_keycloak.sh"
    
    local tmp_file=$(mktemp)
    # Specific fix for the missing 'if' bracket issue in install_traefik_with_keycloak.sh
    awk '
    BEGIN { fixed = 0 }
    
    /if \[\[ "\$0" != \*"\/root\/\_repos\/agency-stack\/scripts\/"\* \]\]; then/ { 
      print $0;
      fixed = 1;
    }
    
    /echo "ERROR: This script must be run from the repository context"/ { 
      print $0;
      if (fixed == 1) {
        fixed = 2;
      }
    }
    
    /exit 1/ {
      print $0;
      if (fixed == 2) {
        print "fi";
        fixed = 3;
      }
    }
    
    !/if \[\[ "\$0" != \*"\/root\/\_repos\/agency-stack\/scripts\/"\* \]\]; then/ && !/echo "ERROR: This script must be run from the repository context"/ && !/exit 1/ {
      print $0;
    }
    ' "$file" > "$tmp_file"
    
    # Copy if changes were made
    if ! cmp -s "$file" "$tmp_file"; then
      log_success "Fixed specific issue in $file"
      create_backup "$file"
      [[ "$DRY_RUN" = "false" ]] && cp "$tmp_file" "$file"
    fi
    
    rm "$tmp_file"
  fi
}

# Process a single component
process_component() {
  local component="$1"
  local script="${REPO_ROOT}/scripts/components/install_${component}.sh"
  
  if [[ ! -f "$script" ]]; then
    log_error "Component script not found: $script"
    return 1
  fi
  
  log_info "Processing ${component}..."
  
  # Apply fixes
  fix_missing_brackets "$script"
  fix_duplicate_log_functions "$script"
  fix_duplicated_blocks "$script"
  fix_traefik_keycloak_issue "$script"
  
  log_success "Completed syntax repair for ${component}"
}

# Main function for processing all components
process_all_components() {
  log_info "Processing all components..."
  
  find "${REPO_ROOT}/scripts/components" -name "install_*.sh" | while read -r script; do
    component=$(basename "$script" | sed 's/^install_//;s/\.sh$//')
    process_component "$component"
  done
  
  log_success "Completed syntax repair for all components"
}

# Main execution
if [[ "$FIX_ALL" = "true" ]]; then
  process_all_components
else
  process_component "$COMPONENT_NAME"
fi

# Record this run in the changelog
if [[ -f "${SCRIPT_DIR}/changelog_utils.sh" ]] && [[ "$DRY_RUN" = "false" ]]; then
  source "${SCRIPT_DIR}/changelog_utils.sh"
  log_agent_fix "syntax_repair" "Fixed syntax issues in component scripts after Charter compliance implementation"
fi

log_success "Syntax repair completed successfully"
