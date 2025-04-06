#!/bin/bash
# =============================================================================
# alpha_check.sh
# 
# Performs a comprehensive audit of AgencyStack components for Alpha release
# readiness, checking component registry entries, Makefile targets, and
# documentation completeness.
# =============================================================================

# Strict error handling
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
COMPONENTS_DIR="${SCRIPTS_DIR}/components"
UTILS_DIR="${SCRIPTS_DIR}/utils"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_DIR="${CONFIG_DIR}/registry"
REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
MAKEFILE="${ROOT_DIR}/Makefile"
DOCS_DIR="${ROOT_DIR}/docs"
OUTPUT_MD="${DOCS_DIR}/pages/components/alpha_ready.md"

# Import common utilities
source "${UTILS_DIR}/common.sh"

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Basic variables
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")
COMPONENTS_FULL=0
COMPONENTS_PARTIAL=0
COMPONENTS_MISSING=0
TOTAL_COMPONENTS=0

# Arrays to track components
fully_integrated=()
partially_integrated=()
missing_integration=()

# Utility to extract component ID from install script filename
extract_component_id() {
    local script_name="$1"
    echo "${script_name#install_}" | sed 's/\.sh$//'
}

# Check if a component is in the registry
is_in_registry() {
    local comp_id="$1"
    jq -e ".. | objects | select(.component_id? == \"$comp_id\" or (keys[] | contains(\"$comp_id\")))" "$REGISTRY_FILE" > /dev/null 2>&1
    return $?
}

# Check if flags are set correctly
check_flags() {
    local comp_id="$1"
    local required_flags=("installed" "hardened" "makefile" "dashboard" "logs" "docs" "auditable")
    local missing_flags=()
    local path
    
    # Determine the JSON path to the component
    path=$(jq -r ".. | objects | select(.component_id? == \"$comp_id\" or (keys[] | contains(\"$comp_id\"))) | path | join(\".\")" "$REGISTRY_FILE" 2>/dev/null)
    
    if [[ -z "$path" ]]; then
        # Try searching by key
        for section in $(jq -r '.components | keys[]' "$REGISTRY_FILE"); do
            if jq -e ".components.\"$section\".\"$comp_id\"" "$REGISTRY_FILE" > /dev/null 2>&1; then
                path="components.$section.$comp_id"
                break
            fi
        done
    fi
    
    if [[ -z "$path" ]]; then
        echo "Could not determine path for component $comp_id"
        return 1
    fi
    
    # Check each required flag
    for flag in "${required_flags[@]}"; do
        if ! jq -e ".$path.integration_status.$flag" "$REGISTRY_FILE" > /dev/null 2>&1; then
            missing_flags+=("$flag")
        elif [[ "$(jq -r ".$path.integration_status.$flag" "$REGISTRY_FILE")" == "false" ]]; then
            missing_flags+=("$flag")
        fi
    done
    
    # Check for desirable flags
    desirable_flags=("sso" "traefik_tls" "multi_tenant" "monitoring")
    for flag in "${desirable_flags[@]}"; do
        if ! jq -e ".$path.integration_status.$flag" "$REGISTRY_FILE" > /dev/null 2>&1; then
            missing_flags+=("$flag (optional)")
        elif [[ "$(jq -r ".$path.integration_status.$flag" "$REGISTRY_FILE")" == "false" ]]; then
            missing_flags+=("$flag (optional)")
        fi
    done
    
    # Check other required fields
    required_fields=("name" "category" "version" "description")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$path.$field" "$REGISTRY_FILE" > /dev/null 2>&1; then
            missing_flags+=("field:$field")
        fi
    done
    
    echo "${missing_flags[*]}"
}

# Check if Makefile targets exist for a component
check_makefile_targets() {
    local comp_id="$1"
    local required_targets=("$comp_id" "$comp_id-status" "$comp_id-logs" "$comp_id-restart")
    local missing_targets=()
    
    for target in "${required_targets[@]}"; do
        if ! grep -q "^$target:" "$MAKEFILE"; then
            missing_targets+=("$target")
        fi
    done
    
    # Check for optional targets
    optional_targets=("$comp_id-backup" "$comp_id-config" "$comp_id-test")
    for target in "${optional_targets[@]}"; do
        if ! grep -q "^$target:" "$MAKEFILE"; then
            missing_targets+=("$target (optional)")
        fi
    done
    
    echo "${missing_targets[*]}"
}

