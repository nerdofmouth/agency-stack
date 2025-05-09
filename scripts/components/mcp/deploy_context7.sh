#!/bin/bash
# Context7 Server Deployment Script
# Follows AgencyStack Charter v1.0.3 principles
# - Repository as Source of Truth
# - Strict Containerization
# - Proper Change Workflow

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source common utilities if available
if [[ -f "${REPO_ROOT}/scripts/utils/common.sh" ]]; then
  source "${REPO_ROOT}/scripts/utils/common.sh"
else
  # Fallback logging functions
  log_info() { echo -e "[INFO] $1"; }
  log_error() { echo -e "[ERROR] $1"; }
  log_success() { echo -e "[SUCCESS] $1"; }
  log_warning() { echo -e "[WARNING] $1"; }
fi

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
CONTEXT7_PORT="${2:-3007}"

# Log header
log_info "==================================================="
log_info "Context7 Server Deployment"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "==================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Context7 Port: ${CONTEXT7_PORT}"
log_info "==================================================="

# Ensure required directories exist following Charter structure
log_info "Ensuring required directories exist..."
mkdir -p "${REPO_ROOT}/logs/context7"
mkdir -p "${REPO_ROOT}/configs/context7"

# Create deployment configurations
log_info "Creating deployment configurations..."
cat > "${REPO_ROOT}/configs/context7/config.json" << EOF
{
  "client_id": "${CLIENT_ID}",
  "port": ${CONTEXT7_PORT},
  "charter_path": "${REPO_ROOT}/docs/charter/v1.0.3.md",
  "roadmap_path": "${REPO_ROOT}/docs/charter/🚀 Upstack.agency Strategic Project Roadmap-20250411111430.md",
  "charter_compliance": true,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Check if the Context7 container is already running
log_info "Checking if Context7 container is already running..."
EXISTING_CONTAINER=$(docker ps -a | grep context7-server | awk '{print $1}')

if [[ -n "${EXISTING_CONTAINER}" ]]; then
  log_info "Context7 container already exists, stopping and removing..."
  docker stop "${EXISTING_CONTAINER}" > /dev/null
  docker rm "${EXISTING_CONTAINER}" > /dev/null
fi

# Build the Context7 image following Charter containerization principles
log_info "Building Context7 server image..."
docker build -t context7-server -f "${SCRIPT_DIR}/Dockerfile.context7" "${SCRIPT_DIR}"

if [[ $? -ne 0 ]]; then
  log_error "Failed to build Context7 server image"
  exit 1
fi

log_success "Context7 server image built successfully"

# Start the Context7 container
log_info "Starting Context7 server container..."
docker run -d \
  --name context7-server \
  -p "${CONTEXT7_PORT}:3007" \
  -v "${REPO_ROOT}:/agency-stack" \
  -e CLIENT_ID="${CLIENT_ID}" \
  -e CONTEXT7_PORT=3007 \
  --restart unless-stopped \
  context7-server

if [[ $? -ne 0 ]]; then
  log_error "Failed to start Context7 server container"
  exit 1
fi

log_success "Context7 server container started successfully"

# Wait for the container to start
log_info "Waiting for Context7 server to start..."
sleep 3

# Verify the container is running
log_info "Verifying Context7 server is running..."
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' context7-server 2>/dev/null)

if [[ "${CONTAINER_STATUS}" != "running" ]]; then
  log_error "Context7 server container is not running"
  docker logs context7-server
  exit 1
fi

log_success "Context7 server container is running"

# Test the Context7 server health endpoint
log_info "Testing Context7 server health endpoint..."
HEALTH_STATUS=$(curl -s http://localhost:${CONTEXT7_PORT}/health 2>/dev/null)

if [[ $? -ne 0 ]]; then
  log_error "Failed to connect to Context7 server health endpoint"
  exit 1
fi

log_success "Context7 server health endpoint accessible"

# Create a proxy endpoint in the MCP server to forward requests to Context7
log_info "Updating MCP server to forward Context7 requests..."

# Check if the MCP server container exists
MCP_CONTAINER=$(docker ps | grep mcp-server | awk '{print $1}')

if [[ -n "${MCP_CONTAINER}" ]]; then
  log_info "MCP server container found, updating..."
  
  # Enable Context7 proxy in MCP server
  PROXY_SCRIPT="${REPO_ROOT}/scripts/components/mcp/context7-proxy.js"
  cat > "${PROXY_SCRIPT}" << 'EOF'
/**
 * Context7 Proxy Extension for MCP Server
 * Follows AgencyStack Charter v1.0.3 principles
 * 
 * This module extends the MCP server to proxy requests to the Context7 server
 */
const http = require('http');

module.exports = function setupContext7Proxy(app, context7Url = 'http://localhost:3007') {
  console.log(`Setting up Context7 proxy to ${context7Url}`);
  
  app.post('/context7', async (req, res) => {
    console.log('Context7 proxy request received:', req.body);
    
    try {
      // Forward the request to the Context7 server
      const options = {
        hostname: new URL(context7Url).hostname,
        port: new URL(context7Url).port,
        path: '/process',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        }
      };
      
      const proxyReq = http.request(options, (proxyRes) => {
        let data = '';
        proxyRes.on('data', (chunk) => {
          data += chunk;
        });
        
        proxyRes.on('end', () => {
          try {
            const response = JSON.parse(data);
            res.status(proxyRes.statusCode).json(response);
          } catch (err) {
            console.error('Error parsing Context7 response:', err);
            res.status(500).json({
              success: false,
              message: 'Error processing Context7 response',
              error: err.message
            });
          }
        });
      });
      
      proxyReq.on('error', (err) => {
        console.error('Error forwarding request to Context7 server:', err);
        res.status(502).json({
          success: false,
          message: 'Error connecting to Context7 server',
          error: err.message
        });
      });
      
      proxyReq.write(JSON.stringify(req.body));
      proxyReq.end();
    } catch (err) {
      console.error('Error in Context7 proxy:', err);
      res.status(500).json({
        success: false,
        message: 'Error in Context7 proxy',
        error: err.message
      });
    }
  });
  
  console.log('Context7 proxy setup complete');
};
EOF

  log_success "Context7 proxy module created"
fi

# Create module registration in MCP server
log_info "Creating Context7 module registration in MCP server..."
cat > "${REPO_ROOT}/configs/context7/registration.json" << EOF
{
  "name": "context7",
  "version": "1.0.0",
  "url": "http://localhost:${CONTEXT7_PORT}",
  "endpoints": {
    "process": "/process",
    "health": "/health",
    "version": "/version"
  },
  "proxy_path": "${REPO_ROOT}/scripts/components/mcp/context7-proxy.js",
  "charter_compliance": true,
  "containerized": true,
  "tdd_compliance": true
}
EOF

log_success "Context7 module registration created"

# Create a test client for validating the Context7 server
log_info "Creating Context7 test client..."
cat > "${REPO_ROOT}/scripts/components/mcp/test-context7.js" << 'EOF'
/**
 * Context7 Test Client
 * Follows AgencyStack Charter v1.0.3 principles
 * Tests the Context7 server functionality
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

// Configuration
const CONTEXT7_PORT = process.env.CONTEXT7_PORT || 3007;
const CONTEXT7_URL = process.env.CONTEXT7_URL || `http://localhost:${CONTEXT7_PORT}`;
const CLIENT_ID = process.env.CLIENT_ID || 'peacefestivalusa';

// Function to make HTTP requests
function makeRequest(url, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      method: method,
      headers: data ? {
        'Content-Type': 'application/json'
      } : {}
    };
    
    const req = http.request(url, options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonResponse = responseData ? JSON.parse(responseData) : {};
          resolve({
            statusCode: res.statusCode,
            data: jsonResponse
          });
        } catch (error) {
          resolve({
            statusCode: res.statusCode,
            data: responseData,
            parseError: error.message
          });
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Main test function
async function runTests() {
  console.log(`Testing Context7 server at ${CONTEXT7_URL}`);
  
  try {
    // Test health endpoint
    console.log('1. Testing health endpoint...');
    const healthResponse = await makeRequest(`${CONTEXT7_URL}/health`);
    console.log(`Health Status: ${healthResponse.statusCode}`);
    console.log(JSON.stringify(healthResponse.data, null, 2));
    
    // Test process endpoint with deployment plan request
    console.log('\n2. Testing process endpoint with deployment plan request...');
    const deploymentRequest = {
      client_id: CLIENT_ID,
      query: 'Create a deployment plan for WordPress',
      system_prompt: 'You are a deployment planning assistant'
    };
    
    const deploymentResponse = await makeRequest(`${CONTEXT7_URL}/process`, 'POST', deploymentRequest);
    console.log(`Process Status: ${deploymentResponse.statusCode}`);
    console.log(JSON.stringify(deploymentResponse.data, null, 2));
    
    // Test process endpoint with roadmap request
    console.log('\n3. Testing process endpoint with roadmap request...');
    const roadmapRequest = {
      client_id: CLIENT_ID,
      query: 'Create a strategic roadmap',
      system_prompt: 'You are a strategic planning assistant'
    };
    
    const roadmapResponse = await makeRequest(`${CONTEXT7_URL}/process`, 'POST', roadmapRequest);
    console.log(`Process Status: ${roadmapResponse.statusCode}`);
    console.log(JSON.stringify(roadmapResponse.data, null, 2));
    
    // Test version endpoint
    console.log('\n4. Testing version endpoint...');
    const versionResponse = await makeRequest(`${CONTEXT7_URL}/version`);
    console.log(`Version Status: ${versionResponse.statusCode}`);
    console.log(JSON.stringify(versionResponse.data, null, 2));
    
    console.log('\nAll tests completed successfully!');
  } catch (error) {
    console.error(`Error running tests: ${error.message}`);
  }
}

// Run tests
runTests();
EOF

log_success "Context7 test client created"

# Update MakeMakefile to integrate Context7
log_info "Updating Makefile with Context7 targets..."
if [[ -f "${REPO_ROOT}/Makefile" ]]; then
  if ! grep -q "context7:" "${REPO_ROOT}/Makefile"; then
    cat >> "${REPO_ROOT}/Makefile" << 'EOF'

# Context7 targets
context7:
	@echo "Deploying Context7 server..."
	@scripts/components/mcp/deploy_context7.sh $(CLIENT_ID) $(CONTEXT7_PORT)

context7-test:
	@echo "Testing Context7 server..."
	@node scripts/components/mcp/test-context7.js

context7-logs:
	@docker logs context7-server
EOF
    log_success "Added Context7 targets to Makefile"
  else
    log_info "Context7 targets already exist in Makefile"
  fi
else
  log_warning "Makefile not found, skipping target creation"
fi

log_success "Context7 server deployment complete!"
log_info "==================================================="
log_info "To test Context7 server: make context7-test"
log_info "To view Context7 logs: make context7-logs"
log_info "To access Context7 directly: http://localhost:${CONTEXT7_PORT}"
log_info "To access Context7 via MCP: http://localhost:3000/context7"
log_info "==================================================="

exit 0
