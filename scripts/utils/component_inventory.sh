#!/bin/bash
# =============================================================================
# component_inventory.sh
# 
# Creates a comprehensive inventory of all installation scripts and compares
# them against the component registry to identify missing components.
# =============================================================================

# Strict error handling
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
COMPONENTS_DIR="${SCRIPTS_DIR}/components"
BUNDLE_DIR="${SCRIPTS_DIR}/agency_stack_bootstrap_bundle_v10"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_DIR="${CONFIG_DIR}/registry"
REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
OUTPUT_DIR="${ROOT_DIR}/tmp"
OUTPUT_FILE="${OUTPUT_DIR}/component_analysis.md"

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

echo "=== AgencyStack Component Inventory ==="
echo "Starting comprehensive component analysis..."

# Temporary files
ALL_SCRIPTS_FILE="${OUTPUT_DIR}/all_install_scripts.txt"
REGISTRY_COMPONENTS_FILE="${OUTPUT_DIR}/registry_components.txt"
MISSING_COMPONENTS_FILE="${OUTPUT_DIR}/missing_components.txt"
MAKEFILE_TARGETS_FILE="${OUTPUT_DIR}/makefile_targets.txt"
DOCS_COMPONENTS_FILE="${OUTPUT_DIR}/docs_components.txt"

# Find all installation scripts in the repository
echo "Finding all installation scripts..."
find "${ROOT_DIR}" -name "install_*.sh" | sort > "${ALL_SCRIPTS_FILE}"
TOTAL_SCRIPTS=$(wc -l < "${ALL_SCRIPTS_FILE}")
echo -e "${GREEN}Found ${TOTAL_SCRIPTS} installation scripts${RESET}"

# Extract component names from script filenames
echo "Extracting component names from scripts..."
grep -o 'install_[^/]*\.sh' "${ALL_SCRIPTS_FILE}" | sed 's/install_\(.*\)\.sh/\1/' | sort | uniq > "${OUTPUT_DIR}/script_components.txt"
TOTAL_COMPONENTS=$(wc -l < "${OUTPUT_DIR}/script_components.txt")
echo -e "${GREEN}Identified ${TOTAL_COMPONENTS} unique components from scripts${RESET}"

# Extract components from registry
echo "Extracting components from registry..."
if [[ -f "${REGISTRY_FILE}" ]]; then
    jq -r '.components | to_entries[] | .key' "${REGISTRY_FILE}" > "${OUTPUT_DIR}/registry_categories.txt"
    jq -r '.components | to_entries[] | .value | to_entries[] | .key' "${REGISTRY_FILE}" | sort > "${REGISTRY_COMPONENTS_FILE}"
    TOTAL_REGISTRY=$(wc -l < "${REGISTRY_COMPONENTS_FILE}")
    echo -e "${GREEN}Found ${TOTAL_REGISTRY} components in registry${RESET}"
else
    echo -e "${RED}Component registry file not found: ${REGISTRY_FILE}${RESET}"
    touch "${REGISTRY_COMPONENTS_FILE}"
    TOTAL_REGISTRY=0
fi

# Extract categories from registry
if [[ -f "${REGISTRY_FILE}" ]]; then
    CATEGORIES=$(jq -r '.components | keys[]' "${REGISTRY_FILE}" | sort | tr '\n' ', ' | sed 's/,$//')
    echo -e "${CYAN}Registry categories: ${CATEGORIES}${RESET}"
fi

# Find components missing from registry
echo "Identifying components missing from registry..."
comm -23 "${OUTPUT_DIR}/script_components.txt" "${REGISTRY_COMPONENTS_FILE}" > "${MISSING_COMPONENTS_FILE}"
MISSING_COUNT=$(wc -l < "${MISSING_COMPONENTS_FILE}")
echo -e "${YELLOW}Found ${MISSING_COUNT} components missing from registry${RESET}"

# Extract Makefile targets
echo "Extracting Makefile component targets..."
grep -E '^[a-zA-Z0-9_-]+:' "${ROOT_DIR}/Makefile" | grep -v "\$(MAKE)" | sed 's/:.*//' | grep -v -E '(help|install$|update$|client$|test-env$|backup$|clean$|stack-info$)' | sort > "${MAKEFILE_TARGETS_FILE}"
MAKEFILE_TARGETS=$(wc -l < "${MAKEFILE_TARGETS_FILE}")
echo -e "${GREEN}Found ${MAKEFILE_TARGETS} Makefile targets${RESET}"

