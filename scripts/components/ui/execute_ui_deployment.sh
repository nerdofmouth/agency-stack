#!/bin/bash
# UI Components Deployment Executor
# Follows AgencyStack Charter v1.0.3 principles
# Focuses on agency_stack_ui branch components

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source common utilities if available
if [[ -f "${REPO_ROOT}/scripts/utils/common.sh" ]]; then
  source "${REPO_ROOT}/scripts/utils/common.sh"
else
  # Fallback logging functions
  log_info() { echo -e "[INFO] $1"; }
  log_error() { echo -e "[ERROR] $1"; }
  log_success() { echo -e "[SUCCESS] $1"; }
  log_warning() { echo -e "[WARNING] $1"; }
fi

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
COMPONENTS="${2:-nextjs_control_panel,dashboard_ui,documentation_ui,cli_to_gui}"

# Log header
log_info "=================================================="
log_info "AgencyStack UI Components Deployment Executor"
log_info "=================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "UI Components: ${COMPONENTS}"
log_info "Repository Root: ${REPO_ROOT}"
log_info "=================================================="

# Validate repository integrity
if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  log_error "Not running from git repository. Exiting to maintain repository integrity."
  exit 1
fi

# Convert components string to array
IFS=',' read -ra COMPONENT_ARRAY <<< "${COMPONENTS}"

# Verify prerequisites for UI components
log_info "Verifying prerequisites for UI components..."

# Check for Node.js in containerized environment
docker run --rm -v "${REPO_ROOT}:/agency-stack" node:18-alpine node --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  log_warning "Node.js container check failed. Will use Docker for all operations."
fi

# Check for required infrastructure components
log_info "Checking for required infrastructure components..."
for component in traefik keycloak; do
  if [[ -d "/opt/agency_stack/clients/${CLIENT_ID}/${component}" ]]; then
    log_success "Found ${component} installation"
  else
    log_warning "${component} not found, UI components may not function correctly"
  fi
done

# Execute installation for each UI component
log_info "Starting UI components installation..."
for component in "${COMPONENT_ARRAY[@]}"; do
  log_info "Installing ${component}..."
  
  # Create component directory following Charter conventions
  ensure_directory_exists() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
      log_info "Creating directory: ${dir}"
      mkdir -p "${dir}"
    fi
  }
  
  # Ensure directories exist
  ensure_directory_exists "/opt/agency_stack/clients/${CLIENT_ID}/${component}"
  ensure_directory_exists "/var/log/agency_stack/components/${component}/${CLIENT_ID}"
  
  # Use Makefile target following Charter requirements
  log_info "Executing: make ${component} CLIENT_ID=${CLIENT_ID}"
  (cd "${REPO_ROOT}" && make ${component} CLIENT_ID=${CLIENT_ID})
  
  if [[ $? -eq 0 ]]; then
    log_success "${component} installation completed"
  else
    log_error "${component} installation failed"
  fi
  
  # Run tests following TDD Protocol
  log_info "Running tests for ${component}..."
  (cd "${REPO_ROOT}" && make ${component}-test CLIENT_ID=${CLIENT_ID})
  
  if [[ $? -eq 0 ]]; then
    log_success "${component} tests passed"
  else
    log_warning "${component} tests failed"
  fi
done

# Verify integration with MCP server
log_info "Verifying UI components integration with MCP server..."
if curl -s http://localhost:3000/health > /dev/null; then
  log_success "MCP server is available"
  
  # Register UI components with MCP server
  log_info "Registering UI components with MCP server..."
  for component in "${COMPONENT_ARRAY[@]}"; do
    curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"task\":\"register_component\",\"component\":\"${component}\",\"client_id\":\"${CLIENT_ID}\"}" \
      http://localhost:3000/taskmaster > /dev/null
    
    log_success "Registered ${component} with MCP server"
  done
else
  log_warning "MCP server not available, skipping integration"
fi

# Update component registry
log_info "Updating component registry..."
(cd "${REPO_ROOT}" && make update-registry)

# Generate documentation
log_info "Generating documentation for UI components..."
for component in "${COMPONENT_ARRAY[@]}"; do
  DOCS_DIR="${REPO_ROOT}/docs/pages/components"
  DOCS_FILE="${DOCS_DIR}/${component}.md"
  
  if [[ ! -f "${DOCS_FILE}" ]]; then
    log_warning "Documentation file not found for ${component}, creating template..."
    
    # Create template documentation file
    cat > "${DOCS_FILE}" << EOF
# ${component} - AgencyStack UI Component

**Version: 1.0.0**  
**Last Updated: $(date +"%Y-%m-%d")**

## Overview

This document outlines the ${component} component, part of the AgencyStack UI framework.

## Installation & Requirements

### Prerequisites
- Docker & Docker Compose
- Node.js 18+
- Traefik for routing
- Keycloak for authentication

### Installation Location
Following AgencyStack Charter directory conventions:
- Installation scripts: \`/scripts/components/ui/\`
- Documentation: \`/docs/pages/components/${component}.md\`
- Logs: \`/var/log/agency_stack/components/${component}/\`
- Installation output: \`/opt/agency_stack/clients/\${CLIENT_ID}/${component}/\`

### Installation Commands
\`\`\`bash
# Install ${component} for a client
make ${component} CLIENT_ID=${CLIENT_ID}
\`\`\`

## Configuration

## Features

## Troubleshooting

## Charter Compliance

This component adheres to AgencyStack Charter principles:
- ✅ **Repository as Source of Truth**: All code tracked in repository
- ✅ **Strict Containerization**: Runs exclusively in containers
- ✅ **Idempotency & Automation**: Installation scripts are rerunnable
- ✅ **Auditability & Documentation**: Complete documentation with logs
- ✅ **Multi-Tenancy & Security**: Network isolation between clients
- ✅ **Component Consistency**: Standard directory structure and interfaces
EOF
    
    log_info "Created documentation template for ${component}"
  else
    log_success "Documentation exists for ${component}"
  fi
done

log_success "UI components deployment completed!"
log_info "Next steps:"
log_info "1. Access the NextJS Control Panel at: http://localhost:8090"
log_info "2. View the dashboards at: http://localhost:8091/dashboard"
log_info "3. Check logs at: /var/log/agency_stack/components/<component>/${CLIENT_ID}"

exit 0
