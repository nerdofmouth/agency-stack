#!/bin/bash
# Utility script to ensure all component installation scripts have proper permissions
# This addresses issues found during VM installations

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils/common.sh
source "$SCRIPT_DIR/common.sh"

# Log initialization
log "INFO" "Starting permission_check.sh"
log "INFO" "Checking and fixing permissions for component scripts"

# Function to ensure executable permissions for all component scripts
ensure_component_script_permissions() {
  local components_dir
  components_dir="$(cd "$SCRIPT_DIR/../components" && pwd)"
  
  log "INFO" "Checking permissions in directory: $components_dir"
  
  # Find all shell scripts in components directory
  local script_count=0
  local fixed_count=0
  
  while IFS= read -r script; do
    script_count=$((script_count + 1))
    
    # Check if script is executable
    if [[ ! -x "$script" ]]; then
      log "WARN" "Script not executable: $script"
      chmod +x "$script"
      log "INFO" "Fixed permissions for: $script"
      fixed_count=$((fixed_count + 1))
    fi
  done < <(find "$components_dir" -type f -name "*.sh")
  
  log "INFO" "Checked $script_count scripts, fixed permissions for $fixed_count scripts"
  
  if [[ $fixed_count -gt 0 ]]; then
    log "SUCCESS" "Fixed permissions for $fixed_count scripts"
  else
    log "SUCCESS" "All scripts already have correct permissions"
  fi
  
  return 0
}

# Function to ensure the permissions are valid for the repo directory
ensure_repo_permissions() {
  log "INFO" "Checking repository permissions"
  
  # Get the current user
  local current_user
  current_user=$(id -un)
  
  # Get the current group
  local current_group
  current_group=$(id -gn)
  
  # The repository path is two levels up from this script
  local repo_path
  repo_path="$(cd "$SCRIPT_DIR/../.." && pwd)"
  
  log "INFO" "Repository path: $repo_path"
  log "INFO" "Current user: $current_user, Current group: $current_group"
  
  # Check if the repo is owned by root but run by another user
  if [[ "$(stat -c '%U' "$repo_path")" != "$current_user" ]]; then
    log "WARN" "Repository is not owned by current user"
    log "INFO" "Adding repository to Git safe.directory"
    
    # Add the repository to Git's safe.directory
    if ! git config --global --get safe.directory | grep -q "$repo_path"; then
      git config --global --add safe.directory "$repo_path"
      log "SUCCESS" "Added $repo_path to Git safe.directory"
    else
      log "INFO" "Repository already in Git safe.directory"
    fi
  fi
  
  return 0
}

# Main execution
ensure_component_script_permissions
ensure_repo_permissions

log "SUCCESS" "Permission check completed successfully"
exit 0
