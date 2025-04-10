#!/bin/bash
# component_validator.sh
# Validates all demo-core components against AgencyStack Alpha Phase Repository Integrity Policy

# Define colors for output
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# Define repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

# Load component list from demo-core-targets.mk
DEMO_CORE_COMPONENTS=(keycloak traefik dashboard posthog prometheus grafana mailu chatwoot voip wordpress peertube builderio calcom documenso erpnext focalboard gitea droneci)

# Analysis results variables
TOTAL_COMPONENTS=0
PASSED_COMPONENTS=0
FAILED_COMPONENTS=0
WARNINGS=0

# Initialize results file
RESULTS_FILE="${REPO_ROOT}/demo-core-validation.md"
echo "# AgencyStack Demo-Core Components Validation" > "$RESULTS_FILE"
echo "Generated: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "## Summary" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "| Component | Install Script | Makefile Targets | Documentation | Component Registry | .installed_ok Path | Validation |" >> "$RESULTS_FILE"
echo "|-----------|----------------|-----------------|---------------|-------------------|-------------------|------------|" >> "$RESULTS_FILE"

# Function to check if a file exists
check_file_exists() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}Found${RESET}"
        return 0
    else
        echo -e "${RED}Missing${RESET}"
        return 1
    fi
}

# Function to check if a string exists in a file
check_string_in_file() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}Found${RESET}"
        return 0
    else
        echo -e "${RED}Missing${RESET}"
        return 1
    fi
}

# Function to check if a component exists in the registry
check_component_in_registry() {
    local component="$1"
    local registry_file="${REPO_ROOT}/config/registry/component_registry.json"
    
    if [ ! -f "$registry_file" ]; then
        echo -e "${RED}Registry Missing${RESET}"
        return 1
    fi
    
    if grep -q "\"$component\":" "$registry_file"; then
        echo -e "${GREEN}Registered${RESET}"
        return 0
    else
        echo -e "${RED}Not in Registry${RESET}"
        return 1
    fi
}

