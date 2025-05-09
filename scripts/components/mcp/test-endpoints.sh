#!/bin/bash
# MCP Server Endpoint Testing Script
# Follows AgencyStack Charter v1.0.3 principles and TDD Protocol

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Log functions
log_info() { echo -e "[INFO] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "[SUCCESS] $1"; }
log_warning() { echo -e "[WARNING] $1"; }

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
MCP_HOST="${2:-mcp-server}"  # Use Docker service name for container networking
MCP_PORT="${3:-3000}"
MCP_URL="http://${MCP_HOST}:${MCP_PORT}"
OUTPUT_DIR="/tmp/mcp-tests"

# Log header
log_info "=================================================="
log_info "AgencyStack MCP Server Endpoint Testing"
log_info "Following AgencyStack Charter and TDD Protocol"
log_info "=================================================="
log_info "MCP URL: ${MCP_URL}"
log_info "Client ID: ${CLIENT_ID}"
log_info "=================================================="

# Check if we're in AgencyStack repository
if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  log_error "Not running from git repository. Exiting to maintain repository integrity."
  exit 1
fi

# Check if MCP server is running
log_info "Checking if MCP server is running..."
MCP_CONTAINER=$(docker ps | grep mcp-server | awk '{print $1}')

if [[ -z "${MCP_CONTAINER}" ]]; then
  log_warning "MCP server container not found. Starting it..."
  (cd "${REPO_ROOT}" && make mcp_server CLIENT_ID="${CLIENT_ID}")
  sleep 5
  MCP_CONTAINER=$(docker ps | grep mcp-server | awk '{print $1}')
  
  if [[ -z "${MCP_CONTAINER}" ]]; then
    log_error "Failed to start MCP server container. Exiting."
    exit 1
  fi
fi

log_success "MCP server is running in container: ${MCP_CONTAINER}"

# Use localhost for direct communication with MCP server
HOST_MCP_URL="http://localhost:3000"
log_info "Using host networking with MCP URL: ${HOST_MCP_URL}"

# Run tests in a container with host networking
log_info "Running tests in Docker container with host networking..."
docker run --rm \
  --network=host \
  -v "${REPO_ROOT}:/app" \
  -w /app \
  -e MCP_URL="${HOST_MCP_URL}" \
  -e CLIENT_ID="${CLIENT_ID}" \
  -e WP_URL="http://localhost:8082" \
  -e OUTPUT_DIR="${OUTPUT_DIR}" \
  node:18-alpine \
  node /app/scripts/components/mcp/test-all-endpoints.js

TEST_EXIT_CODE=$?

# Copy test results from container to host
log_info "Retrieving test results..."
TEST_RESULTS_DIR="${REPO_ROOT}/test-results/mcp"
mkdir -p "${TEST_RESULTS_DIR}"

# Use another container to copy files from the shared volume
docker run --rm \
  -v "${REPO_ROOT}:/app" \
  -v "/tmp:/tmp" \
  alpine:latest \
  sh -c "mkdir -p /app/test-results/mcp && cp -r /tmp/mcp-tests/* /app/test-results/mcp/ || echo 'No test results found'"

# Check if test results were retrieved
if [[ -f "${TEST_RESULTS_DIR}/test-report.html" ]]; then
  log_success "Test results saved to: ${TEST_RESULTS_DIR}/test-report.html"
else
  log_warning "Test results not found in expected location"
fi

# Generate a summary of the test results for the log file
log_info "Generating test summary..."
echo "MCP Server Endpoint Tests - $(date)" > "${REPO_ROOT}/test-results/mcp/summary.log"
echo "=================================================" >> "${REPO_ROOT}/test-results/mcp/summary.log"

if [[ -f "${TEST_RESULTS_DIR}/test-results.json" ]]; then
  TOTAL=$(grep -o '"total":[^,]*' "${TEST_RESULTS_DIR}/test-results.json" | cut -d':' -f2)
  PASSED=$(grep -o '"passed":[^,]*' "${TEST_RESULTS_DIR}/test-results.json" | cut -d':' -f2)
  FAILED=$(grep -o '"failed":[^,]*' "${TEST_RESULTS_DIR}/test-results.json" | cut -d':' -f2)
  
  echo "Total Tests: ${TOTAL}" >> "${REPO_ROOT}/test-results/mcp/summary.log"
  echo "Passed: ${PASSED}" >> "${REPO_ROOT}/test-results/mcp/summary.log"
  echo "Failed: ${FAILED}" >> "${REPO_ROOT}/test-results/mcp/summary.log"
else
  echo "Test results not available" >> "${REPO_ROOT}/test-results/mcp/summary.log"
fi

# Complete the test run
if [[ ${TEST_EXIT_CODE} -eq 0 ]]; then
  log_success "All MCP server endpoint tests passed!"
  exit 0
else
  log_error "Some MCP server endpoint tests failed. See test report for details."
  exit 1
fi
