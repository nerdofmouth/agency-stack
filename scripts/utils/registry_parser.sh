#!/bin/bash
# registry_parser.sh - Extracts valid components and metadata from registry
#
# Provides functions to read and parse component_registry.json
# Usage: source "$(dirname "$0")/../utils/registry_parser.sh"

set -euo pipefail

# Import common utilities if not already sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(type -t log_info)" != "function" ]]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Default registry file
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DEFAULT_REGISTRY_FILE="${ROOT_DIR}/config/registry/component_registry.json"

# Get a list of all registered components
get_registered_components() {
    local registry_file="${1:-$DEFAULT_REGISTRY_FILE}"
    local categories="${2:-}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    if [[ -z "$categories" ]]; then
        # Get all components from all categories
        jq -r '.components | to_entries[] | .value[] | .name' "$registry_file" 2>/dev/null
    else
        # Get components from specific categories
        local IFS=','
        read -ra category_array <<< "$categories"
        
        for category in "${category_array[@]}"; do
            jq -r ".components.\"$category\" | to_entries[] | .value | .name" "$registry_file" 2>/dev/null
        done
    fi
}

# Check if a component exists in the registry
component_exists() {
    local component="$1"
    local registry_file="${2:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    # Search for the component in all categories
    local count
    count=$(jq -r --arg comp "$component" '.components | to_entries[] | .value[] | select(.name == $comp) | .name' "$registry_file" 2>/dev/null | wc -l)
    
    if [[ $count -gt 0 ]]; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

# Get component category
get_component_category() {
    local component="$1"
    local registry_file="${2:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r --arg comp "$component" '.components | to_entries[] | select(.value | to_entries[] | .value | .name == $comp) | .key' "$registry_file" 2>/dev/null
}

# Get component description
get_component_description() {
    local component="$1"
    local registry_file="${2:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r --arg comp "$component" '.components | to_entries[] | .value[] | select(.name == $comp) | .description' "$registry_file" 2>/dev/null
}

# Get component flag value
get_component_flag() {
    local component="$1"
    local flag="$2"
    local registry_file="${3:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r --arg comp "$component" --arg flag "$flag" '.components | to_entries[] | .value[] | select(.name == $comp) | .integration_status[$flag]' "$registry_file" 2>/dev/null
}

# Get all components with a specific flag set to true
get_components_with_flag() {
    local flag="$1"
    local registry_file="${2:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r --arg flag "$flag" '.components | to_entries[] | .value[] | select(.integration_status[$flag] == true) | .name' "$registry_file" 2>/dev/null
}

# Get registry version
get_registry_version() {
    local registry_file="${1:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r '.schema_version' "$registry_file" 2>/dev/null
}

# Get registry last update timestamp
get_registry_last_updated() {
    local registry_file="${1:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r '.last_updated' "$registry_file" 2>/dev/null
}

# List all available categories
get_categories() {
    local registry_file="${1:-$DEFAULT_REGISTRY_FILE}"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Registry file not found: $registry_file"
        return 1
    fi
    
    jq -r '.components | keys[]' "$registry_file" 2>/dev/null
}

# Usage example
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Registry Parser for AgencyStack"
    echo "=============================="
    
    # Parse command line arguments
    ACTION=""
    COMPONENT=""
    FLAG=""
    REGISTRY="${DEFAULT_REGISTRY_FILE}"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list)
                ACTION="list"
                shift
                ;;
            --component)
                COMPONENT="$2"
                shift 2
                ;;
            --flag)
                FLAG="$2"
                shift 2
                ;;
            --category)
                CATEGORY="$2"
                shift 2
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $(basename "$0") [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --list                List all components"
                echo "  --component NAME      Specify component name"
                echo "  --flag FLAG           Specify flag name"
                echo "  --category CATEGORY   Specify category name"
                echo "  --registry PATH       Specify registry file path"
                echo "  --help                Show this help message"
                echo ""
                echo "Examples:"
                echo "  $(basename "$0") --list"
                echo "  $(basename "$0") --component wordpress --flag installed"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute requested action
    if [[ "$ACTION" == "list" ]]; then
        echo "Registered components:"
        get_registered_components "$REGISTRY"
    elif [[ -n "$COMPONENT" && -n "$FLAG" ]]; then
        echo "Flag '$FLAG' for component '$COMPONENT':"
        get_component_flag "$COMPONENT" "$FLAG" "$REGISTRY"
    elif [[ -n "$COMPONENT" ]]; then
        echo "Component: $COMPONENT"
        if component_exists "$COMPONENT" "$REGISTRY"; then
            echo "Category: $(get_component_category "$COMPONENT" "$REGISTRY")"
            echo "Description: $(get_component_description "$COMPONENT" "$REGISTRY")"
        else
            echo "Component not found in registry"
        fi
    else
        echo "No action specified. Use --help for usage information."
    fi
fi
