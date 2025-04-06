#!/bin/bash
# =============================================================================
# simple_alpha_check.sh
#
# Simple utility to check AgencyStack component Alpha readiness
# =============================================================================

set -e

# Directories and files
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"
REGISTRY_FILE="${ROOT_DIR}/config/registry/component_registry.json"
MAKEFILE="${ROOT_DIR}/Makefile"
OUTPUT_MD="${ROOT_DIR}/docs/pages/components/alpha_ready.md"

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_MD")"

# Current date and time
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"
BOLD="\033[1m"

# Find installation scripts
echo -e "${CYAN}${BOLD}Finding installation scripts...${RESET}"
INSTALL_SCRIPTS=()
while IFS= read -r script; do
    INSTALL_SCRIPTS+=("$(basename "$script")")
done < <(find "$COMPONENTS_DIR" -name "install_*.sh" -type f)

# Basic arrays to track components
COMPONENTS=()
FULL_COMPONENTS=()
PARTIAL_COMPONENTS=()
MISSING_COMPONENTS=()
COMPONENT_ISSUES=()

# Extract component ID from script name
extract_component_id() {
    local script="$1"
    echo "${script#install_}" | sed 's/\.sh$//'
}

# Initialize report
cat > "$OUTPUT_MD" << EOF
# AgencyStack Alpha Release Component Status

**Generated:** $CURRENT_DATE at $CURRENT_TIME

This document provides the current status of all AgencyStack components for the Alpha release milestone.

## Component Status

| Component | Registry Entry | Makefile Targets | Documentation | Status |
|-----------|---------------|-----------------|--------------|--------|
EOF

# Check each component
echo -e "${CYAN}${BOLD}Analyzing ${#INSTALL_SCRIPTS[@]} components...${RESET}"
echo ""

