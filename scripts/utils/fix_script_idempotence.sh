#!/bin/bash
# fix_script_idempotence.sh - Adds idempotence checks to component installation scripts
#
# This utility script analyzes and fixes component installation scripts to ensure
# they follow the idempotence standards required by AgencyStack
#
# Usage: ./fix_script_idempotence.sh [--component component_name] [--all]

# DEPRECATION NOTICE: This script's logic should be migrated into component install scripts or common.sh as idempotent install logic. This script will be removed after migration is complete.

set -euo pipefail

# Import common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"

source "${SCRIPT_DIR}/common.sh"

# Parse arguments
COMPONENT=""
FIX_ALL=false
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --all)
            FIX_ALL=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --component NAME    Specify component name to fix"
            echo "  --all               Fix all component installation scripts"
            echo "  --verbose           Show detailed output"
            echo "  --dry-run           Show changes without applying them"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if component or --all is specified
if [[ -z "$COMPONENT" && "$FIX_ALL" != "true" ]]; then
    log_error "You must specify either --component or --all"
    exit 1
fi

# Function to check if script already has idempotence checks
has_idempotence_check() {
    local script_path="$1"
    
    # Look for common idempotence check patterns
    if grep -q "already installed" "$script_path" || 
       grep -q "\.installed_ok" "$script_path" || 
       grep -q "if \[\[ -d" "$script_path" && grep -q "exit 0" "$script_path"; then
        return 0  # Has idempotence checks
    else
        return 1  # No idempotence checks
    fi
}

