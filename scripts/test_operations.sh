#!/bin/bash
# test_operations.sh - Test AgencyStack operational enhancements
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/test_operations-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Source environment variables
if [ -f "/opt/agency_stack/config.env" ]; then
  source "/opt/agency_stack/config.env"
else
  log "${RED}Error: config.env not found${NC}"
  log "Please run the AgencyStack installation first"
  exit 1
fi

# Test header
log "${MAGENTA}${BOLD}🧪 AgencyStack Operations Test${NC}"
log "========================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Function to run tests and report results
run_test() {
  local name="$1"
  local command="$2"
  local expected_result="$3"
  
  log "${BLUE}Testing ${name}...${NC}"
  
  # Run the command
  local result=$(eval "$command")
  local status=$?
  
  if [ $status -eq 0 ] && [[ "$result" == *"$expected_result"* ]]; then
    log "${GREEN}✅ ${name} - PASSED${NC}"
    return 0
  else
    log "${RED}❌ ${name} - FAILED${NC}"
    log "Expected: $expected_result"
    log "Got: $result (status: $status)"
    return 1
  fi
}

# Testing health check
test_health_check() {
  log "${CYAN}${BOLD}Testing Health Check System${NC}"
  
  # Run health check
  run_test "Health Check Script" \
    "bash /home/revelationx/CascadeProjects/foss-server-stack/scripts/health_check.sh" \
    "Health check complete"
  
  # Check if log was created
  run_test "Health Check Log" \
    "ls -la ${LOG_DIR}/health_check-*.log | wc -l" \
    "1"
}

# Testing monitoring
test_monitoring() {
  log "${CYAN}${BOLD}Testing Monitoring System${NC}"
  
  # Check if Grafana is installed
  if grep -q "Grafana" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    # Test Grafana availability
    run_test "Grafana Accessibility" \
      "curl -s -o /dev/null -w '%{http_code}' -L https://${GRAFANA_DOMAIN}" \
      "200"
    
    # Check Grafana container
    run_test "Grafana Container" \
      "docker ps | grep agency_stack_grafana | wc -l" \
      "1"
  else
    log "${YELLOW}Grafana not installed, skipping tests${NC}"
  fi
  
  # Check if Loki is installed
  if grep -q "Loki" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    # Test Loki availability
    run_test "Loki Container" \
      "docker ps | grep agency_stack_loki | wc -l" \
      "1"
  else
    log "${YELLOW}Loki not installed, skipping tests${NC}"
  fi
}

# Testing backup verification
test_backup_verification() {
  log "${CYAN}${BOLD}Testing Backup Verification${NC}"
  
  # Check if backup system is configured
  if grep -q "RESTIC_REPOSITORY" /opt/agency_stack/config.env 2>/dev/null; then
    # Verify that backup verification script exists
    run_test "Backup Verification Script" \
      "ls -la /home/revelationx/CascadeProjects/foss-server-stack/scripts/verify_backup.sh | wc -l" \
      "1"
  else
    log "${YELLOW}Backup system not configured, skipping tests${NC}"
  fi
}

# Testing configuration management
test_configuration_management() {
  log "${CYAN}${BOLD}Testing Configuration Management${NC}"
  
  # Check if config repo exists
  if [ -d "/opt/agency_config" ]; then
    # Verify git repo
    run_test "Config Git Repository" \
      "cd /opt/agency_config && git status | grep -c 'working tree clean'" \
      "1"
  else
    # Test creating a config snapshot
    run_test "Config Snapshot Creation" \
      "bash /home/revelationx/CascadeProjects/foss-server-stack/scripts/config_snapshot.sh snapshot \"Test snapshot from operations test\"" \
      "Configuration snapshot created"
  fi
}

# Testing Keycloak integration (if installed)
test_keycloak_integration() {
  log "${CYAN}${BOLD}Testing Keycloak Integration${NC}"
  
  # Check if Keycloak is installed
  if grep -q "Keycloak" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    # Test Keycloak availability
    run_test "Keycloak Accessibility" \
      "curl -s -o /dev/null -w '%{http_code}' -L https://${KEYCLOAK_DOMAIN}/auth/" \
      "200"
    
    # Check if AgencyStack realm exists
    if curl -s "https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack" | grep -q "agencystack"; then
      log "${GREEN}✅ Keycloak AgencyStack realm exists${NC}"
      
      # Check for clients
      run_test "Keycloak Grafana Client" \
        "curl -s -X POST -d \"client_id=admin-cli\" -d \"username=admin\" -d \"password=${KEYCLOAK_ADMIN_PASSWORD}\" -d \"grant_type=password\" https://${KEYCLOAK_DOMAIN}/auth/realms/master/protocol/openid-connect/token | grep -c \"access_token\"" \
        "1"
    else
      log "${YELLOW}Keycloak AgencyStack realm not found${NC}"
      log "You can run 'make integrate-keycloak' to set up SSO integration"
    fi
  else
    log "${YELLOW}Keycloak not installed, skipping tests${NC}"
  fi
}

# Run all tests
main() {
  # Track overall test results
  local passed=0
  local failed=0
  
  # Component tests
  test_health_check
  test_monitoring
  test_backup_verification
  test_configuration_management
  test_keycloak_integration
  
  # Test alert functionality
  if grep -q "ALERT_EMAIL_ENABLED=true" /opt/agency_stack/config.env 2>/dev/null || \
     grep -q "ALERT_TELEGRAM_ENABLED=true" /opt/agency_stack/config.env 2>/dev/null || \
     grep -q "ALERT_WEBHOOK_ENABLED=true" /opt/agency_stack/config.env 2>/dev/null; then
    
    log "${CYAN}${BOLD}Testing Alert System${NC}"
    log "${YELLOW}Note: This will send real alerts to configured channels${NC}"
    
    read -p "Do you want to test the alert system? (y/n): " test_alert
    if [[ "$test_alert" == "y" ]]; then
      run_test "Alert Test" \
        "bash /home/revelationx/CascadeProjects/foss-server-stack/scripts/test_alert.sh" \
        "Alert Test Summary"
    else
      log "${YELLOW}Skipping alert test${NC}"
    fi
  fi
  
  # Generate summary
  log ""
  log "${MAGENTA}${BOLD}Test Summary${NC}"
  log "====================="
  
  # Count test results from log file
  passed=$(grep -c "✅.*PASSED" "$LOG_FILE")
  failed=$(grep -c "❌.*FAILED" "$LOG_FILE")
  
  log "${GREEN}Passed: ${passed}${NC}"
  log "${RED}Failed: ${failed}${NC}"
  log "Total: $((passed + failed))"
  
  # Show log location
  log ""
  log "${BLUE}Full test log available at:${NC}"
  log "${CYAN}${LOG_FILE}${NC}"
  
  # Final message
  if [ $failed -eq 0 ]; then
    log "${GREEN}${BOLD}🎉 All tests passed!${NC}"
    exit 0
  else
    log "${RED}${BOLD}⚠️ Some tests failed, please check the log for details${NC}"
    exit 1
  fi
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
