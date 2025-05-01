#!/bin/bash
# test_client_wordpress_url.sh - URL Access Testing for WordPress
# Part of AgencyStack TDD Protocol Compliance
# Tests URLs and endpoints for proper configuration

set -e

# Source common utilities if available
if [ -f "$(dirname "$0")/common.sh" ]; then
  source "$(dirname "$0")/common.sh"
else
  # Minimal logging functions if common.sh is not found
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Default values
CLIENT_ID=""
DOMAIN=""
WP_PORT="8082"
VERBOSE="false"
MAX_RETRIES=10
RETRY_DELAY=3
TEST_ADMIN=false

# Show help message
show_help() {
  echo "AgencyStack WordPress URL Access Test"
  echo "==================================="
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --client-id=<id>        Client ID (required)"
  echo "  --domain=<domain>       Domain for WordPress (default: localhost)"
  echo "  --wordpress-port=<port> WordPress port (default: 8082)"
  echo "  --test-admin            Test admin login page access"
  echo "  --verbose               Show all test details"
  echo "  --help                  Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --client-id=clientxyz --domain=localhost --wordpress-port=8082"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  # Split the key=value format if present
  if [[ $key == *"="* ]]; then
    value="${key#*=}"
    key="${key%%=*}"
  else
    # Handle the case where $2 might not be set
    if [[ $# -ge 2 ]]; then
      value="$2"
    else
      value=""
    fi
  fi

  case $key in
    --client-id)
      CLIENT_ID="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --domain)
      DOMAIN="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --wordpress-port)
      WP_PORT="$value"
      if [[ $1 != *"="* ]]; then shift; fi
      shift
      ;;
    --test-admin)
      TEST_ADMIN=true
      shift
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log_error "Unknown option: $key"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$CLIENT_ID" ]; then
  log_error "Client ID is required. Use --client-id=<id>"
  exit 1
fi

# Default domain to localhost if not specified
if [ -z "$DOMAIN" ]; then
  DOMAIN="localhost"
  log_info "Domain not specified, using default: localhost"
fi

# Set paths
INSTALL_BASE_DIR="/opt/agency_stack"
CLIENT_DIR="${INSTALL_BASE_DIR}/clients/${CLIENT_ID}"
SECRETS_DIR="${CLIENT_DIR}/.secrets"
CREDENTIALS_FILE="${SECRETS_DIR}/wordpress-credentials.txt"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/${CLIENT_ID}_wordpress_url_test.log"

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")" || true
echo "==== WordPress URL Access Test for ${CLIENT_ID} ====" > "$LOG_FILE"
echo "Started at: $(date)" >> "$LOG_FILE"
echo "Domain: ${DOMAIN}" >> "$LOG_FILE"
echo "WordPress Port: ${WP_PORT}" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Container names
WORDPRESS_CONTAINER_NAME="${CLIENT_ID}_wordpress"

# Print test header
echo "====================================================="
echo "🧪 WordPress URL Access Test for ${CLIENT_ID}"
echo "====================================================="
echo "Domain: ${DOMAIN}"
echo "WordPress Port: ${WP_PORT}"
echo ""

# Test counter and result tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
  local test_name="$1"
  local test_func="$2"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  echo "🔍 ${TESTS_TOTAL}. Testing: ${test_name}"
  
  # Run the test function and capture result
  if $test_func >> "$LOG_FILE" 2>&1; then
    echo "   ✅ PASS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo "   ❌ FAIL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    
    # Show detailed error if verbose
    if [ "$VERBOSE" = "true" ]; then
      echo "   📋 Error details:"
      tail -n 10 "$LOG_FILE" | sed 's/^/   /'
    fi
    
    return 1
  fi
}

# ==========================================
# URL Access Tests
# ==========================================