# Check for component documentation
echo "Checking for component documentation..."
find "${ROOT_DIR}/docs/pages/components" -name "*.md" | grep -v "index.md" | grep -v "alpha_ready.md" | sed 's/.*\/\(.*\)\.md/\1/' | sort > "${DOCS_COMPONENTS_FILE}"
DOCS_COUNT=$(wc -l < "${DOCS_COMPONENTS_FILE}")
echo -e "${GREEN}Found ${DOCS_COUNT} component documentation files${RESET}"

# Generate the analysis report
echo "Generating comprehensive analysis report..."
cat > "${OUTPUT_FILE}" <<EOL
# AgencyStack Component Inventory Analysis

**Generated:** $(date "+%Y-%m-%d %H:%M:%S")

This report provides a comprehensive analysis of all AgencyStack components, identifying gaps in component registration, Makefile targets, and documentation.

## Summary

- **Total Installation Scripts:** ${TOTAL_SCRIPTS}
- **Unique Components Identified:** ${TOTAL_COMPONENTS}
- **Components in Registry:** ${TOTAL_REGISTRY}
- **Components Missing from Registry:** ${MISSING_COUNT}
- **Makefile Targets:** ${MAKEFILE_TARGETS}
- **Component Documentation Files:** ${DOCS_COUNT}

## Missing Components

The following components have installation scripts but are not properly registered in the component registry:

\`\`\`
$(cat "${MISSING_COMPONENTS_FILE}")
\`\`\`

## Categorized Component Analysis

| Component | In Registry | Has Makefile Target | Has Documentation |
|-----------|-------------|---------------------|-------------------|
EOL

# Generate detailed component analysis
while IFS= read -r component; do
    in_registry="❌"
    has_makefile="❌"
    has_docs="❌"
    
    # Check if in registry
    if grep -q "^${component}$" "${REGISTRY_COMPONENTS_FILE}"; then
        in_registry="✅"
    fi
    
    # Check if has Makefile target
    if grep -q "^${component}:" "${ROOT_DIR}/Makefile"; then
        has_makefile="✅"
    fi
    
    # Check if has documentation
    if grep -q "^${component}$" "${DOCS_COMPONENTS_FILE}"; then
        has_docs="✅"
    fi
    
    # Append to report
    echo "| ${component} | ${in_registry} | ${has_makefile} | ${has_docs} |" >> "${OUTPUT_FILE}"
done < "${OUTPUT_DIR}/script_components.txt"

# Add registry categories section to report
if [[ -f "${REGISTRY_FILE}" ]]; then
    echo "" >> "${OUTPUT_FILE}"
    echo "## Registry Categories" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"
    
    while IFS= read -r category; do
        echo "### ${category^}" >> "${OUTPUT_FILE}"
        echo "" >> "${OUTPUT_FILE}"
        jq -r ".components.${category} | to_entries[] | \"- **\(.value.name)** (\(.key)): \(.value.description // \"No description provided\")\"" "${REGISTRY_FILE}" >> "${OUTPUT_FILE}"
        echo "" >> "${OUTPUT_FILE}"
    done < "${OUTPUT_DIR}/registry_categories.txt"
fi

# Add recommendations section
cat >> "${OUTPUT_FILE}" <<EOL

## Next Steps

1. **Registry Updates:** Add the ${MISSING_COUNT} missing components to the component registry with appropriate metadata.
2. **Makefile Integration:** Ensure each component has consistent install, status, logs, and restart targets.
3. **Documentation:** Create missing documentation for components lacking proper docs.
4. **Alpha Check Enhancement:** Update alpha-check scripts to properly detect and validate all components.

## Action Items by Priority

1. First, add high-priority missing components to the registry:
   - Any security components
   - Core infrastructure components
   - Essential services
   
2. Next, add Makefile targets for high-priority components.

3. Finally, create documentation for high-priority components.
EOL

echo -e "${GREEN}Analysis complete! Report generated at: ${OUTPUT_FILE}${RESET}"
echo "Opening report..."
cat "${OUTPUT_FILE}"
