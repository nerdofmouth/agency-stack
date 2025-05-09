#!/bin/bash
# MCP Server Development Runner
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3
# Follows principles: Repository as Source of Truth, Idempotency & Automation, Auditability & Documentation

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

# Banner display
log_info "=========================================="
log_info "AgencyStack MCP Development Environment"
log_info "Follows AgencyStack Charter v1.0.3"
log_info "=========================================="

# Setup environment variables
ANTHROPIC_API_KEY="REMOVED_SECRET"
PERPLEXITY_API_KEY="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"
CLIENT_ID="${1:-agencystack}"
MCP_PORT="3000"
CONTEXT7_PORT="3007"
TASKMASTER_PORT="3008"

log_info "Using client ID: ${CLIENT_ID}"
log_info "Main MCP port: ${MCP_PORT}"
log_info "Context7 port: ${CONTEXT7_PORT}"
log_info "Taskmaster port: ${TASKMASTER_PORT}"

# Check if Node.js is installed
check_node() {
  log_info "Checking Node.js installation..."
  if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed. Please install Node.js."
    return 1
  fi
  
  NODE_VERSION=$(node -v)
  log_success "Node.js version ${NODE_VERSION} installed"
  return 0
}

# Kill existing services
kill_existing_services() {
  log_info "Checking for existing MCP services..."
  
  # Check for main MCP server
  if pgrep -f "node ${SCRIPT_DIR}/mcp_server_dev.js" > /dev/null; then
    log_warning "Stopping existing MCP server..."
    pkill -f "node ${SCRIPT_DIR}/mcp_server_dev.js"
  fi
  
  # Check for Context7 service
  if pgrep -f "node ${SCRIPT_DIR}/context7-dev.js" > /dev/null; then
    log_warning "Stopping existing Context7 service..."
    pkill -f "node ${SCRIPT_DIR}/context7-dev.js"
  fi
  
  # Check for Taskmaster service
  if pgrep -f "node ${SCRIPT_DIR}/taskmaster-dev.js" > /dev/null; then
    log_warning "Stopping existing Taskmaster service..."
    pkill -f "node ${SCRIPT_DIR}/taskmaster-dev.js"
  fi
  
  # Give services time to shut down
  sleep 2
  log_success "Existing services stopped"
}

# Start MCP server
start_mcp_server() {
  log_info "Starting MCP server on port ${MCP_PORT}..."
  
  # Ensure dependencies are installed
  if [[ ! -d "${SCRIPT_DIR}/node_modules" ]]; then
    log_info "Installing dependencies..."
    cd "${SCRIPT_DIR}" && npm install express body-parser cors
  fi
  
  # Start the server with environment variables
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY}" \
  CLIENT_ID="${CLIENT_ID}" \
  MCP_PORT="${MCP_PORT}" \
  nohup node "${SCRIPT_DIR}/mcp_server_dev.js" > "${LOG_DIR}/mcp_server.log" 2>&1 &
  
  MCP_PID=$!
  log_info "MCP server started with PID: ${MCP_PID}"
  
  # Wait for server to start
  log_info "Waiting for server to start..."
  sleep 3
  
  # Check if server is running
  if ! ps -p ${MCP_PID} > /dev/null; then
    log_error "MCP server failed to start. Check logs at ${LOG_DIR}/mcp_server.log"
    return 1
  fi
  
  log_success "MCP server started successfully on port ${MCP_PORT}"
  return 0
}

# Start Context7 service
start_context7_service() {
  log_info "Starting Context7 service on port ${CONTEXT7_PORT}..."
  
  # Make script executable
  chmod +x "${SCRIPT_DIR}/context7-dev.js"
  
  # Start the context7 service
  CLIENT_ID="${CLIENT_ID}" \
  MCP_PORT="${CONTEXT7_PORT}" \
  nohup node "${SCRIPT_DIR}/context7-dev.js" > "${LOG_DIR}/context7_service.log" 2>&1 &
  
  CONTEXT7_PID=$!
  log_info "Context7 service started with PID: ${CONTEXT7_PID}"
  
  # Wait for service to start
  log_info "Waiting for Context7 service to start..."
  sleep 2
  
  # Check if service is running
  if ! ps -p ${CONTEXT7_PID} > /dev/null; then
    log_error "Context7 service failed to start. Check logs at ${LOG_DIR}/context7_service.log"
    return 1
  fi
  
  log_success "Context7 service started successfully on port ${CONTEXT7_PORT}"
  return 0
}

