#!/bin/bash
# install_traefik.sh - DEVELOPMENT VERSION ONLY
# Creates a development-friendly Traefik configuration
# Following AgencyStack Repository Integrity Policy

echo "[INFO] Starting Traefik installation for development environment..."

# Basic configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"  # Port for dashboard access
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-password123}"
NETWORK_NAME="agency_stack"

# Paths
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

# Create directories
echo "[INFO] Creating directories..."
mkdir -p "${CONFIG_DIR}" "${DATA_DIR}"

# Create Docker network if needed
echo "[INFO] Setting up Docker network..."
docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 || docker network create "${NETWORK_NAME}"

# Create traefik.yml for development
echo "[INFO] Creating configuration files..."
cat > "${CONFIG_DIR}/traefik.yml" <<EOF
# Global configuration
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# API and dashboard configuration
api:
  dashboard: true
  insecure: true  # No auth for dev

# Log configuration
log:
  level: "INFO"

# Entrypoints
entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8080"

# Providers configuration
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${NETWORK_NAME}"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true
EOF

# Create dynamic configuration directory
mkdir -p "${CONFIG_DIR}/dynamic"

# Create dashboard configuration
cat > "${CONFIG_DIR}/dynamic/dashboard.yml" <<EOF
# Dashboard configuration for development
http:
  routers:
    dashboard:
      rule: "PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      service: "api@internal"
      entryPoints: ["dashboard"]
EOF

# Create docker-compose.yml
echo "[INFO] Creating Docker Compose file..."
cat > "${DOCKER_COMPOSE_FILE}" <<EOF
version: '3'

services:
  traefik:
    image: traefik:v2.9
    container_name: traefik_${CLIENT_ID}
    restart: always
    networks:
      - ${NETWORK_NAME}
    ports:
      - "${DASHBOARD_PORT}:8080"  # Dashboard port mapping
      - "80:80"                  # Web traffic port
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${CONFIG_DIR}/dynamic:/etc/traefik/dynamic:ro
    environment:
      - TZ=UTC

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create diagnostic script
cat > "${INSTALL_DIR}/check-dashboard.sh" <<EOF
#!/bin/bash
# Test Traefik dashboard connectivity

# ANSI colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo -e "\${YELLOW}Testing Traefik dashboard access...\${RESET}"
echo -e "\${YELLOW}================================\${RESET}"

# Test dashboard access
echo -en "Dashboard access (port ${DASHBOARD_PORT}): "
if curl -s --head --fail http://localhost:${DASHBOARD_PORT}/dashboard/ > /dev/null; then
  echo -e "\${GREEN}✓ Success\${RESET}"
else
  echo -e "\${RED}✗ Failed\${RESET}"
  echo -e "\${YELLOW}Detailed diagnostics:\${RESET}"
  curl -v http://localhost:${DASHBOARD_PORT}/dashboard/ 2>&1 | grep -E "Failed|refused|error|denied"
fi

# Test Docker container status
echo -en "Traefik container status: "
if docker ps | grep -q "traefik_${CLIENT_ID}"; then
  echo -e "\${GREEN}✓ Running\${RESET}"
else
  echo -e "\${RED}✗ Not running\${RESET}"
  echo "Container logs:"
  docker logs traefik_${CLIENT_ID} --tail 10
fi

echo -e "\${YELLOW}================================\${RESET}"
EOF
chmod +x "${INSTALL_DIR}/check-dashboard.sh"

# Start Traefik
echo "[INFO] Starting Traefik..."
cd "${INSTALL_DIR}" && docker-compose up -d

# Wait for startup
echo "[INFO] Waiting for Traefik to start..."
sleep 3

# Create README with detailed documentation
cat > "${INSTALL_DIR}/README.md" <<EOF
# Traefik - Development Configuration

## Overview
This is a development-only Traefik configuration for the AgencyStack environment.

## Security Notice
**IMPORTANT**: This configuration is intended for development only.
For production, enable proper authentication and HTTPS.

## Dashboard Access
The Traefik dashboard is available at:
- http://localhost:8080/dashboard/ (from within container)

### Accessing from Host Browser
In a Docker-in-Docker environment, you need to:

1. Map port 8080 when starting the development container:
   \`\`\`bash
   docker run -p 8080:8080 ... agencystack-dev
   \`\`\`

2. Or use SSH port forwarding:
   \`\`\`bash
   ssh -p 2222 -L 8080:localhost:8080 -N developer@localhost
   \`\`\`

3. Or create a SOCKS proxy (useful for multiple ports):
   \`\`\`bash
   ssh -p 2222 -D 9090 developer@localhost
   # Then configure browser to use SOCKS proxy localhost:9090
   \`\`\`

## Troubleshooting
If you cannot access the dashboard, run:
\`\`\`
bash ${INSTALL_DIR}/check-dashboard.sh
\`\`\`

## Adding Authentication
To add authentication, modify the dashboard configuration in:
\`${CONFIG_DIR}/dynamic/dashboard.yml\`

Add a middleware section with basicAuth and update the router to use it.
See Traefik documentation for details.

## Default Credentials (When Authentication Enabled)
- Username: ${ADMIN_USER}
- Password: ${ADMIN_PASSWORD}
EOF

# Create clear dashboard access information
echo ""
echo "=============================================================="
echo "  TRAEFIK DASHBOARD - DEVELOPMENT CONFIGURATION"
echo "=============================================================="
echo ""
echo "  Traefik has been installed successfully!"
echo ""
echo "  DASHBOARD ACCESS:"
echo "  - http://localhost:${DASHBOARD_PORT}/dashboard/ (within container)"
echo ""
echo "  FOR HOST BROWSER ACCESS:"
echo "  See ${INSTALL_DIR}/README.md for detailed instructions"
echo "  on accessing from outside the container."
echo ""
echo "  POSSIBLE CONNECTION METHODS:"
echo "  1. Map port ${DASHBOARD_PORT} when starting AgencyStack container"
echo "  2. Use SSH port forwarding:"
echo "     ssh -p 2222 -L ${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT} -N developer@localhost"
echo ""
echo "  NO AUTHENTICATION REQUIRED (Development Mode)"
echo "  Username and password can be added by modifying the configuration"
echo ""
echo "  HAVING TROUBLE ACCESSING THE DASHBOARD?"
echo "  Run the diagnostic script:"
echo "  $ bash ${INSTALL_DIR}/check-dashboard.sh"
echo ""
echo "  DOCUMENTATION:"
echo "  See ${INSTALL_DIR}/README.md for detailed information"
echo "=============================================================="
echo ""
