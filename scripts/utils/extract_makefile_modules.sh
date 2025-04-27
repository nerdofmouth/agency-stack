#!/bin/bash
# extract_makefile_modules.sh - Extracts component targets from main Makefile into modular files
# 
# This script analyzes the main Makefile and extracts component-specific sections,
# creating properly structured component makefiles in the appropriate location.
# 
# Usage: ./extract_makefile_modules.sh [component_name]
#
# If component_name is provided, only extract that specific component.
# Otherwise, extract all identifiable components.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="${REPO_ROOT}/Makefile"
MODULES_DIR="${REPO_ROOT}/makefiles/components"
DOC_PATH="${REPO_ROOT}/docs/pages/development/modular_makefile.md"

# Create the modules directory if it doesn't exist
mkdir -p "$MODULES_DIR"

# Define the help message
HELP_MSG="
Usage: $(basename "$0") [OPTIONS] [COMPONENT]

Extract component targets from main Makefile into modular files.

Options:
  -h, --help      Show this help message
  -f, --force     Overwrite existing module files
  -v, --verbose   Enable verbose output
  -d, --dry-run   Show what would be done without actually doing it

If COMPONENT is provided, only extract that specific component.
Otherwise, extract all identifiable components.

Example:
  $(basename "$0") wordpress    # Extract only WordPress targets
  $(basename "$0")              # Extract all component targets

Documentation:
  See ${DOC_PATH#${REPO_ROOT}/} for more information.
"

# Parse command line arguments
FORCE=false
VERBOSE=false
DRY_RUN=false
COMPONENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "$HELP_MSG"
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "$HELP_MSG"
            exit 1
            ;;
        *)
            if [[ -z "$COMPONENT" ]]; then
                COMPONENT="$1"
            else
                echo "Error: Too many arguments: $1" >&2
                echo "$HELP_MSG"
                exit 1
            fi
            shift
            ;;
    esac
done

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    case "$level" in
        info)
            echo -e "\033[0;32m[INFO]\033[0m $message"
            ;;
        warn)
            echo -e "\033[0;33m[WARN]\033[0m $message" >&2
            ;;
        error)
            echo -e "\033[0;31m[ERROR]\033[0m $message" >&2
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to check if a component makefile already exists
component_exists() {
    local component="$1"
    [[ -f "${MODULES_DIR}/${component}.mk" ]]
}

# Function to extract a specific target and its recipe
extract_target() {
    local target="$1"
    local output_file="$2"
    local tmp_file="/tmp/extract_target_$$"
    local line_count=0
    
    # Escape any regex special characters in the target name
    local escaped_target=$(echo "$target" | sed 's/[\/&]/\\&/g')
    
    # Capture the target and its recipe using grep with line numbers
    local start_line=$(grep -n "^${escaped_target}:" "$MAKEFILE" | cut -d: -f1)
    if [[ -z "$start_line" ]]; then
        log error "Could not find target: $target"
        return 1
    fi
    
    # Extract just the target line first
    sed -n "${start_line}p" "$MAKEFILE" > "${tmp_file}.target"
    
    # Now extract the recipe (indented lines following the target)
    awk -v start="$start_line" 'NR > start && /^\t/ {print} NR > start && !/^\t/ {exit}' "$MAKEFILE" > "${tmp_file}.recipe"
    
    # Combine them
    cat "${tmp_file}.target" "${tmp_file}.recipe" >> "$output_file"
    echo "" >> "$output_file" # Add a blank line after the recipe
    
    line_count=$(($(wc -l < "${tmp_file}.target") + $(wc -l < "${tmp_file}.recipe")))
    
    rm -f "${tmp_file}.target" "${tmp_file}.recipe"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log info "Extracted $line_count lines for target: $target"
    fi
}

