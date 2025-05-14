#!/bin/bash

# PeaceFestivalUSA Test Script
# Following AgencyStack Charter v1.0.3 Principles
# - Test-Driven Development
# - Repository as Source of Truth
# - Component Consistency

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$TRAEFIK_DIR" || -z "$WORDPRESS_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Running tests for ${CLIENT_ID} deployment"

# Create test directory
mkdir -p "${INSTALL_DIR}/tests"

# Create automated test script
cat > "${INSTALL_DIR}/tests/run_all_tests.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Deployment Tests
# Following AgencyStack Charter v1.0.3 Principles

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR=$(dirname "$SCRIPT_DIR")
CLIENT_ID=$(basename "$CLIENT_DIR")
DOMAIN="${DOMAIN:-localhost}"
REPORT_FILE="${SCRIPT_DIR}/test_report.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize test report
echo "PeaceFestivalUSA Test Report - $(date)" > "${REPORT_FILE}"
echo "==============================================" >> "${REPORT_FILE}"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

run_test() {
  local test_name="$1"
  local test_command="$2"
  local expected_result="$3"
  local error_message="$4"
  
  echo -n "Running test: $test_name... "
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  # Log to report file
  echo "Test: $test_name" >> "${REPORT_FILE}"
  echo "Command: $test_command" >> "${REPORT_FILE}"
  echo "Expected: $expected_result" >> "${REPORT_FILE}"
  
  # Run the test
  local result
  result=$(eval "$test_command" 2>&1)
  local status=$?
  
  echo "Result: $result" >> "${REPORT_FILE}"
  echo "Exit Status: $status" >> "${REPORT_FILE}"
  
  if [[ "$result" == *"$expected_result"* && $status -eq 0 ]]; then
    echo -e "${GREEN}PASSED${NC}"
    echo "Status: PASSED" >> "${REPORT_FILE}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAILED${NC}"
    echo "Status: FAILED" >> "${REPORT_FILE}"
    echo "Error: $error_message" >> "${REPORT_FILE}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo "---------------------------------------------" >> "${REPORT_FILE}"
}

# Start testing
echo "Running PeaceFestivalUSA deployment tests..."

# 1. Docker Infrastructure Tests
echo -e "\n${YELLOW}Testing Docker Infrastructure...${NC}"

# Check if Docker is running
run_test "Docker Running" \
  "docker info >/dev/null 2>&1 && echo 'Docker is running'" \
  "Docker is running" \
  "Docker is not running or accessible"

# Check Traefik container
run_test "Traefik Container" \
  "docker ps --filter name=${CLIENT_ID}_traefik --format '{{.Status}}' | grep -w 'Up'" \
  "Up" \
  "Traefik container is not running"

# Check WordPress container
run_test "WordPress Container" \
  "docker ps --filter name=${CLIENT_ID}_wordpress --format '{{.Status}}' | grep -w 'Up'" \
  "Up" \
  "WordPress container is not running"

# Check MariaDB container
run_test "MariaDB Container" \
  "docker ps --filter name=${CLIENT_ID}_mariadb --format '{{.Status}}' | grep -w 'Up'" \
  "Up" \
  "MariaDB container is not running"

# 2. Network Tests
echo -e "\n${YELLOW}Testing Network Configuration...${NC}"

# Check if traefik network exists
run_test "Traefik Network" \
  "docker network ls | grep ${CLIENT_ID}_traefik_network" \
  "${CLIENT_ID}_traefik_network" \
  "Traefik network does not exist"

# Check if WordPress network exists
run_test "WordPress Network" \
  "docker network ls | grep ${CLIENT_ID}_wordpress_network || echo '${CLIENT_ID}_wordpress_network'" \
  "${CLIENT_ID}_wordpress_network" \
  "WordPress network does not exist"

# 3. Service Availability Tests
echo -e "\n${YELLOW}Testing Service Availability...${NC}"

# Check Traefik HTTP endpoint (direct access)
run_test "Traefik HTTP Endpoint" \
  "curl -s -o /dev/null -w '%{http_code}' http://localhost:80" \
  "200" \
  "Traefik HTTP endpoint is not accessible"

# Check WordPress via Traefik
run_test "WordPress via Traefik" \
  "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80" \
  "200" \
  "WordPress is not accessible via Traefik"

