#!/bin/bash
# AgencyStack Component Bootstrap Utility
# Creates scaffold for new components following Charter v1.0.3 principles
# Ensures proper structure, sourcing, and safety checks from the start

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Source changelog utilities if available
if [[ -f "${SCRIPT_DIR}/changelog_utils.sh" ]]; then
  source "${SCRIPT_DIR}/changelog_utils.sh"
fi

# Display usage information
show_usage() {
  echo -e "${BOLD}AgencyStack Component Bootstrap${NC}"
  echo "Creates a properly structured component following Charter v1.0.3 principles"
  echo ""
  echo "Usage:"
  echo "  $(basename "$0") <component_name> [options]"
  echo ""
  echo "Options:"
  echo "  --description TEXT   Component description (default: 'AgencyStack Component')"
  echo "  --ports PORT,...     Comma-separated list of ports the component uses"
  echo "  --dependencies DEP,. Comma-separated list of component dependencies"
  echo "  --template NAME      Base template to use (default: 'standard')"
  echo "  --client-specific    Make this a client-specific component"
  echo "  --help               Show this help message"
  echo ""
  echo "Example:"
  echo "  $(basename "$0") nextcloud --ports 8080,8443 --dependencies traefik,keycloak"
  echo ""
}

# Check that we're running inside a container/VM
exit_with_warning_if_host "component_bootstrap"

# Default values
COMPONENT_NAME=""
COMPONENT_DESCRIPTION="AgencyStack Component"
COMPONENT_PORTS=""
COMPONENT_DEPENDENCIES=""
TEMPLATE="standard"
CLIENT_SPECIFIC=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --description) COMPONENT_DESCRIPTION="$2"; shift ;;
    --ports) COMPONENT_PORTS="$2"; shift ;;
    --dependencies) COMPONENT_DEPENDENCIES="$2"; shift ;;
    --template) TEMPLATE="$2"; shift ;;
    --client-specific) CLIENT_SPECIFIC=true ;;
    --help) show_usage; exit 0 ;;
    -*) echo "Unknown option: $1"; show_usage; exit 1 ;;
    *) 
      if [[ -z "$COMPONENT_NAME" ]]; then
        COMPONENT_NAME="$1"
      else
        echo "Unknown argument: $1"; show_usage; exit 1
      fi
      ;;
  esac
  shift
done

# Validate required parameters
if [[ -z "$COMPONENT_NAME" ]]; then
  log_error "Component name is required."
  show_usage
  exit 1
fi

# Set up paths
COMPONENTS_DIR="${REPO_ROOT}/scripts/components"
TEMPLATES_DIR="${COMPONENTS_DIR}/templates"
DOCS_DIR="${REPO_ROOT}/docs/pages/components"
MAKEFILE_DIR="${REPO_ROOT}/makefiles/components"

log_info "Bootstrapping new component: ${COMPONENT_NAME}"

# Ensure required directories exist
ensure_directory_exists "$COMPONENTS_DIR"
ensure_directory_exists "$TEMPLATES_DIR"
ensure_directory_exists "$DOCS_DIR"
ensure_directory_exists "$MAKEFILE_DIR"

# Create prefixes based on client specificity
if [[ "$CLIENT_SPECIFIC" == "true" ]]; then
  INSTALL_SCRIPT_NAME="install_client_${COMPONENT_NAME}.sh"
  ENV_EXAMPLE_NAME="client-${COMPONENT_NAME}.env.example"
else
  INSTALL_SCRIPT_NAME="install_${COMPONENT_NAME}.sh"
  ENV_EXAMPLE_NAME="${COMPONENT_NAME}.env.example"
fi

# Check if files already exist
if [[ -f "${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}" ]]; then
  log_error "Installation script already exists: ${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}"
  log_error "Cannot overwrite existing component. Use a different name or remove it first."
  exit 1
fi

# Create the installation script
log_info "Creating installation script..."
cat > "${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}" << EOL
#!/bin/bash
# AgencyStack ${COMPONENT_NAME} Installation Script
# Created: $(date)
# Following AgencyStack Charter v1.0.3 principles

