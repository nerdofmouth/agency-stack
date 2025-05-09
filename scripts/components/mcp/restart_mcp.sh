#!/bin/bash
# MCP Server Restart Script
# Follows AgencyStack Charter v1.0.3 principles
# - Repository as Source of Truth
# - Strict Containerization
# - Component Consistency

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Log output functions
log_info() { echo -e "[INFO] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "[SUCCESS] $1"; }

# Configuration
CLIENT_ID="${1:-peacefestivalusa}"
MCP_PORT="${2:-3000}"
ANTHROPIC_API_KEY="REMOVED_SECRET"
PERPLEXITY_API_KEY="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"
MODEL="claude-3-7-sonnet-20250219"
PERPLEXITY_MODEL="sonar-pro"
MAX_TOKENS="64000"
TEMPERATURE="0.2"
DEFAULT_SUBTASKS="5"
DEFAULT_PRIORITY="medium"

# Log restart details
log_info "==================================================="
log_info "MCP Server Restart Script"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "==================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "MCP Port: ${MCP_PORT}"
log_info "==================================================="

# Stop existing MCP server container
log_info "Stopping existing MCP server container..."
docker stop mcp-server >/dev/null 2>&1 || true
docker rm mcp-server >/dev/null 2>&1 || true

# Start new MCP server with proper environment variables
log_info "Starting MCP server with proper environment variables..."
docker run -d \
  --name mcp-server \
  -p "${MCP_PORT}:3000" \
  -v "${REPO_ROOT}:/app" \
  -w /app \
  -e CLIENT_ID="${CLIENT_ID}" \
  -e MCP_PORT="${MCP_PORT}" \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  -e PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY}" \
  -e MODEL="${MODEL}" \
  -e PERPLEXITY_MODEL="${PERPLEXITY_MODEL}" \
  -e MAX_TOKENS="${MAX_TOKENS}" \
  -e TEMPERATURE="${TEMPERATURE}" \
  -e DEFAULT_SUBTASKS="${DEFAULT_SUBTASKS}" \
  -e DEFAULT_PRIORITY="${DEFAULT_PRIORITY}" \
  --network mcp-servers_mcp-network \
  node:18-alpine \
  node /app/scripts/components/mcp/server.js

if [ $? -ne 0 ]; then
  log_error "Failed to start MCP server container"
  exit 1
fi

# Wait for server to start
log_info "Waiting for MCP server to start..."
sleep 3

# Verify server is running
log_info "Verifying MCP server is running..."
curl -s http://localhost:${MCP_PORT}/health > /dev/null
if [ $? -ne 0 ]; then
  log_error "MCP server is not responding to health check"
  docker logs mcp-server
  exit 1
fi

log_success "MCP server restarted successfully!"
log_info "==================================================="
log_info "MCP server is running on http://localhost:${MCP_PORT}"
log_info "API keys are properly configured"
log_info "==================================================="

exit 0