# Function to validate a component
validate_component() {
    local component="$1"
    local status="✅ Pass"
    local issues=0
    local warnings=0
    
    echo -e "\n${BOLD}Validating ${CYAN}$component${RESET}"
    
    # Check install script
    echo -n "  Install script: "
    local install_script="${REPO_ROOT}/scripts/components/install_${component}.sh"
    if ! check_file_exists "$install_script"; then
        status="❌ Fail"
        ((issues++))
    fi
    
    # Check Makefile targets
    echo -n "  Makefile targets: "
    local primary_target_found=false
    local status_target_found=false
    local logs_target_found=false
    local restart_target_found=false
    
    if grep -q "^$component:" "${REPO_ROOT}/Makefile" || grep -q "^install-$component:" "${REPO_ROOT}/Makefile"; then
        primary_target_found=true
    fi
    
    if grep -q "^$component-status:" "${REPO_ROOT}/Makefile"; then
        status_target_found=true
    fi
    
    if grep -q "^$component-logs:" "${REPO_ROOT}/Makefile"; then
        logs_target_found=true
    fi
    
    if grep -q "^$component-restart:" "${REPO_ROOT}/Makefile"; then
        restart_target_found=true
    fi
    
    if $primary_target_found && $status_target_found && $logs_target_found && $restart_target_found; then
        echo -e "${GREEN}Complete${RESET}"
    elif $primary_target_found && $status_target_found; then
        echo -e "${YELLOW}Partial${RESET}"
        ((warnings++))
    else
        echo -e "${RED}Incomplete${RESET}"
        status="❌ Fail"
        ((issues++))
    fi
    
    # Check documentation
    echo -n "  Documentation: "
    local doc_file="${REPO_ROOT}/docs/pages/components/${component}.md"
    if ! check_file_exists "$doc_file"; then
        status="❌ Fail"
        ((issues++))
    fi
    
    # Check component registry
    echo -n "  Component registry: "
    if ! check_component_in_registry "$component"; then
        status="❌ Fail"
        ((issues++))
    fi
    
    # Check installed_ok path definition
    echo -n "  .installed_ok path: "
    if [ -f "$install_script" ]; then
        if grep -q "\.installed_ok" "$install_script"; then
            echo -e "${GREEN}Defined${RESET}"
        else
            echo -e "${RED}Missing${RESET}"
            status="❌ Fail"
            ((issues++))
        fi
    else
        echo -e "${RED}Script Missing${RESET}"
        status="❌ Fail"
        ((issues++))
    fi
    
    # Add to summary table
    local install_status="${GREEN}✓${RESET}"
    local makefile_status="${GREEN}✓${RESET}"
    local doc_status="${GREEN}✓${RESET}"
    local registry_status="${GREEN}✓${RESET}"
    local installed_ok_status="${GREEN}✓${RESET}"
    
    [ ! -f "$install_script" ] && install_status="${RED}✗${RESET}"
    if ! $primary_target_found || ! $status_target_found; then
        makefile_status="${RED}✗${RESET}"
    elif ! $logs_target_found || ! $restart_target_found; then
        makefile_status="${YELLOW}⚠${RESET}"
    fi
    [ ! -f "$doc_file" ] && doc_status="${RED}✗${RESET}"
    check_component_in_registry "$component" > /dev/null || registry_status="${RED}✗${RESET}"
    if [ -f "$install_script" ]; then
        grep -q "\.installed_ok" "$install_script" > /dev/null || installed_ok_status="${RED}✗${RESET}"
    else
        installed_ok_status="${RED}✗${RESET}"
    fi
    
    # For markdown output
    local md_install_status="✓"
    local md_makefile_status="✓"
    local md_doc_status="✓"
    local md_registry_status="✓"
    local md_installed_ok_status="✓"
    local md_status="✅ Pass"
    
    [ ! -f "$install_script" ] && md_install_status="❌"
    if ! $primary_target_found || ! $status_target_found; then
        md_makefile_status="❌"
    elif ! $logs_target_found || ! $restart_target_found; then
        md_makefile_status="⚠️"
    fi
    [ ! -f "$doc_file" ] && md_doc_status="❌"
    check_component_in_registry "$component" > /dev/null || md_registry_status="❌"
    if [ -f "$install_script" ]; then
        grep -q "\.installed_ok" "$install_script" > /dev/null || md_installed_ok_status="❌"
    else
        md_installed_ok_status="❌"
    fi
    
    if [ "$status" = "❌ Fail" ]; then
        md_status="❌ Fail"
    elif [ $warnings -gt 0 ]; then
        md_status="⚠️ Warning"
    fi
    
    echo "| $component | $md_install_status | $md_makefile_status | $md_doc_status | $md_registry_status | $md_installed_ok_status | $md_status |" >> "$RESULTS_FILE"
    
    # Increment counters
    ((TOTAL_COMPONENTS++))
    if [ "$status" = "✅ Pass" ]; then
        ((PASSED_COMPONENTS++))
    else
        ((FAILED_COMPONENTS++))
    fi
    WARNINGS=$((WARNINGS + warnings))
    
    echo -e "  ${BOLD}Result:${RESET} $status"
    
    # Return success if no issues, otherwise failure
    return $issues
}

# Validate all components
echo -e "${BOLD}${CYAN}AgencyStack Demo-Core Components Validation${RESET}\n"
echo -e "${BOLD}Following AgencyStack Alpha Phase Repository Integrity Policy${RESET}\n"

for component in "${DEMO_CORE_COMPONENTS[@]}"; do
    validate_component "$component"
    echo ""
done

# Update summary section with counts
echo -e "\n${BOLD}Validation Summary:${RESET}"
echo -e "  Total components: ${BOLD}${TOTAL_COMPONENTS}${RESET}"
echo -e "  Passed: ${GREEN}${PASSED_COMPONENTS}${RESET}"
echo -e "  Failed: ${RED}${FAILED_COMPONENTS}${RESET}"
echo -e "  Warnings: ${YELLOW}${WARNINGS}${RESET}"

# Update the results file
sed -i "4s/.*$/Total: ${TOTAL_COMPONENTS} | Passed: ${PASSED_COMPONENTS} | Failed: ${FAILED_COMPONENTS} | Warnings: ${WARNINGS}/" "$RESULTS_FILE"

echo -e "\n${BOLD}Detailed results saved to:${RESET} ${CYAN}${RESULTS_FILE}${RESET}"

# Exit with appropriate code
if [ $FAILED_COMPONENTS -gt 0 ]; then
    exit 1
else
    exit 0
fi
