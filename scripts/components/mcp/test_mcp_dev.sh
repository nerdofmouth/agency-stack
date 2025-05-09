#!/bin/bash
# MCP Server Development Test Script
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
# Follows principles: Idempotency & Automation, Auditability & Documentation

# Detect script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Define common utility functions
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1"; }
ensure_directory_exists() { mkdir -p "$1"; }

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../../utils/common.sh"
fi

# Create log directory
LOG_DIR="${REPO_ROOT}/logs/mcp"
ensure_directory_exists "${LOG_DIR}"

# Parse arguments
MCP_PORT="${1:-3000}"
TEST_REPORT_FILE="${LOG_DIR}/mcp_test_report.json"

# Function to test Context7 MCP Server
test_context7() {
  log_info "Testing Context7 MCP Server..."
  
  # Test using npx
  log_info "Testing Context7 via npx..."
  npx -y @upstash/context7-mcp@latest --version > /dev/null 2>&1
  local status=$?
  
  if [[ $status -eq 0 ]]; then
    log_success "Context7 npx test passed"
    return 0
  else
    log_warning "Context7 npx direct test failed. Trying to assess package availability..."
    
    # Check if package exists in npm registry
    npm view @upstash/context7-mcp > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      log_warning "Package exists but may require additional setup"
      return 2
    else
      log_error "Package @upstash/context7-mcp not found in npm registry"
      return 1
    fi
  fi
}

# Function to test Puppeteer endpoint
test_puppeteer() {
  log_info "Testing Puppeteer endpoint..."
  
  # Test puppeteer endpoint
  curl -s -X POST -H "Content-Type: application/json" -d "{}" "http://localhost:${MCP_PORT}/puppeteer" > "${LOG_DIR}/puppeteer_test.json"
  
  if [[ $? -eq 0 ]] && grep -q "success" "${LOG_DIR}/puppeteer_test.json"; then
    log_success "Puppeteer endpoint test passed"
    return 0
  else
    log_error "Puppeteer endpoint test failed"
    log_error "Response: $(cat "${LOG_DIR}/puppeteer_test.json" 2>/dev/null || echo 'No response')"
    return 1
  fi
}

# Function to test Taskmaster AI endpoint
test_taskmaster_ai() {
  log_info "Testing Taskmaster AI endpoint..."
  
  # Set required environment variables
  export ANTHROPIC_API_KEY="REMOVED_SECRET"
  export PERPLEXITY_API_KEY="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"
  
  # Test taskmaster endpoint
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{"task":"Generate a simple test message"}' \
    "http://localhost:${MCP_PORT}/taskmaster" > "${LOG_DIR}/taskmaster_test.json"
  
  if [[ $? -eq 0 ]] && grep -q "success" "${LOG_DIR}/taskmaster_test.json"; then
    log_success "Taskmaster AI endpoint test passed"
    return 0
  else
    log_error "Taskmaster AI endpoint test failed"
    log_error "Response: $(cat "${LOG_DIR}/taskmaster_test.json" 2>/dev/null || echo 'No response')"
    return 1
  fi
}

# Function to test Taskmaster AI2 via npx
test_taskmaster_ai2() {
  log_info "Testing Taskmaster AI2 via npx..."
  
  # Test using npx
  npx -y --package=task-master-ai task-master-ai --version > /dev/null 2>&1
  local status=$?
  
  if [[ $status -eq 0 ]]; then
    log_success "Taskmaster AI2 npx test passed"
    return 0
  else
    log_warning "Taskmaster AI2 npx direct test failed. Trying to assess package availability..."
    
    # Check if package exists in npm registry
    npm view task-master-ai > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      log_warning "Package exists but may require additional setup"
      return 2
    else
      log_error "Package task-master-ai not found in npm registry"
      return 1
    fi
  fi
}