# Function to extract all targets for a component
extract_component() {
    local component="$1"
    local output_file="${MODULES_DIR}/${component}.mk"
    local tmp_file="/tmp/extract_component_$$"
    local found=false
    local phony_targets=""
    
    # Check if the output file already exists and we're not forcing overwrite
    if component_exists "$component" && [[ "$FORCE" != "true" ]]; then
        log warn "Module file already exists for $component. Use --force to overwrite."
        return 0
    fi
    
    # Create a temp file for our module
    cat > "$tmp_file" <<EOF
# ${component^} component targets
# Auto-extracted from main Makefile by extract_makefile_modules.sh
# See docs/pages/development/modular_makefile.md for more information

EOF
    
    log info "Searching for ${component} targets in Makefile..."
    
    # Main target forms:
    # 1. component:
    # 2. install-component:
    if grep -q "^${component}:" "$MAKEFILE"; then
        log info "Found main target: ${component}"
        extract_target "${component}" "$tmp_file"
        found=true
        phony_targets="${component}"
    elif grep -q "^install-${component}:" "$MAKEFILE"; then
        log info "Found main target: install-${component}"
        extract_target "install-${component}" "$tmp_file"
        found=true
        phony_targets="install-${component}"
    fi
    
    # Extract hyphenated targets (component-*):
    for target in $(grep -E "^${component}-[a-zA-Z0-9_-]+:" "$MAKEFILE" | sed 's/:.*//' | sort); do
        log info "Found secondary target: ${target}"
        extract_target "${target}" "$tmp_file"
        phony_targets="${phony_targets} ${target}"
        found=true
    done
    
    # If we found any targets, add the .PHONY declaration and write the file
    if [[ "$found" == "true" ]]; then
        echo ".PHONY: ${phony_targets}" >> "$tmp_file"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log info "Would write module file: $output_file"
            if [[ "$VERBOSE" == "true" ]]; then
                log info "Content:"
                cat "$tmp_file"
            fi
        else
            mkdir -p "$(dirname "$output_file")"
            mv "$tmp_file" "$output_file"
            log info "Created module file: $output_file"
        fi
    else
        log warn "No targets found for component: $component"
        rm -f "$tmp_file"
    fi
}

# Function to find all component targets in the Makefile
find_components() {
    local components=()
    
    # Pattern 1: component:
    while IFS= read -r line; do
        component=${line%:}
        # Filter out common non-component targets
        if [[ ! "$component" =~ ^(help|all|clean|install|update|validate|setup|deploy|test) ]]; then
            components+=("$component")
        fi
    done < <(grep -E '^[a-zA-Z0-9_-]+:' "$MAKEFILE" | grep -v -E '^[a-zA-Z0-9_-]+-[a-zA-Z0-9_-]+:' | sed 's/:.*$/:/g')
    
    # Pattern 2: install-component:
    while IFS= read -r line; do
        install_component=${line#install-}
        install_component=${install_component%:}
        components+=("$install_component")
    done < <(grep -E '^install-[a-zA-Z0-9_-]+:' "$MAKEFILE" | sed 's/:.*$/:/g')
    
    # De-duplicate the list
    printf '%s\n' "${components[@]}" | sort -u
}

# Main logic
if [[ -n "$COMPONENT" ]]; then
    # Extract a specific component
    extract_component "$COMPONENT"
else
    # Extract all components
    log info "Scanning Makefile for component targets..."
    components=($(find_components))
    
    if [[ "${#components[@]}" -eq 0 ]]; then
        log error "No component targets found in Makefile."
        exit 1
    fi
    
    log info "Found ${#components[@]} components to extract."
    
    for component in "${components[@]}"; do
        extract_component "$component"
    done
    
    log info "Extraction complete. See $MODULES_DIR for extracted modules."
    log info "Next steps:"
    log info "1. Review the extracted modules for correctness"
    log info "2. Ensure the main Makefile includes: -include makefiles/components/*.mk"
    log info "3. Test that 'make <component>' still works as expected"
    log info "4. Refer to ${DOC_PATH#${REPO_ROOT}/} for more information"
fi

# Clean up
if [[ -f "$tmp_file" ]]; then
    rm "$tmp_file"
fi