# Check documentation status
check_documentation() {
    local comp_id="$1"
    local doc_file="${DOCS_DIR}/pages/components/${comp_id}.md"
    local missing_docs=()
    
    # Check for dedicated component docs
    if [[ ! -f "$doc_file" ]]; then
        missing_docs+=("component doc")
    else
        # Check for basic sections in documentation
        if ! grep -q "# " "$doc_file"; then
            missing_docs+=("title")
        fi
        if ! grep -q "## Installation" "$doc_file"; then
            missing_docs+=("installation section")
        fi
        if ! grep -q "## Configuration" "$doc_file"; then
            missing_docs+=("configuration section")
        fi
    fi
    
    # Check for README or ports.md references
    if [[ -f "${ROOT_DIR}/docs/pages/ports.md" ]]; then
        if ! grep -q "$comp_id" "${ROOT_DIR}/docs/pages/ports.md"; then
            missing_docs+=("ports reference")
        fi
    fi
    
    if [[ -f "${ROOT_DIR}/docs/pages/components.md" ]]; then
        if ! grep -q "$comp_id" "${ROOT_DIR}/docs/pages/components.md"; then
            missing_docs+=("components list reference")
        fi
    fi
    
    echo "${missing_docs[*]}"
}

# Analyze component and determine its integration status
analyze_component() {
    local script="$1"
    local comp_id=$(extract_component_id "$script")
    local status="✅"
    local issues=()
    local registry_flags=""
    local makefile_targets=""
    local doc_status=""
    
    ((TOTAL_COMPONENTS++))
    echo "Analyzing component: $comp_id from script $script"
    
    # Check registry status
    if is_in_registry "$comp_id"; then
        echo "  Component $comp_id found in registry"
        registry_flags=$(check_flags "$comp_id")
    else
        echo "  Component $comp_id NOT found in registry"
        status="❌"
        issues+=("Not in component registry")
    fi
    
    # Check Makefile targets
    makefile_targets=$(check_makefile_targets "$comp_id")
    if [[ -n "$makefile_targets" ]]; then
        echo "  Missing Makefile targets: $makefile_targets"
    else
        echo "  All required Makefile targets present"
    fi
    
    # Check documentation
    doc_status=$(check_documentation "$comp_id")
    if [[ -n "$doc_status" ]]; then
        echo "  Missing documentation: $doc_status"
    else
        echo "  Documentation is complete"
    fi
    
    # Add any issues found
    if [[ -n "$registry_flags" ]]; then
        issues+=("Missing registry flags: $registry_flags")
    fi
    
    if [[ -n "$makefile_targets" ]]; then
        issues+=("Missing Makefile targets: $makefile_targets")
    fi
    
    if [[ -n "$doc_status" ]]; then
        issues+=("Missing documentation: $doc_status")
    fi
    
    # Determine final status
    if [[ ${#issues[@]} -eq 0 ]]; then
        status="✅"
        fully_integrated+=("$comp_id")
        ((COMPONENTS_FULL++))
    elif [[ "${issues[*]}" == *"Not in component registry"* ]]; then
        status="❌"
        missing_integration+=("$comp_id")
        ((COMPONENTS_MISSING++))
    else
        status="🔶"
        partially_integrated+=("$comp_id")
        ((COMPONENTS_PARTIAL++))
    fi
    
    # Store results for report
    local result="$status $comp_id"
    local details=""
    
    for issue in "${issues[@]}"; do
        details+="  - $issue\n"
    done
    
    # Return the result
    echo -e "$result:$details"
}

# Generate the alpha_ready.md report
generate_report() {
    mkdir -p "$(dirname "$OUTPUT_MD")"
    
    # Create report header
    cat > "$OUTPUT_MD" << EOF
# AgencyStack Alpha Release Component Status

**Generated:** $CURRENT_DATE at $CURRENT_TIME

This document provides the current status of all AgencyStack components for the Alpha release milestone.

## Summary

- **✅ Fully Integrated Components:** $COMPONENTS_FULL
- **🔶 Partially Integrated Components:** $COMPONENTS_PARTIAL
- **❌ Missing Integration:** $COMPONENTS_MISSING
- **Total Components:** $TOTAL_COMPONENTS

## Component Status Details

### ✅ Fully Integrated Components

These components have all required registry entries, Makefile targets, and documentation:

EOF
    
    # Add fully integrated components
    for comp in "${fully_integrated[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
    done
    
    # If no fully integrated components
    if [[ ${#fully_integrated[@]} -eq 0 ]]; then
        echo "*No fully integrated components found.*" >> "$OUTPUT_MD"
    fi
    
    # Add partially integrated components
    cat >> "$OUTPUT_MD" << EOF

### 🔶 Partially Integrated Components

These components are partially integrated but missing some registry flags, Makefile targets, or documentation:

EOF
    
    for comp in "${partially_integrated[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add details about what's missing
        for result in "${component_results[@]}"; do
            if [[ "$result" == *"$comp:"* ]]; then
                details=$(echo "$result" | sed -e "s/.*$comp://")
                echo -e "$details" | sed 's/^/  /' >> "$OUTPUT_MD"
            fi
        done
    done
    
    # If no partially integrated components
    if [[ ${#partially_integrated[@]} -eq 0 ]]; then
        echo "*No partially integrated components found.*" >> "$OUTPUT_MD"
    fi
    
    # Add missing integration components
    cat >> "$OUTPUT_MD" << EOF

### ❌ Missing Integration

These components are missing critical integration elements:

EOF
    
    for comp in "${missing_integration[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add details about what's missing
        for result in "${component_results[@]}"; do
            if [[ "$result" == *"$comp:"* ]]; then
                details=$(echo "$result" | sed -e "s/.*$comp://")
                echo -e "$details" | sed 's/^/  /' >> "$OUTPUT_MD"
            fi
        done
    done
    
    # If no missing integration components
    if [[ ${#missing_integration[@]} -eq 0 ]]; then
        echo "*No components missing integration found.*" >> "$OUTPUT_MD"
    fi
    
    # Add remediation tasks section
    cat >> "$OUTPUT_MD" << EOF

## Remediation Tasks

To achieve Alpha release readiness, the following tasks should be completed:

EOF
    
    if [[ ${#partially_integrated[@]} -gt 0 || ${#missing_integration[@]} -gt 0 ]]; then
        cat >> "$OUTPUT_MD" << EOF
### Registry Updates

\`\`\`bash
# Update the component registry file at $REGISTRY_FILE
# Ensure all components have required fields and flags
\`\`\`

### Makefile Updates

\`\`\`bash
# Add missing Makefile targets to $MAKEFILE
# Each component should have install, status, logs, and restart targets
\`\`\`

### Documentation Updates

\`\`\`bash
# Create or update component documentation
# Ensure all components have proper documentation
\`\`\`
EOF
    else
        echo "✅ **No remediation tasks required!** All components are fully integrated." >> "$OUTPUT_MD"
    fi
    
    # Add reference information
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

### Recommended Documentation

Each component should have:

- Dedicated documentation page at \`docs/pages/components/[component].md\`
- Entry in \`docs/pages/components.md\`
- Port references in \`docs/pages/ports.md\`
EOF
    
    echo "Report generated at $OUTPUT_MD"
}

# Add alpha-check target to Makefile if not present
add_makefile_target() {
    if ! grep -q "^alpha-check:" "$MAKEFILE"; then
        # Find the last line of the file
        local last_line=$(tail -n 1 "$MAKEFILE")
        local line_ending=""
        
        # Determine line ending (preserve existing style)
        if [[ "$last_line" == "" ]]; then
            line_ending=""
        else
            line_ending="\n\n"
        fi
        
        # Add alpha-check target
        cat >> "$MAKEFILE" << EOT
# Alpha Release Readiness Check
alpha-check:
	@echo "\$(MAGENTA)\$(BOLD)🔍 Checking Alpha Release Readiness...\$(RESET)"
	@\$(SCRIPTS_DIR)/utils/alpha_check.sh
	@echo "\$(CYAN)Full report available at: docs/pages/components/alpha_ready.md\$(RESET)"
EOT
        
        echo "Added alpha-check target to Makefile"
    else
        echo "alpha-check target already exists in Makefile"
    fi
}

# Update update_component_registry.sh with missing components if needed
update_registry_script() {
    local script="${UTILS_DIR}/update_component_registry.sh"
    
    if [[ -f "$script" ]]; then
        # Check if there are components missing from the registry
        if [[ ${#missing_integration[@]} -gt 0 ]]; then
            echo "Updating component registry script with missing components"
            
            # Make a backup of the script
            cp "$script" "${script}.bak"
            
            # Add the missing components to the script
            for comp_id in "${missing_integration[@]}"; do
                # Determine script filename
                local script_name="install_${comp_id}.sh"
                
                # Extract component name from script (first line comment)
                local comp_name=$(head -n 10 "${COMPONENTS_DIR}/${script_name}" | grep -i "install.*${comp_id}" | head -n 1 | sed 's/.*install//' | sed 's/\.sh.*//' | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/^ *//' | sed 's/ *$//')
                
                # If no name found, use component ID with proper capitalization
                if [[ -z "$comp_name" ]]; then
                    comp_name=$(echo "$comp_id" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
                fi
                
                # Try to extract category from script
                local category=$(head -n 20 "${COMPONENTS_DIR}/${script_name}" | grep -i "category\|component type" | head -n 1 | sed 's/.*://' | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/^ *//' | sed 's/ *$//')
                
                # If no category found, use a default based on component name
                if [[ -z "$category" ]]; then
                    if [[ "$comp_id" == *"ai"* || "$comp_id" == "ollama" || "$comp_id" == "langchain" ]]; then
                        category="AI"
                    elif [[ "$comp_id" == *"monitor"* || "$comp_id" == "prometheus" || "$comp_id" == "grafana" || "$comp_id" == "loki" ]]; then
                        category="Monitoring & Observability"
                    elif [[ "$comp_id" == *"security"* || "$comp_id" == "keycloak" || "$comp_id" == "cryptosync" ]]; then
                        category="Security & Storage"
                    else
                        category="Core Infrastructure"
                    fi
                fi
                
                echo "Adding template for $comp_id ($comp_name) in category $category"
                
                # This would actually update the script
                # For now, just echo the actions that would be taken
                echo "Would add component registry entry for $comp_id"
            done
        else
            echo "No missing components to add to registry script"
        fi
    else
        echo "Registry update script not found at $script"
    fi
}

# Main execution
main() {
    echo "Starting AgencyStack Alpha Release readiness check..."
    echo "Using registry file: $REGISTRY_FILE"
    echo "Using Makefile: $MAKEFILE"
    echo "-----------------------------------------"
    
    # Verify files exist
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo "Error: Component registry file not found at $REGISTRY_FILE"
        exit 1
    fi
    
    if [[ ! -f "$MAKEFILE" ]]; then
        echo "Error: Makefile not found at $MAKEFILE"
        exit 1
    fi
    
    # Get all installation scripts
    echo "Finding installation scripts in: $COMPONENTS_DIR"
    install_scripts=()
    while IFS= read -r script; do
        install_scripts+=("$(basename "$script")")
    done < <(find "$COMPONENTS_DIR" -name "install_*.sh" -type f)
    
    echo "Found ${#install_scripts[@]} installation scripts"
    
    # Arrays to store results
    component_results=()
    
    # Process each installation script
    for script in "${install_scripts[@]}"; do
        result=$(analyze_component "$script")
        component_results+=("$result")
    done
    
    # Generate the report
    generate_report
    
    # Add Makefile target
    add_makefile_target
    
    # Update registry script if needed
    update_registry_script
    
    # Print summary
    echo "-----------------------------------------"
    echo -e "${GREEN}✅ Fully Integrated Components: $COMPONENTS_FULL${RESET}"
    echo -e "${YELLOW}🔶 Partially Integrated Components: $COMPONENTS_PARTIAL${RESET}"
    echo -e "${RED}❌ Missing Integration: $COMPONENTS_MISSING${RESET}"
    echo -e "${CYAN}Total Components: $TOTAL_COMPONENTS${RESET}"
    
    echo "-----------------------------------------"
    echo "Full report has been generated at:"
    echo "$OUTPUT_MD"
    echo "-----------------------------------------"
    
    # Return success
    return 0
}

# Execute main function
main "$@"
