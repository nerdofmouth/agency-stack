#!/bin/bash
# install_traefik.sh - OFFICIAL MINIMAL VERSION
# Following AgencyStack Repository Integrity Policy

set -e

echo "[INFO] Installing Traefik with dashboard (official minimal config)..."

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
DASHBOARD_PORT="8081"
CONTAINER_NAME="traefik_${CLIENT_ID}"

# Directory structure (AgencyStack standard)
BASE_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
if [ ! -w "$(dirname ${BASE_DIR})" ]; then
  BASE_DIR="/tmp/agency_stack/${CLIENT_ID}"
fi

INSTALL_DIR="${BASE_DIR}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
LOG_DIR="/var/log/agency_stack/components/traefik"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"

# Create directories
mkdir -p "${CONFIG_DIR}" "${SCRIPTS_DIR}" "${LOG_DIR}"

# Clean up any existing container
echo "[INFO] Cleaning up any existing containers..."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Create the traefik.yml configuration - OFFICIAL MINIMAL VERSION
echo "[INFO] Creating official minimal configuration..."
cat > "${CONFIG_DIR}/traefik.yml" <<EOF
# Official minimal configuration - from Traefik documentation
api:
  # Enable Dashboard
  dashboard: true
  insecure: true

# Entry Points configuration
entryPoints:
  # Main entrypoint
  web:
    address: ":80"

  # Dashboard entrypoint
  traefik:
    address: ":8080"

# Providers configuration
providers:
  file:
    directory: "/etc/traefik/conf.d"
    watch: true
EOF

# Create a configuration directory
mkdir -p "${CONFIG_DIR}/conf.d"

# Create a simple test script
echo "[INFO] Creating verification script..."
cat > "${SCRIPTS_DIR}/verify.sh" <<EOF
#!/bin/bash
# Simple dashboard verification script

echo "Testing Traefik dashboard..."
echo "URL: http://localhost:${DASHBOARD_PORT}/dashboard/"

# Test dashboard access
RESPONSE=\$(curl -s -I "http://localhost:${DASHBOARD_PORT}/dashboard/" | head -1)
echo "Response: \$RESPONSE"

# Show Traefik container status
echo "Container status:"
docker ps | grep ${CONTAINER_NAME}

# Show latest logs
echo "Container logs:"
docker logs ${CONTAINER_NAME} --tail 10
EOF
chmod +x "${SCRIPTS_DIR}/verify.sh"

# Create a README.md file
echo "[INFO] Creating documentation..."
cat > "${INSTALL_DIR}/README.md" <<EOF
# Traefik Dashboard - Official Minimal Configuration

This is the official minimal configuration for Traefik dashboard, based on the Traefik documentation.

## Access

The dashboard is available at:
\`\`\`
http://localhost:${DASHBOARD_PORT}/dashboard/
\`\`\`

## Verification

To verify dashboard access:
\`\`\`
${SCRIPTS_DIR}/verify.sh
\`\`\`

## Logs

Logs are available in:
\`\`\`
${LOG_DIR}
\`\`\`

## Restart

To restart Traefik:
\`\`\`
docker restart ${CONTAINER_NAME}
\`\`\`
or
\`\`\`
make traefik-restart
\`\`\`
EOF

# Start Traefik with the official minimal configuration
echo "[INFO] Starting Traefik with official minimal configuration..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "80:80" \
  -p "${DASHBOARD_PORT}:8080" \
  -v "${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro" \
  -v "${CONFIG_DIR}/conf.d:/etc/traefik/conf.d:ro" \
  -v "${LOG_DIR}:/var/log/traefik" \
  traefik:v2.9

# Wait for initialization
echo "[INFO] Waiting for initialization..."
sleep 5

# Check if container is running
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
  echo "[ERROR] Container failed to start!"
  exit 1
fi

echo ""
echo "=============================================================="
echo "  TRAEFIK DASHBOARD - OFFICIAL MINIMAL CONFIGURATION"
echo "=============================================================="
echo ""
echo "  Dashboard URL: http://localhost:${DASHBOARD_PORT}/dashboard/"
echo ""
echo "  To verify access, run: ${SCRIPTS_DIR}/verify.sh"
echo ""
echo "  This configuration follows the official"
echo "  Traefik documentation for dashboard setup."
echo ""
echo "=============================================================="
echo ""

# Provide a browser access tip
echo "[INFO] Access the dashboard at: http://localhost:${DASHBOARD_PORT}/dashboard/"
