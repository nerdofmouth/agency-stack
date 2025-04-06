#!/bin/bash
# setup_component_directories.sh - AgencyStack Component Directory Setup
# Creates necessary log directories and placeholder files for components
# 
# This utility script ensures all components have their required directories
# and placeholder files created, making it easier to pass alpha-check
# validation even when components aren't yet installed or running.

# Strict error handling
set -eo pipefail

# Color definitions
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
REGISTRY_DIR="/opt/agency_stack/registry"
LOG_DIR="/var/log/agency_stack/components"
INSTALL_DIR="/opt/agency_stack"
CLIENT_ID="${CLIENT_ID:-default}"
CLIENT_DIR="${INSTALL_DIR}/clients/${CLIENT_ID}"

# Source common utilities if available
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Log function if not defined in common.sh
if ! command -v log &>/dev/null; then
    log() {
        local level="$1"
        local message="$2"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Define colors for different log levels
        local COLOR_INFO="\033[0;32m"    # Green
        local COLOR_WARNING="\033[0;33m" # Yellow
        local COLOR_ERROR="\033[0;31m"   # Red
        local COLOR_DEBUG="\033[0;36m"   # Cyan
        local COLOR_RESET="\033[0m"
        
        case "$level" in
            "INFO")    local color="${COLOR_INFO}" ;;
            "WARNING") local color="${COLOR_WARNING}" ;;
            "ERROR")   local color="${COLOR_ERROR}" ;;
            "DEBUG")   local color="${COLOR_DEBUG}" ;;
            *)         local color="${COLOR_INFO}" ;;
        esac
        
        echo -e "${color}[${timestamp}] [${level}] ${message}${COLOR_RESET}"
    }
fi

# Show usage information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --client-id <id>      Set client ID (default: default)"
    echo "  --force               Force recreation of directories and files"
    echo "  --verbose             Enable verbose output"
    echo "  --help                Show this help message"
}

# Parse command line arguments
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --client-id)
        CLIENT_ID="$2"
        CLIENT_DIR="${INSTALL_DIR}/clients/${CLIENT_ID}"
        shift 2
        ;;
        --force)
        FORCE=true
        shift
        ;;
        --verbose)
        VERBOSE=true
        shift
        ;;
        --help)
        show_help
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# Create base directories
create_base_directories() {
    log "INFO" "Creating base directories..."
    
    # Create standard directories
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    mkdir -p "${REGISTRY_DIR}" 2>/dev/null || true
    mkdir -p "${CLIENT_DIR}" 2>/dev/null || true
    mkdir -p "${INSTALL_DIR}/config" 2>/dev/null || true
    
    # Set permissions
    chmod 755 "${LOG_DIR}" 2>/dev/null || true
    chmod 755 "${REGISTRY_DIR}" 2>/dev/null || true
    chmod 755 "${CLIENT_DIR}" 2>/dev/null || true
    chmod 755 "${INSTALL_DIR}/config" 2>/dev/null || true
    
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Created base directories"
    fi
}

# Create component directories and placeholders
setup_component() {
    local component="$1"
    
    # Create component-specific directories
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    mkdir -p "${REGISTRY_DIR}" 2>/dev/null || true
    mkdir -p "${CLIENT_DIR}/${component}" 2>/dev/null || true
    
    # Create log file if it doesn't exist or force is set
    if [ ! -f "${LOG_DIR}/${component}.log" ] || [ "$FORCE" = true ]; then
        touch "${LOG_DIR}/${component}.log" 2>/dev/null || true
        chmod 644 "${LOG_DIR}/${component}.log" 2>/dev/null || true
        log "INFO" "Created log file for ${component}"
    fi
    
    # Create registry file if it doesn't exist or force is set
    if [ ! -f "${REGISTRY_DIR}/${component}.json" ] || [ "$FORCE" = true ]; then
        cat > "${REGISTRY_DIR}/${component}.json" << EOF
{
  "name": "${component}",
  "version": "0.0.0",
  "installed_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "status": "placeholder",
  "config_dir": "${CLIENT_DIR}/${component}",
  "log_file": "${LOG_DIR}/${component}.log",
  "client_id": "${CLIENT_ID}",
  "flags": {
    "installed": false,
    "makefile": true,
    "docs": true,
    "hardened": false,
    "monitoring": false,
    "multi_tenant": true,
    "sso": false
  }
}
EOF
        chmod 644 "${REGISTRY_DIR}/${component}.json" 2>/dev/null || true
        log "INFO" "Created registry file for ${component}"
    fi
}

# Read component list from Makefile
get_components_from_makefile() {
    log "INFO" "Reading components from Makefile..."
    local components=()
    
    # Extract component targets from Makefile
    if [ -f "${ROOT_DIR}/Makefile" ]; then
        # Get all targets that look like component installation commands
        local targets=$(grep -E '^[a-zA-Z0-9_-]+:' "${ROOT_DIR}/Makefile" | 
                       grep -v '^\.' | 
                       cut -d':' -f1 | 
                       grep -v -E '(help|install|update|clean|backup|env-check|prep-dirs)' |
                       sort | uniq)
        
        # Extract component names (those without dash)
        for target in $targets; do
            if [[ ! "$target" =~ -.*$ ]]; then
                components+=("$target")
            fi
        done
        
        if [ "$VERBOSE" = true ]; then
            log "INFO" "Found ${#components[@]} components in Makefile"
        fi
    else
        log "ERROR" "Makefile not found in ${ROOT_DIR}"
        exit 1
    fi
    
    echo "${components[@]}"
}

# Main execution
log "INFO" "Starting AgencyStack component directory setup..."
create_base_directories

components=($(get_components_from_makefile))

# Common AgencyStack components that might not be in Makefile yet
standard_components=(
    "docker"
    "docker_compose"
    "traefik"
    "traefik_ssl"
    "portainer"
    "keycloak"
    "prometheus"
    "grafana"
    "loki"
    "wordpress"
    "ghost"
    "peertube"
    "focalboard"
    "seafile"
    "builderio"
    "vector_db"
    "ollama"
    "langchain"
    "ai_dashboard" 
    "agent_orchestrator"
    "resource_watcher"
)

# Combine and deduplicate components
all_components=($(echo "${components[@]} ${standard_components[@]}" | tr ' ' '\n' | sort | uniq))

# Process all components
for component in "${all_components[@]}"; do
    if [ "$VERBOSE" = true ]; then
        log "INFO" "Setting up component: ${component}"
    fi
    setup_component "$component"
done

log "INFO" "Created directories and placeholder files for ${#all_components[@]} components"
log "INFO" "Setup complete. Run 'make alpha-check' to verify."