# Start Taskmaster service
start_taskmaster_service() {
  log_info "Starting Taskmaster service on port ${TASKMASTER_PORT}..."
  
  # Make script executable
  chmod +x "${SCRIPT_DIR}/taskmaster-dev.js"
  
  # Start the taskmaster service
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY}" \
  CLIENT_ID="${CLIENT_ID}" \
  MCP_PORT="${TASKMASTER_PORT}" \
  nohup node "${SCRIPT_DIR}/taskmaster-dev.js" > "${LOG_DIR}/taskmaster_service.log" 2>&1 &
  
  TASKMASTER_PID=$!
  log_info "Taskmaster service started with PID: ${TASKMASTER_PID}"
  
  # Wait for service to start
  log_info "Waiting for Taskmaster service to start..."
  sleep 2
  
  # Check if service is running
  if ! ps -p ${TASKMASTER_PID} > /dev/null; then
    log_error "Taskmaster service failed to start. Check logs at ${LOG_DIR}/taskmaster_service.log"
    return 1
  fi
  
  log_success "Taskmaster service started successfully on port ${TASKMASTER_PORT}"
  return 0
}

# Test MCP service health
test_service_health() {
  local service_name=$1
  local port=$2
  
  log_info "Testing ${service_name} health on port ${port}..."
  
  # Test health endpoint
  local health_response=$(curl -s "http://localhost:${port}/health" 2>/dev/null)
  
  if [[ $? -eq 0 && "${health_response}" == *"healthy"* ]]; then
    log_success "${service_name} health check passed!"
    return 0
  else
    log_error "${service_name} health check failed!"
    log_error "Response: ${health_response}"
    return 1
  fi
}

# Update MCP config to use our development services
update_mcp_config() {
  log_info "Updating MCP development configuration..."
  
  # Create the development config file if it doesn't exist
  cat > "${SCRIPT_DIR}/mcp_dev_config.json" <<EOL
{
  "mcpServers": {
    "context7": {
      "command": "node",
      "args": ["${SCRIPT_DIR}/context7-dev.js"],
      "env": {
        "CLIENT_ID": "${CLIENT_ID}",
        "MCP_PORT": "${CONTEXT7_PORT}"
      }
    },
    "puppeteer": {
      "command": "curl",
      "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:${MCP_PORT}/puppeteer"],
      "env": {}
    },
    "taskmaster-ai": {
      "command": "curl",
      "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:${MCP_PORT}/taskmaster"],
      "env": {
        "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}",
        "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
      }
    },
    "taskmaster-ai2": {
      "command": "node",
      "args": ["${SCRIPT_DIR}/taskmaster-dev.js"],
      "env": {
        "CLIENT_ID": "${CLIENT_ID}",
        "MCP_PORT": "${TASKMASTER_PORT}",
        "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}",
        "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
      }
    }
  }
}
EOL
  
  log_success "MCP development configuration updated at ${SCRIPT_DIR}/mcp_dev_config.json"
}

# Generate a status report
generate_status_report() {
  log_info "Generating MCP services status report..."
  
  # Get status of each service
  MCP_STATUS=$(test_service_health "MCP Server" "${MCP_PORT}" > /dev/null 2>&1; echo $?)
  CONTEXT7_STATUS=$(test_service_health "Context7" "${CONTEXT7_PORT}" > /dev/null 2>&1; echo $?)
  TASKMASTER_STATUS=$(test_service_health "Taskmaster" "${TASKMASTER_PORT}" > /dev/null 2>&1; echo $?)
  
  # Create report file
  cat > "${LOG_DIR}/mcp_status_report.json" <<EOL
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "services": {
    "mcp_server": {
      "status": $([ $MCP_STATUS -eq 0 ] && echo "\"running\"" || echo "\"failed\""),
      "port": ${MCP_PORT},
      "healthy": $([ $MCP_STATUS -eq 0 ] && echo "true" || echo "false")
    },
    "context7": {
      "status": $([ $CONTEXT7_STATUS -eq 0 ] && echo "\"running\"" || echo "\"failed\""),
      "port": ${CONTEXT7_PORT},
      "healthy": $([ $CONTEXT7_STATUS -eq 0 ] && echo "true" || echo "false")
    },
    "taskmaster": {
      "status": $([ $TASKMASTER_STATUS -eq 0 ] && echo "\"running\"" || echo "\"failed\""),
      "port": ${TASKMASTER_PORT},
      "healthy": $([ $TASKMASTER_STATUS -eq 0 ] && echo "true" || echo "false")
    }
  },
  "summary": {
    "all_services_running": $([ $MCP_STATUS -eq 0 ] && [ $CONTEXT7_STATUS -eq 0 ] && [ $TASKMASTER_STATUS -eq 0 ] && echo "true" || echo "false"),
    "client_id": "${CLIENT_ID}"
  }
}
EOL
  
  log_success "Status report generated at ${LOG_DIR}/mcp_status_report.json"
  
  # Print summary
  log_info "MCP Services Summary:"
  log_info "- MCP Server: $([ $MCP_STATUS -eq 0 ] && echo "✅ Running on port ${MCP_PORT}" || echo "❌ Not running")"
  log_info "- Context7: $([ $CONTEXT7_STATUS -eq 0 ] && echo "✅ Running on port ${CONTEXT7_PORT}" || echo "❌ Not running")"
  log_info "- Taskmaster: $([ $TASKMASTER_STATUS -eq 0 ] && echo "✅ Running on port ${TASKMASTER_PORT}" || echo "❌ Not running")"
  
  if [ $MCP_STATUS -eq 0 ] && [ $CONTEXT7_STATUS -eq 0 ] && [ $TASKMASTER_STATUS -eq 0 ]; then
    log_success "All MCP services are running!"
    return 0
  else
    log_error "Some MCP services failed to start."
    return 1
  fi
}

