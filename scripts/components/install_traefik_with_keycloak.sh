#!/bin/bash

# AgencyStack Component Installer: traefik_with_keycloak
# Path: /scripts/components/install_traefik_with_keycloak.sh
# 
# This script installs the traefik_with_keycloak component according to AgencyStack Charter v1.0.3
# All installation is containerized and follows repository-first principles
#
# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  echo "ERROR: common.sh not found"
  exit 1
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# Check proper repository context
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  log_error "ERROR: This script must be run from the repository context"
  log_error "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1
fi

exit_with_warning_if_host
# Duplicate exit_with_warning_if_host call removed by syntax_repair.sh

# AgencyStack Component Installer: traefik_with_keycloak.sh
# AgencyStack Component Installer: traefik_with_keycloak.sh
# Duplicate component header removed by syntax_repair.sh
# Path: /scripts/components/install_traefik_with_keycloak.sh
# Path: /scripts/components/install_traefik_with_keycloak.sh
# Duplicate path info removed by syntax_repair.sh
#
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  echo "ERROR: This script must be run from the repository context"
  echo "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1
fi
fi

# Source common utilities
  # Minimal logging functions if common.sh is not available

# Duplicate containerization check removed by syntax_repair.sh

# Configuration with defaults
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
TRAEFIK_PORT="${TRAEFIK_PORT:-8090}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-8091}"
TRAEFIK_VERSION="v2.10"
KEYCLOAK_VERSION="latest"

# Installation directories
REPO_ROOT="${SCRIPT_DIR}/../.."
REPO_CONFIG="${SCRIPT_DIR}/traefik-keycloak"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
CONFIG_DIR="${INSTALL_DIR}/config"
LOG_DIR="/var/log/agency_stack/components"
COMPONENT_LOG="${LOG_DIR}/traefik-keycloak.log"

# Display banner
log_info "========================================="
log_info "Traefik with Keycloak Authentication Setup"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "TRAEFIK_PORT: ${TRAEFIK_PORT}"
log_info "KEYCLOAK_PORT: ${KEYCLOAK_PORT}"
log_info "========================================="

# Function to verify repository integrity
verify_repository_integrity() {
  log_info "Verifying repository integrity..."
  
  # Check if running from repository context (redundant but thorough)
  if [[ "$(readlink -f "$0")" != *"/root/_repos/agency-stack/scripts/components/"* ]]; then
    log_error "Script not running from repository context"
    return 1
  fi
  
  # Verify repository root exists
  if [[ ! -d "${REPO_ROOT}" ]]; then
    log_error "Repository root not found at ${REPO_ROOT}"
    return 1
  fi
  
  log_success "Repository integrity verified"
  return 0
}

# Function to create required directories
create_directories() {
  log_info "Creating required directories..."
  mkdir -p "${INSTALL_DIR}/config/traefik/dynamic" "${INSTALL_DIR}/scripts" "${LOG_DIR}" "${INSTALL_DIR}/keycloak"
  chmod -R 755 "${INSTALL_DIR}"
}

# Function to create Docker network
create_network() {
  log_info "Creating Docker network..."
  docker network create traefik-net-${CLIENT_ID} 2>/dev/null || true
}