for script in "${INSTALL_SCRIPTS[@]}"; do
    comp_id=$(extract_component_id "$script")
    COMPONENTS+=("$comp_id")
    
    echo -e "${BOLD}Checking component: $comp_id${RESET}"
    
    # Variables to track status
    registry_status="❌"
    makefile_status="❌"
    doc_status="❌"
    issues=()
    
    # Check registry entry - simplified approach
    comp_dash="${comp_id//_/-}"
    comp_underscore="${comp_id//-/_}"
    
    if grep -q "\"$comp_id\"" "$REGISTRY_FILE" || grep -q "\"$comp_dash\"" "$REGISTRY_FILE" || grep -q "\"$comp_underscore\"" "$REGISTRY_FILE" || grep -q "\"component_id\": \"$comp_id\"" "$REGISTRY_FILE" || grep -q "\"component_id\": \"$comp_dash\"" "$REGISTRY_FILE" || grep -q "\"component_id\": \"$comp_underscore\"" "$REGISTRY_FILE"; then
        registry_status="✅"
        echo "  Registry: Found"
    else
        echo "  Registry: Not found"
        issues+=("Not in component registry")
    fi
    
    # Check Makefile targets
    make_targets=0
    required_targets=0
    
    # Check install target
    if grep -q "^$comp_id:" "$MAKEFILE" || grep -q "^$comp_dash:" "$MAKEFILE" || grep -q "^$comp_underscore:" "$MAKEFILE" || grep -q "^install-$comp_id:" "$MAKEFILE" || grep -q "^install-$comp_dash:" "$MAKEFILE" || grep -q "^install-$comp_underscore:" "$MAKEFILE"; then
        ((make_targets++))
    else
        issues+=("Missing install target")
    fi
    ((required_targets++))
    
    # Check status target
    if grep -q "^$comp_id-status:" "$MAKEFILE" || grep -q "^$comp_dash-status:" "$MAKEFILE" || grep -q "^$comp_underscore-status:" "$MAKEFILE"; then
        ((make_targets++))
    else
        issues+=("Missing status target")
    fi
    ((required_targets++))
    
    # Check logs target
    if grep -q "^$comp_id-logs:" "$MAKEFILE" || grep -q "^$comp_dash-logs:" "$MAKEFILE" || grep -q "^$comp_underscore-logs:" "$MAKEFILE"; then
        ((make_targets++))
    else
        issues+=("Missing logs target")
    fi
    ((required_targets++))
    
    # Check restart target
    if grep -q "^$comp_id-restart:" "$MAKEFILE" || grep -q "^$comp_dash-restart:" "$MAKEFILE" || grep -q "^$comp_underscore-restart:" "$MAKEFILE"; then
        ((make_targets++))
    else
        issues+=("Missing restart target")
    fi
    ((required_targets++))
    
    if [ $make_targets -eq $required_targets ]; then
        makefile_status="✅"
        echo "  Makefile targets: Complete ($make_targets/$required_targets)"
    else
        makefile_status="🔶"
        echo "  Makefile targets: Incomplete ($make_targets/$required_targets)"
    fi
    
    # Check for documentation
    doc_found=false
    
    # Check in components/ directory
    if [[ -f "${ROOT_DIR}/docs/pages/components/${comp_id}.md" || -f "${ROOT_DIR}/docs/pages/components/${comp_dash}.md" || -f "${ROOT_DIR}/docs/pages/components/${comp_underscore}.md" ]]; then
        doc_found=true
    fi
    
    # Check in ai/ directory for AI components
    if [[ "$doc_found" == "false" && ( "$comp_id" == *"ai"* || "$comp_id" == "ollama" || "$comp_id" == "langchain" || "$comp_id" == "resource_watcher" || "$comp_id" == "agent_orchestrator" ) ]]; then
        if [[ -f "${ROOT_DIR}/docs/pages/ai/${comp_id}.md" || -f "${ROOT_DIR}/docs/pages/ai/${comp_dash}.md" || -f "${ROOT_DIR}/docs/pages/ai/${comp_underscore}.md" ]]; then
            doc_found=true
        fi
    fi
    
    if [[ "$doc_found" == "true" ]]; then
        doc_status="✅"
        echo "  Documentation: Found"
    else
        issues+=("Missing documentation")
        echo "  Documentation: Not found"
    fi
    
    # Determine overall status
    if [[ "$registry_status" == "✅" && "$makefile_status" == "✅" && "$doc_status" == "✅" ]]; then
        overall_status="✅"
        FULL_COMPONENTS+=("$comp_id")
        echo "  Overall status: ${GREEN}Fully Integrated${RESET}"
    elif [[ "$registry_status" == "❌" ]]; then
        overall_status="❌"
        MISSING_COMPONENTS+=("$comp_id")
        COMPONENT_ISSUES+=("$comp_id: ${issues[*]}")
        echo "  Overall status: ${RED}Missing Integration${RESET}"
    else
        overall_status="🔶"
        PARTIAL_COMPONENTS+=("$comp_id")
        COMPONENT_ISSUES+=("$comp_id: ${issues[*]}")
        echo "  Overall status: ${YELLOW}Partially Integrated${RESET}"
    fi
    
    # Add to report
    echo "| $comp_id | $registry_status | $makefile_status | $doc_status | $overall_status |" >> "$OUTPUT_MD"
    echo ""
done

# Add summary to report
cat >> "$OUTPUT_MD" << EOF

## Summary

