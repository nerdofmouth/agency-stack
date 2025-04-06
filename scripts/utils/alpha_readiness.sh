#!/bin/bash
# =============================================================================
# alpha_readiness.sh
#
# A streamlined utility to check AgencyStack component Alpha readiness
# Focuses on registry entries, Makefile targets, and documentation
# =============================================================================

set -e

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"
BOLD="\033[1m"

# Directories and files
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
COMPONENTS_DIR="${SCRIPTS_DIR}/components"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_FILE="${CONFIG_DIR}/registry/component_registry.json"
MAKEFILE="${ROOT_DIR}/Makefile"
OUTPUT_MD="${ROOT_DIR}/docs/pages/components/alpha_ready.md"

# Date and time
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")

# Arrays for tracking component status
INSTALL_SCRIPTS=()
COMPONENT_IDS=()
REGISTRY_STATUS=()
MAKEFILE_STATUS=()
DOCS_STATUS=()
OVERALL_STATUS=()
ISSUES=()

# Statistics
TOTAL=0
FULLY_INTEGRATED=0
PARTIALLY_INTEGRATED=0
MISSING_INTEGRATION=0

# Function to get standardized component ID (both with underscore and hyphen versions)
get_component_id() {
    local script="$1"
    echo "${script#install_}" | sed 's/\.sh$//'
}

# Function to check if component is in registry
check_registry() {
    local comp_id="$1"
    local hyphen_id="${comp_id//_/-}"
    local underscore_id="${comp_id//-/_}"
    
    # Check direct key match in any section
    if jq -e ".components | to_entries[] | .value | has(\"$comp_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    # Check for hyphenated version
    if [[ "$hyphen_id" != "$comp_id" ]] && jq -e ".components | to_entries[] | .value | has(\"$hyphen_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    # Check for underscore version
    if [[ "$underscore_id" != "$comp_id" ]] && jq -e ".components | to_entries[] | .value | has(\"$underscore_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    # Check for component_id field
    if jq -e ".components | to_entries[] | .value | to_entries[] | .value | select(.component_id == \"$comp_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    # Check for hyphenated component_id
    if [[ "$hyphen_id" != "$comp_id" ]] && jq -e ".components | to_entries[] | .value | to_entries[] | .value | select(.component_id == \"$hyphen_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    # Check for underscore component_id
    if [[ "$underscore_id" != "$comp_id" ]] && jq -e ".components | to_entries[] | .value | to_entries[] | .value | select(.component_id == \"$underscore_id\")" "$REGISTRY_FILE" &>/dev/null; then
        echo "✅"
        return 0
    fi
    
    echo "❌"
    return 1
}