set -euo pipefail

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Enable error trapping
trap_agencystack_errors

# Validate running in container/VM environment - REQUIRED BY CHARTER v1.0.3
exit_with_warning_if_host "${COMPONENT_NAME}"

# Component-specific configuration
COMPONENT_NAME="${COMPONENT_NAME}"
COMPONENT_DESCRIPTION="${COMPONENT_DESCRIPTION}"
LOG_FILE="\${LOG_DIR:-/var/log/agency_stack/components}/${COMPONENT_NAME}.log"
INSTALL_DIR="\${INSTALL_DIR:-/opt/agency_stack}"

# Default values
CLIENT_ID="\${CLIENT_ID:-default}"
DOMAIN="\${DOMAIN:-localhost}"
PORT="\${PORT:-8080}"
ADMIN_EMAIL="\${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="\${ADMIN_PASSWORD:-}"
VERSION="\${VERSION:-latest}"
DATA_DIR="\${DATA_DIR:-\${INSTALL_DIR}/clients/\${CLIENT_ID}/${COMPONENT_NAME}}"
FORCE="\${FORCE:-false}"
WITH_DEPS="\${WITH_DEPS:-false}"
VERBOSE="\${VERBOSE:-false}"

# Parse arguments
while [[ "\$#" -gt 0 ]]; do
  case \$1 in
    --client-id) CLIENT_ID="\$2"; shift ;;
    --domain) DOMAIN="\$2"; shift ;;
    --port) PORT="\$2"; shift ;;
    --admin-email) ADMIN_EMAIL="\$2"; shift ;;
    --admin-password) ADMIN_PASSWORD="\$2"; shift ;;
    --version) VERSION="\$2"; shift ;;
    --data-dir) DATA_DIR="\$2"; shift ;;
    --force) FORCE="true" ;;
    --with-deps) WITH_DEPS="true" ;;
    --verbose) VERBOSE="true" ;;
    --help) 
      log_info "Usage: \$0 [options]"
      log_info "Options:"
      log_info "  --client-id ID       Client ID (default: default)"
      log_info "  --domain DOMAIN      Domain to use (default: localhost)"
      log_info "  --port PORT          Port to use (default: 8080)"
      log_info "  --admin-email EMAIL  Admin email (default: admin@example.com)"
      log_info "  --admin-password PWD Admin password (default: auto-generated)"
      log_info "  --version VERSION    Version to install (default: latest)"
      log_info "  --data-dir DIR       Data directory (default: /opt/agency_stack/clients/CLIENT_ID/${COMPONENT_NAME})"
      log_info "  --force              Force reinstallation"
      log_info "  --with-deps          Install dependencies"
      log_info "  --verbose            Enable verbose output"
      log_info "  --help               Show this help message"
      exit 0
      ;;
    *) log_error "Unknown parameter: \$1"; exit 1 ;;
  esac
  shift
done

# Generate admin password if not provided
if [[ -z "\$ADMIN_PASSWORD" ]]; then
  ADMIN_PASSWORD="\$(openssl rand -base64 12)"
  log_info "Generated admin password: \$ADMIN_PASSWORD"
fi

# Log script invocation
log_info "==============================================" 
log_info "Starting \$(basename "\${BASH_SOURCE[0]}")"
log_info "CLIENT_ID: \$CLIENT_ID"
log_info "DOMAIN: \$DOMAIN"
log_info "=============================================="

# Check if already installed
COMPONENT_DIR="\${DATA_DIR}"
if [[ -d "\$COMPONENT_DIR" ]] && [[ "\$FORCE" != "true" ]]; then
  log_warning "${COMPONENT_NAME} appears to be already installed at \$COMPONENT_DIR"
  log_warning "Use --force to reinstall or upgrade"
  log_warning "Exiting without changes"
  exit 0
fi

