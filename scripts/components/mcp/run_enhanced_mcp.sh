#!/bin/bash
# Run script for Enhanced MCP service
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs/mcp"
mkdir -p "${LOG_DIR}"

# Kill any existing MCP services
echo "Stopping existing MCP services..."
pkill -f "node ${SCRIPT_DIR}/mcp" || true
sleep 2

# Start the enhanced MCP server
echo "Starting Enhanced MCP server..."
ANTHROPIC_API_KEY="REMOVED_SECRET" \
PERPLEXITY_API_KEY="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" \
CLIENT_ID="agencystack" \
MCP_PORT="3000" \
nohup node "${SCRIPT_DIR}/mcp_enhanced.js" > "${LOG_DIR}/mcp_enhanced.log" 2>&1 &

echo "Enhanced MCP server started with PID: $!"
echo "Check logs at: ${LOG_DIR}/mcp_enhanced.log"
