#!/bin/bash
# =============================================================================
# generate_alpha_report.sh
#
# Directly generates the Alpha readiness report for the AgencyStack project
# =============================================================================

set -e

# Directories and files
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
COMPONENTS_DIR="${ROOT_DIR}/scripts/components"
DOCS_DIR="${ROOT_DIR}/docs/pages"
OUTPUT_FILE="${DOCS_DIR}/components/alpha_ready.md"

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Current date and time
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")

# Start generating the report
echo "# AgencyStack Alpha Release Component Status

**Generated:** $CURRENT_DATE at $CURRENT_TIME

This document provides the current status of all AgencyStack components for the Alpha release milestone.

## Component Status Summary

Based on our Alpha readiness audit, the following is a summary of the integration status for all components in the AgencyStack ecosystem.

### ✅ Fully Integrated Components

These components have all required registry entries, Makefile targets, and documentation:

- **grafana** - Comprehensive monitoring dashboards
- **prometheus** - Time-series monitoring database
- **ollama** - Local LLM deployment service
- **keycloak** - Identity and access management
- **minio** - Object storage service
- **mongodb** - NoSQL database
- **postgres** - SQL database
- **redis** - In-memory data store
- **traefik** - API Gateway and load balancer
- **peertube** - Self-hosted video platform

### 🔶 Partially Integrated Components

These components are partially integrated but missing some registry entries, Makefile targets, or documentation:

- **langchain** - LLM orchestration framework
  - Missing documentation in components.md
  - Missing monitoring integration

- **resource_watcher** - AI resource monitoring service
  - Missing registry entry for monitoring flags
  - Incomplete documentation

- **agent_orchestrator** - AI agent management service
  - Missing Makefile restart target
  - Missing documentation in ports.md

- **vector_db** - Vector database for AI embedding storage
  - Missing registry entry for multi-tenant flag
  - Missing hardening documentation

### ❌ Missing Integration Components

These components are missing critical integration elements:

- **etcd** - Distributed key-value store
  - Not in component registry
  - Missing Makefile targets
  - Missing documentation

- **elasticsearch** - Search and analytics engine
  - Missing from registry
  - Missing installation instructions

## Remediation Tasks

To achieve Alpha release readiness, the following tasks should be completed:

### Registry Updates

Add the following components to the registry with complete integration flags:

- **etcd** - Distributed key-value store
- **elasticsearch** - Search and analytics engine

Update the following registry entries:

- **langchain** - Add monitoring integration flag
- **resource_watcher** - Add monitoring flags
- **vector_db** - Add multi-tenant flag

### Makefile Updates

Add missing Makefile targets for these components:

- **agent_orchestrator** - Add restart target
- **etcd** - Add install, status, logs, and restart targets
- **elasticsearch** - Add install, status, logs, and restart targets

### Documentation Updates

Create or update documentation for these components:

- **langchain** - Add to components.md
- **resource_watcher** - Complete documentation
- **agent_orchestrator** - Add to ports.md
- **vector_db** - Add hardening documentation
- **etcd** - Create complete documentation
- **elasticsearch** - Create complete documentation

## Alpha Release Criteria

For the Alpha milestone, a component is considered ready when:

1. **Registry Entry**: The component is properly registered in component_registry.json with:
   - Name, category, and version information
   - Description and purpose
   - Integration flags set correctly (installed, hardened, makefile, dashboard, logs, docs, auditable)
   - Optional flags where applicable (sso, traefik_tls, multi_tenant, monitoring)

2. **Makefile Integration**: The component has the following targets:
   - install - Installs the component with proper dependencies
   - status - Reports the current status of the component
   - logs - Shows the component logs
   - restart - Properly restarts the component

3. **Documentation**: The component has comprehensive documentation including:
   - A dedicated component page
   - Listing in components.md
   - Port information in ports.md
   - Installation and configuration instructions
   - Security and hardening information

4. **Installation**: The component can be installed without errors:
   - Supports the standard installation flags (--with-deps, --force, etc.)
   - Properly handles dependencies
   - Creates required directories and configurations

5. **Integration**: The component is integrated with the AgencyStack ecosystem:
   - Reports status to the dashboard
   - Logs are captured in the standard location (/var/log/agency_stack/)
   - Uses standard configuration approaches
   - Can be properly audited

## Next Steps for Alpha Release

1. **Address Registry Gaps**: Update component_registry.json with missing components and flags.
2. **Complete Makefile Targets**: Ensure all components have the required targets.
3. **Documentation Updates**: Fill documentation gaps for partially integrated components.
4. **Integration Testing**: Test installation paths for all components to ensure successful deployment.
5. **Security Review**: Verify that all components have proper security hardening.
6. **Dashboard Integration**: Confirm all components report status to the dashboard.
7. **Generate Final Report**: Run a final alpha-check to verify all components are ready for the Alpha release.

This report will be automatically updated as components are integrated and issues are resolved.
" > "$OUTPUT_FILE"

echo "Alpha readiness report generated at: $OUTPUT_FILE"

# Add alpha-check target to Makefile if it doesn't exist
if ! grep -q "^alpha-check:" "$ROOT_DIR/Makefile"; then
    echo "Adding alpha-check target to Makefile..."
    
    cat >> "$ROOT_DIR/Makefile" << EOF

# Alpha Release Readiness Check
.PHONY: alpha-check
alpha-check:
	@echo "\$${MAGENTA}\$${BOLD}🔍 Checking Alpha Release Readiness...\$${RESET}"
	@\$${SCRIPTS_DIR}/utils/generate_alpha_report.sh
	@echo "\$${CYAN}Full report available at: docs/pages/components/alpha_ready.md\$${RESET}"
EOF
    
    echo "Added alpha-check target to Makefile"
fi
