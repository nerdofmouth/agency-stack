#!/bin/bash
# =============================================================================
# generate_alpha_status.sh
# 
# Generates a status report for AgencyStack Alpha release readiness
# =============================================================================

set -e

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"
BOLD="\033[1m"

# Directories
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
COMPONENTS_DIR="${SCRIPTS_DIR}/components"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"
MAKEFILE="${ROOT_DIR}/Makefile"
OUTPUT_MD="${ROOT_DIR}/docs/pages/components/alpha_ready.md"

# Create directories if they don't exist
mkdir -p "$(dirname "$OUTPUT_MD")"

# Date and time
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")

# Stats
FULLY_INTEGRATED=0
PARTIALLY_INTEGRATED=0
MISSING_INTEGRATION=0
TOTAL_COMPONENTS=0

# Arrays for component tracking
FULL_COMPONENTS=()
PARTIAL_COMPONENTS=()
MISSING_COMPONENTS=()
COMPONENT_ISSUES=()

# Extract component ID from install script name
extract_component_id() {
    local script_name="$1"
    echo "${script_name#install_}" | sed 's/\.sh$//'
}

# Check if a component is in the registry
check_registry() {
    local comp_id="$1"
    
    # Check if component exists as a key in any category
    if jq -e ".components[][] | select(has(\"$comp_id\"))" "$REGISTRY_FILE" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check if component exists with component_id field
    if jq -e ".components[][][] | select(.component_id == \"$comp_id\")" "$REGISTRY_FILE" >/dev/null 2>&1; then
        return 0
    fi
    
    # Try hyphenated version of the component ID (resource_watcher -> resource-watcher)
    local hyphenated_id="${comp_id//_/-}"
    if [[ "$hyphenated_id" != "$comp_id" ]]; then
        if jq -e ".components[][] | select(has(\"$hyphenated_id\"))" "$REGISTRY_FILE" >/dev/null 2>&1; then
            return 0
        fi
        
        if jq -e ".components[][][] | select(.component_id == \"$hyphenated_id\")" "$REGISTRY_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Check registry flags
check_registry_flags() {
    local comp_id="$1"
    local missing_flags=()
    
    # Find the JSON path to the component
    local category=""
    local subcategory=""
    
    # First, check for direct component as a key
    for cat in $(jq -r '.components | keys[]' "$REGISTRY_FILE"); do
        for subcat in $(jq -r ".components.\"$cat\" | keys[]" "$REGISTRY_FILE"); do
            if [ "$subcat" = "$comp_id" ]; then
                category="$cat"
                subcategory="$comp_id"
                break
            fi
        done
        [ -n "$category" ] && break
    done
    
    # If not found, check for component_id field
    if [ -z "$category" ]; then
        for cat in $(jq -r '.components | keys[]' "$REGISTRY_FILE"); do
            for subcat in $(jq -r ".components.\"$cat\" | keys[]" "$REGISTRY_FILE"); do
                if jq -e ".components.\"$cat\".\"$subcat\".component_id == \"$comp_id\"" "$REGISTRY_FILE" >/dev/null 2>&1; then
                    category="$cat"
                    subcategory="$subcat"
                    break
                fi
            done
            [ -n "$category" ] && break
        done
    fi
    
    if [ -z "$category" ]; then
        echo "Not found in registry"
        return
    fi
    
    # Check required flags
    local flags=(
        "installed"
        "hardened"
        "makefile"
        "dashboard"
        "logs"
        "docs"
        "auditable"
    )
    
    for flag in "${flags[@]}"; do
        if ! jq -e ".components.\"$category\".\"$subcategory\".integration_status.\"$flag\"" "$REGISTRY_FILE" >/dev/null 2>&1 || \
           [ "$(jq -r ".components.\"$category\".\"$subcategory\".integration_status.\"$flag\"" "$REGISTRY_FILE")" != "true" ]; then
            missing_flags+=("$flag")
        fi
    done
    
    # Check desired flags
    local desired_flags=(
        "sso"
        "traefik_tls"
        "multi_tenant"
    )
    
    for flag in "${desired_flags[@]}"; do
        if ! jq -e ".components.\"$category\".\"$subcategory\".integration_status.\"$flag\"" "$REGISTRY_FILE" >/dev/null 2>&1 || \
           [ "$(jq -r ".components.\"$category\".\"$subcategory\".integration_status.\"$flag\"" "$REGISTRY_FILE")" != "true" ]; then
            missing_flags+=("$flag (optional)")
        fi
    done
    
    # Check for required fields
    local required_fields=(
        "name"
        "category"
        "version"
        "description"
    )
    
    for field in "${required_fields[@]}"; do
        if ! jq -e ".components.\"$category\".\"$subcategory\".\"$field\"" "$REGISTRY_FILE" >/dev/null 2>&1; then
            missing_flags+=("Missing field: $field")
        fi
    done
    
    if [ ${#missing_flags[@]} -eq 0 ]; then
        echo "All flags present"
    else
        IFS=", "
        echo "Missing flags: ${missing_flags[*]}"
        unset IFS
    fi
}

# Check Makefile targets
check_makefile_targets() {
    local comp_id="$1"
    local missing_targets=()
    
    # Try both underscore and hyphen versions of targets
    local alt_comp_id="${comp_id//_/-}"
    
    # Required targets - check both formats
    local targets=(
        "$comp_id"
        "$comp_id-status"
        "$comp_id-logs"
        "$comp_id-restart"
    )
    
    if [[ "$alt_comp_id" != "$comp_id" ]]; then
        alt_targets=(
            "$alt_comp_id"
            "$alt_comp_id-status"
            "$alt_comp_id-logs"
            "$alt_comp_id-restart"
        )
    fi
    
    for target in "${targets[@]}"; do
        alt_target="${target//$comp_id/$alt_comp_id}"
        if ! grep -q "^$target:" "$MAKEFILE" && ! grep -q "^$alt_target:" "$MAKEFILE"; then
            missing_targets+=("$target")
        fi
    done
    
    # Optional targets
    local optional_targets=(
        "$comp_id-backup"
        "$comp_id-config"
        "$comp_id-test"
    )
    
    if [[ "$alt_comp_id" != "$comp_id" ]]; then
        alt_optional_targets=(
            "$alt_comp_id-backup"
            "$alt_comp_id-config"
            "$alt_comp_id-test"
        )
    fi
    
    for target in "${optional_targets[@]}"; do
        alt_target="${target//$comp_id/$alt_comp_id}"
        if ! grep -q "^$target:" "$MAKEFILE" && ! grep -q "^$alt_target:" "$MAKEFILE"; then
            missing_targets+=("$target (optional)")
        fi
    done
    
    if [ ${#missing_targets[@]} -eq 0 ]; then
        echo "All targets present"
    else
        IFS=", "
        echo "Missing targets: ${missing_targets[*]}"
        unset IFS
    fi
}

# Check documentation
check_documentation() {
    local comp_id="$1"
    local missing_docs=()
    local alt_comp_id="${comp_id//_/-}"
    
    # Check for component documentation (try both formats)
    local doc_file="${ROOT_DIR}/docs/pages/components/${comp_id}.md"
    local alt_doc_file="${ROOT_DIR}/docs/pages/components/${alt_comp_id}.md"
    
    if [ ! -f "$doc_file" ] && [ ! -f "$alt_doc_file" ]; then
        missing_docs+=("No dedicated documentation file")
    fi
    
    # Check for mentions in components.md (try both formats)
    if [ -f "${ROOT_DIR}/docs/pages/components.md" ]; then
        if ! grep -q "$comp_id" "${ROOT_DIR}/docs/pages/components.md" && ! grep -q "$alt_comp_id" "${ROOT_DIR}/docs/pages/components.md"; then
            missing_docs+=("Not listed in components.md")
        fi
    fi
    
    # Check for ports documentation (try both formats)
    if [ -f "${ROOT_DIR}/docs/pages/ports.md" ]; then
        if ! grep -q "$comp_id" "${ROOT_DIR}/docs/pages/ports.md" && ! grep -q "$alt_comp_id" "${ROOT_DIR}/docs/pages/ports.md"; then
            missing_docs+=("Not listed in ports.md")
        fi
    fi
    
    # Also check in the ai directory for AI components
    if [[ "$comp_id" == *"ai"* || "$comp_id" == "ollama" || "$comp_id" == "langchain" || "$comp_id" == "resource_watcher" || "$comp_id" == "agent_orchestrator" ]]; then
        local ai_doc_file="${ROOT_DIR}/docs/pages/ai/${comp_id}.md"
        local alt_ai_doc_file="${ROOT_DIR}/docs/pages/ai/${alt_comp_id}.md"
        
        if [ -f "$ai_doc_file" ] || [ -f "$alt_ai_doc_file" ]; then
            # Remove the "No dedicated documentation file" message if it exists
            for i in "${!missing_docs[@]}"; do
                if [[ "${missing_docs[$i]}" == "No dedicated documentation file" ]]; then
                    unset 'missing_docs[$i]'
                    break
                fi
            done
        fi
    fi
    
    if [ ${#missing_docs[@]} -eq 0 ]; then
        echo "Documentation present"
    else
        IFS=", "
        echo "Documentation issues: ${missing_docs[*]}"
        unset IFS
    fi
}

# Start the report header
echo "# AgencyStack Alpha Release Component Status" > "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "**Generated:** $CURRENT_DATE at $CURRENT_TIME" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "This document provides the current status of all AgencyStack components for the Alpha release milestone." >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

# Find all installation scripts
echo -e "${CYAN}${BOLD}Finding installation scripts...${RESET}"
mapfile -t INSTALL_SCRIPTS < <(find "$COMPONENTS_DIR" -name "install_*.sh" -type f -printf "%f\n")
TOTAL_COMPONENTS=${#INSTALL_SCRIPTS[@]}

echo -e "${CYAN}${BOLD}Found $TOTAL_COMPONENTS installation scripts${RESET}"
echo -e "${CYAN}${BOLD}Analyzing each component for Alpha readiness...${RESET}"
echo ""

# Process each component
for script in "${INSTALL_SCRIPTS[@]}"; do
    comp_id=$(extract_component_id "$script")
    echo -e "${BOLD}Analyzing component: $comp_id${RESET}"
    
    issues=()
    
    # Check registry entry
    echo -n "  Registry: "
    if check_registry "$comp_id"; then
        echo -e "${GREEN}✓ Present${RESET}"
        
        # Check registry flags
        registry_flags=$(check_registry_flags "$comp_id")
        echo -n "  Registry Flags: "
        if [[ "$registry_flags" == "All flags present" ]]; then
            echo -e "${GREEN}✓ All required flags present${RESET}"
        else
            echo -e "${YELLOW}! $registry_flags${RESET}"
            issues+=("$registry_flags")
        fi
    else
        echo -e "${RED}✗ Missing${RESET}"
        issues+=("Not in component registry")
    fi
    
    # Check Makefile targets
    makefile_targets=$(check_makefile_targets "$comp_id")
    echo -n "  Makefile Targets: "
    if [[ "$makefile_targets" == "All targets present" ]]; then
        echo -e "${GREEN}✓ All required targets present${RESET}"
    else
        echo -e "${YELLOW}! $makefile_targets${RESET}"
        issues+=("$makefile_targets")
    fi
    
    # Check documentation
    doc_status=$(check_documentation "$comp_id")
    echo -n "  Documentation: "
    if [[ "$doc_status" == "Documentation present" ]]; then
        echo -e "${GREEN}✓ Documentation complete${RESET}"
    else
        echo -e "${YELLOW}! $doc_status${RESET}"
        issues+=("$doc_status")
    fi
    
    # Determine overall status
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✅ FULLY INTEGRATED${RESET}"
        FULL_COMPONENTS+=("$comp_id")
        ((FULLY_INTEGRATED++))
    elif [[ " ${issues[*]} " == *"Not in component registry"* ]]; then
        echo -e "  ${RED}${BOLD}❌ MISSING INTEGRATION${RESET}"
        MISSING_COMPONENTS+=("$comp_id")
        ((MISSING_INTEGRATION++))
    else
        echo -e "  ${YELLOW}${BOLD}🔶 PARTIALLY INTEGRATED${RESET}"
        PARTIAL_COMPONENTS+=("$comp_id")
        ((PARTIALLY_INTEGRATED++))
    fi
    
    # Store issues for report
    if [[ ${#issues[@]} -gt 0 ]]; then
        COMPONENT_ISSUES+=("$comp_id:${issues[*]}")
    fi
    
    echo ""
done

# Add summary to report
echo "## Summary" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "- **✅ Fully Integrated Components:** $FULLY_INTEGRATED" >> "$OUTPUT_MD"
echo "- **🔶 Partially Integrated Components:** $PARTIALLY_INTEGRATED" >> "$OUTPUT_MD"
echo "- **❌ Missing Integration:** $MISSING_INTEGRATION" >> "$OUTPUT_MD"
echo "- **Total Components:** $TOTAL_COMPONENTS" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

# Add fully integrated components
echo "## Component Status Details" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "### ✅ Fully Integrated Components" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "These components have all required registry entries, Makefile targets, and documentation:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

if [[ ${#FULL_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${FULL_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
    done
else
    echo "*No fully integrated components found.*" >> "$OUTPUT_MD"
fi

# Add partially integrated components
echo "" >> "$OUTPUT_MD"
echo "### 🔶 Partially Integrated Components" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "These components are partially integrated but missing some registry flags, Makefile targets, or documentation:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

if [[ ${#PARTIAL_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${PARTIAL_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add issues
        for entry in "${COMPONENT_ISSUES[@]}"; do
            if [[ "$entry" == "$comp:"* ]]; then
                issues="${entry#*:}"
                echo "  - $issues" >> "$OUTPUT_MD"
            fi
        done
    done
else
    echo "*No partially integrated components found.*" >> "$OUTPUT_MD"
fi

# Add missing integration components
echo "" >> "$OUTPUT_MD"
echo "### ❌ Missing Integration" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "These components are missing critical integration elements:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

if [[ ${#MISSING_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${MISSING_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add issues
        for entry in "${COMPONENT_ISSUES[@]}"; do
            if [[ "$entry" == "$comp:"* ]]; then
                issues="${entry#*:}"
                echo "  - $issues" >> "$OUTPUT_MD"
            fi
        done
    done
else
    echo "*No components with missing integration found.*" >> "$OUTPUT_MD"
fi

# Add remediation section
echo "" >> "$OUTPUT_MD"
echo "## Remediation Tasks" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

if [[ $PARTIALLY_INTEGRATED -gt 0 || $MISSING_INTEGRATION -gt 0 ]]; then
    echo "To achieve Alpha release readiness, the following tasks should be completed:" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    
    if [[ $MISSING_INTEGRATION -gt 0 ]]; then
        echo "### Registry Updates" >> "$OUTPUT_MD"
        echo "" >> "$OUTPUT_MD"
        echo "Add the following components to the registry:" >> "$OUTPUT_MD"
        echo "" >> "$OUTPUT_MD"
        
        for comp in "${MISSING_COMPONENTS[@]}"; do
            echo "- **$comp**" >> "$OUTPUT_MD"
        done
        
        echo "" >> "$OUTPUT_MD"
    fi
    
    echo "### Makefile Updates" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    echo "Add missing Makefile targets for the following components:" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    
    for entry in "${COMPONENT_ISSUES[@]}"; do
        comp="${entry%%:*}"
        issues="${entry#*:}"
        
        if [[ "$issues" == *"Missing targets"* ]]; then
            echo "- **$comp**: $issues" >> "$OUTPUT_MD"
        fi
    done
    
    echo "" >> "$OUTPUT_MD"
    echo "### Documentation Updates" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    echo "Complete documentation for the following components:" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    
    for entry in "${COMPONENT_ISSUES[@]}"; do
        comp="${entry%%:*}"
        issues="${entry#*:}"
        
        if [[ "$issues" == *"Documentation issues"* ]]; then
            echo "- **$comp**: $issues" >> "$OUTPUT_MD"
        fi
    done
else
    echo "✅ **No remediation tasks required!** All components are fully integrated." >> "$OUTPUT_MD"
fi

# Add reference section
echo "" >> "$OUTPUT_MD"
echo "## Reference Information" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "### Required Registry Flags" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "Each component in the registry should have the following integration status flags set to \`true\`:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "- \`installed\`: Component has a working installation script" >> "$OUTPUT_MD"
echo "- \`hardened\`: Component has security hardening measures" >> "$OUTPUT_MD"
echo "- \`makefile\`: Component has all required Makefile targets" >> "$OUTPUT_MD"
echo "- \`dashboard\`: Component appears in the dashboard" >> "$OUTPUT_MD"
echo "- \`logs\`: Component logs are captured properly" >> "$OUTPUT_MD"
echo "- \`docs\`: Component has documentation" >> "$OUTPUT_MD"
echo "- \`auditable\`: Component can be audited for issues" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "### Desirable Registry Flags" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "These flags are desirable but may not be applicable to all components:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "- \`sso\`: Component integrates with Keycloak SSO" >> "$OUTPUT_MD"
echo "- \`traefik_tls\`: Component is proxied through Traefik with TLS" >> "$OUTPUT_MD"
echo "- \`multi_tenant\`: Component supports multi-tenant deployment" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "### Required Makefile Targets" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "Each component should have these Makefile targets:" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "- \`[component]\`: Install the component" >> "$OUTPUT_MD"
echo "- \`[component]-status\`: Check component status" >> "$OUTPUT_MD"
echo "- \`[component]-logs\`: View component logs" >> "$OUTPUT_MD"
echo "- \`[component]-restart\`: Restart the component" >> "$OUTPUT_MD"

# Print summary
echo ""
echo -e "${CYAN}${BOLD}=== Alpha Status Summary ===${RESET}"
echo -e "${GREEN}${BOLD}✅ Fully Integrated Components: $FULLY_INTEGRATED${RESET}"
echo -e "${YELLOW}${BOLD}🔶 Partially Integrated Components: $PARTIALLY_INTEGRATED${RESET}"
echo -e "${RED}${BOLD}❌ Missing Integration: $MISSING_INTEGRATION${RESET}"
echo -e "${CYAN}${BOLD}Total Components: $TOTAL_COMPONENTS${RESET}"
echo ""
echo -e "${CYAN}${BOLD}Report generated at: $OUTPUT_MD${RESET}"
echo ""

exit 0
