#!/bin/bash
# Test script for Enhanced MCP service
# Part of AgencyStack (Upstack.agency) - AgencyStack Charter v1.0.3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs/mcp"
mkdir -p "${LOG_DIR}"

echo "Testing Enhanced MCP service..."

# Test health endpoint
echo -e "\n\033[0;34m[TEST]\033[0m Health endpoint"
curl -s http://localhost:3000/health | jq

# Test Puppeteer endpoint with script analysis
echo -e "\n\033[0;34m[TEST]\033[0m Puppeteer endpoint (script analysis)"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"task":"script_analysis","url":"http://example.com"}' \
  http://localhost:3000/puppeteer | jq

# Test Puppeteer endpoint with interface validation
echo -e "\n\033[0;34m[TEST]\033[0m Puppeteer endpoint (interface validation)"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"task":"interface_validation","url":"http://example.com","checks":[{"selector":".example","shouldExist":true}]}' \
  http://localhost:3000/puppeteer | jq

# Test Taskmaster endpoint
echo -e "\n\033[0;34m[TEST]\033[0m Taskmaster endpoint"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"task":"Create a simple AgencyStack component installation guide following Charter principles"}' \
  http://localhost:3000/taskmaster | jq

echo -e "\n\033[0;32m[SUCCESS]\033[0m Tests completed"
echo "Check the response format of each test to verify enhanced functionality"