# Function to add idempotence check to a script
add_idempotence_check() {
    local script_path="$1"
    local component_name="$2"
    local temp_file="${script_path}.temp"
    
    # Extract current directory variables from the script
    local install_dir_var
    install_dir_var=$(grep -E "INSTALL_DIR=|install_dir=" "$script_path" | head -1 | cut -d '=' -f2- | tr -d '"')
    
    if [[ -z "$install_dir_var" ]]; then
        # If no INSTALL_DIR found, use default pattern
        install_dir_var="/opt/agency_stack/clients/\${CLIENT_ID:-default}/$component_name"
    fi
    
    # Create the idempotence check code block
    local idempotence_check="
# Check if already installed
if [[ -d $install_dir_var && -f \"${install_dir_var}/.installed_ok\" && \"\${FORCE:-false}\" != \"true\" ]]; then
    log_info \"$component_name is already installed. Use --force to reinstall.\"
    exit 0
fi
"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would add idempotence check to: $script_path"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${CYAN}${idempotence_check}${NC}"
        fi
        return 0
    fi
    
    # Find the right position to insert the check (after variable declarations, before main logic)
    local insertion_line
    
    # Try to find the log line showing installation start
    insertion_line=$(grep -n "Starting.*installation" "$script_path" | head -1 | cut -d':' -f1)
    
    if [[ -z "$insertion_line" ]]; then
        # If not found, look for first log_info or echo
        insertion_line=$(grep -n -E "log_info|echo" "$script_path" | head -1 | cut -d':' -f1)
    fi
    
    if [[ -z "$insertion_line" ]]; then
        # If still not found, insert after shebang and comments
        insertion_line=20
    fi
    
    # Create a new file with the idempotence check inserted
    head -n "$insertion_line" "$script_path" > "$temp_file"
    echo -e "$idempotence_check" >> "$temp_file"
    tail -n +$((insertion_line + 1)) "$script_path" >> "$temp_file"
    
    # Replace the original with the updated version
    mv "$temp_file" "$script_path"
    chmod +x "$script_path"
    
    log_success "Added idempotence check to: $script_path"
    return 0
}

# Function to add a marker at the end of a successful installation
add_installation_marker() {
    local script_path="$1"
    local temp_file="${script_path}.temp"
    
    # Look for the end of the script where success is indicated
    local success_line
    success_line=$(grep -n -E "installation completed successfully|completed successfully" "$script_path" | tail -1 | cut -d':' -f1)
    
    if [[ -z "$success_line" ]]; then
        # If not found, look for docker-compose up success
        success_line=$(grep -n -E "docker-compose up -d|docker compose up -d" "$script_path" | tail -1 | cut -d':' -f1)
    fi
    
    if [[ -z "$success_line" ]]; then
        log_warning "Could not find appropriate location to add installation marker in: $script_path"
        return 1
    fi
    
    # Extract install directory from the script
    local install_dir_var
    install_dir_var=$(grep -E "INSTALL_DIR=|install_dir=" "$script_path" | head -1 | cut -d '=' -f2- | tr -d '"')
    
    if [[ -z "$install_dir_var" ]]; then
        # If no INSTALL_DIR found, use default pattern
        local component_name=$(basename "$script_path" | sed 's/install_//' | sed 's/\.sh//')
        install_dir_var="/opt/agency_stack/clients/\${CLIENT_ID:-default}/$component_name"
    fi
    
    # Create the marker code
    local marker_code="
    # Mark as installed
    touch \"${install_dir_var}/.installed_ok\"
"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would add installation marker to: $script_path"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${CYAN}${marker_code}${NC}"
        fi
        return 0
    fi
    
    # Check if the marker already exists
    if grep -q "\.installed_ok" "$script_path"; then
        log_info "Installation marker already exists in: $script_path"
        return 0
    fi
    
    # Create a new file with the marker inserted
    head -n "$success_line" "$script_path" > "$temp_file"
    echo -e "$marker_code" >> "$temp_file"
    tail -n +$((success_line + 1)) "$script_path" >> "$temp_file"
    
    # Replace the original with the updated version
    mv "$temp_file" "$script_path"
    chmod +x "$script_path"
    
    log_success "Added installation marker to: $script_path"
    return 0
}

# Function to add FORCE parameter to a script
add_force_parameter() {
    local script_path="$1"
    local temp_file="${script_path}.temp"
    
    # Check if FORCE is already a parameter
    if grep -q "FORCE=" "$script_path"; then
        log_info "FORCE parameter already exists in: $script_path"
        return 0
    fi
    
    # Find the parameter parsing section
    local param_section
    param_section=$(grep -n -A 20 "while \[\[ \$# -gt 0 \]\]" "$script_path" | head -1 | cut -d':' -f1)
    
    if [[ -z "$param_section" ]]; then
        log_warning "Could not find parameter section in: $script_path"
        return 1
    fi
    
    # Find the default variables section
    local default_section
    default_section=$(grep -n -E "(# Default|# Variables)" "$script_path" | head -1 | cut -d':' -f1)
    
    if [[ -z "$default_section" ]]; then
        log_warning "Could not find default variables section in: $script_path"
        return 1
    fi
    
    # Add FORCE to default variables
    local force_var="FORCE=false"
    
    # Add FORCE to parameter parsing
    local force_param="        --force)
            FORCE=true
            shift
            ;;"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would add FORCE parameter to: $script_path"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "Add to defaults: ${CYAN}${force_var}${NC}"
            echo -e "Add to parameters: ${CYAN}${force_param}${NC}"
        fi
        return 0
    fi
    
    # Add to defaults
    sed -i "$default_section a $force_var" "$script_path"
    
    # Find the right position to add the parameter
    local last_param
    last_param=$(grep -n -B 1 "\*)" "$script_path" | head -1 | cut -d'-' -f1)
    
    if [[ -z "$last_param" ]]; then
        log_warning "Could not find parameter parsing end in: $script_path"
        return 1
    fi
    
    # Add the force parameter
    sed -i "$last_param i $force_param" "$script_path"
    
    log_success "Added FORCE parameter to: $script_path"
    return 0
}

# Function to fix idempotence in a single script
fix_script_idempotence() {
    local script_path="$1"
    local component_name=$(basename "$script_path" | sed 's/install_//' | sed 's/\.sh//')
    
    log_info "Analyzing script: $script_path"
    
    # Check if script already has idempotence
    if has_idempotence_check "$script_path"; then
        log_info "Script already has idempotence checks: $script_path"
    else
        log_warning "Script lacks idempotence checks: $script_path"
        add_idempotence_check "$script_path" "$component_name"
    fi
    
    # Add installation marker if missing
    add_installation_marker "$script_path"
    
    # Add FORCE parameter if missing
    add_force_parameter "$script_path"
    
    log_success "Idempotence check completed for: $component_name"
    return 0
}

# Process specified component or all components
if [[ "$FIX_ALL" == "true" ]]; then
    log_info "Processing all component installation scripts..."
    
    find "$COMPONENTS_DIR" -name "install_*.sh" -not -name "install_prerequisites.sh" | while read -r script; do
        fix_script_idempotence "$script"
    done
    
    log_success "Completed idempotence fixes for all components"
else
    log_info "Processing component: $COMPONENT"
    
    script_path="${COMPONENTS_DIR}/install_${COMPONENT}.sh"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        exit 1
    fi
    
    fix_script_idempotence "$script_path"
    
    log_success "Completed idempotence fix for: $COMPONENT"
fi

# Summary
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run completed. No changes were made."
    echo -e "${YELLOW}To apply changes, run without the --dry-run flag${NC}"
else
    log_success "Idempotence fixes completed successfully"
    echo -e "${GREEN}Run 'make alpha-check' to verify fixed scripts${NC}"
fi

exit 0
