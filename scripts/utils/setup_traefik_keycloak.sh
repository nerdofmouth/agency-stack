#!/bin/bash
# Quick setup script for Traefik with Keycloak authentication
# Following the AgencyStack Repository Integrity Policy

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  # Minimal logging functions if common.sh is not available
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
TRAEFIK_PORT=8081
KEYCLOAK_PORT=8082
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
LOG_DIR="/var/log/agency_stack/components"

# Create necessary directories
mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}/dynamic" "${LOG_DIR}"

# Stop existing containers
log_info "Stopping existing containers..."
docker stop traefik_default keycloak_default traefik_forward_auth 2>/dev/null || true
docker rm traefik_default keycloak_default traefik_forward_auth 2>/dev/null || true

# Create docker network if it doesn't exist
log_info "Setting up Docker network..."
docker network create traefik-net 2>/dev/null || true

# Create Traefik config
log_info "Creating Traefik configuration..."
cat > "${CONFIG_DIR}/traefik.yml" <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":8080"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/dynamic"

log:
  level: "INFO"
EOF

# Start Traefik container
log_info "Starting Traefik container..."
docker run -d --name traefik_default \
  --network traefik-net \
  -p ${TRAEFIK_PORT}:8080 \
  -p 80:80 \
  -v ${CONFIG_DIR}/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v ${CONFIG_DIR}/dynamic:/etc/traefik/dynamic:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.dashboard.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)" \
  --label "traefik.http.routers.dashboard.service=api@internal" \
  --label "traefik.http.routers.dashboard.entrypoints=dashboard" \
  traefik:v2.10

# Start Keycloak container
log_info "Starting Keycloak container..."
docker run -d --name keycloak_default \
  --network traefik-net \
  -p ${KEYCLOAK_PORT}:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest \
  start-dev

# Wait for Keycloak to start
log_info "Waiting for Keycloak to start..."
sleep 10

# Verify both services are running
TRAEFIK_RUNNING=$(docker ps -q -f "name=traefik_default" 2>/dev/null)
KEYCLOAK_RUNNING=$(docker ps -q -f "name=keycloak_default" 2>/dev/null)

if [[ -n "$TRAEFIK_RUNNING" && -n "$KEYCLOAK_RUNNING" ]]; then
  log_success "Both services are running!"
  log_info "Traefik dashboard: http://localhost:${TRAEFIK_PORT}/dashboard/"
  log_info "Keycloak admin console: http://localhost:${KEYCLOAK_PORT}/admin/"
  log_info "Keycloak admin credentials: admin/admin"
  
  # Create verification script
  log_info "Creating verification script..."
  mkdir -p "${INSTALL_DIR}/scripts"
  cat > "${INSTALL_DIR}/scripts/verify.sh" <<EOF2
#!/bin/bash
echo "=== Traefik & Keycloak Verification ==="
echo "Checking services status..."

# Check if containers are running
TRAEFIK_RUNNING=\$(docker ps -q -f "name=traefik_default" 2>/dev/null)
KEYCLOAK_RUNNING=\$(docker ps -q -f "name=keycloak_default" 2>/dev/null)

if [ -n "\$TRAEFIK_RUNNING" ]; then
  echo "✅ Traefik is running"
else
  echo "❌ Traefik is not running"
fi

if [ -n "\$KEYCLOAK_RUNNING" ]; then
  echo "✅ Keycloak is running"
else
  echo "❌ Keycloak is not running"
fi

# Check dashboard access
TRAEFIK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TRAEFIK_PORT}/dashboard/)
echo "Traefik dashboard status: HTTP \$TRAEFIK_STATUS"

# Check Keycloak access
KEYCLOAK_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${KEYCLOAK_PORT})
echo "Keycloak status: HTTP \$KEYCLOAK_STATUS"

echo "Verification complete."
EOF2
  chmod +x "${INSTALL_DIR}/scripts/verify.sh"
  
  log_info "Next steps for Keycloak integration:"
  log_info "1. Create a new client in Keycloak at http://localhost:${KEYCLOAK_PORT}/admin/"
  log_info "2. Set up a Forward Auth middleware in Traefik"
  log_info "3. Add the middleware to the dashboard router"
  
  exit 0
else
  log_error "One or more services failed to start."
  docker logs traefik_default
  docker logs keycloak_default
  exit 1
fi