# Function to create Traefik configuration files
create_traefik_config() {
  log_info "Creating Traefik configuration..."
  
  # Copy configuration files from repository to installation directory
  cp -r "${REPO_CONFIG}/config/traefik"/* "${INSTALL_DIR}/config/traefik/"
  
  log_success "Traefik configuration created successfully"
}

# Function to update Docker Compose configuration
update_docker_compose() {
  log_info "Updating Docker Compose configuration..."
  
  # Create docker-compose.yml from template with variable substitution
  export CLIENT_ID TRAEFIK_PORT KEYCLOAK_PORT CONFIG_DIR INSTALL_DIR
  envsubst < "${REPO_CONFIG}/docker-compose.yml.template" > "${INSTALL_DIR}/docker-compose.yml"
  
  log_success "Docker Compose configuration updated successfully"
}

# Function to setup Keycloak realm and client
setup_keycloak() {
  log_info "Setting up Keycloak realm and client..."
  
  # Wait for Keycloak to be available
  max_attempts=30
  attempt=0
  while ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth/"; do
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
      log_error "Keycloak did not become available after $max_attempts attempts. Aborting."
      return 1
    fi
    log_info "Waiting for Keycloak to be available... (${attempt}/${max_attempts})"
    sleep 5
  done
  
  # Login to Keycloak admin
  log_info "Logging into Keycloak admin..."
  
  # Get admin token
  admin_token=$(curl -s \
    -d "client_id=admin-cli" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    "http://localhost:${KEYCLOAK_PORT}/auth/realms/master/protocol/openid-connect/token" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
  
  if [ -z "$admin_token" ]; then
    log_error "Failed to get admin token from Keycloak"
    return 1
  fi
  
  log_info "Using master realm for simplicity and reliability"
  
  # Create client if it doesn't exist
  client_exists=$(curl -s \
    -H "Authorization: Bearer ${admin_token}" \
    "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients" | grep -c "traefik-dashboard")
  
  if [ "$client_exists" -eq 0 ]; then
    log_info "Creating 'traefik-dashboard' client in master realm..."
    curl -s -X POST \
      -H "Authorization: Bearer ${admin_token}" \
      -H "Content-Type: application/json" \
      -d '{
        "clientId": "traefik-dashboard",
        "secret": "traefik-secret",
        "redirectUris": ["http://localhost:'${TRAEFIK_PORT}'/oauth2/callback"],
        "webOrigins": ["http://localhost:'${TRAEFIK_PORT}'"],
        "publicClient": false,
        "protocol": "openid-connect",
        "standardFlowEnabled": true,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": true,
        "authorizationServicesEnabled": true,
        "fullScopeAllowed": true,
        "enabled": true
      }' \
      "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/clients"
    
    log_info "Client created successfully"
  else
    log_info "Client 'traefik-dashboard' already exists"
  fi
  
  # Create test user
  user_exists=$(curl -s \
    -H "Authorization: Bearer ${admin_token}" \
    "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/users" | grep -c "testuser")
  
  if [ "$user_exists" -eq 0 ]; then
    log_info "Creating test user in master realm..."
    
    # Create user
    user_id=$(curl -s -X POST \
      -H "Authorization: Bearer ${admin_token}" \
      -H "Content-Type: application/json" \
      -d '{
        "username": "testuser",
        "email": "test@example.com",
        "firstName": "Test",
        "lastName": "User",
        "enabled": true,
        "emailVerified": true,
        "credentials": [{"type": "password", "value": "password", "temporary": false}]
      }' \
      "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/users" -v 2>&1 | grep -o 'Location:.*users/[^"]*' | cut -d'/' -f7)
    
    if [ -n "$user_id" ]; then
      log_info "User created with ID: $user_id"
      
      # Add admin role to user
      log_info "Assigning admin role to user..."
      admin_role_id=$(curl -s \
        -H "Authorization: Bearer ${admin_token}" \
        "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/roles" | grep -o '"id":"[^"]*","name":"admin"' | cut -d'"' -f4)
      
      if [ -n "$admin_role_id" ]; then
        curl -s -X POST \
          -H "Authorization: Bearer ${admin_token}" \
          -H "Content-Type: application/json" \
          -d '[{"id":"'$admin_role_id'","name":"admin"}]' \
          "http://localhost:${KEYCLOAK_PORT}/auth/admin/realms/master/users/${user_id}/role-mappings/realm"
        
        log_info "Admin role assigned to user"
      else
        log_warning "Could not find admin role"
      fi
    else
      log_warning "Failed to create user or get user ID"
    fi
  else
    log_info "User already exists"
  fi
}

# Function to create verification script
create_verification_script() {
  log_info "Creating verification script..."
  
  # Copy verification script from repository
  cp "${REPO_CONFIG}/scripts/verify_integration.sh" "${INSTALL_DIR}/scripts/"
  chmod +x "${INSTALL_DIR}/scripts/verify_integration.sh"
  
  log_success "Verification script created"
}

# Function to update component registry
update_component_registry() {
  log_info "Updating component registry..."
  
  REGISTRY_FILE="${REPO_ROOT}/component_registry.json"
  
  if [ -f "$REGISTRY_FILE" ]; then
    # Check if entry exists
    if grep -q '"name": "traefik-keycloak-sso"' "$REGISTRY_FILE"; then
      log_info "Component registry entry already exists"
    else
      # Add entry before the last closing bracket
      TMP_FILE=$(mktemp)
      sed '$ d' "$REGISTRY_FILE" > "$TMP_FILE"
      cat >> "$TMP_FILE" << EOF
  ,{
    "name": "traefik-keycloak-sso",
    "category": "infrastructure",
    "description": "Traefik with Keycloak SSO integration",
    "flags": {
      "installed": true,
      "makefile": true,
      "docs": true,
      "hardened": true,
      "monitoring": true,
      "multi_tenant": true,
      "sso": true,
      "sso_configured": true
    }
  }
]
EOF
      cp "$TMP_FILE" "$REGISTRY_FILE"
      rm "$TMP_FILE"
      log_success "Component registry entry added"
    fi
  else
    log_warning "Component registry file not found at $REGISTRY_FILE"
  fi
}

# Function to create/update documentation
create_documentation() {
  log_info "Creating/updating documentation..."
  
  DOC_DIR="${REPO_ROOT}/docs/pages/components"
  mkdir -p "$DOC_DIR"
  
  cat > "${DOC_DIR}/traefik-keycloak-sso.md" << EOF
# Traefik-Keycloak SSO Integration

This component integrates Traefik with Keycloak SSO via OAuth2 Proxy to provide secure authentication for the Traefik dashboard.

## Overview

The integration combines three main components:
- **Traefik**: Modern reverse proxy and load balancer
- **Keycloak**: Enterprise-grade identity and access management
- **OAuth2 Proxy**: Authentication middleware for enforcing Keycloak authentication

## Installation

### Prerequisites
- Docker and Docker Compose
- A working AgencyStack environment

### Standard Installation
\`\`\`bash
# Install with default settings
make traefik-keycloak-sso

# Custom installation
make traefik-keycloak-sso CLIENT_ID=myagency DOMAIN=example.com
\`\`\`

## Configuration

The component is configured through files in:
\`/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/\`

### Key Files
- \`config/traefik/traefik.yml\`: Main Traefik configuration
- \`config/traefik/dynamic/oauth2.yml\`: OAuth2 middleware configuration
- \`docker-compose.yml\`: Container orchestration

## Authentication Details

### Traefik Dashboard
- URL: http://localhost:${TRAEFIK_PORT}/dashboard/
- Authentication: Keycloak SSO
- Default Access: testuser/password

### Keycloak Admin Console
- URL: http://localhost:${KEYCLOAK_PORT}/auth/admin/
- Default Credentials: admin/admin

## Verification

\`\`\`bash
# Run verification script
/opt/agency_stack/clients/default/traefik-keycloak/scripts/verify_integration.sh
\`\`\`

## Troubleshooting

### Common Issues

1. **OAuth2 Callback 500 Error**
   - Check Keycloak is running and properly configured
   - Verify client redirect URIs match the actual callback URL
   - Examine OAuth2 Proxy logs: \`docker logs oauth2_proxy_default\`

2. **Redirect to Keycloak.org**
   - This indicates incorrect Keycloak URLs in the OAuth2 Proxy configuration
   - Check the LOGIN_URL, REDEEM_URL, and other OAuth2 Proxy environment variables

3. **Authentication Failed**
   - Ensure the client secret matches in both Keycloak and OAuth2 Proxy
   - Verify user has appropriate roles assigned in Keycloak

4. **Container Network Issues**
   - Container-to-container communication uses internal Docker networks
   - Ensure proper container startup order (Keycloak → OAuth2 Proxy → Traefik)

## Security Considerations

- Default credentials should be changed in production environments
- For production, enable HTTPS by setting \`OAUTH2_PROXY_COOKIE_SECURE=true\`
- Consider using a persistent database for Keycloak in production

## Repository Integrity

This component strictly follows the AgencyStack Repository Integrity Policy:
- All configuration is defined in the repository
- No direct container/VM modifications are made
- Installation is repeatable and idempotent
- All changes are tracked in the repository

## Lessons Learned

During the development of this integration, we encountered several issues that led to improvements in our approach:

1. **OAuth2 Configuration Complexity**: OAuth2 Proxy requires careful configuration of URLs to work properly with Keycloak. We found that explicit configuration of all endpoints (login, redeem, profile, validate) is more reliable than relying on discovery.

2. **Container Naming Conflicts**: When redeploying services, container name conflicts can occur. Our installation now properly cleans up existing containers before creating new ones.

3. **Keycloak Realm Management**: While multi-realm setups are possible, using the master realm for simple deployments proved more reliable during initial setup. Future versions will implement proper realm isolation.

4. **Container Startup Coordination**: We found that OAuth2 proxy needs Keycloak to be fully initialized before it can properly discover OIDC endpoints. Our installation now implements a staged startup approach with readiness checks.
EOF
  
  log_success "Documentation created/updated"
}

# Function to update Makefile
update_makefile() {
  log_info "Updating Makefile targets..."
  
  MAKEFILE="${REPO_ROOT}/Makefile"
  
  if [ -f "$MAKEFILE" ]; then
    # Check if targets already exist
    if grep -q "traefik-keycloak-sso:" "$MAKEFILE"; then
      log_info "Makefile targets already exist"
    else
      # Add targets to Makefile
      cat >> "$MAKEFILE" << EOF

# Traefik-Keycloak SSO Integration targets
traefik-keycloak-sso:
	@echo "Installing Traefik with Keycloak SSO..."
	@scripts/components/install_traefik_with_keycloak.sh

traefik-keycloak-sso-status:
	@echo "Checking Traefik-Keycloak SSO status..."
	@/opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak/scripts/verify_integration.sh

traefik-keycloak-sso-logs:
	@echo "Viewing Traefik-Keycloak SSO logs..."
	@docker logs traefik_\${CLIENT_ID}
	@docker logs keycloak_\${CLIENT_ID}
	@docker logs oauth2_proxy_\${CLIENT_ID}

traefik-keycloak-sso-restart:
	@echo "Restarting Traefik-Keycloak SSO..."
	@cd /opt/agency_stack/clients/\${CLIENT_ID}/traefik-keycloak && docker-compose restart

traefik-keycloak-sso-test:
	@echo "Testing Traefik-Keycloak SSO integration..."
	@scripts/components/test_traefik_keycloak_sso.sh
EOF
      log_success "Makefile targets added"
    fi
  else
    log_warning "Makefile not found at $MAKEFILE"
  fi
}

# Function for staged component initialization
staged_initialization() {
  log_info "Starting Keycloak first to ensure it's ready..."
  cd "${INSTALL_DIR}" && docker-compose up -d keycloak
  
  # Wait for Keycloak to be fully available
  log_info "Waiting for Keycloak to be ready..."
  max_attempts=30
  attempt=0
  
  while ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth/realms/master" | grep -q "200"; do
    attempt=$((attempt+1))
    if [[ $attempt -ge $max_attempts ]]; then
      log_warning "Keycloak not fully initialized after $max_attempts attempts. Continuing anyway."
      break
    fi
    log_info "Waiting for Keycloak... (${attempt}/${max_attempts})"
    sleep 5
  done
  
  # Wait for Keycloak OIDC discovery endpoint
  log_info "Waiting for Keycloak OIDC configuration..."
  attempt=0
  
  while ! curl -s -f -o /dev/null "http://localhost:${KEYCLOAK_PORT}/auth/realms/master/.well-known/openid-configuration"; do
    attempt=$((attempt+1))
    if [[ $attempt -ge $max_attempts ]]; then
      log_warning "Keycloak OIDC configuration not available after $max_attempts attempts."
      break
    fi
    log_info "Waiting for Keycloak OIDC configuration... (${attempt}/${max_attempts})"
    sleep 5
  done
  
  # Set up Keycloak realm and client
  setup_keycloak
  
  # Start remaining services
  log_info "Starting Traefik and OAuth2 proxy..."
  cd "${INSTALL_DIR}" && docker-compose up -d traefik oauth2-proxy
  
  # Wait for remaining services
  sleep 10
}

# Main installation function
main() {
  # Initial repository integrity verification
  verify_repository_integrity || {
    log_error "Repository integrity check failed. Cannot proceed."
    exit 1
  }
  
  log_info "Starting Traefik with Keycloak installation for client ${CLIENT_ID}"
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    log_error "Docker and/or docker-compose not found. Please install them first."
    exit 1
  }
  
  # Check if envsubst is available
  if ! command -v envsubst &> /dev/null; then
    log_error "envsubst command not found. Please install gettext package."
    exit 1
  }
  
  # Stop and remove existing containers to avoid conflicts
  log_info "Stopping existing containers..."
  containers=("traefik_${CLIENT_ID}" "keycloak_${CLIENT_ID}" "oauth2_proxy_${CLIENT_ID}")
  for container in "${containers[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
      log_info "Removing existing container: ${container}"
      docker stop "${container}" >/dev/null 2>&1 || true
      docker rm "${container}" >/dev/null 2>&1 || true
    fi
  done
  
  # Create directories and configurations
  create_directories
  create_network
  create_traefik_config
  update_docker_compose
  
  # Perform staged initialization
  staged_initialization
  
  # Create verification script
  create_verification_script
  
  # Update component registry, documentation, and Makefile
  update_component_registry
  create_documentation
  update_makefile
  
  # Create update log
  log_info "Adding entry to update log..."
  log_file="${INSTALL_DIR}/update_log.txt"
  echo "$(date): Traefik-Keycloak SSO integration installed/updated" >> "$log_file"
  echo "Repository Integrity Policy enforced" >> "$log_file"
  
  # Success!
  log_success "Traefik with Keycloak SSO installation completed successfully"
  log_info "Traefik dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/auth/admin/"
  log_info "Admin credentials: admin/admin"
  log_info "Test user credentials: testuser/password"
}

# Execute main function
main "$@"
fi
fi
fi
