#!/bin/bash
# install_traefik.sh - DEVELOPMENT VERSION ONLY
# Creates a development-friendly Traefik configuration
# Following AgencyStack Repository Integrity Policy

set -e

echo "[INFO] Starting Traefik installation for development environment..."

# Basic configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8081}"  # Port for dashboard access
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-password123}"
NETWORK_NAME="agency_stack"

# Set paths that work in both Docker and host environments
BASE_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
# Use /tmp as fallback for development/testing environments
if [ ! -w "$(dirname ${BASE_DIR})" ]; then
  echo "[INFO] Using alternative install location due to permission constraints"
  BASE_DIR="/tmp/agency_stack/${CLIENT_ID}"
fi

INSTALL_DIR="${BASE_DIR}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
DOCKER_COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

# Create directories
echo "[INFO] Creating directories..."
mkdir -p "${CONFIG_DIR}/dynamic" "${DATA_DIR}/logs"

# Create Docker network if needed (only if Docker is available)
if command -v docker >/dev/null 2>&1; then
  echo "[INFO] Setting up Docker network..."
  docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 || docker network create "${NETWORK_NAME}" || true
fi

# Create static configuration file
echo "[INFO] Creating configuration files..."
cat > "${CONFIG_DIR}/traefik.yml" <<EOF
# Global configuration
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# API and dashboard configuration
api:
  dashboard: true
  # For development only
  insecure: false

# Log configuration
log:
  level: "INFO"
  filePath: "/logs/traefik.log"

# Access logs
accessLog:
  filePath: "/logs/access.log"

# Entrypoints
entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8081"

# Providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${NETWORK_NAME}"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true
EOF

# Create a hashed password (pre-generated with htpasswd for "password123")
HASHED_PASSWORD="\$apr1\$H6uskkkW\$IgXLP6ewTrSuBkTrqE8wj/"

# Create dashboard configuration with basic auth
echo "[INFO] Creating dashboard configuration with authentication..."
cat > "${CONFIG_DIR}/dynamic/dashboard.yml" <<EOF
# Dashboard configuration
http:
  routers:
    dashboard:
      rule: "PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      service: "api@internal"
      entryPoints: ["dashboard"]
      middlewares:
        - auth
  middlewares:
    auth:
      basicAuth:
        users:
          - "${ADMIN_USER}:${HASHED_PASSWORD}"
EOF

# Create Docker Compose file
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
      - "${DASHBOARD_PORT}:8081"
      - "80:80"
    volumes:
      - ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${CONFIG_DIR}/dynamic:/etc/traefik/dynamic:ro
      - ${DATA_DIR}/logs:/logs
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - TZ=UTC

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Create helper scripts directory
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
mkdir -p "${SCRIPTS_DIR}"

# Create a script to check if Traefik is running properly
echo "[INFO] Creating diagnostic script..."
cat > "${SCRIPTS_DIR}/check-dashboard.sh" <<EOF
#!/bin/bash
# Script to check Traefik dashboard accessibility

# ANSI colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo -e "\${YELLOW}Testing Traefik dashboard access...\${RESET}"
echo -e "\${YELLOW}================================\${RESET}"

# Check if Traefik container exists
if command -v docker >/dev/null 2>&1; then
  echo -en "Traefik container status: "
  if docker ps | grep -q "traefik_${CLIENT_ID}"; then
    echo -e "\${GREEN}Running\${RESET}"
    
    # Check ports
    echo -en "Port ${DASHBOARD_PORT} accessible: "
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${DASHBOARD_PORT} | grep -q -E "200|401"; then
      echo -e "\${GREEN}Yes\${RESET}"
    else
      echo -e "\${RED}No\${RESET}"
    fi
  else
    echo -e "\${RED}Not running\${RESET}"
    echo "Starting container..."
    cd "${INSTALL_DIR}" && docker-compose up -d
  fi
else
  echo -e "\${RED}Docker not available\${RESET}"
fi

# Try to access dashboard
echo -e "\nAttempting to access dashboard at http://localhost:${DASHBOARD_PORT}/dashboard/"
curl -v -u ${ADMIN_USER}:password123 http://localhost:${DASHBOARD_PORT}/dashboard/ 2>&1 | grep -E "HTTP|error|refused"

echo -e "\n\${YELLOW}================================\${RESET}"
echo -e "If you're having trouble accessing the dashboard, make sure:"
echo -e "1. Port ${DASHBOARD_PORT} is not in use by another application"
echo -e "2. You're using the correct credentials:\n   Username: ${ADMIN_USER}\n   Password: password123"
echo -e "3. Docker is running and accessible"
EOF
chmod +x "${SCRIPTS_DIR}/check-dashboard.sh"