# Function to check MCP server health
check_mcp_server_health() {
  log_info "Checking MCP server health..."
  
  # Check if MCP server is running
  curl -s "http://localhost:${MCP_PORT}/health" > "${LOG_DIR}/health_test.json"
  
  if [[ $? -eq 0 ]] && grep -q "healthy" "${LOG_DIR}/health_test.json"; then
    log_success "MCP server is healthy"
    return 0
  else
    log_error "MCP server health check failed"
    log_error "Response: $(cat "${LOG_DIR}/health_test.json" 2>/dev/null || echo 'No response')"
    return 1
  fi
}

# Function to generate test report
generate_test_report() {
  local context7_status=$1
  local puppeteer_status=$2
  local taskmaster_status=$3
  local taskmaster2_status=$4
  local server_status=$5
  
  log_info "Generating test report..."
  
  # Create JSON report
  cat > "${TEST_REPORT_FILE}" <<EOL
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tests": {
    "context7": {
      "status": ${context7_status},
      "message": "$([ ${context7_status} -eq 0 ] && echo "Success" || echo "Failed")"
    },
    "puppeteer": {
      "status": ${puppeteer_status},
      "message": "$([ ${puppeteer_status} -eq 0 ] && echo "Success" || echo "Failed")"
    },
    "taskmaster_ai": {
      "status": ${taskmaster_status},
      "message": "$([ ${taskmaster_status} -eq 0 ] && echo "Success" || echo "Failed")"
    },
    "taskmaster_ai2": {
      "status": ${taskmaster2_status},
      "message": "$([ ${taskmaster2_status} -eq 0 ] && echo "Success" || echo "Failed with code ${taskmaster2_status}")"
    },
    "server_health": {
      "status": ${server_status},
      "message": "$([ ${server_status} -eq 0 ] && echo "Healthy" || echo "Unhealthy")"
    }
  },
  "summary": {
    "total": 5,
    "passed": $(( (context7_status == 0) + (puppeteer_status == 0) + (taskmaster_status == 0) + (taskmaster2_status == 0) + (server_status == 0) )),
    "failed": $(( (context7_status != 0) + (puppeteer_status != 0) + (taskmaster_status != 0) + (taskmaster2_status != 0) + (server_status != 0) ))
  }
}
EOL
  
  log_success "Test report generated at ${TEST_REPORT_FILE}"
  
  # Print summary
  log_info "Test Summary:"
  log_info "- Context7: $([ ${context7_status} -eq 0 ] && echo "✅ Passed" || echo "❌ Failed")"
  log_info "- Puppeteer: $([ ${puppeteer_status} -eq 0 ] && echo "✅ Passed" || echo "❌ Failed")"
  log_info "- Taskmaster AI: $([ ${taskmaster_status} -eq 0 ] && echo "✅ Passed" || echo "❌ Failed")"
  log_info "- Taskmaster AI2: $([ ${taskmaster2_status} -eq 0 ] && echo "✅ Passed" || echo "❌ Failed with code ${taskmaster2_status}")"
  log_info "- Server Health: $([ ${server_status} -eq 0 ] && echo "✅ Healthy" || echo "❌ Unhealthy")"
}

# Main function
main() {
  log_info "Starting MCP server development tests..."
  
  # Check if server is running
  check_mcp_server_health
  local server_status=$?
  
  if [[ $server_status -ne 0 ]]; then
    log_warning "MCP server not running or not healthy. Some tests may fail."
  fi
  
  # Run tests
  test_context7
  local context7_status=$?
  
  test_puppeteer
  local puppeteer_status=$?
  
  test_taskmaster_ai
  local taskmaster_status=$?
  
  test_taskmaster_ai2
  local taskmaster2_status=$?
  
  # Generate report
  generate_test_report $context7_status $puppeteer_status $taskmaster_status $taskmaster2_status $server_status
  
  # Return overall status
  if [[ $context7_status -eq 0 && $puppeteer_status -eq 0 && $taskmaster_status -eq 0 && $taskmaster2_status -eq 0 && $server_status -eq 0 ]]; then
    log_success "All MCP server tests passed"
    return 0
  else
    log_warning "Some MCP server tests failed. Check report for details."
    return 1
  fi
}

# Run the main function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
