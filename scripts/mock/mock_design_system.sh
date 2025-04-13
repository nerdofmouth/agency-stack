#!/bin/bash

# AgencyStack Design System Mock Script
# Simulates component interactions and provides mock data for testing

# Source common utilities
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
CLIENT_ID="default"
MOCK_PORT=3334
LOG_FILE="/var/log/agency_stack/components/design-system-mock.log"
MOCK_DIR="/tmp/agency_stack_mock/design-system"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --client-id=*)
      CLIENT_ID="${1#*=}"
      shift
      ;;
    --port=*)
      MOCK_PORT="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: $0 [--client-id=<client-id>] [--port=<port>]"
      echo "  --client-id    Client ID for multi-tenant deployments (default: default)"
      echo "  --port         Port for mock server (default: 3334)"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Create necessary directories
log_info "Creating mock directories..."
mkdir -p "${MOCK_DIR}"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Generate mock component data
log_info "Generating mock component data..."
cat > "${MOCK_DIR}/components.json" << EOFJSON
{
  "components": [
    {
      "name": "InstallCard",
      "category": "UI",
      "description": "Card showing installation status",
      "version": "1.0.0",
      "status": "available",
      "previewUrl": "/design-system/#/~compositions/ui/install-card/basic-install-card"
    },
    {
      "name": "StatusCard",
      "category": "UI",
      "description": "Card showing component status",
      "version": "0.9.0",
      "status": "available",
      "previewUrl": "/design-system/#/~compositions/ui/status-card/basic-status-card"
    },
    {
      "name": "LogViewer",
      "category": "UI",
      "description": "Component for viewing logs",
      "version": "1.0.0",
      "status": "available",
      "previewUrl": "/design-system/#/~compositions/ui/log-viewer/basic-log-viewer"
    },
    {
      "name": "MetricsPanel",
      "category": "UI",
      "description": "Panel for displaying metrics",
      "version": "0.8.0",
      "status": "in-development",
      "previewUrl": "/design-system/#/~compositions/ui/metrics-panel/basic-metrics-panel"
    }
  ]
}
EOFJSON

# Generate mock usage data
log_info "Generating mock usage data..."
cat > "${MOCK_DIR}/usage.json" << EOFJSON
{
  "usage": [
    {
      "component": "InstallCard",
      "usedBy": ["dashboard", "launchpad"],
      "lastUsed": "$(date -d "2 hours ago" +"%Y-%m-%dT%H:%M:%SZ")",
      "count": 15
    },
    {
      "component": "StatusCard",
      "usedBy": ["dashboard"],
      "lastUsed": "$(date -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ")",
      "count": 8
    },
    {
      "component": "LogViewer",
      "usedBy": ["dashboard", "peertube"],
      "lastUsed": "$(date -d "30 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")",
      "count": 12
    }
  ]
}
EOFJSON

# Mock logs
log_info "Generating mock logs..."
echo "[$(date -Iseconds)] INFO: Design System mock started for client ${CLIENT_ID}" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Loading component: InstallCard" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Loading component: StatusCard" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Loading component: LogViewer" >> "$LOG_FILE"
echo "[$(date -Iseconds)] WARN: Component MetricsPanel is still in development" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Dashboard service connected" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Component InstallCard rendered 3 times" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Component StatusCard rendered 2 times" >> "$LOG_FILE"
echo "[$(date -Iseconds)] ERROR: Failed to load custom theme for client XYZ" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: Using default theme instead" >> "$LOG_FILE"
echo "[$(date -Iseconds)] INFO: All components successfully registered" >> "$LOG_FILE"

# Start mock server if Node.js is available
if command -v node &> /dev/null; then
  log_info "Starting mock server on port ${MOCK_PORT}..."
  cat > "${MOCK_DIR}/mock_server.js" << EOFJS