# Create a script for running Traefik from outside a container
echo "[INFO] Creating host launcher script..."
cat > "${SCRIPTS_DIR}/host-launch.sh" <<EOF
#!/bin/bash
# Script to launch Traefik on host system

# Stop existing Traefik
docker rm -f traefik_${CLIENT_ID} >/dev/null 2>&1 || true

# Start Traefik with the correct configuration
docker run -d --name traefik_${CLIENT_ID} \\
  -p ${DASHBOARD_PORT}:8081 \\
  -p 80:80 \\
  -v ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro \\
  -v ${CONFIG_DIR}/dynamic:/etc/traefik/dynamic:ro \\
  -v ${DATA_DIR}/logs:/logs \\
  -v /var/run/docker.sock:/var/run/docker.sock:ro \\
  traefik:v2.9

echo "Traefik started with dashboard at: http://localhost:${DASHBOARD_PORT}/dashboard/"
echo "Username: ${ADMIN_USER}"
echo "Password: password123"
EOF
chmod +x "${SCRIPTS_DIR}/host-launch.sh"

# Create README with documentation (following AgencyStack standards)
echo "[INFO] Creating documentation..."
cat > "${INSTALL_DIR}/README.md" <<EOF
# Traefik - Development Configuration

## Overview
This is a development-only Traefik configuration for the AgencyStack environment.

## Security Notice
**IMPORTANT**: This configuration is intended for development only.
For production, additional security measures should be implemented.

## Installation Paths
- Configuration: \`${CONFIG_DIR}\`
- Data/Logs: \`${DATA_DIR}\`
- Helper Scripts: \`${SCRIPTS_DIR}\`

## Dashboard Access
The Traefik dashboard is available at:
- URL: \`http://localhost:${DASHBOARD_PORT}/dashboard/\`
- Username: \`${ADMIN_USER}\`
- Password: \`password123\`

## Helper Scripts
This installation includes utility scripts:
- \`${SCRIPTS_DIR}/check-dashboard.sh\`: Tests dashboard connectivity
- \`${SCRIPTS_DIR}/host-launch.sh\`: Launches Traefik on the host system

## Ports
- Dashboard: ${DASHBOARD_PORT}
- Web traffic: 80

## Logs
- Access logs: \`${DATA_DIR}/logs/access.log\`
- Application logs: \`${DATA_DIR}/logs/traefik.log\`

## Docker-in-Docker Environments
In Docker-in-Docker environments, use one of these approaches:
1. Map port ${DASHBOARD_PORT} when starting the container
2. Run the host launcher: \`bash ${SCRIPTS_DIR}/host-launch.sh\`

## Troubleshooting
If you cannot access the dashboard:
1. Run \`${SCRIPTS_DIR}/check-dashboard.sh\` to diagnose issues
2. Ensure port ${DASHBOARD_PORT} is not in use by another application
3. Make sure you're using the correct credentials

## Restart Method
To restart Traefik:
\`\`\`bash
cd ${INSTALL_DIR} && docker-compose restart
\`\`\`
EOF

# Start Traefik container if Docker is available
if command -v docker >/dev/null 2>&1 && [ -S /var/run/docker.sock ]; then
  echo "[INFO] Starting Traefik container..."
  cd "${INSTALL_DIR}" && docker-compose up -d
  echo "[INFO] Waiting for Traefik to start..."
  sleep 3
else
  echo "[INFO] Docker not available or not accessible."
  echo "[INFO] To start Traefik manually, use: bash ${SCRIPTS_DIR}/host-launch.sh"
fi

# Create symlink to host-launch script in utils for easy access
HOST_UTILS_DIR="$(dirname "$(dirname "$0")")/utils"
if [ -d "${HOST_UTILS_DIR}" ]; then
  echo "[INFO] Creating utility symlink in utils directory..."
  ln -sf "${SCRIPTS_DIR}/host-launch.sh" "${HOST_UTILS_DIR}/traefik-launch.sh" 2>/dev/null || true
fi

# Print success message and instructions
echo ""
echo "=============================================================="
echo "  TRAEFIK DASHBOARD - DEVELOPMENT CONFIGURATION"
echo "=============================================================="
echo ""
echo "  Traefik has been installed in: ${INSTALL_DIR}"
echo ""
echo "  DASHBOARD ACCESS:"
echo "  - URL: http://localhost:${DASHBOARD_PORT}/dashboard/"
echo "  - Username: ${ADMIN_USER}"
echo "  - Password: password123"
echo ""
echo "  HELPER SCRIPTS:"
echo "  - Check dashboard: bash ${SCRIPTS_DIR}/check-dashboard.sh"
echo "  - Host launcher: bash ${SCRIPTS_DIR}/host-launch.sh"
echo ""
echo "  DOCUMENTATION:"
echo "  See ${INSTALL_DIR}/README.md for detailed information"
echo "=============================================================="
echo ""
