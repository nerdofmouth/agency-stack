#!/bin/bash
# MCP Server Testing Protocol
# Following AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Component Consistency

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Client ID for testing
CLIENT_ID="${1:-peacefestivalusa}"

# Test MCP server installation
test_mcp_installation() {
  log_info "Testing MCP server installation..."
  
  # Check if install script exists
  if [[ ! -f "${REPO_ROOT}/scripts/components/install_mcp_server.sh" ]]; then
    log_error "MCP server installation script not found"
    return 1
  fi
  
  # Check if launch script exists
  if [[ ! -f "${REPO_ROOT}/scripts/components/launch_mcp_server.sh" ]]; then
    log_error "MCP server launch script not found"
    return 1
  }
  
  log_success "MCP server scripts validated"
  return 0
}

# Test MCP server API
test_mcp_api() {
  log_info "Testing MCP server API..."
  
  # Check if MCP server is running
  if ! docker ps | grep -q "mcp-server"; then
    log_error "MCP server is not running"
    return 1
  fi
  
  # Test health endpoint
  local health_response=$(curl -s http://localhost:3000/health)
  if [[ -z "$health_response" ]]; then
    log_error "MCP server health endpoint not responding"
    return 1
  fi
  
  log_info "Health endpoint response: $health_response"
  
  # Test taskmaster endpoint
  local taskmaster_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"task":"test","component":"mcp","client":"'${CLIENT_ID}'"}' \
    http://localhost:3000/taskmaster)
  
  if [[ -z "$taskmaster_response" ]]; then
    log_error "MCP server taskmaster endpoint not responding"
    return 1
  fi
  
  log_info "Taskmaster endpoint response: $taskmaster_response"
  
  # Test puppeteer endpoint
  local puppeteer_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"task":"script_analysis","repository":"'${REPO_ROOT}'","patterns":["scripts/components/install_mcp_server.sh"]}' \
    http://localhost:3000/puppeteer)
  
  if [[ -z "$puppeteer_response" ]]; then
    log_error "MCP server puppeteer endpoint not responding"
    return 1
  fi
  
  log_info "Puppeteer endpoint response: $puppeteer_response"
  
  log_success "MCP server API tests passed"
  return 0
}

# Test WordPress validation
test_wordpress_validation() {
  log_info "Testing WordPress validation with MCP server..."
  
  # Check if the WordPress site is accessible
  local wp_url="http://host.docker.internal:8082"
  
  # Test WordPress validation endpoint
  local wordpress_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"task":"verify_wordpress","url":"'${wp_url}'"}' \
    http://localhost:3000/puppeteer)
  
  if [[ -z "$wordpress_response" ]]; then
    log_error "MCP server WordPress validation endpoint not responding"
    return 1
  fi
  
  log_info "WordPress validation response: $wordpress_response"
  
  if echo "$wordpress_response" | grep -q "\"success\":true"; then
    log_success "WordPress validation tests passed"
    return 0
  else
    log_warning "WordPress validation incomplete - site may not be fully configured"
    return 1
  fi
}

# Run all tests
run_tests() {
  log_info "Running MCP server testing protocol for client: ${CLIENT_ID}"
  
  # Array to track test results
  local test_results=()
  
  # Run installation tests
  if test_mcp_installation; then
    test_results+=("Installation: PASS")
  else
    test_results+=("Installation: FAIL")
  fi
  
  # Run API tests
  if test_mcp_api; then
    test_results+=("API: PASS")
  else
    test_results+=("API: FAIL")
  fi
  
  # Run WordPress validation tests
  if test_wordpress_validation; then
    test_results+=("WordPress Validation: PASS")
  else
    test_results+=("WordPress Validation: FAIL")
  fi
  
  # Print test summary
  log_info "Test Results Summary:"
  for result in "${test_results[@]}"; do
    if [[ "$result" == *": PASS" ]]; then
      log_success "$result"
    else
      log_error "$result"
    fi
  done
  
  # Determine overall test status
  if [[ "${test_results[*]}" != *": FAIL"* ]]; then
    log_success "All tests passed!"
    return 0
  else
    log_error "Some tests failed. See summary above."
    return 1
  fi
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
fi