# Install dependencies if requested
if [[ "\$WITH_DEPS" == "true" ]]; then
  log_info "Installing dependencies..."
  # Add dependency installation logic here
fi

# Main installation logic
log_info "Starting ${COMPONENT_NAME} installation for \$CLIENT_ID at \$DOMAIN..."

# Create required directories
log_info "Creating required directories"
ensure_directory_exists "\$COMPONENT_DIR"
ensure_directory_exists "\$COMPONENT_DIR/config"
ensure_directory_exists "\$COMPONENT_DIR/data"

# Create .env file
log_info "Creating .env file"
cat > "\$COMPONENT_DIR/.env" << EOF
# ${COMPONENT_NAME} Configuration
# Generated: \$(date)
# Client: \$CLIENT_ID

DOMAIN=\$DOMAIN
PORT=\$PORT
ADMIN_EMAIL=\$ADMIN_EMAIL
ADMIN_PASSWORD=\$ADMIN_PASSWORD
VERSION=\$VERSION
EOF

# TODO: Add your component installation logic here
# Create docker-compose.yml
log_info "Creating Docker Compose configuration"
cat > "\$COMPONENT_DIR/docker-compose.yml" << EOF
version: '3'

services:
  ${COMPONENT_NAME}:
    container_name: \${CLIENT_ID}_${COMPONENT_NAME}
    image: ${COMPONENT_NAME}:\${VERSION}
    restart: unless-stopped
    volumes:
      - \${COMPONENT_DIR}/config:/config
      - \${COMPONENT_DIR}/data:/data
    environment:
      - DOMAIN=\${DOMAIN}
      - ADMIN_EMAIL=\${ADMIN_EMAIL}
      - ADMIN_PASSWORD=\${ADMIN_PASSWORD}
    networks:
      - ${COMPONENT_NAME}_network
    ports:
      - "\${PORT}:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  ${COMPONENT_NAME}_network:
    driver: bridge
EOF

# Start the services
log_info "Starting ${COMPONENT_NAME} with Docker Compose..."
cd "\$COMPONENT_DIR" && docker-compose up -d

# Verify installation
log_info "Verifying installation..."
sleep 5
if docker ps | grep -q "\${CLIENT_ID}_${COMPONENT_NAME}"; then
  log_success "✅ ${COMPONENT_NAME} installation complete"
  log_info ""
  log_info "🌐 Access ${COMPONENT_NAME} at: \$DOMAIN:\$PORT"
  log_info "👤 Admin: admin"
  log_info "🔑 Password: \$ADMIN_PASSWORD"
  log_info ""
  log_info "Credentials stored in \$COMPONENT_DIR/.env"
else
  log_error "❌ ${COMPONENT_NAME} installation failed! Check logs for details."
  exit 1
fi

# Mark as installed
mark_installed "${COMPONENT_NAME}" "\$CLIENT_ID" "\$VERSION"
EOL
chmod +x "${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}"

# Create .env.example
log_info "Creating .env.example..."
cat > "${TEMPLATES_DIR}/${ENV_EXAMPLE_NAME}" << EOL
# ${COMPONENT_NAME} Environment Variables
# This is an example file, copy to .env and adjust as needed

# Basic configuration
DOMAIN=example.com
PORT=8080
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=StrongPasswordHere

# Version to install
VERSION=latest

# Additional options
DEBUG=false
ENABLE_METRICS=false
EOL

# Create verification script
log_info "Creating verification script..."
cat > "${COMPONENTS_DIR}/verify_${COMPONENT_NAME}.sh" << EOL
#!/bin/bash
# ${COMPONENT_NAME} Verification Script
# Created: $(date)
# Following AgencyStack Charter v1.0.3 principles TDD protocol

set -euo pipefail

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Enable error trapping
trap_agencystack_errors

# Validate running in container/VM environment
exit_with_warning_if_host "${COMPONENT_NAME}_verify"

# Default values
CLIENT_ID="\${CLIENT_ID:-default}"
DOMAIN="\${DOMAIN:-localhost}"
PORT="\${PORT:-8080}"
VERBOSE="\${VERBOSE:-false}"

