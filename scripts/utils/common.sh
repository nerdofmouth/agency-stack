#!/bin/bash
# common.sh - Core utility functions for AgencyStack installation scripts
# 
# This script provides logging, error handling, and safety functions that should be
# included in all component installation scripts to ensure consistency and reliability.
#
# Usage: source "$(dirname "$0")/../utils/common.sh"

set -euo pipefail

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Set default values
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
VERBOSE="${VERBOSE:-false}"

# Ensure log directory exists
LOG_DIR="/var/log/agency_stack/components"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [INFO] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[${timestamp}] [INFO] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_success() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${GREEN}SUCCESS${NC}] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [SUCCESS] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_warning() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${YELLOW}WARNING${NC}] ${message}"
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [WARNING] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[${timestamp}] [${RED}ERROR${NC}] ${message}" >&2
    
    # Log to file if LOG_FILE is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [ERROR] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Safety functions
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        return 1
    fi
    return 0
}

ensure_directory() {
    local dir="$1"
    local permissions="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        log_info "Creating directory: $dir"
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
        chmod "$permissions" "$dir" 2>/dev/null || {
            log_warning "Failed to set permissions on: $dir"
        }
    fi
    return 0
}

# Function to safely replace a string in a file
safe_replace() {
    local file="$1"
    local search="$2"
    local replace="$3"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Create backup
    cp "$file" "${file}.bak" || {
        log_error "Failed to create backup of: $file"
        return 1
    }
    
    # Perform replacement
    sed -i "s|${search}|${replace}|g" "$file" || {
        log_error "Failed to perform replacement in: $file"
        # Restore backup
        mv "${file}.bak" "$file"
        return 1
    }
    
    # Remove backup on success
    rm "${file}.bak"
    return 0
}

# Function to mark a component as installed
mark_installed() {
    local component="$1"
    local install_dir="${2:-/opt/agency_stack/clients/${CLIENT_ID}/${component}}"
    
    ensure_directory "$install_dir"
    touch "${install_dir}/.installed_ok"
    log_info "Marked ${component} as installed"
    
    # Update component registry if available
    if command -v update_component_registry.sh &> /dev/null; then
        "$(dirname "$0")/../utils/update_component_registry.sh" \
            --component="$component" \
            --flag="installed" \
            --value="true" || log_warning "Failed to update component registry"
    fi
}

# Function to check if a component is already installed
is_component_installed() {
    local component="$1"
    local install_dir="${2:-/opt/agency_stack/clients/${CLIENT_ID}/${component}}"
    
    if [[ -d "$install_dir" && -f "${install_dir}/.installed_ok" ]]; then
        return 0  # Already installed
    fi
    return 1  # Not installed
}

# Function to handle script cleanup on exit
cleanup() {
    # Perform any necessary cleanup here
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
    
    # Log completion
    if [[ "${SCRIPT_SUCCESS:-false}" == "true" ]]; then
        log_success "Script completed successfully"
    else
        log_error "Script did not complete successfully"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Display script start banner
log_info "==========================================="
log_info "Starting $(basename "$0")"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="
