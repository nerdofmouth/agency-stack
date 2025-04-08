#!/bin/bash
# Install AgencyStack Dashboard Component
# Installs and configures the dashboard for monitoring component status

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh" || {
  echo "Error: Failed to source common utilities"
  exit 1
}

# Initialize logging
init_log "dashboard"
log_info "Starting dashboard component installation"

# Parse command-line arguments
DOMAIN=""
ADMIN_EMAIL=""
CLIENT_ID=""
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if jq is installed, install if needed
check_install_jq() {
  log_info "Checking if jq is installed"
  if ! command -v jq &> /dev/null; then
    log_info "jq not found, installing..."
    if [[ "$(get_os_type)" == "debian" ]]; then
      apt-get update -y && apt-get install -y jq
    elif [[ "$(get_os_type)" == "rhel" ]]; then
      yum install -y jq
    else
      log_error "Unsupported OS for automatic jq installation"
      exit 1
    fi
    
    # Verify installation succeeded
    if ! command -v jq &> /dev/null; then
      log_error "Failed to install jq"
      exit 1
    fi
    log_info "jq installed successfully"
  else
    log_info "jq is already installed"
  fi
}

# Setup dashboard directory structure
setup_dashboard_dirs() {
  local base_dir="/opt/agency_stack"
  local dashboard_dir="${base_dir}/dashboard"
  
  if [[ -n "$CLIENT_ID" ]]; then
    dashboard_dir="${base_dir}/clients/${CLIENT_ID}/dashboard"
  fi
  
  log_info "Creating dashboard directory at ${dashboard_dir}"
  mkdir -p "${dashboard_dir}"
  
  # Copy dashboard files
  log_info "Copying dashboard files to ${dashboard_dir}"
  cp -f "${REPO_ROOT}/dashboard/agency_stack_cli_dashboard.sh" "${dashboard_dir}/"
  cp -f "${REPO_ROOT}/dashboard/agency_stack_dashboard_spec.json" "${dashboard_dir}/"
  
  # Make script executable
  chmod +x "${dashboard_dir}/agency_stack_cli_dashboard.sh"
  
  # Create symlink to make it accessible
  ln -sf "${dashboard_dir}/agency_stack_cli_dashboard.sh" "/usr/local/bin/agency-stack-dashboard"
  
  # Create success marker
  touch "${dashboard_dir}/.installed_ok"
  
  log_info "Dashboard installation complete"
}

# Update registry
update_component_registry() {
  log_info "Updating component registry"
  
  # TODO: Add proper registry update logic when registry format is finalized
  # For now we're just demonstrating the concept
  log_info "Registry update would happen here"
}

# Main installation process
main() {
  log_info "Starting dashboard installation"
  
  # Check for dependencies
  check_install_jq
  
  # Setup directories and copy files
  setup_dashboard_dirs
  
  # Update component registry
  update_component_registry
  
  log_info "Dashboard installation completed successfully"
  echo "Dashboard installed successfully! Run 'make dashboard' to view the component status."
}

# Run main function
main
