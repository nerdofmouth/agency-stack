#!/bin/bash
# directory_helpers.sh - Directory management utilities for AgencyStack
#
# Provides functions to create, verify, and fix key directories with permissions
# Usage: source "$(dirname "$0")/../utils/directory_helpers.sh"

set -euo pipefail

# Import common utilities if not already sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(type -t log_info)" != "function" ]]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Standard directory structure
DEFAULT_BASE_DIR="/opt/agency_stack"
DEFAULT_LOG_DIR="/var/log/agency_stack"
DEFAULT_CLIENT_ID="${CLIENT_ID:-default}"

# Create standard directories for a component
create_component_dirs() {
    local component="$1"
    local client_id="${2:-$DEFAULT_CLIENT_ID}"
    local base_dir="${3:-$DEFAULT_BASE_DIR}"
    local log_dir="${4:-$DEFAULT_LOG_DIR}"
    
    # Create component installation directory
    local install_dir="${base_dir}/clients/${client_id}/${component}"
    ensure_directory "$install_dir" "750"
    
    # Create data directory
    local data_dir="${install_dir}/data"
    ensure_directory "$data_dir" "750"
    
    # Create config directory
    local config_dir="${install_dir}/config"
    ensure_directory "$config_dir" "750"
    
    # Create backup directory
    local backup_dir="${install_dir}/backups"
    ensure_directory "$backup_dir" "750"
    
    # Create logs directory
    local component_log_dir="${log_dir}/components"
    ensure_directory "$component_log_dir" "750"
    
    log_info "Created standard directory structure for ${component}"
    
    # Return the installation directory
    echo "$install_dir"
}

# Verify component directory structure
verify_component_dirs() {
    local component="$1"
    local client_id="${2:-$DEFAULT_CLIENT_ID}"
    local base_dir="${3:-$DEFAULT_BASE_DIR}"
    local log_dir="${4:-$DEFAULT_LOG_DIR}"
    
    local issues=0
    local install_dir="${base_dir}/clients/${client_id}/${component}"
    local data_dir="${install_dir}/data"
    local config_dir="${install_dir}/config"
    local backup_dir="${install_dir}/backups"
    local component_log_dir="${log_dir}/components"
    
    # Check installation directory
    if [[ ! -d "$install_dir" ]]; then
        log_warning "Missing installation directory: $install_dir"
        ((issues++))
    fi
    
    # Check data directory
    if [[ ! -d "$data_dir" ]]; then
        log_warning "Missing data directory: $data_dir"
        ((issues++))
    fi
    
    # Check config directory
    if [[ ! -d "$config_dir" ]]; then
        log_warning "Missing config directory: $config_dir"
        ((issues++))
    fi
    
    # Check backup directory
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "Missing backup directory: $backup_dir"
        ((issues++))
    fi
    
    # Check logs directory
    if [[ ! -d "$component_log_dir" ]]; then
        log_warning "Missing logs directory: $component_log_dir"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Component directory structure verified for ${component}"
        return 0
    else
        log_warning "Component ${component} has $issues directory issues"
        return 1
    fi
}

# Fix component directory structure
fix_component_dirs() {
    local component="$1"
    local client_id="${2:-$DEFAULT_CLIENT_ID}"
    local base_dir="${3:-$DEFAULT_BASE_DIR}"
    local log_dir="${4:-$DEFAULT_LOG_DIR}"
    
    local install_dir="${base_dir}/clients/${client_id}/${component}"
    local data_dir="${install_dir}/data"
    local config_dir="${install_dir}/config"
    local backup_dir="${install_dir}/backups"
    local component_log_dir="${log_dir}/components"
    
    # Fix installation directory
    if [[ ! -d "$install_dir" ]]; then
        ensure_directory "$install_dir" "750"
    fi
    
    # Fix data directory
    if [[ ! -d "$data_dir" ]]; then
        ensure_directory "$data_dir" "750"
    fi
    
    # Fix config directory
    if [[ ! -d "$config_dir" ]]; then
        ensure_directory "$config_dir" "750"
    fi
    
    # Fix backup directory
    if [[ ! -d "$backup_dir" ]]; then
        ensure_directory "$backup_dir" "750"
    fi
    
    # Fix logs directory
    if [[ ! -d "$component_log_dir" ]]; then
        ensure_directory "$component_log_dir" "750"
    fi
    
    log_success "Fixed directory structure for ${component}"
    return 0
}

# Clean up component directories (use with caution)
cleanup_component_dirs() {
    local component="$1"
    local client_id="${2:-$DEFAULT_CLIENT_ID}"
    local base_dir="${3:-$DEFAULT_BASE_DIR}"
    
    local install_dir="${base_dir}/clients/${client_id}/${component}"
    
    if [[ -d "$install_dir" ]]; then
        log_warning "Removing component directory: $install_dir"
        rm -rf "$install_dir"
        log_success "Removed component directory: $install_dir"
        return 0
    else
        log_warning "Component directory doesn't exist: $install_dir"
        return 1
    fi
}

# Create all required base directories
create_base_dirs() {
    local base_dir="${1:-$DEFAULT_BASE_DIR}"
    local log_dir="${2:-$DEFAULT_LOG_DIR}"
    
    # Create base directory structure
    ensure_directory "$base_dir" "755"
    ensure_directory "${base_dir}/clients" "755"
    ensure_directory "${base_dir}/secrets" "700"
    ensure_directory "${base_dir}/ports" "755"
    ensure_directory "${base_dir}/config" "755"
    ensure_directory "${base_dir}/backups" "755"
    
    # Create log directory structure
    ensure_directory "$log_dir" "755"
    ensure_directory "${log_dir}/components" "755"
    ensure_directory "${log_dir}/clients" "755"
    ensure_directory "${log_dir}/integrations" "755"
    ensure_directory "${log_dir}/audit" "700"
    
    log_success "Created all base directories"
    return 0
}

# Usage example
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Directory Helpers for AgencyStack"
    echo "================================="
    echo "This script provides utility functions for directory management."
    echo "It should be sourced from other scripts, not run directly."
    echo ""
    echo "Example usage:"
    echo "  source directory_helpers.sh"
    echo "  create_component_dirs 'mycomponent'"
    echo "  verify_component_dirs 'mycomponent'"
    echo "  fix_component_dirs 'mycomponent'"
    echo ""
    
    # Show directory structure if requested
    if [[ "${1:-}" == "--show-structure" ]]; then
        COMPONENT="example"
        CLIENT_ID="default"
        echo "Standard directory structure for component: $COMPONENT"
        echo "- /opt/agency_stack/clients/$CLIENT_ID/$COMPONENT"
        echo "  ├── data"
        echo "  ├── config"
        echo "  └── backups"
        echo "- /var/log/agency_stack/components/$COMPONENT.log"
    fi
fi