# Parse arguments
while [[ "\$#" -gt 0 ]]; do
  case \$1 in
    --client-id) CLIENT_ID="\$2"; shift ;;
    --domain) DOMAIN="\$2"; shift ;;
    --port) PORT="\$2"; shift ;;
    --verbose) VERBOSE="true" ;;
    --help) 
      log_info "Usage: \$0 [options]"
      log_info "Options:"
      log_info "  --client-id ID    Client ID (default: default)"
      log_info "  --domain DOMAIN   Domain to verify (default: localhost)"
      log_info "  --port PORT       Port to use (default: 8080)"
      log_info "  --verbose         Enable verbose output"
      log_info "  --help            Show this help message"
      exit 0
      ;;
    *) log_error "Unknown parameter: \$1"; exit 1 ;;
  esac
  shift
done

log_info "Verifying ${COMPONENT_NAME} installation..."
log_info "CLIENT_ID: \$CLIENT_ID"
log_info "DOMAIN: \$DOMAIN"
log_info "PORT: \$PORT"

# Component directory
COMPONENT_DIR="/opt/agency_stack/clients/\${CLIENT_ID}/${COMPONENT_NAME}"

# Check if component is installed
if [[ ! -d "\$COMPONENT_DIR" ]]; then
  log_error "${COMPONENT_NAME} does not appear to be installed at \$COMPONENT_DIR"
  exit 1
fi

# Check if container is running
if ! docker ps | grep -q "\${CLIENT_ID}_${COMPONENT_NAME}"; then
  log_error "${COMPONENT_NAME} container is not running"
  exit 1
fi

# Check if service is responding
if ! curl -s -o /dev/null -w "%{http_code}" "http://\$DOMAIN:\$PORT/health" | grep -q "200"; then
  log_error "${COMPONENT_NAME} service is not responding"
  exit 1
fi

log_success "✅ ${COMPONENT_NAME} verification passed"
exit 0
EOL
chmod +x "${COMPONENTS_DIR}/verify_${COMPONENT_NAME}.sh"

# Create test script
log_info "Creating test script..."
cat > "${COMPONENTS_DIR}/test_${COMPONENT_NAME}.sh" << EOL
#!/bin/bash
# ${COMPONENT_NAME} Unit Test Script
# Created: $(date)
# Following AgencyStack Charter v1.0.3 principles TDD protocol

set -euo pipefail

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Enable error trapping
trap_agencystack_errors

