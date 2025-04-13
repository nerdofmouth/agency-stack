#!/bin/bash

# AgencyStack Design System Dev Environment Installation Script
# Integrates Bit.dev with AgencyStack Dashboard for component development

# Source common utilities
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_DIR}/../utils/common.sh"

# Default configuration
ENABLE_CLOUD=false
CLIENT_ID="default"
DESIGN_SYSTEM_PORT=3333
BIT_DEV_PORT=3000
LOG_FILE="/var/log/agency_stack/components/design-system.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/design-system"
DESIGN_SYSTEM_REPO_DIR="/opt/agency_stack/repo/design-system-bit"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --client-id=*)
      CLIENT_ID="${1#*=}"
      shift
      ;;
    --port=*)
      DESIGN_SYSTEM_PORT="${1#*=}"
      shift
      ;;
    --bit-port=*)
      BIT_DEV_PORT="${1#*=}"
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--client-id=<client-id>] [--port=<port>] [--bit-port=<bit-port>] [--enable-cloud]"
      echo "  --client-id    Client ID for multi-tenant deployments (default: default)"
      echo "  --port         Port for design system dashboard (default: 3333)"
      echo "  --bit-port     Port for Bit dev server (default: 3000)"
      echo "  --enable-cloud Enable Bit.dev cloud features (default: off/sovereign mode)"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Create necessary directories
log_info "Creating AgencyStack Design System directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Ensure node.js and npm are installed
if ! command -v node &> /dev/null; then
  log_info "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  apt-get install -y nodejs
fi

# Check if Bit is installed globally
if ! command -v bit &> /dev/null; then
  log_info "Installing Bit globally..."
  npm install -g @teambit/bvm
  export PATH="$PATH:$HOME/bin"
  bvm install
  
  # Disable analytics for sovereignty unless cloud is enabled
  if [ "$ENABLE_CLOUD" != "true" ]; then
    log_info "Configuring Bit for sovereign mode (disabling analytics)..."
    bit config set analytics_reporting false
    bit config set anonymous_reporting false
  fi
fi

# Copy design system files to install directory
log_info "Installing AgencyStack Design System files..."
rsync -av --exclude="node_modules" "$DESIGN_SYSTEM_REPO_DIR/" "${INSTALL_DIR}/"

# Create dashboard integration script
log_info "Creating dashboard integration script..."
cat > "${INSTALL_DIR}/dashboard-integration.js" << 'EOFJS'
#!/usr/bin/env node