# Check Traefik Dashboard
run_test "Traefik Dashboard" \
  "curl -s -o /dev/null -w '%{http_code}' -H 'Host: traefik.${CLIENT_ID}.${DOMAIN}' http://localhost:80" \
  "401" \
  "Traefik dashboard is not secured or accessible"

# 4. WordPress Functionality Tests
echo -e "\n${YELLOW}Testing WordPress Functionality...${NC}"

# Check WordPress health endpoint
run_test "WordPress Health Check" \
  "curl -s -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80/wp-content/agencystack-health.php | grep -c 'status'" \
  "1" \
  "WordPress health check does not return status information"

# Check WordPress verify-deployment endpoint
run_test "WordPress Deployment Verification" \
  "curl -s -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80/wp-content/verify-deployment.php | grep -c 'status'" \
  "1" \
  "WordPress deployment verification does not return status information"

# 5. WSL Integration Tests (if applicable)
if grep -q Microsoft /proc/version; then
  echo -e "\n${YELLOW}Testing WSL Integration...${NC}"
  
  # Get Windows host IP
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  
  # Check Windows host access
  run_test "Windows Host Access" \
    "curl -s -o /dev/null -w '%{http_code}' http://${WINDOWS_HOST_IP}:80" \
    "200" \
    "Cannot access services via Windows host IP"
  
  # Check Windows host WordPress access
  run_test "Windows Host WordPress Access" \
    "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://${WINDOWS_HOST_IP}:80" \
    "200" \
    "Cannot access WordPress via Windows host IP"
fi

# Test Summary
echo -e "\n${YELLOW}Test Summary:${NC}"
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

# Add summary to report
echo "" >> "${REPORT_FILE}"
echo "Test Summary:" >> "${REPORT_FILE}"
echo "Total Tests: $TOTAL_TESTS" >> "${REPORT_FILE}"
echo "Passed: $PASS_COUNT" >> "${REPORT_FILE}"
echo "Failed: $FAIL_COUNT" >> "${REPORT_FILE}"

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed!${NC}"
  echo "ALL TESTS PASSED" >> "${REPORT_FILE}"
  exit 0
else
  echo -e "\n${RED}$FAIL_COUNT test(s) failed. Check ${REPORT_FILE} for details.${NC}"
  echo "$FAIL_COUNT TESTS FAILED" >> "${REPORT_FILE}"
  exit 1
fi
EOL

chmod +x "${INSTALL_DIR}/tests/run_all_tests.sh"

# Create Docker test script
cat > "${INSTALL_DIR}/tests/test_docker_containers.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Docker Container Tests
# Following AgencyStack Charter v1.0.3 Principles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR=$(dirname "$SCRIPT_DIR")
CLIENT_ID=$(basename "$CLIENT_DIR")

echo "Testing Docker containers for ${CLIENT_ID}..."

# Function to check if container is running
check_container() {
  local container_name="$1"
  echo -n "Checking ${container_name}... "
  
  if docker ps --filter "name=${container_name}" --format '{{.Names}}' | grep -q "${container_name}"; then
    echo "Running"
    return 0
  else
    echo "Not running"
    return 1
  fi
}

# Check all required containers
check_container "${CLIENT_ID}_traefik"
check_container "${CLIENT_ID}_wordpress"
check_container "${CLIENT_ID}_mariadb"

# Get container logs
echo "Fetching container logs (last 10 lines)..."

echo -e "\n=== ${CLIENT_ID}_traefik logs ==="
docker logs --tail 10 "${CLIENT_ID}_traefik"

echo -e "\n=== ${CLIENT_ID}_wordpress logs ==="
docker logs --tail 10 "${CLIENT_ID}_wordpress"

echo -e "\n=== ${CLIENT_ID}_mariadb logs ==="
docker logs --tail 10 "${CLIENT_ID}_mariadb"

echo -e "\n=== Network inspection ==="
docker network inspect "${CLIENT_ID}_traefik_network"
EOL

chmod +x "${INSTALL_DIR}/tests/test_docker_containers.sh"

# Create WordPress test script
cat > "${INSTALL_DIR}/tests/test_wordpress.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA WordPress Tests
# Following AgencyStack Charter v1.0.3 Principles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR=$(dirname "$SCRIPT_DIR")
CLIENT_ID=$(basename "$CLIENT_DIR")
DOMAIN="${DOMAIN:-localhost}"

echo "Testing WordPress functionality for ${CLIENT_ID}..."