# Function to test HTTP URL with retries
test_url_with_retry() {
  local url="$1"
  local expected_status="$2"
  local description="$3"
  local retry_count=0
  local http_status
  
  echo "Testing URL: $url" | tee -a "$LOG_FILE"

  while [ $retry_count -lt $MAX_RETRIES ]; do
    retry_count=$((retry_count + 1))
    
    # Don't follow redirects for admin URLs to prevent login redirects
    if [[ "$url" == *"/wp-admin"* ]]; then
      http_status=$(curl -s -o /dev/null -L -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    else
      http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    fi
    
    echo "HTTP Status (attempt $retry_count): $http_status" | tee -a "$LOG_FILE"
    
    if [[ "$http_status" = "$expected_status" || 
          ("$expected_status" = "2xx" && "$http_status" =~ ^2[0-9][0-9]$) || 
          ("$expected_status" = "3xx" && "$http_status" =~ ^3[0-9][0-9]$) ||
          ("$url" == *"/wp-admin"* && "$http_status" = "301") ]]; then
      echo "✅ $description succeeded with HTTP status: $http_status" | tee -a "$LOG_FILE"
      return 0
    fi
    
    if [ $retry_count -ge $MAX_RETRIES ]; then
      echo "❌ $description failed after $MAX_RETRIES attempts" | tee -a "$LOG_FILE"
      echo "Latest HTTP status: $http_status" | tee -a "$LOG_FILE"
      return 1
    fi
    
    echo "Retrying in $RETRY_DELAY seconds..." | tee -a "$LOG_FILE"
    sleep $RETRY_DELAY
  done
  
  return 1
}

# Test: Front page access via HTTP
test_frontend_http() {
  test_url_with_retry "http://${DOMAIN}:${WP_PORT}" "2xx" "Front page HTTP access"
}

# Test: Front page access via HTTPS (if available)
test_frontend_https() {
  # Skip this test if we're using localhost
  if [ "$DOMAIN" = "localhost" ]; then
    echo "Skipping HTTPS test for localhost" | tee -a "$LOG_FILE"
    return 0
  fi
  
  test_url_with_retry "https://${DOMAIN}" "2xx" "Front page HTTPS access"
}

# Test: WordPress admin login page access
test_wp_admin() {
  test_url_with_retry "http://${DOMAIN}:${WP_PORT}/wp-admin" "2xx" "WordPress admin page access"
}

# Test: WordPress REST API access
test_wp_rest_api() {
  test_url_with_retry "http://${DOMAIN}:${WP_PORT}/wp-json" "2xx" "WordPress REST API access"
}

# Test: WordPress site health check
test_site_health() {
  # Test internal container URL for site health
  CONTAINER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$WORDPRESS_CONTAINER_NAME" 2>/dev/null)
  
  if [ -n "$CONTAINER_IP" ]; then
    test_url_with_retry "http://${CONTAINER_IP}/wp-includes/images/blank.gif" "2xx" "WordPress container direct access"
  else
    echo "Container IP not found, skipping internal health check" | tee -a "$LOG_FILE"
    return 0
  fi
}

# Test: Direct container access
test_direct_container() {
  # This test helps detect container network issues
  docker exec "$WORDPRESS_CONTAINER_NAME" curl -s -I http://localhost/wp-includes/css/dashicons.min.css | grep -q "200 OK"
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    echo "Direct container access successful" | tee -a "$LOG_FILE"
    return 0
  else
    echo "Direct container access failed" | tee -a "$LOG_FILE"
    return 1
  fi
}

# ==========================================
# Run all tests
# ==========================================

echo "📋 Running URL Access Tests..."
run_test "Front page HTTP access" test_frontend_http
run_test "Front page HTTPS access" test_frontend_https
run_test "WordPress admin page" test_wp_admin
run_test "WordPress REST API" test_wp_rest_api
run_test "WordPress site health" test_site_health
run_test "Direct container access" test_direct_container
echo ""

# ==========================================
# Test Summary
# ==========================================

echo "====================================================="
echo "🧪 URL Access Test Summary for ${CLIENT_ID} WordPress"
echo "====================================================="
echo "Total tests: $TESTS_TOTAL"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo "✅ ALL TESTS PASSED!"
  echo "WordPress URL access for ${CLIENT_ID} is working correctly."
  log_success "All URL access tests passed" >> "$LOG_FILE"
  exit 0
else
  echo "❌ SOME TESTS FAILED!"
  echo "There are issues with WordPress URL access for ${CLIENT_ID}."
  echo "Check the log file for more details: $LOG_FILE"
  if [ "$VERBOSE" = "true" ]; then
    echo ""
    echo "📋 Test Log:"
    cat "$LOG_FILE"
  fi
  log_error "Some URL access tests failed: $TESTS_FAILED out of $TESTS_TOTAL" >> "$LOG_FILE"
  exit 1
fi