/**
 * AgencyStack Design System Dashboard Integration
 * 
 * This script creates a proxy server that:
 * 1. Serves the Bit dev environment at /design-system
 * 2. Adds links to the AgencyStack dashboard
 * 3. Logs component usage to standard AgencyStack log paths
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');
const path = require('path');
const app = express();
const port = process.env.PORT || 3333;
const bitDevPort = process.env.BIT_DEV_PORT || 3000;
const clientId = process.env.CLIENT_ID || 'default';
const logFile = process.env.LOG_FILE || '/var/log/agency_stack/components/design-system.log';

// Ensure log directory exists
const logDir = path.dirname(logFile);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Logger middleware
const logRequest = (req, res, next) => {
  const timestamp = new Date().toISOString();
  const log = `[${timestamp}] ${req.method} ${req.url} ${clientId}\n`;
  fs.appendFileSync(logFile, log);
  next();
};

// Use logging middleware
app.use(logRequest);

// Add API endpoints to interact with the design system
app.get('/api/components', (req, res) => {
  // This would normally read from component_registry.json
  // For now, we'll return a static list
  res.json({
    components: [
      {
        name: 'InstallCard',
        category: 'UI',
        description: 'Card showing installation status',
        version: '1.0.0',
        bitPath: 'nerdofmouth.design-system/ui/install-card',
        status: 'available',
        previewUrl: `/design-system/#/~compositions/nerdofmouth.design-system/ui/install-card/basic-install-card`
      }
    ]
  });
});

// Proxy requests to the bit dev server
app.use('/design-system', createProxyMiddleware({
  target: `http://localhost:${bitDevPort}`,
  changeOrigin: true,
  pathRewrite: {
    '^/design-system': '/'
  },
  onProxyReq: (proxyReq, req, res) => {
    // Log bit dev requests
    const timestamp = new Date().toISOString();
    const log = `[${timestamp}] PROXY ${req.method} ${req.url} to Bit Dev\n`;
    fs.appendFileSync(logFile, log);
  }
}));

// Serve the dashboard integration UI - using non-template literal to avoid JS parsing issues
app.get('/', (req, res) => {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>AgencyStack Design System</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body {
          font-family: system-ui, -apple-system, sans-serif;
          line-height: 1.5;
          margin: 0;
          padding: 0;
          color: #333;
          background-color: #f8f9fa;
        }
        .container {
          max-width: 1200px;
          margin: 0 auto;
          padding: 2rem;
        }
        header {
          background-color: #0070f3;
          color: white;
          padding: 1rem 0;
          margin-bottom: 2rem;
        }
        h1 {
          margin: 0;
          font-size: 1.5rem;
        }
        .card {
          background: white;
          border-radius: 8px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          padding: 1.5rem;
          margin-bottom: 1rem;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
          gap: 1.5rem;
        }
        .button {
          display: inline-block;
          background-color: #0070f3;
          color: white;
          border: none;
          padding: 0.5rem 1rem;
          border-radius: 4px;
          text-decoration: none;
          cursor: pointer;
        }
        .button:hover {
          background-color: #005cc5;
        }
        .tag {
          display: inline-block;
          background-color: #e0f2fe;
          color: #0070f3;
          padding: 0.25rem 0.5rem;
          border-radius: 4px;
          font-size: 0.875rem;
          margin-right: 0.5rem;
        }
      </style>
    </head>
    <body>
      <header>
        <div class="container">
          <h1>AgencyStack Design System</h1>
        </div>
      </header>
      <div class="container">
        <div class="card">
          <h2>Development Environment</h2>
          <p>The Bit development environment is running and can be accessed through this dashboard integration.</p>
          <p>
            <a href="/design-system" class="button" target="_blank">Open Bit Dev Environment</a>
          </p>
        </div>
        
        <h2>Available Components</h2>
        <div class="grid" id="components-grid">
          <div class="card">
            <span class="tag">UI</span>
            <h3>InstallCard</h3>
            <p>Card showing installation status</p>
            <p>Version: 1.0.0</p>
            <p>
              <a href="/design-system/#/~compositions/ui/install-card/basic-install-card" class="button" target="_blank">View Component</a>
            </p>
          </div>
        </div>
        
        <h2>Integration with AgencyStack</h2>
        <div class="card">
          <p>This design system is integrated with AgencyStack:</p>
          <ul>
            <li>Components can be used in the AgencyStack dashboard</li>
            <li>Usage is logged to standard AgencyStack log paths</li>
            <li>Components follow sovereign design principles</li>
          </ul>
          <p>Client ID: ${clientId}</p>
        </div>
      </div>
      
      <script>
        // This would normally fetch from the API
        // fetch('/api/components')
        //   .then(res => res.json())
        //   .then(data => {
        //     const grid = document.getElementById('components-grid');
        //     grid.innerHTML = data.components.map(component => {
        //       return '<div class="card">' +
        //         '<span class="tag">' + component.category + '</span>' +
        //         '<h3>' + component.name + '</h3>' +
        //         '<p>' + component.description + '</p>' +
        //         '<p>Version: ' + component.version + '</p>' +
        //         '<p>' +
        //           '<a href="' + component.previewUrl + '" class="button" target="_blank">View Component</a>' +
        //         '</p>' +
        //       '</div>';
        //     }).join('');
        //   });
      </script>
    </body>
    </html>
  `;
  res.send(html);
});

// Start the server
app.listen(port, () => {
  console.log(`AgencyStack Design System dashboard running at http://localhost:${port}`);
  console.log(`Proxying Bit dev from http://localhost:${bitDevPort}`);
});
EOFJS

# Create service file for the design system dashboard
log_info "Creating systemd service for design system dashboard..."
cat > "/etc/systemd/system/agencystack-design-system.service" << EOFSVC
[Unit]
Description=AgencyStack Design System Dashboard
After=network.target

[Service]
Environment=PORT=${DESIGN_SYSTEM_PORT}
Environment=BIT_DEV_PORT=${BIT_DEV_PORT}
Environment=CLIENT_ID=${CLIENT_ID}
Environment=LOG_FILE=${LOG_FILE}
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node ${INSTALL_DIR}/dashboard-integration.js
Restart=on-failure
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOFSVC

# Install required node dependencies
log_info "Installing required Node.js dependencies..."
cd "${INSTALL_DIR}"
npm install express http-proxy-middleware

# Register with AgencyStack Dashboard
log_info "Registering Design System with AgencyStack Dashboard..."
DASHBOARD_DATA_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
mkdir -p "$DASHBOARD_DATA_DIR"

cat > "$DASHBOARD_DATA_DIR/design-system.json" << EOFJSON
{
  "name": "Design System",
  "description": "AgencyStack Design System Development Environment",
  "version": "1.0.0",
  "url": "http://localhost:${DESIGN_SYSTEM_PORT}",
  "icon": "🎨",
  "category": "Development",
  "ports": {
    "dashboard": ${DESIGN_SYSTEM_PORT},
    "bit_dev": ${BIT_DEV_PORT}
  },
  "status": "available",
  "links": [
    {
      "label": "Dashboard",
      "url": "http://localhost:${DESIGN_SYSTEM_PORT}"
    },
    {
      "label": "Bit Dev",
      "url": "http://localhost:${DESIGN_SYSTEM_PORT}/design-system"
    }
  ],
  "component_registry": {
    "install-card": {
      "path": "ui/install-card",
      "version": "1.0.0",
      "status": "available"
    }
  }
}
EOFJSON

# Enable and start the service
log_info "Enabling and starting AgencyStack Design System service..."
systemctl daemon-reload
systemctl enable agencystack-design-system.service
systemctl start agencystack-design-system.service

# Start Bit dev server in background
log_info "Starting Bit dev server..."
cd "${INSTALL_DIR}"
nohup bit dev --port ${BIT_DEV_PORT} > "${LOG_FILE}.bit-dev" 2>&1 &

log_success "AgencyStack Design System has been installed and integrated with the dashboard"
log_info "Access the dashboard at: http://localhost:${DESIGN_SYSTEM_PORT}"
log_info "Access Bit dev directly at: http://localhost:${BIT_DEV_PORT}"
log_info "or through the proxy at: http://localhost:${DESIGN_SYSTEM_PORT}/design-system"