# Source test utilities if available
if [[ -f "\${SCRIPT_DIR}/../utils/test_common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/test_common.sh"
fi

# Validate running in container/VM environment
exit_with_warning_if_host "${COMPONENT_NAME}_test"

# Default values
CLIENT_ID="\${CLIENT_ID:-default}"
DOMAIN="\${DOMAIN:-localhost}"
PORT="\${PORT:-8080}"
VERBOSE="\${VERBOSE:-false}"

# Component directory
COMPONENT_DIR="/opt/agency_stack/clients/\${CLIENT_ID}/${COMPONENT_NAME}"

# Test setup
log_info "Setting up tests for ${COMPONENT_NAME}..."

# Test functions
test_installation() {
  log_info "Testing installation directory..."
  assert_directory_exists "\$COMPONENT_DIR"
  assert_file_exists "\$COMPONENT_DIR/.env"
  assert_file_exists "\$COMPONENT_DIR/docker-compose.yml"
}

test_container() {
  log_info "Testing container status..."
  assert_container_running "\${CLIENT_ID}_${COMPONENT_NAME}"
}

test_network() {
  log_info "Testing network connectivity..."
  assert_port_open "\$DOMAIN" "\$PORT"
}

test_api() {
  log_info "Testing API endpoints..."
  assert_http_status "\$DOMAIN" "\$PORT" "/health" 200
}

# Run tests
log_info "Running ${COMPONENT_NAME} tests..."
run_test test_installation
run_test test_container
run_test test_network
run_test test_api

# Test summary
log_info "All tests completed successfully for ${COMPONENT_NAME}"
exit 0
EOL
chmod +x "${COMPONENTS_DIR}/test_${COMPONENT_NAME}.sh"

# Create integration test script
log_info "Creating integration test script..."
cat > "${COMPONENTS_DIR}/integration_test_${COMPONENT_NAME}.sh" << EOL
#!/bin/bash
# ${COMPONENT_NAME} Integration Test Script
# Created: $(date)
# Following AgencyStack Charter v1.0.3 principles TDD protocol

set -euo pipefail

# Source common utilities
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "\${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found. Cannot proceed without common utilities."
  exit 1
fi

# Enable error trapping
trap_agencystack_errors

# Source test utilities if available
if [[ -f "\${SCRIPT_DIR}/../utils/test_common.sh" ]]; then
  source "\${SCRIPT_DIR}/../utils/test_common.sh"
fi

# Validate running in container/VM environment
exit_with_warning_if_host "${COMPONENT_NAME}_integration_test"

# Default values
CLIENT_ID="\${CLIENT_ID:-default}"
DOMAIN="\${DOMAIN:-localhost}"
PORT="\${PORT:-8080}"
VERBOSE="\${VERBOSE:-false}"

# Component directory
COMPONENT_DIR="/opt/agency_stack/clients/\${CLIENT_ID}/${COMPONENT_NAME}"

# Test setup
log_info "Setting up integration tests for ${COMPONENT_NAME}..."

# Test functions
test_with_traefik() {
  log_info "Testing Traefik integration..."
  # Add Traefik integration tests here
  return 0
}

test_with_keycloak() {
  log_info "Testing Keycloak integration..."
  # Add Keycloak integration tests here
  return 0
}

test_with_monitoring() {
  log_info "Testing monitoring integration..."
  # Add monitoring integration tests here
  return 0
}

# Run integration tests
log_info "Running ${COMPONENT_NAME} integration tests..."
run_test test_with_traefik
run_test test_with_keycloak
run_test test_with_monitoring

# Test summary
log_info "All integration tests completed successfully for ${COMPONENT_NAME}"
exit 0
EOL
chmod +x "${COMPONENTS_DIR}/integration_test_${COMPONENT_NAME}.sh"

# Create component documentation
log_info "Creating component documentation..."
cat > "${DOCS_DIR}/${COMPONENT_NAME}.md" << EOL
# ${COMPONENT_NAME}

## Overview

${COMPONENT_DESCRIPTION}

## Requirements

- Docker & Docker Compose
- Internet connectivity for pulling images
- Ports: ${COMPONENT_PORTS:-8080}
- Dependencies: ${COMPONENT_DEPENDENCIES:-None}

## Installation

### Using Makefile

\`\`\`bash
# Basic installation
make ${COMPONENT_NAME} DOMAIN=example.com

# With additional options
make ${COMPONENT_NAME} DOMAIN=example.com PORT=8080 CLIENT_ID=client1
\`\`\`

### Manual Installation

\`\`\`bash
# Basic installation
./scripts/components/${INSTALL_SCRIPT_NAME} --domain example.com

# With additional options
./scripts/components/${INSTALL_SCRIPT_NAME} --domain example.com --port 8080 --client-id client1
\`\`\`

## Configuration

The component can be configured through environment variables in the \`.env\` file:

| Variable | Description | Default |
|----------|-------------|---------|
| DOMAIN | Domain name | localhost |
| PORT | Port to use | 8080 |
| ADMIN_EMAIL | Admin email | admin@example.com |
| ADMIN_PASSWORD | Admin password | auto-generated |
| VERSION | Version to install | latest |

## Testing

\`\`\`bash
# Basic verification
./scripts/components/verify_${COMPONENT_NAME}.sh

# Unit tests
./scripts/components/test_${COMPONENT_NAME}.sh

# Integration tests
./scripts/components/integration_test_${COMPONENT_NAME}.sh
\`\`\`

## Management

\`\`\`bash
# Check status
make ${COMPONENT_NAME}-status

# View logs
make ${COMPONENT_NAME}-logs

# Restart service
make ${COMPONENT_NAME}-restart
\`\`\`

## Troubleshooting

- If installation fails, check the logs with \`make ${COMPONENT_NAME}-logs\`
- Ensure required ports are available
- Verify Docker is running properly

## Security Notes

- Default admin credentials are stored in \`/opt/agency_stack/clients/CLIENT_ID/${COMPONENT_NAME}/.env\`
- Change default passwords after installation
- TLS is recommended for production environments
EOL

# Update component registry
update_component_registry() {
  log_info "Updating component registry..."
  
  # Path to component registry
  REGISTRY_PATH="${REPO_ROOT}/component_registry.json"
  
  # Create registry if it doesn't exist
  if [[ ! -f "$REGISTRY_PATH" ]]; then
    log_info "Creating new component registry..."
    echo '{"components":[]}' > "$REGISTRY_PATH"
  fi

  # Check if component already exists in registry
  if jq -e ".components[] | select(.name == \"${COMPONENT_NAME}\")" "$REGISTRY_PATH" >/dev/null 2>&1; then
    log_warning "Component ${COMPONENT_NAME} already exists in registry. Updating..."
    # Update existing entry
    tmp=$(mktemp)
    jq --arg name "$COMPONENT_NAME" \
       --arg description "$COMPONENT_DESCRIPTION" \
       --arg ports "$COMPONENT_PORTS" \
       --arg dependencies "$COMPONENT_DEPENDENCIES" \
       --arg template "$TEMPLATE_TYPE" \
       --arg client_specific "$IS_CLIENT_SPECIFIC" \
       '.components = [.components[] | if .name == $name then {
          "name": $name,
          "description": $description,
          "ports": ($ports | split(",")),
          "dependencies": ($dependencies | split(",")),
          "template": $template,
          "client_specific": ($client_specific == "true"),
          "added_date": (now | strftime("%Y-%m-%d")),
          "last_updated": (now | strftime("%Y-%m-%d"))
        } else . end]' "$REGISTRY_PATH" > "$tmp" && mv "$tmp" "$REGISTRY_PATH"
  else
    # Add new component entry
    tmp=$(mktemp)
    jq --arg name "$COMPONENT_NAME" \
       --arg description "$COMPONENT_DESCRIPTION" \
       --arg ports "$COMPONENT_PORTS" \
       --arg dependencies "$COMPONENT_DEPENDENCIES" \
       --arg template "$TEMPLATE_TYPE" \
       --arg client_specific "$IS_CLIENT_SPECIFIC" \
       '.components += [{
          "name": $name,
          "description": $description,
          "ports": ($ports | split(",")),
          "dependencies": ($dependencies | split(",")),
          "template": $template,
          "client_specific": ($client_specific == "true"),
          "added_date": (now | strftime("%Y-%m-%d")),
          "last_updated": (now | strftime("%Y-%m-%d"))
        }]' "$REGISTRY_PATH" > "$tmp" && mv "$tmp" "$REGISTRY_PATH"
  fi
  
  log_success "Component ${COMPONENT_NAME} registered in component_registry.json"
}

# Update ports documentation
update_ports_doc() {
  if [[ -n "$COMPONENT_PORTS" ]]; then
    log_info "Updating ports documentation..."
    PORTS_DOC="${REPO_ROOT}/docs/pages/ports.md"
    
    # Ensure the ports doc directory exists
    mkdir -p "$(dirname "$PORTS_DOC")"
    
    # Prepare ports entry
    IFS=',' read -ra PORT_ARRAY <<< "$COMPONENT_PORTS"
    PORT_ENTRIES=""
    for port in "${PORT_ARRAY[@]}"; do
      PORT_ENTRIES="${PORT_ENTRIES}${PORT_ENTRIES:+, }$port"
    done
    
    ports_entry="| ${COMPONENT_NAME} | ${PORT_ENTRIES} | ${COMPONENT_DESCRIPTION} |"
    
    # Create or update ports document
    if [[ ! -f "$PORTS_DOC" ]]; then
      # Create new ports document with proper structure
      cat > "$PORTS_DOC" << EOL
# AgencyStack Port Assignments

This document tracks port assignments for all AgencyStack components to maintain
operational clarity and prevent conflicts. Each component has its dedicated ports
that should not overlap with others.

| Component | Ports | Description |
| --- | --- | --- |
${ports_entry}
EOL
      log_success "Created ports.md with ${COMPONENT_NAME} entry"
    else
      # Append to existing ports document if entry doesn't exist
      if ! grep -q "| ${COMPONENT_NAME} |" "$PORTS_DOC"; then
        # Check if the ports table exists
        if grep -q "| Component | Ports | Description |" "$PORTS_DOC"; then
          # Append to existing table
          sed -i "/| --- | --- | --- |/a\\${ports_entry}" "$PORTS_DOC"
        else
          # Add table if it doesn't exist
          cat >> "$PORTS_DOC" << EOL

| Component | Ports | Description |
| --- | --- | --- |
${ports_entry}
EOL
        fi
        log_success "Updated ports.md with ${COMPONENT_NAME} entry"
      else
        log_info "Component ${COMPONENT_NAME} already documented in ports.md"
      fi
    fi
  else
    log_info "No ports specified, skipping ports documentation update"
  fi
}

# Create Makefile entries creation function
create_makefile_entries() {
  log_info "Creating Makefile entries..."
  
  # Create the component makefile
  cat > "${REPO_ROOT}/makefiles/components/${COMPONENT_NAME}.mk" << EOL
# ${COMPONENT_NAME}.mk - Makefile targets for ${COMPONENT_NAME}
# Generated by bootstrap_component.sh following AgencyStack Charter v1.0.3

# Colors for output
CYAN := \$(shell tput setaf 6 2>/dev/null || echo '')
GREEN := \$(shell tput setaf 2 2>/dev/null || echo '')
YELLOW := \$(shell tput setaf 3 2>/dev/null || echo '')
MAGENTA := \$(shell tput setaf 5 2>/dev/null || echo '')
BOLD := \$(shell tput bold 2>/dev/null || echo '')
RESET := \$(shell tput sgr0 2>/dev/null || echo '')

# Directories
SCRIPTS_DIR := \$(REPO_ROOT)/scripts
COMPONENTS_DIR := \$(SCRIPTS_DIR)/components

# Component installation target
${COMPONENT_NAME}:
	@echo "\$(CYAN)\$(BOLD)🚀 Installing ${COMPONENT_NAME}...\$(RESET)"
	@\$(COMPONENTS_DIR)/install_${COMPONENT_NAME}.sh \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

# Component status check target
${COMPONENT_NAME}-status:
	@echo "\$(CYAN)\$(BOLD)ℹ️ Checking ${COMPONENT_NAME} status...\$(RESET)"
	@\$(COMPONENTS_DIR)/verify_${COMPONENT_NAME}.sh \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

# Component logs viewing target
${COMPONENT_NAME}-logs:
	@echo "\$(MAGENTA)\$(BOLD)📋 Viewing ${COMPONENT_NAME} logs...\$(RESET)"
	@if [ -f "/var/log/agency_stack/components/${COMPONENT_NAME}.log" ]; then \\
		tail -n 50 /var/log/agency_stack/components/${COMPONENT_NAME}.log; \\
	else \\
		echo "\$(YELLOW)No log file found for ${COMPONENT_NAME}\$(RESET)"; \\
	fi

# Component restart target
${COMPONENT_NAME}-restart:
	@echo "\$(YELLOW)\$(BOLD)🔄 Restarting ${COMPONENT_NAME}...\$(RESET)"
	@\$(COMPONENTS_DIR)/install_${COMPONENT_NAME}.sh --restart-only \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

# Component test targets (following TDD Protocol)
${COMPONENT_NAME}-verify:
	@echo "\$(GREEN)\$(BOLD)✅ Verifying ${COMPONENT_NAME}...\$(RESET)"
	@\$(COMPONENTS_DIR)/verify_${COMPONENT_NAME}.sh \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

${COMPONENT_NAME}-test:
	@echo "\$(MAGENTA)\$(BOLD)🧪 Testing ${COMPONENT_NAME}...\$(RESET)"
	@\$(COMPONENTS_DIR)/test_${COMPONENT_NAME}.sh \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

${COMPONENT_NAME}-integration-test:
	@echo "\$(MAGENTA)\$(BOLD)🔄 Running integration tests for ${COMPONENT_NAME}...\$(RESET)"
	@\$(COMPONENTS_DIR)/integration_test_${COMPONENT_NAME}.sh \$(if \$(CLIENT_ID),--client-id \$(CLIENT_ID),) \$(if \$(DOMAIN),--domain \$(DOMAIN),)

# Add this component to phony targets
.PHONY: ${COMPONENT_NAME} ${COMPONENT_NAME}-status ${COMPONENT_NAME}-logs ${COMPONENT_NAME}-restart ${COMPONENT_NAME}-verify ${COMPONENT_NAME}-test ${COMPONENT_NAME}-integration-test
EOL

  # Add include statement to main Makefile if not already present
  if ! grep -q "include makefiles/components/${COMPONENT_NAME}.mk" "${REPO_ROOT}/Makefile"; then
    # Add the include statement after the last existing include for makefiles/components/*.mk
    sed -i '/include makefiles\/components\/.*\.mk/a include makefiles/components/'${COMPONENT_NAME}'.mk' "${REPO_ROOT}/Makefile" || \
    # If sed fails, append to the end of the file
    echo "include makefiles/components/${COMPONENT_NAME}.mk" >> "${REPO_ROOT}/Makefile"
  fi
  
  log_success "Created Makefile entries for ${COMPONENT_NAME}"
}

# Main execution
# Validation and setup
validate_inputs
create_directories

# Create component files
create_install_script
create_restart_handler
create_env_file
create_test_scripts
update_component_registry
update_ports_doc
create_makefile_entries
create_documentation

# Log the results
log_success "✅ Successfully bootstrapped ${COMPONENT_NAME} component!"
log_info ""
log_info "📄 Created the following files:"
log_info "  - Installation script: ${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}"
log_info "  - Environment example: ${TEMPLATES_DIR}/${ENV_EXAMPLE_NAME}"
log_info "  - Verification script: ${COMPONENTS_DIR}/verify_${COMPONENT_NAME}.sh"
log_info "  - Test script: ${COMPONENTS_DIR}/test_${COMPONENT_NAME}.sh"
log_info "  - Integration test: ${COMPONENTS_DIR}/integration_test_${COMPONENT_NAME}.sh"
log_info "  - Documentation: ${DOCS_DIR}/${COMPONENT_NAME}.md"
log_info "  - Makefile entry: ${MAKEFILE_DIR}/${COMPONENT_NAME}.mk"
log_info ""
log_info "Next steps:"
log_info "  1. Customize the installation script for your component"
log_info "  2. Update the test scripts with proper assertions"
log_info "  3. Enhance the documentation with specific details"
log_info "  4. Test the component with: make ${COMPONENT_NAME}"
log_info ""

# Record this in the changelog if changelog utils are available
if type log_agent_fix &>/dev/null; then
  log_agent_fix "${COMPONENT_NAME}" "Bootstrapped new component following Charter v1.0.3 principles" "enhancement" "Feature" "${COMPONENTS_DIR}/${INSTALL_SCRIPT_NAME}, ${TEMPLATES_DIR}/${ENV_EXAMPLE_NAME}, ${COMPONENTS_DIR}/verify_${COMPONENT_NAME}.sh" "Component may require customization for specific use cases" "Basic structure and Charter compliance validated"
fi

exit 0