# Function to get missing registry flags
get_missing_registry_flags() {
    local comp_id="$1"
    local hyphen_id="${comp_id//_/-}"
    local underscore_id="${comp_id//-/_}"
    local json_path=""
    local component_json=""
    
    # Try to find the component in the registry
    for id in "$comp_id" "$hyphen_id" "$underscore_id"; do
        # Try direct key match
        if jq -e ".components | to_entries[] | select(.value | has(\"$id\"))" "$REGISTRY_FILE" &>/dev/null; then
            local section=$(jq -r ".components | to_entries[] | select(.value | has(\"$id\")) | .key" "$REGISTRY_FILE")
            json_path=".components.\"$section\".\"$id\""
            component_json=$(jq "$json_path" "$REGISTRY_FILE")
            break
        fi
        
        # Try component_id field
        local result=$(jq -r ".components | to_entries[] | .value | to_entries[] | select(.value.component_id == \"$id\") | [.key, (.value | .component_id)] | @tsv" "$REGISTRY_FILE" 2>/dev/null)
        if [[ -n "$result" ]]; then
            local parts=($result)
            local subcategory=${parts[0]}
            local section=$(jq -r ".components | to_entries[] | select(.value | has(\"$subcategory\")) | .key" "$REGISTRY_FILE")
            json_path=".components.\"$section\".\"$subcategory\""
            component_json=$(jq "$json_path" "$REGISTRY_FILE")
            break
        fi
    done
    
    # If component not found
    if [[ -z "$json_path" ]]; then
        echo "Not in registry"
        return
    fi
    
    # Check required flags
    local missing=()
    local required_flags=("installed" "hardened" "makefile" "dashboard" "logs" "docs" "auditable")
    
    for flag in "${required_flags[@]}"; do
        if ! echo "$component_json" | jq -e ".integration_status.\"$flag\"" &>/dev/null || \
           [[ $(echo "$component_json" | jq -r ".integration_status.\"$flag\"") != "true" ]]; then
            missing+=("$flag")
        fi
    done
    
    # Check desirable flags (these aren't strictly required but are good to have)
    local desirable_flags=("sso" "traefik_tls" "multi_tenant" "monitoring")
    local missing_desirable=()
    
    for flag in "${desirable_flags[@]}"; do
        if ! echo "$component_json" | jq -e ".integration_status.\"$flag\"" &>/dev/null || \
           [[ $(echo "$component_json" | jq -r ".integration_status.\"$flag\"") != "true" ]]; then
            missing_desirable+=("$flag (optional)")
        fi
    done
    
    # Check required fields
    local required_fields=("name" "category" "version" "description")
    local missing_fields=()
    
    for field in "${required_fields[@]}"; do
        if ! echo "$component_json" | jq -e ".\"$field\"" &>/dev/null; then
            missing_fields+=("$field")
        fi
    done
    
    # Construct output
    local output=""
    if [[ ${#missing[@]} -gt 0 ]]; then
        output+="Missing flags: ${missing[*]}"
    fi
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        if [[ -n "$output" ]]; then
            output+=", "
        fi
        output+="Missing fields: ${missing_fields[*]}"
    fi
    
    if [[ ${#missing_desirable[@]} -gt 0 ]]; then
        if [[ -n "$output" ]]; then
            output+=", "
        fi
        output+="Missing optional: ${missing_desirable[*]}"
    fi
    
    if [[ -z "$output" ]]; then
        echo "All flags present"
        return 0
    else
        echo "$output"
        return 1
    fi
}

# Function to check Makefile targets
check_makefile_targets() {
    local comp_id="$1"
    local hyphen_id="${comp_id//_/-}"
    local underscore_id="${comp_id//-/_}"
    local ids=("$comp_id" "$hyphen_id" "$underscore_id")
    local missing=()
    
    # Required targets
    local required_targets=("install" "status" "logs" "restart")
    
    for base in "${ids[@]}"; do
        # Skip if identical to already checked ID
        [[ "$base" == "$comp_id" || ( "$base" != "$hyphen_id" && "$base" != "$underscore_id" ) ]] || continue
        
        for suffix in "${required_targets[@]}"; do
            local target="$base"
            [[ "$suffix" != "install" ]] && target="$base-$suffix"
            
            if ! grep -q "^$target:" "$MAKEFILE"; then
                # Special case for "install" target with specific naming
                if [[ "$suffix" == "install" && ( -n "$(grep -E "^install-$base:" "$MAKEFILE")" || -n "$(grep -E "^$base:" "$MAKEFILE")" ) ]]; then
                    continue
                fi
                missing+=("$target")
            fi
        done
    done
    
    # Optional targets
    local optional_targets=("backup" "config" "test")
    local missing_optional=()
    
    for base in "${ids[@]}"; do
        # Skip if identical to already checked ID
        [[ "$base" == "$comp_id" || ( "$base" != "$hyphen_id" && "$base" != "$underscore_id" ) ]] || continue
        
        for suffix in "${optional_targets[@]}"; do
            local target="$base-$suffix"
            if ! grep -q "^$target:" "$MAKEFILE"; then
                missing_optional+=("$target (optional)")
            fi
        done
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        if [[ ${#missing_optional[@]} -eq 0 ]]; then
            echo "✅"
            return 0
        else
            echo "🔶 Missing optional: ${missing_optional[*]}"
            return 0
        fi
    else
        echo "❌ Missing: ${missing[*]}"
        return 1
    fi
}

# Function to check documentation
check_documentation() {
    local comp_id="$1"
    local hyphen_id="${comp_id//_/-}"
    local underscore_id="${comp_id//-/_}"
    local ids=("$comp_id" "$hyphen_id" "$underscore_id")
    local missing=()
    
    # Check for component documentation
    local found_doc=false
    
    # Check in components directory
    for id in "${ids[@]}"; do
        if [[ -f "${ROOT_DIR}/docs/pages/components/${id}.md" ]]; then
            found_doc=true
            break
        fi
    done
    
    # If not in components, check in AI directory for AI-related components
    if [[ "$found_doc" == "false" && ( "$comp_id" == *"ai"* || "$comp_id" == "ollama" || "$comp_id" == "langchain" || "$comp_id" == "resource_watcher" || "$comp_id" == "agent_orchestrator" ) ]]; then
        for id in "${ids[@]}"; do
            if [[ -f "${ROOT_DIR}/docs/pages/ai/${id}.md" ]]; then
                found_doc=true
                break
            fi
        done
    fi
    
    if [[ "$found_doc" == "false" ]]; then
        missing+=("No dedicated documentation file")
    fi
    
    # Check for mentions in components.md
    if [[ -f "${ROOT_DIR}/docs/pages/components.md" ]]; then
        local found_in_components=false
        for id in "${ids[@]}"; do
            if grep -q "$id" "${ROOT_DIR}/docs/pages/components.md"; then
                found_in_components=true
                break
            fi
        done
        
        if [[ "$found_in_components" == "false" ]]; then
            missing+=("Not in components.md")
        fi
    fi
    
    # Check for mentions in ports.md
    if [[ -f "${ROOT_DIR}/docs/pages/ports.md" ]]; then
        local found_in_ports=false
        for id in "${ids[@]}"; do
            if grep -q "$id" "${ROOT_DIR}/docs/pages/ports.md"; then
                found_in_ports=true
                break
            fi
        done
        
        if [[ "$found_in_ports" == "false" ]]; then
            missing+=("Not in ports.md")
        fi
    fi
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "✅"
        return 0
    else
        local msg="❌ "
        for (( i=0; i<${#missing[@]}; i++ )); do
            if [[ $i > 0 ]]; then
                msg+=", "
            fi
            msg+="${missing[$i]}"
        done
        echo "$msg"
        return 1
    fi
}

# Function to determine overall status
determine_status() {
    local registry="$1"
    local makefile="$2"
    local docs="$3"
    
    if [[ "$registry" == "✅" && "$makefile" == "✅" && "$docs" == "✅" ]]; then
        echo "✅"
        ((FULLY_INTEGRATED++))
        return 0
    elif [[ "$registry" == "❌" ]]; then
        echo "❌"
        ((MISSING_INTEGRATION++))
        return 2
    else
        echo "🔶"
        ((PARTIALLY_INTEGRATED++))
        return 1
    fi
}

# Generate report header
generate_report_header() {
    mkdir -p $(dirname "$OUTPUT_MD")
    
    cat > "$OUTPUT_MD" << EOF
# AgencyStack Alpha Release Component Status

**Generated:** $CURRENT_DATE at $CURRENT_TIME

This document provides the current status of all AgencyStack components for the Alpha release milestone.

## Summary

- **✅ Fully Integrated Components:** $FULLY_INTEGRATED
- **🔶 Partially Integrated Components:** $PARTIALLY_INTEGRATED
- **❌ Missing Integration:** $MISSING_INTEGRATION
- **Total Components:** $TOTAL

## Component Status Details

EOF
}

# Generate fully integrated components section
generate_full_section() {
    cat >> "$OUTPUT_MD" << EOF
### ✅ Fully Integrated Components

These components have all required registry entries, Makefile targets, and documentation:

EOF
    
    local count=0
    for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
        if [[ "${OVERALL_STATUS[$i]}" == "✅" ]]; then
            echo "- **${COMPONENT_IDS[$i]}**" >> "$OUTPUT_MD"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "*No fully integrated components found.*" >> "$OUTPUT_MD"
    fi
}

# Generate partially integrated components section
generate_partial_section() {
    cat >> "$OUTPUT_MD" << EOF

### 🔶 Partially Integrated Components

These components are partially integrated but missing some registry flags, Makefile targets, or documentation:

EOF
    
    local count=0
    for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
        if [[ "${OVERALL_STATUS[$i]}" == "🔶" ]]; then
            echo "- **${COMPONENT_IDS[$i]}**" >> "$OUTPUT_MD"
            echo "  - ${ISSUES[$i]}" >> "$OUTPUT_MD"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "*No partially integrated components found.*" >> "$OUTPUT_MD"
    fi
}

# Generate missing integration components section
generate_missing_section() {
    cat >> "$OUTPUT_MD" << EOF

### ❌ Missing Integration

These components are missing critical integration elements:

EOF
    
    local count=0
    for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
        if [[ "${OVERALL_STATUS[$i]}" == "❌" ]]; then
            echo "- **${COMPONENT_IDS[$i]}**" >> "$OUTPUT_MD"
            echo "  - ${ISSUES[$i]}" >> "$OUTPUT_MD"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "*No components with missing integration found.*" >> "$OUTPUT_MD"
    fi
}

# Generate remediation tasks section
generate_remediation_section() {
    cat >> "$OUTPUT_MD" << EOF

## Remediation Tasks

EOF
    
    if [[ $PARTIALLY_INTEGRATED -gt 0 || $MISSING_INTEGRATION -gt 0 ]]; then
        cat >> "$OUTPUT_MD" << EOF
To achieve Alpha release readiness, the following tasks should be completed:

### Registry Updates

The following components need registry updates:
EOF
        
        for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
            if [[ "${REGISTRY_STATUS[$i]}" == "❌" || "${REGISTRY_STATUS[$i]}" == *"Missing"* ]]; then
                echo "- **${COMPONENT_IDS[$i]}**: ${REGISTRY_STATUS[$i]}" >> "$OUTPUT_MD"
            fi
        done
        
        cat >> "$OUTPUT_MD" << EOF

### Makefile Updates

The following components need Makefile target updates:
EOF
        
        for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
            if [[ "${MAKEFILE_STATUS[$i]}" == "❌"* ]]; then
                echo "- **${COMPONENT_IDS[$i]}**: ${MAKEFILE_STATUS[$i]}" >> "$OUTPUT_MD"
            fi
        done
        
        cat >> "$OUTPUT_MD" << EOF

### Documentation Updates

The following components need documentation updates:
EOF
        
        for (( i=0; i<${#COMPONENT_IDS[@]}; i++ )); do
            if [[ "${DOCS_STATUS[$i]}" == "❌"* ]]; then
                echo "- **${COMPONENT_IDS[$i]}**: ${DOCS_STATUS[$i]}" >> "$OUTPUT_MD"
            fi
        done
    else
        echo "✅ **No remediation tasks required!** All components are fully integrated." >> "$OUTPUT_MD"
    fi
}

# Generate reference information section
generate_reference_section() {
    cat >> "$OUTPUT_MD" << EOF

## Reference Information

### Required Registry Flags

Each component in the registry should have the following integration status flags set to \`true\`:

- \`installed\`: Component has a working installation script
- \`hardened\`: Component has security hardening measures
- \`makefile\`: Component has all required Makefile targets
- \`dashboard\`: Component appears in the dashboard
- \`logs\`: Component logs are captured properly
- \`docs\`: Component has documentation
- \`auditable\`: Component can be audited for issues

### Desirable Registry Flags

These flags are desirable but may not be applicable to all components:

- \`sso\`: Component integrates with Keycloak SSO
- \`traefik_tls\`: Component is proxied through Traefik with TLS
- \`multi_tenant\`: Component supports multi-tenant deployment
- \`monitoring\`: Component has monitoring integration

### Required Makefile Targets

Each component should have these Makefile targets:

- \`[component]\`: Install the component
- \`[component]-status\`: Check component status
- \`[component]-logs\`: View component logs
- \`[component]-restart\`: Restart the component

### Alpha Release Criteria

For a component to be considered Alpha-ready, it must:

1. Be represented in the component registry with all required flags
2. Have all required Makefile targets implemented
3. Include comprehensive documentation
4. Successfully install without errors
5. Report status back to the dashboard
EOF
}

# Main function
main() {
    echo -e "${CYAN}${BOLD}AgencyStack Alpha Release Readiness Check${RESET}"
    echo -e "${CYAN}${BOLD}=======================================${RESET}"
    echo ""
    
    echo -e "${CYAN}Finding installation scripts...${RESET}"
    while IFS= read -r script; do
        INSTALL_SCRIPTS+=("$(basename "$script")")
    done < <(find "$COMPONENTS_DIR" -name "install_*.sh" -type f)
    
    TOTAL=${#INSTALL_SCRIPTS[@]}
    echo -e "${CYAN}Found $TOTAL installation scripts${RESET}"
    echo ""
    
    # Table header
    printf "%-30s | %-15s | %-30s | %-30s | %s\n" "Component" "Registry" "Makefile" "Documentation" "Status"
    printf "%-30s-|-%-15s-|-%-30s-|-%-30s-|-%s\n" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..15})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..10})"
    
    # Process each component
    for script in "${INSTALL_SCRIPTS[@]}"; do
        comp_id=$(get_component_id "$script")
        COMPONENT_IDS+=("$comp_id")
        
        # Check registry
        reg_status=$(check_registry "$comp_id")
        REGISTRY_STATUS+=("$reg_status")
        
        # Check registry flags if in registry
        if [[ "$reg_status" == "✅" ]]; then
            reg_flags=$(get_missing_registry_flags "$comp_id")
            if [[ "$reg_flags" != "All flags present" ]]; then
                REGISTRY_STATUS[$((${#REGISTRY_STATUS[@]}-1))]="$reg_flags"
            fi
        fi
        
        # Check Makefile targets
        make_status=$(check_makefile_targets "$comp_id")
        MAKEFILE_STATUS+=("$make_status")
        
        # Check documentation
        doc_status=$(check_documentation "$comp_id")
        DOCS_STATUS+=("$doc_status")
        
        # Determine overall status
        overall=$(determine_status "${REGISTRY_STATUS[$((${#REGISTRY_STATUS[@]}-1))]}" "${MAKEFILE_STATUS[$((${#MAKEFILE_STATUS[@]}-1))]}" "${DOCS_STATUS[$((${#DOCS_STATUS[@]}-1))]}")
        OVERALL_STATUS+=("$overall")
        
        # Collect issues
        issues=""
        if [[ "${REGISTRY_STATUS[$((${#REGISTRY_STATUS[@]}-1))]}" != "✅" ]]; then
            issues+="Registry: ${REGISTRY_STATUS[$((${#REGISTRY_STATUS[@]}-1))]}"
        fi
        
        if [[ "${MAKEFILE_STATUS[$((${#MAKEFILE_STATUS[@]}-1))]}" != "✅" ]]; then
            [[ -n "$issues" ]] && issues+=", "
            issues+="Makefile: ${MAKEFILE_STATUS[$((${#MAKEFILE_STATUS[@]}-1))]}"
        fi
        
        if [[ "${DOCS_STATUS[$((${#DOCS_STATUS[@]}-1))]}" != "✅" ]]; then
            [[ -n "$issues" ]] && issues+=", "
            issues+="Docs: ${DOCS_STATUS[$((${#DOCS_STATUS[@]}-1))]}"
        fi
        
        ISSUES+=("$issues")
        
        # Print table row
        printf "%-30s | %-15s | %-30s | %-30s | %s\n" "$comp_id" "${REGISTRY_STATUS[$((${#REGISTRY_STATUS[@]}-1))]}" "${MAKEFILE_STATUS[$((${#MAKEFILE_STATUS[@]}-1))]}" "${DOCS_STATUS[$((${#DOCS_STATUS[@]}-1))]}" "${OVERALL_STATUS[$((${#OVERALL_STATUS[@]}-1))]}"
    done
    
    echo ""
    echo -e "${CYAN}${BOLD}Generating Alpha readiness report...${RESET}"
    
    # Generate report
    generate_report_header
    generate_full_section
    generate_partial_section
    generate_missing_section
    generate_remediation_section
    generate_reference_section
    
    echo -e "${GREEN}${BOLD}Report generated:${RESET} $OUTPUT_MD"
    echo ""
    echo -e "${CYAN}${BOLD}Summary:${RESET}"
    echo -e "${GREEN}✅ Fully Integrated: $FULLY_INTEGRATED${RESET}"
    echo -e "${YELLOW}🔶 Partially Integrated: $PARTIALLY_INTEGRATED${RESET}"
    echo -e "${RED}❌ Missing Integration: $MISSING_INTEGRATION${RESET}"
    echo -e "${CYAN}Total Components: $TOTAL${RESET}"
}

# Run the main function
main
