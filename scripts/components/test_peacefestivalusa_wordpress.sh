#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Testing: peacefestivalusa_wordpress
# Path: /scripts/components/test_peacefestivalusa_wordpress.sh
#
# Comprehensive testing script following TDD Protocol
# This script tests the PeaceFestivalUSA WordPress implementation in a local environment
# while ensuring isolation from production deployments.

# Default configuration
CLIENT_ID="peacefestivalusa"
DOMAIN="localhost:8080"
CONTAINER_PREFIX="test_pfusa_"
TEST_PORT="8080"
TEST_DB_PORT="3306"
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --client-id) CLIENT_ID="$2"; shift ;;
    --domain) DOMAIN="$2"; shift ;;
    --container-prefix) CONTAINER_PREFIX="$2"; shift ;;
    --port) TEST_PORT="$2"; shift ;;
    --db-port) TEST_DB_PORT="$2"; shift ;;
    --force) FORCE="--force"; shift; continue ;;
    --help) 
      echo "Usage: $0 [--client-id ID] [--domain example.com] [--container-prefix prefix_] [--port 8080] [--db-port 3306] [--force]"
      exit 0 
      ;;
    *) log_error "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Run a test case and track results
run_test() {
  local test_name="$1"
  local test_cmd="$2"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  log_info "Running test: $test_name"
  
  if eval "$test_cmd"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "✓ Test passed: $test_name"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "✗ Test failed: $test_name"
    return 1
  fi
}

log_info "Starting PeaceFestivalUSA WordPress testing with container prefix: $CONTAINER_PREFIX"

# Create test directory
TEST_DIR="/tmp/agency_stack_test/peacefestivalusa"
mkdir -p "$TEST_DIR"

# Create temporary .env file for testing
cat > "$TEST_DIR/.env" << EOL
# PeaceFestivalUSA WordPress Test Environment
CLIENT_ID=$CLIENT_ID
DOMAIN=$DOMAIN
WORDPRESS_DB_NAME=wordpress_test
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=test_password
WORDPRESS_TABLE_PREFIX=wp_
MYSQL_ROOT_PASSWORD=root_test_password
EOL

log_info "Test environment file created at $TEST_DIR/.env"

# Test 1: Installation
log_info "Testing WordPress installation..."
run_test "Installation" "${SCRIPT_DIR}/install_client_wordpress.sh --client-id $CLIENT_ID --domain $DOMAIN --admin-email test@example.com --wp-port $TEST_PORT --db-port $TEST_DB_PORT --container-name-prefix $CONTAINER_PREFIX --enable-traefik $FORCE"

# Wait for containers to start
log_info "Waiting for containers to initialize..."
sleep 5

# Test 2: Container Status
run_test "WordPress container running" "docker ps | grep -q '${CONTAINER_PREFIX}wordpress'"
run_test "Database container running" "docker ps | grep -q '${CONTAINER_PREFIX}db'"

# Test 3: WordPress Web Access
if [ "$DOMAIN" = "localhost:8080" ]; then
  run_test "WordPress web access" "curl -s http://localhost:$TEST_PORT | grep -q -i wordpress"
else
  log_info "Skipping direct web access test for non-localhost domain"
fi

# Test 4: Database Connection
run_test "Database connection" "docker exec ${CONTAINER_PREFIX}db mysql -u root -proot_test_password -e 'SHOW DATABASES;' | grep -q wordpress_test"

# Test 5: WordPress Configuration
run_test "WordPress configuration" "docker exec ${CONTAINER_PREFIX}wordpress ls -la /var/www/html/wp-config.php | grep -q wp-config.php"

# Test 6: WordPress Admin Access
if [ "$DOMAIN" = "localhost:8080" ]; then
  run_test "WordPress admin access" "curl -s http://localhost:$TEST_PORT/wp-admin | grep -q -i username"
else
  log_info "Skipping admin access test for non-localhost domain"
fi

# Display test results
log_info "Test Results for PeaceFestivalUSA WordPress:"
log_info "Total tests: $TESTS_TOTAL"
log_success "Passed: $TESTS_PASSED"
[[ $TESTS_FAILED -gt 0 ]] && log_error "Failed: $TESTS_FAILED" || log_info "Failed: $TESTS_FAILED"

# Clean up (optional)
if [[ "$TESTS_FAILED" -eq 0 && -z "$KEEP_TEST" ]]; then
  log_info "Cleaning up test environment..."
  ${SCRIPT_DIR}/install_client_wordpress.sh --client-id $CLIENT_ID --domain $DOMAIN --container-name-prefix $CONTAINER_PREFIX --remove
  rm -rf "$TEST_DIR"
  log_success "Test environment cleaned up"
else
  log_info "Test environment preserved for debugging at $TEST_DIR"
  log_info "To remove manually, run: ${SCRIPT_DIR}/install_client_wordpress.sh --client-id $CLIENT_ID --domain $DOMAIN --container-name-prefix $CONTAINER_PREFIX --remove"
fi

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]]; then
  log_success "All tests passed successfully"
  exit 0
else
  log_error "Some tests failed. See output for details."
  exit 1
fi
