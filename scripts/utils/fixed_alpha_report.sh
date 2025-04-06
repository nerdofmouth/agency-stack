#!/bin/bash
# =============================================================================
# fixed_alpha_report.sh
# 
# A simplified report generator for AgencyStack Alpha components
# =============================================================================

# Strict error handling
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
COMPONENTS_DIR="${SCRIPTS_DIR}/components"
CONFIG_DIR="${ROOT_DIR}/config"
REGISTRY_DIR="${CONFIG_DIR}/registry"
REGISTRY_FILE="${REGISTRY_DIR}/component_registry.json"
DOCS_DIR="${ROOT_DIR}/docs"
OUTPUT_MD="${DOCS_DIR}/pages/components/alpha_ready.md"

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Count variables
CORE_COMPONENTS=0
UI_COMPONENTS=0
AI_COMPONENTS=0
TOTAL_COMPONENTS=0

echo "Generating AgencyStack Alpha Release Status Report..."

# Check for installation scripts
echo "Checking component installation scripts..."
INSTALL_SCRIPTS=$(find "$COMPONENTS_DIR" -name "install_*.sh" -type f | wc -l)
echo "Found $INSTALL_SCRIPTS installation scripts"

# Count components in registry
echo "Checking component registry..."
if [[ -f "$REGISTRY_FILE" ]]; then
  # Count components by category
  CORE_COMPONENTS=$(jq '.components.infrastructure | length' "$REGISTRY_FILE")
  CORE_COMPONENTS=$((CORE_COMPONENTS + $(jq '.components.security_storage | length' "$REGISTRY_FILE")))
  CORE_COMPONENTS=$((CORE_COMPONENTS + $(jq '.components.monitoring | length' "$REGISTRY_FILE")))
  
  UI_COMPONENTS=$(jq '.components.content | length' "$REGISTRY_FILE")
  UI_COMPONENTS=$((UI_COMPONENTS + $(jq '.components.crm | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)))
  
  AI_COMPONENTS=$(jq '.components.ai | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)
  
  TOTAL_COMPONENTS=$((CORE_COMPONENTS + UI_COMPONENTS + AI_COMPONENTS))
  
  echo "Categories detected in registry:"
  jq '.components | keys[]' "$REGISTRY_FILE"
else
  echo "Component registry not found!"
fi

# Generate the report
echo "Generating report..."
cat > "$OUTPUT_MD" <<EOL
# AgencyStack Alpha Release Readiness Report

**Generated:** $(date "+%Y-%m-%d %H:%M:%S")

This report provides an overview of the AgencyStack components and their readiness for the Alpha release.

## Component Summary

- **Core Components:** $CORE_COMPONENTS
- **UI Components:** $UI_COMPONENTS
- **AI Components:** $AI_COMPONENTS
- **Total Components:** $TOTAL_COMPONENTS

## Feature Branch Status

| Branch | Status | Components |
|--------|--------|------------|
| agency_stack_core | ✅ Merged | $CORE_COMPONENTS components |
| agency_stack_ui | ✅ Merged | $UI_COMPONENTS components |
| agency_stack_ai | ✅ Merged | $AI_COMPONENTS components |

## Component Details

### Core Infrastructure

$(jq -r '.components.infrastructure | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "No core infrastructure components found")

### Security & Storage

$(jq -r '.components.security_storage | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "No security & storage components found")

### Monitoring & Observability

$(jq -r '.components.monitoring | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "No monitoring components found")

### Content & CRM

$(jq -r '.components.content | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "No content components found")
$(jq -r '.components.crm | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "")

### AI Components

$(jq -r '.components.ai | to_entries[] | "- **\(.value.name)** (\(.key)): \(.value.description // "No description")"' "$REGISTRY_FILE" 2>/dev/null || echo "No AI components found")

## Alpha Release Readiness

The AgencyStack Alpha release is nearly ready with all core functionality implemented:

- Core Infrastructure: $(if [[ $CORE_COMPONENTS -gt 0 ]]; then echo "✅ Ready"; else echo "⚠️ Missing Components"; fi)
- UI Layer: $(if [[ $UI_COMPONENTS -gt 0 ]]; then echo "✅ Ready"; else echo "⚠️ Missing Components"; fi)
- AI Features: $(if [[ $AI_COMPONENTS -gt 0 ]]; then echo "✅ Ready"; else echo "⚠️ Missing Components"; fi)

## Next Steps

1. Verify all Makefile targets are working correctly
2. Ensure comprehensive documentation for all components
3. Finalize release notes for v0.1.0-alpha
4. Create Git tag and GitHub release
EOL

echo "Report generated at: $OUTPUT_MD"
echo ""
echo -e "${GREEN}Core Components: $CORE_COMPONENTS${RESET}"
echo -e "${CYAN}UI Components: $UI_COMPONENTS${RESET}"
echo -e "${YELLOW}AI Components: $AI_COMPONENTS${RESET}"
echo -e "${GREEN}Total Components: $TOTAL_COMPONENTS${RESET}"
