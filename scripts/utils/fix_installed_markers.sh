#!/bin/bash
# fix_installed_markers.sh
# Adds proper .installed_ok marker creation to all component installation scripts

# Define colors for output
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# Define repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

# List of components to check and fix
COMPONENTS=(keycloak prometheus grafana chatwoot voip wordpress peertube posthog builderio calcom documenso erpnext focalboard gitea droneci)

# Counter for stats
FIXED_COUNT=0
ALREADY_GOOD=0
MISSING=0

echo -e "${BOLD}${CYAN}AgencyStack .installed_ok Marker Standardization${RESET}\n"
echo -e "${BOLD}Following AgencyStack Alpha Phase Repository Integrity Policy${RESET}\n"

# Function to fix a component script
fix_component_script() {
    local component="$1"
    local install_script="${REPO_ROOT}/scripts/components/install_${component}.sh"
    
    if [ ! -f "$install_script" ]; then
        echo -e "${RED}✗ Script for $component not found${RESET}"
        ((MISSING++))
        return 1
    fi
    
    echo -n "Checking $component... "
    
    # Check if script already calls mark_installed
    if grep -q "mark_installed" "$install_script"; then
        echo -e "${GREEN}✓ Already uses mark_installed()${RESET}"
        ((ALREADY_GOOD++))
        return 0
    fi
    
    # Check if script creates .installed_ok directly
    if grep -q "\.installed_ok" "$install_script"; then
        echo -e "${YELLOW}⚠ Uses direct .installed_ok creation, standardizing...${RESET}"
    else
        echo -e "${RED}✗ No .installed_ok marker creation found, adding...${RESET}"
    fi
    
    # Create backup
    cp "$install_script" "${install_script}.bak"
    
    # Find appropriate spot to add mark_installed
    # Usually after main installation logic but before final success message
    if grep -q "SUCCESS.*installation completed" "$install_script"; then
        # Add before success message
        sed -i '/SUCCESS.*installation completed/i \
    # Mark component as installed\
    mark_installed "'$component'" "${COMPONENT_DIR}"\
        ' "$install_script"
    elif grep -q "log_success" "$install_script"; then
        # Add before the first log_success call
        sed -i '/log_success/i \
    # Mark component as installed\
    mark_installed "'$component'" "${COMPONENT_DIR}"\
        ' "$install_script"
    else
        # Add at the end of the script, before the return statement
        sed -i '/return 0/i \
# Mark component as installed\
mark_installed "'$component'" "${COMPONENT_DIR}"\
        ' "$install_script"
    fi
    
    # Ensure common.sh is sourced
    if ! grep -q "source.*common.sh" "$install_script"; then
        sed -i '2i \
# Source common utilities\
source "$(dirname "$0")/../utils/common.sh"\
        ' "$install_script"
    fi
    
    echo -e "${GREEN}✓ Fixed${RESET}"
    ((FIXED_COUNT++))
    return 0
}

# Main function
main() {
    # First check if common.sh has the mark_installed function
    if ! grep -q "mark_installed()" "${REPO_ROOT}/scripts/utils/common.sh"; then
        echo -e "${RED}Error: mark_installed() function not found in common.sh${RESET}"
        exit 1
    fi
    
    # Process each component
    for component in "${COMPONENTS[@]}"; do
        fix_component_script "$component"
    done
    
    # Output summary
    echo -e "\n${BOLD}Summary:${RESET}"
    echo -e "  Components processed: ${BOLD}${#COMPONENTS[@]}${RESET}"
    echo -e "  Already standardized: ${GREEN}${ALREADY_GOOD}${RESET}"
    echo -e "  Fixed: ${CYAN}${FIXED_COUNT}${RESET}"
    echo -e "  Missing scripts: ${RED}${MISSING}${RESET}"
    
    if [ $FIXED_COUNT -gt 0 ]; then
        echo -e "\n${YELLOW}Installation scripts have been modified. Backup files created with .bak extension.${RESET}"
        echo -e "${CYAN}Changes were made to add proper .installed_ok marker creation via mark_installed() function.${RESET}"
        echo -e "${CYAN}This standardizes component status reporting across the platform.${RESET}"
    fi
    
    echo -e "\n${BOLD}Next steps:${RESET}"
    echo -e "1. Review the changes with ${CYAN}git diff${RESET}"
    echo -e "2. Test the fixed components with ${CYAN}make <component>${RESET}"
    echo -e "3. Verify status with ${CYAN}make <component>-status${RESET}"
    echo -e "4. Commit the changes if the tests pass"
    
    # Check documentation for PostHog
    if [[ ! -f "${REPO_ROOT}/docs/pages/components/posthog.md" ]]; then
        echo -e "\n${YELLOW}Note: PostHog documentation is missing${RESET}"
        echo -e "Create ${CYAN}${REPO_ROOT}/docs/pages/components/posthog.md${RESET} with proper documentation"
    fi
    
    # Return success
    return 0
}

# Execute main function
main "$@"
exit $?