const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const port = ${MOCK_PORT};
const mockDir = '${MOCK_DIR}';
const logFile = '${LOG_FILE}';

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  
  // Log the request
  const timestamp = new Date().toISOString();
  fs.appendFileSync(logFile, \`[\${timestamp}] REQUEST: \${req.method} \${pathname}\n\`);
  
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return;
  }
  
  // Mock API endpoints
  if (pathname === '/api/components') {
    res.setHeader('Content-Type', 'application/json');
    const componentsData = fs.readFileSync(\`\${mockDir}/components.json\`);
    res.end(componentsData);
    return;
  }
  
  if (pathname === '/api/usage') {
    res.setHeader('Content-Type', 'application/json');
    const usageData = fs.readFileSync(\`\${mockDir}/usage.json\`);
    res.end(usageData);
    return;
  }
  
  if (pathname === '/api/logs') {
    res.setHeader('Content-Type', 'application/json');
    const logs = fs.readFileSync(logFile, 'utf8')
      .split('\n')
      .filter(line => line.trim() !== '')
      .slice(-20);
    
    res.end(JSON.stringify({ logs }));
    return;
  }
  
  // Mock installation status endpoint
  if (pathname.startsWith('/api/status/')) {
    const component = pathname.split('/').pop();
    res.setHeader('Content-Type', 'application/json');
    
    const status = Math.random() > 0.2 ? 'installed' : 'error';
    const timestamp = new Date().toISOString();
    
    fs.appendFileSync(logFile, \`[\${timestamp}] STATUS CHECK: \${component} -> \${status}\n\`);
    
    res.end(JSON.stringify({
      component,
      status,
      last_updated: timestamp,
      version: '1.0.0',
      memory_usage: Math.floor(Math.random() * 100) + 'MB',
      cpu_usage: Math.floor(Math.random() * 10) + '%'
    }));
    return;
  }
  
  // Default response for all other requests
  res.setHeader('Content-Type', 'text/html');
  res.end(\`
    <!DOCTYPE html>
    <html>
    <head>
      <title>AgencyStack Design System Mock</title>
      <style>
        body { font-family: system-ui, sans-serif; line-height: 1.5; padding: 2rem; max-width: 800px; margin: 0 auto; }
        h1 { color: #0070f3; }
        .card { background: #f9f9f9; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; }
        .endpoints { background: #f0f0f0; padding: 0.5rem; border-radius: 4px; }
        pre { overflow: auto; }
      </style>
    </head>
    <body>
      <h1>AgencyStack Design System Mock</h1>
      <div class="card">
        <h2>Mock Environment</h2>
        <p>This is a mock server that simulates the Design System and Bit.dev integration.</p>
        <p>Client ID: ${CLIENT_ID}</p>
      </div>
      
      <h2>Available Endpoints</h2>
      <div class="endpoints">
        <pre>GET /api/components - List all components
GET /api/usage - Component usage statistics
GET /api/logs - Recent log entries
GET /api/status/:component - Status of a specific component</pre>
      </div>
      
      <h2>Testing</h2>
      <p>Use these endpoints to test dashboard integration without a full Bit.dev environment.</p>
    </body>
    </html>
  \`);
});

server.listen(port, () => {
  console.log(\`Mock server running at http://localhost:\${port}/\`);
  fs.appendFileSync(logFile, \`[\${new Date().toISOString()}] INFO: Mock server started on port \${port}\n\`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  fs.appendFileSync(logFile, \`[\${new Date().toISOString()}] INFO: Mock server shutting down\n\`);
  server.close(() => {
    process.exit(0);
  });
});
EOFJS

  # Start the mock server in the background
  nohup node "${MOCK_DIR}/mock_server.js" > "${LOG_FILE}.server" 2>&1 &
  SERVER_PID=$!
  
  echo "Mock server started with PID: ${SERVER_PID}"
  echo "Access the mock server at: http://localhost:${MOCK_PORT}/"
  echo "Mock API available at: http://localhost:${MOCK_PORT}/api/components"
  echo "To stop the server: kill ${SERVER_PID}"
else
  log_warning "Node.js not found, mock server not started."
  log_info "Mock data generated in ${MOCK_DIR}"
fi

log_success "Design System mock environment setup complete"
log_info "Mock data available at: ${MOCK_DIR}"
log_info "Mock logs available at: ${LOG_FILE}"