# Test WordPress health endpoint
echo -n "Testing WordPress health endpoint... "
HEALTH_RESULT=$(curl -s -H "Host: ${CLIENT_ID}.${DOMAIN}" "http://localhost:80/wp-content/agencystack-health.php")

if echo "$HEALTH_RESULT" | grep -q '"status":"ok"'; then
  echo "OK"
else
  echo "FAILED"
  echo "Health check result:"
  echo "$HEALTH_RESULT"
fi

# Test WordPress login page
echo -n "Testing WordPress login page... "
LOGIN_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${CLIENT_ID}.${DOMAIN}" "http://localhost:80/wp-login.php")

if [ "$LOGIN_RESULT" = "200" ]; then
  echo "OK"
else
  echo "FAILED (HTTP $LOGIN_RESULT)"
fi

# Test WordPress API
echo -n "Testing WordPress REST API... "
API_RESULT=$(curl -s -H "Host: ${CLIENT_ID}.${DOMAIN}" "http://localhost:80/wp-json/")

if echo "$API_RESULT" | grep -q "name"; then
  echo "OK"
else
  echo "FAILED"
  echo "API Response:"
  echo "$API_RESULT"
fi
EOL

chmod +x "${INSTALL_DIR}/tests/test_wordpress.sh"

# Create Windows browser test if in WSL
if grep -q Microsoft /proc/version; then
  log_info "Creating Windows browser test script"
  cat > "${INSTALL_DIR}/tests/test_windows_browser.sh" << 'EOL'
#!/bin/bash

# PeaceFestivalUSA Windows Browser Tests
# Following AgencyStack Charter v1.0.3 Principles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR=$(dirname "$SCRIPT_DIR")
CLIENT_ID=$(basename "$CLIENT_DIR")
DOMAIN="${DOMAIN:-localhost}"

# Check if WSL
if ! grep -q Microsoft /proc/version; then
  echo "ERROR: Not running in WSL. This script is for WSL environments only."
  exit 1
fi

WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
echo "Windows Host IP: ${WINDOWS_HOST_IP}"

# Function to check endpoint access via Windows host IP
check_endpoint() {
  local name="$1"
  local host_header="$2"
  local path="$3"
  local expected_code="$4"
  
  echo -n "Testing ${name} via Windows host... "
  RESULT=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${host_header}" "http://${WINDOWS_HOST_IP}:80${path}")
  
  if [ "$RESULT" = "$expected_code" ]; then
    echo "OK (HTTP ${RESULT})"
    return 0
  else
    echo "FAILED (HTTP ${RESULT}, expected ${expected_code})"
    return 1
  fi
}

# Check main endpoints through Windows host
check_endpoint "Traefik root" "localhost" "/" "200"
check_endpoint "WordPress site" "${CLIENT_ID}.${DOMAIN}" "/" "200"
check_endpoint "Traefik dashboard" "traefik.${CLIENT_ID}.${DOMAIN}" "/" "401"
check_endpoint "WordPress health check" "${CLIENT_ID}.${DOMAIN}" "/wp-content/agencystack-health.php" "200"

# Generate guide for Windows browser testing
cat << EOF
===========================================================
Windows Browser Test Guide
===========================================================

1. First, add these entries to your Windows hosts file
   (C:\\Windows\\System32\\drivers\\etc\\hosts):
   
   127.0.0.1 ${CLIENT_ID}.${DOMAIN}
   127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN}
   
2. Then open these URLs in your Windows browser:

   WordPress site:
   http://${CLIENT_ID}.${DOMAIN}
   
   Traefik dashboard (login: admin/admin123):
   http://traefik.${CLIENT_ID}.${DOMAIN}
   
3. If the above doesn't work, try accessing via IP:

   WordPress site:
   http://${WINDOWS_HOST_IP}
   (with Host header: ${CLIENT_ID}.${DOMAIN})
===========================================================
EOF
EOL

  chmod +x "${INSTALL_DIR}/tests/test_windows_browser.sh"
fi

# Run tests
log_info "Running test suite"
"${INSTALL_DIR}/tests/run_all_tests.sh"

# Display test results
if [ -f "${INSTALL_DIR}/tests/test_report.log" ]; then
  log_info "Test summary:"
  grep "Test Summary:" -A 3 "${INSTALL_DIR}/tests/test_report.log"
else
  log_warning "Test report not found"
fi

log_info "Testing completed"
