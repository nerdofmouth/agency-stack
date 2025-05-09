#!/bin/bash
# MCP Server Development Setup Script
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
# Follows principles: Repository as Source of Truth, Idempotency & Automation

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
DEV_MODE="${1:-true}"
CLIENT_ID="${2:-agencystack}"
MCP_PORT="${3:-3000}"

# Print banner for better visibility
log_info "=========================================="
log_info "Starting MCP Server Development Setup"
log_info "Client ID: ${CLIENT_ID}"
log_info "MCP Port: ${MCP_PORT}"
log_info "Dev Mode: ${DEV_MODE}"
log_info "=========================================="

# Function to check for required dependencies
check_dependencies() {
  log_info "Checking for required dependencies..."
  
  # Check for Node.js
  if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed. Please install Node.js v18 or higher."
    exit 1
  fi
  
  # Check for npm
  if ! command -v npm &> /dev/null; then
    log_error "npm is not installed. Please install npm."
    exit 1
  fi
  
  # Check for curl
  if ! command -v curl &> /dev/null; then
    log_error "curl is not installed. Please install curl."
    exit 1
  fi
  
  # Log node and npm versions
  log_info "Node.js version: $(node -v)"
  log_info "npm version: $(npm -v)"
  
  log_success "All dependencies are installed"
}

# Function to install required Node.js packages
install_node_packages() {
  log_info "Installing required Node.js packages..."
  
  # Create a temporary package.json if it doesn't exist
  if [[ ! -f "${SCRIPT_DIR}/package.json" ]]; then
    cat > "${SCRIPT_DIR}/package.json" <<'EOL'
{
  "name": "agency-stack-mcp",
  "version": "1.0.0",
  "description": "AgencyStack MCP server for development",
  "main": "server.js",
  "dependencies": {
    "express": "^4.17.1",
    "body-parser": "^1.19.0",
    "cors": "^2.8.5",
    "puppeteer": "^19.7.0",
    "@upstash/context7-mcp": "latest",
    "task-master-ai": "latest"
  }
}
EOL
  fi
  
  # Install dependencies
  log_info "Installing Node.js packages in ${SCRIPT_DIR}..."
  cd "${SCRIPT_DIR}" && npm install
  
  log_success "Node.js packages installed successfully"
}

# Function to start the MCP server
start_mcp_server() {
  log_info "Starting MCP server on port ${MCP_PORT}..."
  
  # First check if the server is already running
  if pgrep -f "node ${SCRIPT_DIR}/server.js" > /dev/null; then
    log_warning "MCP server is already running. Stopping it first..."
    pkill -f "node ${SCRIPT_DIR}/server.js"
    sleep 2
  fi
  
  # Start the server with environment variables
  ANTHROPIC_API_KEY="REMOVED_SECRET" \
  PERPLEXITY_API_KEY="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" \
  CLIENT_ID="${CLIENT_ID}" \
  MCP_PORT="${MCP_PORT}" \
  MODEL="claude-3-7-sonnet-20250219" \
  PERPLEXITY_MODEL="sonar-pro" \
  MAX_TOKENS="64000" \
  TEMPERATURE="0.2" \
  nohup node "${SCRIPT_DIR}/mcp_server_dev.js" > "${LOG_DIR}/mcp_server.log" 2>&1 &
  
  SERVER_PID=$!
  log_info "MCP server started with PID: ${SERVER_PID}"
  
  # Wait for server to start
  log_info "Waiting for server to start..."
  sleep 3
  
  # Check if server is running
  if ! ps -p ${SERVER_PID} > /dev/null; then
    log_error "MCP server failed to start. Check logs at ${LOG_DIR}/mcp_server.log"
    exit 1
  fi
  
  log_success "MCP server started successfully on port ${MCP_PORT}"
}

# Function to test the MCP server endpoints
test_mcp_server() {
  log_info "Testing MCP server endpoints..."
  
  # Test health endpoint
  log_info "Testing health endpoint..."
  health_response=$(curl -s "http://localhost:${MCP_PORT}/health")
  if [[ $health_response == *"healthy"* ]]; then
    log_success "Health endpoint test passed"
  else
    log_error "Health endpoint test failed: ${health_response}"
    return 1
  fi
  
  # Test puppeteer endpoint
  log_info "Testing puppeteer endpoint..."
  puppeteer_response=$(curl -s -X POST -H "Content-Type: application/json" -d "{}" "http://localhost:${MCP_PORT}/puppeteer")
  if [[ $puppeteer_response == *"success"* ]]; then
    log_success "Puppeteer endpoint test passed"
  else
    log_error "Puppeteer endpoint test failed: ${puppeteer_response}"
    return 1
  fi
  
  # Test taskmaster endpoint
  log_info "Testing taskmaster endpoint..."
  taskmaster_response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"task\":\"test\"}" "http://localhost:${MCP_PORT}/taskmaster")
  if [[ $taskmaster_response == *"success"* ]]; then
    log_success "Taskmaster endpoint test passed"
  else
    log_error "Taskmaster endpoint test failed: ${taskmaster_response}"
    return 1
  fi
  
  log_success "All MCP server endpoint tests passed"
  return 0
}

# Function to test the direct MCP tools
test_mcp_tools() {
  log_info "Testing MCP tools from development config..."
  
  # Load the development config
  CONFIG_FILE="${SCRIPT_DIR}/mcp_dev_config.json"
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_error "Development config file ${CONFIG_FILE} not found"
    return 1
  fi
  
  log_info "Testing context7 tool..."
  npx -y @upstash/context7-mcp@latest --help > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    log_success "context7 tool test passed"
  else
    log_warning "context7 tool test failed. This might be normal if the package doesn't have a --help option."
  fi
  
  log_info "Testing taskmaster-ai2 tool..."
  npx -y --package=task-master-ai task-master-ai --help > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    log_success "taskmaster-ai2 tool test passed"
  else
    log_warning "taskmaster-ai2 tool test failed. This might be normal if the package doesn't have a --help option."
  fi
  
  log_success "MCP tools test completed"
  return 0
}

# Main function
main() {
  log_info "Setting up MCP development environment..."
  
  check_dependencies
  install_node_packages
  start_mcp_server
  
  # Test MCP server and tools
  if test_mcp_server && test_mcp_tools; then
    log_success "MCP development environment setup completed successfully"
    log_info "MCP server is running on port ${MCP_PORT}"
    log_info "You can now use the MCP tools from your development environment"
    log_info "To stop the server, run: pkill -f 'node ${SCRIPT_DIR}/server.js'"
  else
    log_error "MCP development environment setup completed with errors"
    log_info "Check the logs for more information"
  fi
}

# Run the main function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