# Create instructions for using the services
create_usage_instructions() {
  log_info "Creating MCP services usage instructions..."
  
  cat > "${LOG_DIR}/mcp_usage_instructions.md" <<EOL
# AgencyStack MCP Services - Development Usage Guide

This guide explains how to interact with the MCP services running in development mode.

## Available Services

- **MCP Server**: Running on port ${MCP_PORT}
  - Health check: \`curl http://localhost:${MCP_PORT}/health\`
  - Puppeteer endpoint: \`curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:${MCP_PORT}/puppeteer\`
  - Taskmaster endpoint: \`curl -X POST -H "Content-Type: application/json" -d '{"task":"test"}' http://localhost:${MCP_PORT}/taskmaster\`

- **Context7 Service**: Running on port ${CONTEXT7_PORT}
  - Health check: \`curl http://localhost:${CONTEXT7_PORT}/health\`
  - Context7 endpoint: \`curl -X POST -H "Content-Type: application/json" -d '{"context":"test"}' http://localhost:${CONTEXT7_PORT}/context7\`

- **Taskmaster Service**: Running on port ${TASKMASTER_PORT}
  - Health check: \`curl http://localhost:${TASKMASTER_PORT}/health\`
  - Taskmaster endpoint: \`curl -X POST -H "Content-Type: application/json" -d '{"task":"test"}' http://localhost:${TASKMASTER_PORT}/taskmaster\`

## Using in Windsurf IDE

The MCP configuration in Windsurf IDE can use these services directly. The development configuration has been saved to:
\`/root/_repos/agency-stack/scripts/components/mcp/mcp_dev_config.json\`

## Testing the Services

You can run a health check on all services with:
\`/root/_repos/agency-stack/scripts/components/mcp/test_mcp_dev.sh\`

## Stopping the Services

To stop all MCP services, run:
\`pkill -f "node /root/_repos/agency-stack/scripts/components/mcp/"\`

## Logs

Service logs are available in the \`/root/_repos/agency-stack/logs/mcp/\` directory:
- MCP Server: \`mcp_server.log\`
- Context7 Service: \`context7_service.log\`
- Taskmaster Service: \`taskmaster_service.log\`
EOL
  
  log_success "Usage instructions created at ${LOG_DIR}/mcp_usage_instructions.md"
  
  # Output key usage examples
  log_info "=========================================="
  log_info "Quick Usage Examples:"
  log_info "- Check MCP server: curl http://localhost:${MCP_PORT}/health"
  log_info "- Check Context7: curl http://localhost:${CONTEXT7_PORT}/health"
  log_info "- Check Taskmaster: curl http://localhost:${TASKMASTER_PORT}/health"
  log_info "=========================================="
}

# Main function
main() {
  log_info "Setting up MCP development environment..."
  
  # Check prerequisites
  check_node || return 1
  
  # Stop any existing services
  kill_existing_services
  
  # Start services
  start_mcp_server
  start_context7_service
  start_taskmaster_service
  
  # Update MCP config
  update_mcp_config
  
  # Generate status report and usage instructions
  generate_status_report
  create_usage_instructions
  
  log_success "MCP development environment setup completed!"
  log_info "Check ${LOG_DIR}/mcp_usage_instructions.md for usage instructions"
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
