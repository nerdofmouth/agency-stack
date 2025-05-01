#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: test_traefik_keycloak.sh
# Path: /scripts/components/test_traefik_keycloak.sh
#

# Enforce containerization (prevent host contamination)

# Test Config
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_PORT="8090"
KEYCLOAK_PORT="8091"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak"
AUTH_USERNAME="admin"
AUTH_PASSWORD="password"
EXPECTED_SUCCESS=0
EXPECTED_FAILURE=1
DEBUG=false

# Counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parameters
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --help)
      echo "Usage: $(basename "$0") [options]"
      echo "Options:"
      echo "  --client-id <id>  Client ID for testing (default: default)"
      echo "  --debug           Enable debug output"
      echo "  --help            Display this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Print test header
print_header() {
  local title="$1"
  echo -e "\n${BLUE}======================================================="
  echo -e "= $title"
  echo -e "=======================================================${NC}"
}

# Print test result
print_result() {
  local test_name="$1"
  local result="$2"
  local details="${3:-}"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  if [[ "$result" == "$EXPECTED_SUCCESS" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS:${NC} $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL:${NC} $test_name"
    if [[ -n "$details" ]]; then
      echo -e "  ${YELLOW}Details:${NC} $details"
    fi
  fi
}

# Print debug information
debug_info() {
  if [[ "$DEBUG" == "true" ]]; then
    echo -e "${YELLOW}DEBUG:${NC} $1"
  fi
}

# Print summary
print_summary() {
  echo -e "\n${BLUE}======================================================="
  echo -e "= TEST SUMMARY"
  echo -e "=======================================================${NC}"
  echo -e "Total tests: $TESTS_TOTAL"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
    exit 0
  else
    echo -e "\n${RED}Some tests failed. Check the output for details.${NC}"
    exit 1
  fi
}

# Unit Tests
run_unit_tests() {
  print_header "UNIT TESTS"
  
  # Test 1: Check directory structure
  local dir_test=0
  if [[ -d "${INSTALL_DIR}" && -d "${INSTALL_DIR}/config" ]]; then
    dir_test=0
  else
    dir_test=1
  fi
  print_result "Directory structure" "$dir_test" "INSTALL_DIR: ${INSTALL_DIR}"
  
  # Test 2: Check Traefik config exists
  local config_test=0
  if [[ -f "${INSTALL_DIR}/config/traefik/traefik.yml" ]]; then
    config_test=0
  else
    config_test=1
  fi
  print_result "Traefik configuration file" "$config_test" "CONFIG: ${INSTALL_DIR}/config/traefik/traefik.yml"
  
  # Test 3: Check auth config exists
  local auth_test=0
  if [[ -f "${INSTALL_DIR}/config/traefik/dynamic/basicauth.yml" ]]; then
    auth_test=0
  else
    auth_test=1
  fi
  print_result "Auth configuration file" "$auth_test" "CONFIG: ${INSTALL_DIR}/config/traefik/dynamic/basicauth.yml"
}

# Integration Tests
run_integration_tests() {
  print_header "INTEGRATION TESTS"
  
  # Test 4: Check if Traefik container is running
  local traefik_running_test=0
  local traefik_container=$(docker ps -q -f "name=traefik_${CLIENT_ID}" 2>/dev/null)
  if [[ -n "$traefik_container" ]]; then
    traefik_running_test=0
  else
    traefik_running_test=1
  fi
  print_result "Traefik container running" "$traefik_running_test" "CONTAINER: $traefik_container"
  
  # Test 5: Check if Keycloak container is running
  local keycloak_running_test=0
  local keycloak_container=$(docker ps -q -f "name=keycloak_${CLIENT_ID}" 2>/dev/null)
  if [[ -n "$keycloak_container" ]]; then
    keycloak_running_test=0
  else
    keycloak_running_test=1
  fi
  print_result "Keycloak container running" "$keycloak_running_test" "CONTAINER: $keycloak_container"
  
  # Test 6: Check Docker network
  local network_test=0
  if docker network inspect traefik-net-${CLIENT_ID} &>/dev/null; then
    network_test=0
  else
    network_test=1
  fi
  print_result "Docker network exists" "$network_test" "NETWORK: traefik-net-${CLIENT_ID}"
  
  # Test 7: Check Traefik connection to Docker network
  local traefik_network_test=0
  if docker network inspect traefik-net-${CLIENT_ID} | grep -q "${traefik_container}"; then
    traefik_network_test=0
  else
    traefik_network_test=1
  fi
  print_result "Traefik connected to network" "$traefik_network_test"
  
  # Test 8: Check Keycloak connection to Docker network
  local keycloak_network_test=0
  if docker network inspect traefik-net-${CLIENT_ID} | grep -q "${keycloak_container}"; then
    keycloak_network_test=0
  else
    keycloak_network_test=1
  fi
  print_result "Keycloak connected to network" "$keycloak_network_test"
}

# System Tests
run_system_tests() {
  print_header "SYSTEM TESTS"
  
  # Test 9: Check Traefik API endpoint
  local api_test=0
  local api_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/api/version" 2>/dev/null)
  debug_info "Traefik API status: $api_status"
  if [[ "$api_status" == "401" || "$api_status" == "200" ]]; then
    api_test=0 # Either protected (401) or accessible (200)
  else
    api_test=1
  fi
  print_result "Traefik API endpoint" "$api_test" "STATUS: $api_status"
  
  # Test 10: Check Traefik Dashboard with basic auth
  local dashboard_test=0
  local dashboard_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  debug_info "Dashboard status: $dashboard_status"
  if [[ "$dashboard_status" == "401" || "$dashboard_status" == "200" ]]; then
    dashboard_test=0 # Either protected (401) or accessible (200)
  else
    dashboard_test=1
  fi
  print_result "Traefik Dashboard endpoint" "$dashboard_test" "STATUS: $dashboard_status"
  
  # Test 11: Check Dashboard with authentication
  local auth_test=0
  local auth_status=$(curl -s -o /dev/null -w "%{http_code}" -u "${AUTH_USERNAME}:${AUTH_PASSWORD}" "http://localhost:${TRAEFIK_PORT}/dashboard/" 2>/dev/null)
  debug_info "Dashboard auth status: $auth_status"
  if [[ "$auth_status" == "200" ]]; then
    auth_test=0
  else
    auth_test=1
  fi
  print_result "Traefik Dashboard authentication" "$auth_test" "STATUS: $auth_status"
  
  # Test 12: Check Keycloak availability
  local keycloak_test=0
  local keycloak_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${KEYCLOAK_PORT}/auth" 2>/dev/null)
  debug_info "Keycloak status: $keycloak_status"
  if [[ "$keycloak_status" == "200" || "$keycloak_status" == "303" ]]; then
    keycloak_test=0
  else
    keycloak_test=1
  fi
  print_result "Keycloak availability" "$keycloak_test" "STATUS: $keycloak_status"
}

# Main function
main() {
  echo -e "${BLUE}Traefik-Keycloak Integration Tests${NC}"
  echo "Client ID: ${CLIENT_ID}"
  echo "Traefik Port: ${TRAEFIK_PORT}"
  echo "Keycloak Port: ${KEYCLOAK_PORT}"
  echo -e "Running tests...\n"
  
  # Run test suites
  run_unit_tests
  run_integration_tests
  run_system_tests
  
  # Print summary
  print_summary
}

# Execute main function
main