- **✅ Fully Integrated Components:** ${#FULL_COMPONENTS[@]}
- **🔶 Partially Integrated Components:** ${#PARTIAL_COMPONENTS[@]}
- **❌ Missing Integration:** ${#MISSING_COMPONENTS[@]}
- **Total Components:** ${#COMPONENTS[@]}

## Component Status Details

### ✅ Fully Integrated Components

These components have all required registry entries, Makefile targets, and documentation:

EOF

# Add fully integrated components
if [[ ${#FULL_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${FULL_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
    done
else
    echo "*No fully integrated components found.*" >> "$OUTPUT_MD"
fi

# Add partially integrated components
cat >> "$OUTPUT_MD" << EOF

### 🔶 Partially Integrated Components

These components are partially integrated but missing some registry entries, Makefile targets, or documentation:

EOF

if [[ ${#PARTIAL_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${PARTIAL_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add issues
        for issue in "${COMPONENT_ISSUES[@]}"; do
            if [[ "$issue" == "$comp:"* ]]; then
                echo "  - ${issue#*: }" >> "$OUTPUT_MD"
                break
            fi
        done
    done
else
    echo "*No partially integrated components found.*" >> "$OUTPUT_MD"
fi

# Add missing integration components
cat >> "$OUTPUT_MD" << EOF

### ❌ Missing Integration

These components are missing critical integration elements:

EOF

if [[ ${#MISSING_COMPONENTS[@]} -gt 0 ]]; then
    for comp in "${MISSING_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
        
        # Add issues
        for issue in "${COMPONENT_ISSUES[@]}"; do
            if [[ "$issue" == "$comp:"* ]]; then
                echo "  - ${issue#*: }" >> "$OUTPUT_MD"
                break
            fi
        done
    done
else
    echo "*No components with missing integration found.*" >> "$OUTPUT_MD"
fi

# Add remediation tasks section
cat >> "$OUTPUT_MD" << EOF

## Remediation Tasks

EOF

if [[ ${#PARTIAL_COMPONENTS[@]} -gt 0 || ${#MISSING_COMPONENTS[@]} -gt 0 ]]; then
    cat >> "$OUTPUT_MD" << EOF
To achieve Alpha release readiness, the following tasks should be completed:

### Registry Updates

Add the following components to the registry:

EOF
    
    for comp in "${MISSING_COMPONENTS[@]}"; do
        echo "- **$comp**" >> "$OUTPUT_MD"
    done
    
    cat >> "$OUTPUT_MD" << EOF

### Makefile Updates

Add missing Makefile targets for these components:

EOF
    
    for issue in "${COMPONENT_ISSUES[@]}"; do
        if [[ "$issue" == *"Missing"*"target"* ]]; then
            comp="${issue%%:*}"
            targets="${issue#*: }"
            echo "- **$comp**: $targets" >> "$OUTPUT_MD"
        fi
    done
    
    cat >> "$OUTPUT_MD" << EOF

### Documentation Updates

Create documentation for these components:

EOF
    
    for issue in "${COMPONENT_ISSUES[@]}"; do
        if [[ "$issue" == *"Missing documentation"* ]]; then
            comp="${issue%%:*}"
            echo "- **$comp**" >> "$OUTPUT_MD"
        fi
    done
else
    echo "✅ **No remediation tasks required!** All components are fully integrated." >> "$OUTPUT_MD"
fi

# Add reference information
cat >> "$OUTPUT_MD" << EOF

## Reference Information

### Required Registry Entries

Each component should be registered in \`component_registry.json\` with the following attributes:

- Component name, category, and version
- Description of the component's purpose
- Integration status flags (installed, hardened, makefile, etc.)
- Port information if applicable

### Required Makefile Targets

Each component should have the following Makefile targets:

- \`[component]\` or \`install-[component]\`: Install the component
- \`[component]-status\`: Check the component's status
- \`[component]-logs\`: View the component's logs
- \`[component]-restart\`: Restart the component

### Required Documentation

Each component should have:

- A dedicated documentation file at \`docs/pages/components/[component].md\`
- AI-related components may have documentation in \`docs/pages/ai/[component].md\`

## Alpha Readiness Criteria

For the Alpha milestone, a component is considered ready when:

1. It has a complete registry entry with proper flags
2. It has all required Makefile targets
3. It has comprehensive documentation
4. It can be installed without errors
5. It is integrated with the dashboard
6. It supports multi-tenancy where applicable
EOF

# Print summary
echo -e "${CYAN}${BOLD}Alpha Readiness Summary:${RESET}"
echo -e "${GREEN}✅ Fully Integrated: ${#FULL_COMPONENTS[@]}${RESET}"
echo -e "${YELLOW}🔶 Partially Integrated: ${#PARTIAL_COMPONENTS[@]}${RESET}"
echo -e "${RED}❌ Missing Integration: ${#MISSING_COMPONENTS[@]}${RESET}"
echo -e "${CYAN}Total Components: ${#COMPONENTS[@]}${RESET}"
echo ""
echo -e "${CYAN}${BOLD}Report generated at:${RESET} $OUTPUT_MD"

# Update the Makefile if alpha-check target doesn't exist
if ! grep -q "^alpha-check:" "$MAKEFILE"; then
    echo -e "${CYAN}${BOLD}Adding alpha-check target to Makefile...${RESET}"
    
    cat >> "$MAKEFILE" << EOF

# Alpha Release Readiness Check
alpha-check:
	@echo "\$(MAGENTA)\$(BOLD)🔍 Checking Alpha Release Readiness...\$(RESET)"
	@\$(SCRIPTS_DIR)/utils/simple_alpha_check.sh
	@echo "\$(CYAN)Full report available at: docs/pages/components/alpha_ready.md\$(RESET)"
EOF
    
    echo -e "${GREEN}Added alpha-check target to Makefile${RESET}"
fi
