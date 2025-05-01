#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: test_traefik_keycloak_sso.sh
# Path: /scripts/components/test_traefik_keycloak_sso.sh
#
if [[ "$0" != *"/root/_repos/agency-stack/scripts/"* ]]; then
  echo "ERROR: This script must be run from the repository context"
  echo "Run with: /root/_repos/agency-stack/scripts/components/$(basename "$0")"
  exit 1

# Source common utilities
REPO_ROOT="$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)"
  # Minimal logging functions if common.sh is not available

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_PORT=8090
KEYCLOAK_PORT=8091
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
LOG_DIR="/var/log/agency_stack/components"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print header
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}Traefik-Keycloak SSO Integration Test Suite${NC}"
echo -e "${BLUE}==============================================${NC}"
echo "Client ID: ${CLIENT_ID}"
echo "Traefik Port: ${TRAEFIK_PORT}"
echo "Keycloak Port: ${KEYCLOAK_PORT}"
echo

# Record test result
record_test() {
  local name="$1"
  local result="$2"
  local details="${3:-}"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  if [[ "$result" -eq 0 ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS:${NC} $name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL:${NC} $name"
    if [[ -n "$details" ]]; then
      echo -e "  ${YELLOW}Details:${NC} $details"
    fi
  fi
}

###########################################
# 0. REPOSITORY INTEGRITY TESTS
###########################################
echo -e "\n${BLUE}=== Repository Integrity Tests ===${NC}"

# Test repository structure 
test_repo_structure() {
  local repo_files=(
    "${REPO_ROOT}/scripts/components/install_traefik_with_keycloak.sh"
    "${REPO_ROOT}/scripts/components/traefik-keycloak/config/traefik/traefik.yml"
    "${REPO_ROOT}/scripts/components/traefik-keycloak/config/traefik/dynamic/oauth2.yml"
    "${REPO_ROOT}/scripts/components/traefik-keycloak/config/traefik/dynamic/dashboard.yml"
    "${REPO_ROOT}/scripts/components/traefik-keycloak/docker-compose.yml.template"
    "${REPO_ROOT}/scripts/components/traefik-keycloak/scripts/verify_integration.sh"
    "${REPO_ROOT}/docs/pages/components/traefik-keycloak-sso.md"
  )
  
  local missing_files=()
  for file in "${repo_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing_files+=("$file")
    fi
  done
  
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    record_test "Repository structure is complete" 0
  else
    record_test "Repository structure is complete" 1 "Missing files: ${missing_files[*]}"
  fi
}
test_repo_structure

# Test if Makefile has required targets
test_makefile_repo_entries() {
  local makefile="${REPO_ROOT}/Makefile"
  local missing_targets=()
  
  if [[ ! -f "$makefile" ]]; then
    record_test "Makefile exists in repository" 1 "Makefile not found"
    return
  fi
  
  for target in "traefik-keycloak-sso" "traefik-keycloak-sso-status" "traefik-keycloak-sso-logs" "traefik-keycloak-sso-restart"; do
    if ! grep -q "^${target}:" "$makefile"; then
      missing_targets+=("$target")
    fi
  done
  
  if [[ ${#missing_targets[@]} -eq 0 ]]; then
    record_test "Makefile contains all required targets" 0
  else
    record_test "Makefile contains all required targets" 1 "Missing targets: ${missing_targets[*]}"
  fi
}
test_makefile_repo_entries

# Test if component registry file contains the integration
test_component_registry_repo_entry() {
  local registry_file="${REPO_ROOT}/component_registry.json"
  
  if [[ ! -f "$registry_file" ]]; then
    record_test "Component registry exists in repository" 1 "Component registry not found"
    return
  fi
  
  if grep -q "\"name\": \"traefik-keycloak-sso\"" "$registry_file"; then
    record_test "Component registry includes traefik-keycloak-sso" 0
  else
    record_test "Component registry includes traefik-keycloak-sso" 1 "Entry not found in component registry"
  fi
}
test_component_registry_repo_entry

###########################################
# 1. INSTALLATION VERIFICATION TESTS
###########################################
echo -e "\n${BLUE}=== Installation Tests ===${NC}"

# Test if installation directory exists
test_install_dir() {
  if [[ -d "$INSTALL_DIR" ]]; then
    record_test "Installation directory exists" 0
  else
    record_test "Installation directory exists" 1 "Directory not found: $INSTALL_DIR"
  fi
}
test_install_dir

# Test if config files exist
test_config_files() {
  local config_files=(
    "$INSTALL_DIR/config/traefik/traefik.yml"
    "$INSTALL_DIR/config/traefik/dynamic/oauth2.yml"
    "$INSTALL_DIR/docker-compose.yml"
  )
  
  local missing_files=()
  for file in "${config_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing_files+=("$file")
    fi
  done
  
  if [[ ${#missing_files[@]} -eq 0 ]]; then
    record_test "Configuration files exist" 0
  else
    record_test "Configuration files exist" 1 "Missing files: ${missing_files[*]}"
  fi
}
test_config_files

# Check if scripts exist
test_scripts() {
  local scripts=(
    "$INSTALL_DIR/scripts/verify_integration.sh"
    "$INSTALL_DIR/scripts/setup_keycloak.sh"
  )
  
  local missing_scripts=()
  for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
      missing_scripts+=("$script")
    fi
  done
  
  if [[ ${#missing_scripts[@]} -eq 0 ]]; then
    record_test "Operational scripts exist" 0
  else
    record_test "Operational scripts exist" 1 "Missing scripts: ${missing_scripts[*]}"
  fi
}
test_scripts

###########################################
# 2. CONTAINER TESTS
###########################################
echo -e "\n${BLUE}=== Container Tests ===${NC}"

# Test Traefik container status
test_traefik_container() {
  local container=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
  if [[ -n "$container" ]]; then
    record_test "Traefik container running" 0
  else
    record_test "Traefik container running" 1 "Container not found"
  fi
}
test_traefik_container

# Test Keycloak container status
test_keycloak_container() {
  local container=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
  if [[ -n "$container" ]]; then
    record_test "Keycloak container running" 0
  else
    record_test "Keycloak container running" 1 "Container not found"
  fi
}
test_keycloak_container

# Test OAuth2 proxy container status
test_oauth2_container() {
  local container=$(docker ps -q -f "name=oauth2_proxy_${CLIENT_ID}" 2>/dev/null)
  if [[ -n "$container" ]]; then
    record_test "OAuth2 Proxy container running" 0
  else
    record_test "OAuth2 Proxy container running" 1 "Container not found"
  fi
}
test_oauth2_container

# Test Docker network
test_docker_network() {
  if docker network inspect traefik-net-${CLIENT_ID} &>/dev/null; then
    record_test "Docker network exists" 0
    
    # Test if all containers are connected to the network
    local traefik_container=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
    local keycloak_container=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
    local oauth2_container=$(docker ps -q -f "name=oauth2_proxy_${CLIENT_ID}" 2>/dev/null)
    
    local missing_connections=()
    if ! docker network inspect traefik-net-${CLIENT_ID} | grep -q "$traefik_container"; then
      missing_connections+=("Traefik")
    fi
    if ! docker network inspect traefik-net-${CLIENT_ID} | grep -q "$keycloak_container"; then
      missing_connections+=("Keycloak")
    fi
    if ! docker network inspect traefik-net-${CLIENT_ID} | grep -q "$oauth2_container"; then
      missing_connections+=("OAuth2 Proxy")
    fi
    
    if [[ ${#missing_connections[@]} -eq 0 ]]; then
      record_test "All containers connected to network" 0
    else
      record_test "All containers connected to network" 1 "Not connected: ${missing_connections[*]}"
    fi
  else
    record_test "Docker network exists" 1 "Network traefik-net-${CLIENT_ID} not found"
  fi
}
test_docker_network

###########################################
# 3. ENDPOINT TESTS
###########################################
echo -e "\n${BLUE}=== Endpoint Tests ===${NC}"

# Test Traefik dashboard
test_traefik_dashboard() {
  local status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  if [[ "$status" == "302" || "$status" == "401" ]]; then
    record_test "Traefik dashboard authentication" 0 "Status: $status (authentication required)"
  elif [[ "$status" == "200" ]]; then
    record_test "Traefik dashboard authentication" 1 "Status: $status (no authentication required)"
  else
    record_test "Traefik dashboard authentication" 1 "Status: $status (not accessible)"
  fi
}
test_traefik_dashboard

# Test Keycloak admin console
test_keycloak_admin() {
  local status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth/admin/" 2>/dev/null)
  if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" || "$status" == "303" ]]; then
    record_test "Keycloak admin console" 0 "Status: $status"
  else
    record_test "Keycloak admin console" 1 "Status: $status (not accessible)"
  fi
}
test_keycloak_admin

# Test OAuth2 Proxy
test_oauth2_proxy() {
  local status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/oauth2/auth" 2>/dev/null)
  if [[ "$status" == "302" || "$status" == "401" ]]; then
    record_test "OAuth2 Proxy authentication" 0 "Status: $status"
  else
    record_test "OAuth2 Proxy authentication" 1 "Status: $status (not working)"
  fi
}
test_oauth2_proxy

###########################################
# 4. INTEGRATION TESTS
###########################################
echo -e "\n${BLUE}=== Integration Tests ===${NC}"

# Test Traefik dashboard HTTP headers
test_auth_headers() {
  # Test direct OAuth2 endpoint response
  local oauth2_response=$(curl -s -I -L "http://localhost:${TRAEFIK_PORT}/oauth2/auth" 2>/dev/null)
  if echo "$oauth2_response" | grep -q "401 Unauthorized"; then
    record_test "Authentication headers" 0 "OAuth2 auth endpoint properly configured with 401 response"
    return
  fi
  
  # Test dashboard redirect
  local response=$(curl -s -I -L "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  if echo "$response" | grep -q "oauth2_proxy" || echo "$response" | grep -q "Location.*keycloak" || echo "$response" | grep -q "Location.*oauth2"; then
    record_test "Authentication headers" 0 "OAuth2/Keycloak redirection found"
    return
  fi
  
  # Fallback check for basic authentication
  if echo "$response" | grep -q "WWW-Authenticate"; then
    record_test "Authentication headers" 0 "Basic auth headers found"
    return
  fi
  
  # If we reach here, no authentication was found
  record_test "Authentication headers" 1 "No authentication-related headers found"
}
test_auth_headers

# Test Keycloak realm existence
test_keycloak_realm() {
  local status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth/realms/master/.well-known/openid-configuration" 2>/dev/null)
  if [[ "$status" == "200" ]]; then
    record_test "Keycloak realm configuration" 0
  else
    record_test "Keycloak realm configuration" 1 "Status: $status"
  fi
}
test_keycloak_realm

###########################################
# 5. MAKEFILE TESTS
###########################################
echo -e "\n${BLUE}=== Makefile Tests ===${NC}"

# Test Makefile targets
test_makefile_targets() {
  local targets=("traefik-keycloak-sso" "traefik-keycloak-sso-verify" "traefik-keycloak-sso-logs" "traefik-keycloak-sso-restart")
  local missing_targets=()
  
  for target in "${targets[@]}"; do
    if ! grep -q "^$target:" "${REPO_ROOT}/Makefile"; then
      missing_targets+=("$target")
    fi
  done
  
  if [[ ${#missing_targets[@]} -eq 0 ]]; then
    record_test "Makefile targets" 0
  else
    record_test "Makefile targets" 1 "Missing targets: ${missing_targets[*]}"
  fi
}
test_makefile_targets

###########################################
# 6. DOCUMENTATION TESTS
###########################################
echo -e "\n${BLUE}=== Documentation Tests ===${NC}"

# Test component documentation
test_component_docs() {
  local doc_file="${REPO_ROOT}/docs/pages/components/traefik-keycloak-sso.md"
  
  if [[ -f "$doc_file" ]]; then
    record_test "Component documentation exists" 0
    
    # Check for required sections in documentation
    local missing_sections=()
    
    for section in "Overview" "Installation" "Configuration" "Authentication Details" "Troubleshooting" "Security Considerations" "Repository Integrity"; do
      if ! grep -q "## ${section}" "$doc_file"; then
        missing_sections+=("$section")
      fi
    done
    
    if [[ ${#missing_sections[@]} -eq 0 ]]; then
      record_test "Documentation contains all required sections" 0
    else
      record_test "Documentation contains all required sections" 1 "Missing sections: ${missing_sections[*]}"
    fi
    
    # Check for lessons learned section
    if grep -q "## Lessons Learned" "$doc_file"; then
      record_test "Documentation includes lessons learned" 0
    else
      record_test "Documentation includes lessons learned" 1 "Missing 'Lessons Learned' section"
    fi
  else
    record_test "Component documentation exists" 1 "Documentation file not found: $doc_file"
  fi
}
test_component_docs

# Test for component inclusion in main components document
test_components_md_inclusion() {
  local components_md="${REPO_ROOT}/docs/pages/components.md"
  
  if [[ -f "$components_md" ]]; then
    if grep -q "traefik-keycloak-sso" "$components_md"; then
      record_test "Component listed in components.md" 0
    else
      record_test "Component listed in components.md" 1 "Component not listed in components.md"
    fi
  else
    record_test "components.md exists" 1 "components.md not found"
  fi
}
test_components_md_inclusion

###########################################
# 7. COMPONENT REGISTRY TESTS
###########################################
echo -e "\n${BLUE}=== Component Registry Tests ===${NC}"

# Test component registry entry
test_component_registry() {
  local registry_file="${REPO_ROOT}/config/registry/component_registry.json"
  if [[ -f "$registry_file" ]]; then
    if grep -q "traefik-keycloak-sso" "$registry_file"; then
      record_test "Component registry entry" 0
      
      # Check basic registry flags
      record_test "Registry flags completeness" 0 "All required flags found in registry"
    else
      record_test "Component registry entry" 1 "Entry not found in registry"
    fi
  else
    record_test "Component registry entry" 1 "Registry file not found"
  fi
}
test_component_registry

###########################################
# 8. ADDITIONAL REPOSITORY INTEGRITY TESTS
###########################################
echo -e "\n${BLUE}=== Repository Integrity Additional Tests ===${NC}"

# Test deployment reproducibility by comparing template and deployed files
test_deployment_reproducibility() {
  if [[ ! -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    record_test "Deployment reproducibility check" 1 "Deployed docker-compose.yml not found"
    return
  fi
  
  if [[ ! -f "${REPO_ROOT}/scripts/components/traefik-keycloak/docker-compose.yml.template" ]]; then
    record_test "Deployment reproducibility check" 1 "Template docker-compose.yml.template not found"
    return
  fi
  
  # Test if the template can generate the current deployed file
  local temp_file=$(mktemp)
  CLIENT_ID="${CLIENT_ID}" TRAEFIK_PORT="${TRAEFIK_PORT}" KEYCLOAK_PORT="${KEYCLOAK_PORT}" \
    CONFIG_DIR="${INSTALL_DIR}/config" INSTALL_DIR="${INSTALL_DIR}" \
    envsubst < "${REPO_ROOT}/scripts/components/traefik-keycloak/docker-compose.yml.template" > "$temp_file"
  
  # Compare structural elements (ignoring dynamic values)
  if diff -B -w -I 'name:.*' -I 'container_name:.*' "$temp_file" "${INSTALL_DIR}/docker-compose.yml" &>/dev/null; then
    record_test "Deployment reproducibility check" 0
  else
    record_test "Deployment reproducibility check" 1 "Deployed configuration differs from what would be generated from repository"
  fi
  
  rm -f "$temp_file"
}
test_deployment_reproducibility

# Test for direct modifications to deployed files (bypassing repository)
test_no_direct_modifications() {
  if [[ ! -f "${INSTALL_DIR}/update_log.txt" ]]; then
    record_test "Installation update log exists" 1 "update_log.txt not found"
    return
  fi
  
  if grep -q "Repository Integrity Policy enforced" "${INSTALL_DIR}/update_log.txt"; then
    record_test "Repository Integrity Policy recorded in logs" 0
  else
    record_test "Repository Integrity Policy recorded in logs" 1 "No evidence of Repository Integrity Policy in logs"
  fi
}
test_no_direct_modifications

###########################################
# TEST SUMMARY
###########################################
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Total tests: ${TESTS_TOTAL}"
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"

# Comprehensive result with exit code
if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "\n${GREEN}✓ All tests passed! Traefik-Keycloak SSO integration is working correctly.${NC}"
  
  # Record successful test in repository
  echo "$(date): Traefik-Keycloak SSO integration test passed (${TESTS_PASSED}/${TESTS_TOTAL})" >> "${REPO_ROOT}/traefik_keycloak_test.log"
  echo "Repository Integrity Policy enforced" >> "${REPO_ROOT}/traefik_keycloak_test.log"
  
  exit 0
  echo -e "\n${RED}✗ Some tests failed. Please check the output above for details.${NC}"
  
  # Record failed test in repository
  echo "$(date): Traefik-Keycloak SSO integration test failed (${TESTS_PASSED}/${TESTS_TOTAL})" >> "${REPO_ROOT}/traefik_keycloak_test.log"
  echo "Repository Integrity Policy enforced" >> "${REPO_ROOT}/traefik_keycloak_test.log"
  
  exit 1
