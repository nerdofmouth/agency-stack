#!/bin/bash
# setup_keycloak_dev.sh - Configure Keycloak within AgencyStack development environment
# This script adheres to the AgencyStack repository integrity policy by pulling from the repo

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default settings
DOMAIN="localhost.test"
ADMIN_EMAIL="admin@localhost.test"
CLIENT_ID="default"
WITH_TRAEFIK=true
START_PORT=8080

# Log function
log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${BOLD}$1${NC}"
}

# Ensure we're in the right directory
cd ~/projects/agency-stack || {
  log "${RED}Failed to change to the project directory. Please run this script from the container.${NC}"
  exit 1
}

# Ensure we have the latest code
log "Pulling latest changes from repository..."
git pull origin main

# Create necessary directories
log "Setting up required directories..."
sudo mkdir -p /opt/agency_stack/clients/${CLIENT_ID}/keycloak
sudo mkdir -p /var/log/agency_stack/components
sudo chown -R developer:developer /opt/agency_stack
sudo chown -R developer:developer /var/log/agency_stack

# Set up /etc/hosts for local development
log "Configuring /etc/hosts for ${DOMAIN}..."
if ! grep -q "${DOMAIN}" /etc/hosts; then
  echo "127.0.0.1 ${DOMAIN}" | sudo tee -a /etc/hosts
fi

# Install and start Keycloak
log "Installing Keycloak via AgencyStack Makefile..."
if [ "$WITH_TRAEFIK" = true ]; then
  # Set up Traefik first
  log "Installing Traefik as a reverse proxy..."
  make traefik DOMAIN=${DOMAIN} || {
    log "${YELLOW}Traefik installation might have issues. Continuing anyway...${NC}"
  }
fi

# Install Keycloak
log "Installing Keycloak..."
make keycloak DOMAIN=${DOMAIN} ADMIN_EMAIL=${ADMIN_EMAIL} CLIENT_ID=${CLIENT_ID} WITH_DEPS=true

# Check status
log "Checking Keycloak status..."
make keycloak-status DOMAIN=${DOMAIN} CLIENT_ID=${CLIENT_ID} || true

# Create a simple standalone docker-compose if Traefik isn't available
if [ "$WITH_TRAEFIK" = false ]; then
  log "Creating standalone Keycloak Docker Compose file..."
  cat > docker-compose.keycloak.yml << EOF
version: '3'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak_${DOMAIN}
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=admin
      - KC_PROXY=edge
      - KC_HOSTNAME_STRICT=false
      - KC_HTTP_ENABLED=true
      - KC_HTTP_PORT=8080
    command: start-dev
    ports:
      - "${START_PORT}:8080"
    volumes:
      - /opt/agency_stack/clients/${CLIENT_ID}/keycloak:/opt/keycloak/data
    networks:
      - keycloak_network

networks:
  keycloak_network:
    driver: bridge
EOF

  # Start the standalone Keycloak
  log "Starting standalone Keycloak..."
  docker-compose -f docker-compose.keycloak.yml up -d

  # Display access information
  log "${GREEN}✅ Keycloak is now running!${NC}"
  log "Access Keycloak at: ${YELLOW}http://localhost:${START_PORT}/auth/${NC}"
  log "Admin credentials: ${YELLOW}admin / admin${NC}"
else
  # Display access information for Traefik setup
  log "${GREEN}✅ Keycloak is now running behind Traefik!${NC}"
  log "Access Keycloak at: ${YELLOW}https://${DOMAIN}/auth/${NC}"
  log "Check logs with: ${YELLOW}make keycloak-logs${NC}"
fi

# Create a browser-viewable HTML status page
log "Creating status page..."
cat > /home/developer/keycloak_status.html << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Keycloak Status - AgencyStack Development</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #336699; }
    .card { border: 1px solid #ddd; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
    .success { color: green; }
    .error { color: red; }
    pre { background: #f4f4f4; padding: 10px; border-radius: 4px; overflow-x: auto; }
    .btn { background: #336699; color: white; padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; }
  </style>
</head>
<body>
  <h1>Keycloak Status - AgencyStack Development</h1>
  
  <div class="card">
    <h2>Keycloak Access</h2>
    <p>Access your Keycloak instance at:</p>
    <p><a href="http${WITH_TRAEFIK:+s}://${DOMAIN}${WITH_TRAEFIK:+/auth/}" target="_blank">http${WITH_TRAEFIK:+s}://${DOMAIN}${WITH_TRAEFIK:+/auth/}</a></p>
  </div>
  
  <div class="card">
    <h2>Container Status</h2>
    <pre id="status">Loading...</pre>
    <button class="btn" onclick="checkStatus()">Refresh Status</button>
  </div>
  
  <div class="card">
    <h2>Recent Logs</h2>
    <pre id="logs">Loading...</pre>
    <button class="btn" onclick="checkLogs()">Refresh Logs</button>
  </div>
  
  <script>
    function checkStatus() {
      document.getElementById('status').innerHTML = 'Checking status...';
      fetch('/status.txt')
        .then(response => response.text())
        .then(data => {
          document.getElementById('status').innerHTML = data;
        })
        .catch(error => {
          document.getElementById('status').innerHTML = 'Error fetching status: ' + error;
        });
    }
    
    function checkLogs() {
      document.getElementById('logs').innerHTML = 'Fetching logs...';
      fetch('/logs.txt')
        .then(response => response.text())
        .then(data => {
          document.getElementById('logs').innerHTML = data;
        })
        .catch(error => {
          document.getElementById('logs').innerHTML = 'Error fetching logs: ' + error;
        });
    }
    
    // Initial load
    checkStatus();
    checkLogs();
  </script>
</body>
</html>
EOF

log "${GREEN}✅ Setup complete!${NC}"
log "To check your Keycloak status at any time, run: ${YELLOW}make keycloak-status DOMAIN=${DOMAIN}${NC}"
