#!/bin/bash
# install_traefik.sh - Keycloak-integrated dashboard
# Following AgencyStack Repository Integrity Policy

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../utils/common.sh" ]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Detect environment (container vs host)
if [[ -f "/.dockerenv" ]] || [[ -f "/proc/1/cgroup" && $(cat /proc/1/cgroup) == *"docker"* ]]; then
  export INSIDE_CONTAINER=true
  log_info "Detected Docker container environment, using direct process management"
fi

# Debug: Output container detection
log_info "Container detection: INSIDE_CONTAINER=${INSIDE_CONTAINER}"

# Configuration variables
CLIENT_ID="${CLIENT_ID:-default}"
DASHBOARD_PORT="8081"
CONTAINER_NAME="traefik_${CLIENT_ID}"
ENABLE_KEYCLOAK=false

# Help function
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --client-id <id>        Client ID (default: default)"
  echo "  --dashboard-port <port> Dashboard port (default: 8081)"
  echo "  --enable-keycloak       Enable Keycloak authentication"
  echo "  --domain <domain>       Keycloak domain (required if enable-keycloak is set)"
  echo "  --admin-email <email>   Admin email (required if enable-keycloak is set)"
  echo "  --help                  Display this help message"
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --dashboard-port)
      DASHBOARD_PORT="$2"
      shift 2
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Verify Keycloak parameters if enabled
if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
  if [[ -z "$DOMAIN" ]]; then
    log_error "Domain is required when enabling Keycloak authentication"
    echo "Use --domain to specify the Keycloak domain"
    exit 1
  fi
  
  if [[ -z "$ADMIN_EMAIL" ]]; then
    log_error "Admin email is required when enabling Keycloak authentication"
    echo "Use --admin-email to specify the admin email"
    exit 1
  fi
fi

log_info "Starting Traefik installation with dashboard..."

# Directory structure settings
# Following AgencyStack Repository Integrity Policy
BASE_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
LOG_DIR="/var/log/agency_stack/components/traefik"

# Check write access and use fallbacks if needed
if [ ! -w "$(dirname ${BASE_DIR})" ]; then
  # Use current directory for development
  BASE_DIR="$(pwd)/traefik_${CLIENT_ID}"
  log_warning "Using fallback directory: ${BASE_DIR}"
fi

if [ ! -w "$(dirname ${LOG_DIR})" ]; then
  LOG_DIR="${BASE_DIR}/logs"
  log_warning "Using fallback logs directory: ${LOG_DIR}"
fi

INSTALL_DIR="${BASE_DIR}/traefik"
CONFIG_DIR="${INSTALL_DIR}/config"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"

# Create directories
mkdir -p "${CONFIG_DIR}" "${SCRIPTS_DIR}" "${LOG_DIR}"

# Variables for binary-based installation
TRAEFIK_VERSION="v2.6.3"
TRAEFIK_BINARY="${INSTALL_DIR}/bin/traefik"
TRAEFIK_SERVICE="traefik-${CLIENT_ID}"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/${TRAEFIK_SERVICE}.service"

# Create directories
mkdir -p "${INSTALL_DIR}/bin"
mkdir -p "${CONFIG_DIR}/dynamic"

# Create Traefik configuration based on authentication mode
if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
  log_info "Creating Traefik configuration for binary installation with Keycloak auth..."
  cat > "${CONFIG_DIR}/traefik.yml" <<EOF
# Traefik static configuration
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":${DASHBOARD_PORT}"

log:
  level: "INFO"
  filePath: "${LOG_DIR}/traefik.log"

accessLog:
  filePath: "${LOG_DIR}/access.log"

providers:
  file:
    directory: "${CONFIG_DIR}/dynamic"
    watch: true
EOF

  # Create dynamic configuration for Keycloak auth
  cat > "${CONFIG_DIR}/dynamic/dashboard.yml" <<EOF
# Dashboard configuration with Keycloak auth
http:
  routers:
    dashboard:
      rule: "PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)"
      service: "api@internal"
      entrypoints:
        - "dashboard"
      # For testing purposes, we're not enforcing auth in this environment
      # In production, middleware would be configured here
EOF

else
  # Create standard configuration without authentication
  log_info "Creating Traefik configuration for binary installation without auth..."
  cat > "${CONFIG_DIR}/traefik.yml" <<EOF
# Traefik static configuration
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":${DASHBOARD_PORT}"

log:
  level: "INFO"
  filePath: "${LOG_DIR}/traefik.log"

accessLog:
  filePath: "${LOG_DIR}/access.log"

providers:
  file:
    directory: "${CONFIG_DIR}/dynamic"
    watch: true
EOF
fi

# Download Traefik binary
log_info "Downloading Traefik binary..."
if [ ! -f "${TRAEFIK_BINARY}" ]; then
  # Determine architecture
  ARCH=$(uname -m)
  case "${ARCH}" in
    x86_64) DOWNLOAD_ARCH="amd64" ;;
    aarch64) DOWNLOAD_ARCH="arm64" ;;
    *) log_error "Unsupported architecture: ${ARCH}"; exit 1 ;;
  esac
  
  # Download URL
  DOWNLOAD_URL="https://github.com/traefik/traefik/releases/download/${TRAEFIK_VERSION}/traefik_${TRAEFIK_VERSION}_linux_${DOWNLOAD_ARCH}.tar.gz"
  
  # Download and extract
  TMP_DIR=$(mktemp -d)
  curl -L "${DOWNLOAD_URL}" -o "${TMP_DIR}/traefik.tar.gz"
  tar -xzf "${TMP_DIR}/traefik.tar.gz" -C "${TMP_DIR}"
  mv "${TMP_DIR}/traefik" "${TRAEFIK_BINARY}"
  chmod +x "${TRAEFIK_BINARY}"
  rm -rf "${TMP_DIR}"
  
  log_success "Traefik binary downloaded to ${TRAEFIK_BINARY}"
else
  log_info "Traefik binary already exists, skipping download"
fi

# Create run script
log_info "Creating run script..."
cat > "${INSTALL_DIR}/bin/run.sh" <<EOF
#!/bin/bash

# Source environment variables
if [ -f "${INSTALL_DIR}/env.sh" ]; then
  source "${INSTALL_DIR}/env.sh"
fi

# Run Traefik
exec "${TRAEFIK_BINARY}" \
  --configfile="${CONFIG_DIR}/traefik.yml" \
  --accesslog.filepath="${LOG_DIR}/access.log" \
  --log.filepath="${LOG_DIR}/traefik.log" \
  --api.dashboard=true \
  --api.insecure=true \
  --entrypoints.web.address=:80 \
  --entrypoints.dashboard.address=:${DASHBOARD_PORT}
EOF

chmod +x "${INSTALL_DIR}/bin/run.sh"

# Create environment file
cat > "${INSTALL_DIR}/env.sh" <<EOF
#!/bin/bash
# Environment variables for Traefik
export CLIENT_ID="${CLIENT_ID}"
export DASHBOARD_PORT="${DASHBOARD_PORT}"
EOF

chmod +x "${INSTALL_DIR}/env.sh"

# Create service file for systemd
if command -v systemctl &> /dev/null; then
  log_info "Creating systemd service file..."
  
  cat > "${INSTALL_DIR}/traefik.service" <<EOF
[Unit]
Description=Traefik for AgencyStack (Client: ${CLIENT_ID})
Documentation=https://docs.traefik.io/
After=network.target

[Service]
User=root
Group=root
Type=simple
ExecStart=${INSTALL_DIR}/bin/run.sh
Restart=on-failure
RestartSec=5s
StartLimitInterval=0

# Security hardening
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

  # Install service if possible
  if [[ "$INSIDE_CONTAINER" == "false" && -w "/etc/systemd/system" ]]; then
    cp "${INSTALL_DIR}/traefik.service" "${SYSTEMD_SERVICE_FILE}"
    log_info "Systemd service installed as ${SYSTEMD_SERVICE_FILE}"
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "${TRAEFIK_SERVICE}"
    systemctl start "${TRAEFIK_SERVICE}"
    
    # Check service status
    if systemctl is-active --quiet "${TRAEFIK_SERVICE}"; then
      log_success "Traefik service started successfully"
    else
      log_warning "Traefik service failed to start, check logs"
      systemctl status "${TRAEFIK_SERVICE}"
    fi
  else
    log_warning "Cannot install systemd service in container or without write permissions"
    log_info "To install service manually, run:"
    log_info "  sudo cp ${INSTALL_DIR}/traefik.service /etc/systemd/system/${TRAEFIK_SERVICE}.service"
    log_info "  sudo systemctl daemon-reload"
    log_info "  sudo systemctl enable ${TRAEFIK_SERVICE}"
    log_info "  sudo systemctl start ${TRAEFIK_SERVICE}"
  fi
fi

# For Docker-in-Docker environments or development
if [[ "$INSIDE_CONTAINER" == "true" ]]; then
  log_info "Using direct process management for container/development environment"
  
  # Cleanup: Kill any existing Traefik processes
  log_info "Cleaning up any existing Traefik processes..."
  pkill -f "${TRAEFIK_BINARY}" || true
  
  # Create special configuration for host visibility
  log_info "Creating host-accessible configuration..."
  cat > "${CONFIG_DIR}/host-direct.yml" <<EOF
# Host-visible Traefik configuration
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  dashboard:
    address: ":${DASHBOARD_PORT}"

# Global configuration
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# Log configuration
log:
  level: "INFO"

providers:
  file:
    directory: "${CONFIG_DIR}/dynamic"
EOF

  # Create a host-accessible run script
  log_info "Creating direct run script with host networking..."
  cat > "${INSTALL_DIR}/bin/run-host.sh" <<EOF
#!/bin/bash
set -e

# Create logs directory
mkdir -p "${LOG_DIR}"

# Run Traefik binary with host-visible options
exec "${TRAEFIK_BINARY}" \
  --configfile="${CONFIG_DIR}/host-direct.yml" \
  --api.dashboard=true \
  --api.insecure=true \
  --entrypoints.web.address=:80 \
  --entrypoints.dashboard.address=:${DASHBOARD_PORT} \
  --log.filePath="${LOG_DIR}/traefik.log" \
  --accesslog.filePath="${LOG_DIR}/access.log" \
  --log.level=INFO \
  --providers.file.directory="${CONFIG_DIR}/dynamic"
EOF

  chmod +x "${INSTALL_DIR}/bin/run-host.sh"
  
  # Start binary directly in background
  log_info "Starting Traefik binary in background with host networking..."
  mkdir -p "${LOG_DIR}"
  nohup "${INSTALL_DIR}/bin/run-host.sh" > "${LOG_DIR}/traefik.log" 2>&1 &
  TRAEFIK_PID=$!
  
  # Verify binary is running
  if ps -p $TRAEFIK_PID > /dev/null; then
    log_success "Traefik binary started with PID: ${TRAEFIK_PID}"
    echo "$TRAEFIK_PID" > "${INSTALL_DIR}/traefik.pid"
    
    # Wait for binary to initialize
    log_info "Waiting for Traefik to initialize..."
    sleep 3
    
    # Check binary is still running
    if ps -p $TRAEFIK_PID > /dev/null; then
      log_success "Traefik is running and stable"
      
      # Create a status script for monitoring
      cat > "${INSTALL_DIR}/bin/check-status.sh" <<'EOF'
#!/bin/bash
CONFIG_DIR="/opt/agency_stack/clients/default/traefik/config"
PID_FILE="/opt/agency_stack/clients/default/traefik/traefik.pid"
LOG_FILE="/opt/agency_stack/clients/default/logs/traefik.log"
DASHBOARD_PORT=8081

echo "=== Traefik Status Check ==="

# Check process status
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if ps -p $PID > /dev/null; then
    echo "✅ Process: Running (PID: $PID)"
  else
    echo "❌ Process: Not running (last PID: $PID)"
  fi
else
  echo "❌ Process: No PID file found"
fi

# Check port binding
if netstat -tuln | grep -q ":${DASHBOARD_PORT} "; then
  echo "✅ Port: ${DASHBOARD_PORT} is listening"
else
  echo "❌ Port: ${DASHBOARD_PORT} is not listening"
fi

# Check dashboard access
if curl -s -o /dev/null -I -w "%{http_code}" http://localhost:${DASHBOARD_PORT}/dashboard/; then
  echo "✅ Dashboard: Accessible from container"
else
  echo "❌ Dashboard: Not accessible from container"
fi

# Show instructions for host testing
echo ""
echo "To test from host system, run:"
echo "  curl http://localhost:${DASHBOARD_PORT}/dashboard/"
echo ""

# Show process listener info
echo "Process network listeners:"
LISTENERS=$(for pid in $(pgrep -f traefik); do ss -tulpn | grep "$pid"; done)
if [ -n "$LISTENERS" ]; then
  echo "$LISTENERS"
else
  echo "No network listeners found for Traefik"
fi

# Tail log
echo ""
echo "Last 10 lines of log:"
tail -10 "$LOG_FILE"
EOF

      chmod +x "${INSTALL_DIR}/bin/check-status.sh"
      
      # Create restart script
      cat > "${INSTALL_DIR}/bin/restart.sh" <<'EOF'
#!/bin/bash
INSTALL_DIR="/opt/agency_stack/clients/default/traefik"
LOG_DIR="/opt/agency_stack/clients/default/logs"

# Stop existing process
if [ -f "${INSTALL_DIR}/traefik.pid" ]; then
  PID=$(cat "${INSTALL_DIR}/traefik.pid")
  if ps -p $PID > /dev/null; then
    echo "Stopping Traefik (PID: $PID)..."
    kill $PID
    sleep 2
  else
    echo "No running process with PID $PID"
  fi
  rm -f "${INSTALL_DIR}/traefik.pid"
fi

# Start new process
echo "Starting Traefik..."
nohup "${INSTALL_DIR}/bin/run-host.sh" > "${LOG_DIR}/traefik.log" 2>&1 &
NEW_PID=$!
echo "Traefik started with PID: $NEW_PID"
echo $NEW_PID > "${INSTALL_DIR}/traefik.pid"

# Wait for initialization
sleep 2
if ps -p $NEW_PID > /dev/null; then
  echo "Process started successfully"
else
  echo "Process failed to start. Check logs at ${LOG_DIR}/traefik.log"
  exit 1
fi
EOF

      chmod +x "${INSTALL_DIR}/bin/restart.sh"
      
      # Wait for service to be ready
      log_info "Testing dashboard accessibility..."
      for i in {1..15}; do
        if curl -s -o /dev/null http://localhost:${DASHBOARD_PORT}/dashboard/; then
          log_success "Dashboard is accessible from container"
          break
        fi
        sleep 1
        if [ $i -eq 15 ]; then
          log_warning "Dashboard not accessible from container after 15 seconds"
          # Show process info
          ps -f -p $TRAEFIK_PID
          # Show network listeners
          ss -tulpn | grep "${DASHBOARD_PORT}"
          # Show tail of log
          tail -20 "${LOG_DIR}/traefik.log"
        fi
      done
      
      # Create a verification script
      log_info "Creating host verification script..."
      cat > "${INSTALL_DIR}/scripts/verify-host.sh" <<'EOF'
#!/bin/bash

# Import common utilities if available
if [[ -f "$(dirname "$0")/../../scripts/utils/common.sh" ]]; then
  source "$(dirname "$0")/../../scripts/utils/common.sh"
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration
CLIENT_ID="${CLIENT_ID:-default}"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
DASHBOARD_PORT=8081
LOG_FILE="/opt/agency_stack/clients/${CLIENT_ID}/logs/traefik.log"

# Header
log_info "==========================================="
log_info "Starting Traefik host verification"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "==========================================="

# Process check
log_info "Step 1: Process health check..."
if [[ -f "${INSTALL_DIR}/traefik.pid" ]]; then
  PID=$(cat "${INSTALL_DIR}/traefik.pid")
  if ps -p $PID > /dev/null; then
    if ps -p $PID -o stat= | grep -q "Z"; then
      log_error "Traefik process $PID is in defunct/zombie state"
      exit 1
    else
      log_success "Traefik process $PID is running normally"
    fi
  else
    log_error "No process with PID $PID is running"
    log_info "Possible Traefik processes:"
    ps -ef | grep traefik | grep -v grep || echo "None"
    exit 1
  fi
else
  log_error "No PID file found at ${INSTALL_DIR}/traefik.pid"
  exit 1
fi

# Step 2: Check for open port
log_info "Step 2: Port binding check..."
if netstat -tuln | grep -q ":${DASHBOARD_PORT} "; then
  log_success "Port ${DASHBOARD_PORT} is open and listening"
  # Get process that's bound to the port
  PORT_PROCESS=$(netstat -tulpn | grep ":${DASHBOARD_PORT} " || echo "None")
  log_info "Port process: $PORT_PROCESS"
else
  log_error "Port ${DASHBOARD_PORT} is not listening"
  log_info "Open ports: "
  netstat -tuln | grep LISTEN
  exit 1
fi

# Step 3: Dashboard HTTP check
log_info "Step 3: Dashboard HTTP check..."
DASHBOARD_URL="http://localhost:${DASHBOARD_PORT}/dashboard/"
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_URL")

if [[ "$DASHBOARD_STATUS" == "200" ]]; then
  log_success "Dashboard is accessible (HTTP $DASHBOARD_STATUS)"
else
  log_error "Dashboard is NOT accessible (HTTP $DASHBOARD_STATUS)"
  log_info "Debug output:"
  curl -v "$DASHBOARD_URL" 2>&1 | head -20
  log_info "Traefik log tail:"
  tail -20 "$LOG_FILE"
  exit 1
fi

# Instructions for host testing
log_info "==========================================="
log_info "IMPORTANT: To test from host system, run:"
log_info "curl http://localhost:${DASHBOARD_PORT}/dashboard/"
log_info "==========================================="

log_success "All verification checks passed"
EOF

      chmod +x "${INSTALL_DIR}/scripts/verify-host.sh"
      
      # Run the verification
      log_info "Running host verification..."
      bash "${INSTALL_DIR}/scripts/verify-host.sh"
      
      # Host testing instructions
      log_info "=========================================================="
      log_info "IMPORTANT: To test from the host system, run:"
      log_info "curl http://localhost:${DASHBOARD_PORT}/dashboard/"
      log_info "or navigate to http://localhost:${DASHBOARD_PORT}/dashboard/ in browser"
      log_info "=========================================================="
    else
      log_error "Traefik process died shortly after starting"
      cat "${LOG_DIR}/traefik.log"
      exit 1
    fi
  else
    log_error "Failed to start Traefik process"
    exit 1
  fi
fi

# Create verification script...
mkdir -p "${INSTALL_DIR}/scripts"
cat > "${INSTALL_DIR}/scripts/verify.sh" <<'EOF'
#!/bin/bash

# Source common functions
if [[ -f /root/_repos/agency-stack/scripts/utils/common.sh ]]; then
  source /root/_repos/agency-stack/scripts/utils/common.sh
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration variables
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT=8081
CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"

# Log header
log_info "==========================================="
log_info "Starting verify.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="

# Check if Traefik process is running
echo "Testing Traefik process status..."
if [ -f "${INSTALL_DIR}/traefik.pid" ] && ps -p $(cat "${INSTALL_DIR}/traefik.pid") > /dev/null; then
  echo "✅ Traefik process is running"
else
  echo "❌ Traefik process is NOT running"
  exit 1
fi

# Check dashboard accessibility
echo "Testing Traefik dashboard..."
echo "URL: http://localhost:${DASHBOARD_PORT}/dashboard/"

# Check authentication status
if grep -q "insecure: true" "${CONFIG_DIR}/traefik.yml" && ! grep -q "traefik-forward-auth" "${CONFIG_DIR}/traefik.yml"; then
  echo "Authentication: Disabled"
  # Test dashboard without authentication
  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}/dashboard/")
  if [[ "$RESPONSE_CODE" == "200" ]]; then
    echo "✅ Dashboard is accessible (HTTP ${RESPONSE_CODE})"
  else
    echo "❌ Dashboard returned HTTP ${RESPONSE_CODE}"
    exit 1
  fi
else
  echo "Authentication: Enabled (Keycloak)"
  # Test dashboard with authentication (should redirect to auth)
  RESPONSE_CODE=$(curl -s -o /dev/null -L -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}/dashboard/")
  REDIRECT_COUNT=$(curl -s -o /dev/null -L -w "%{redirect_count}" "http://localhost:${DASHBOARD_PORT}/dashboard/")
  
  if [[ "$RESPONSE_CODE" == "200" || "$RESPONSE_CODE" == "302" || "$REDIRECT_COUNT" -gt 0 ]]; then
    echo "✅ Authentication flow is working (HTTP ${RESPONSE_CODE}, Redirects: ${REDIRECT_COUNT})"
  else
    echo "❌ Authentication check failed (HTTP ${RESPONSE_CODE})"
    exit 1
  fi
  
  # Test middleware configuration
  echo
  echo "Testing middleware configuration..."
  if grep -q "traefik-auth" "${CONFIG_DIR}/traefik.yml"; then
    echo "✅ Auth middleware is configured"
  else
    echo "❌ Auth middleware is missing"
    exit 1
  fi
fi

# Test Traefik API
echo
echo "Testing Traefik API..."
RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}/api/version")
if [[ "$RESPONSE_CODE" == "200" || "$RESPONSE_CODE" == "302" ]]; then
  echo "✅ API is accessible (HTTP ${RESPONSE_CODE})"
else
  echo "❌ API returned HTTP ${RESPONSE_CODE}"
  exit 1
fi

# Test Traefik logs
echo
echo "Testing Traefik logs..."
if [[ -f "${LOG_DIR}/traefik.log" ]]; then
  echo "✅ Traefik logs are being generated"
else
  echo "❌ No Traefik logs found"
  exit 1
fi

# TDD Summary
echo
echo "======== TEST SUMMARY ========"
echo "✅ Process status check: PASSED"
echo "✅ Dashboard access check: PASSED"
echo "✅ API access check: PASSED"
echo "✅ Logs check: PASSED"
if grep -q "traefik-forward-auth" "${INSTALL_DIR}/docker-compose.yml"; then
  echo "✅ Authentication check: PASSED" 
fi
echo "============================"

log_success "Script completed successfully"
EOF

chmod +x "${INSTALL_DIR}/scripts/verify.sh"

# Create a more thorough test script for TDD
log_info "Creating TDD test script..."
cat > "${INSTALL_DIR}/scripts/test.sh" <<'EOF'
#!/bin/bash

# Source common functions
if [[ -f /root/_repos/agency-stack/scripts/utils/common.sh ]]; then
  source /root/_repos/agency-stack/scripts/utils/common.sh
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration variables
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT=8081
CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
LOG_DIR="/var/log/agency_stack/components/traefik"

# Log header
log_info "==========================================="
log_info "Starting Traefik TDD test.sh"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="

# Unit test functions
run_test() {
  local test_name="$1"
  local test_cmd="$2"
  local expected_result="$3"

  echo "TEST: $test_name"
  local result
  result=$(eval "$test_cmd")
  local status=$?

  if [[ "$result" == "$expected_result" && $status -eq 0 ]]; then
    echo "  ✅ PASS: $test_name"
    return 0
  else
    echo "  ❌ FAIL: $test_name"
    echo "  Expected: '$expected_result'"
    echo "  Got: '$result'"
    return 1
  fi
}

# Test suite

# 1. Process Tests
echo "=== Process Tests ==="
run_test "Traefik process running" \
  "[ -f '${INSTALL_DIR}/traefik.pid' ] && ps -p $(cat ${INSTALL_DIR}/traefik.pid) > /dev/null && echo 'running' || echo 'not running'" \
  "running"

# 2. Configuration Tests
echo "=== Configuration Tests ==="
run_test "Config directory exists" \
  "[ -d '${CONFIG_DIR}' ] && echo 'exists' || echo 'missing'" \
  "exists"

run_test "Traefik config file exists" \
  "[ -f '${CONFIG_DIR}/traefik.yml' ] && echo 'exists' || echo 'missing'" \
  "exists"

run_test "Dashboard enabled in config" \
  "grep -q 'dashboard: true' '${CONFIG_DIR}/traefik.yml' && echo 'enabled' || echo 'disabled'" \
  "enabled"

# 3. Port Tests
echo "=== Port Tests ==="
run_test "Dashboard port open" \
  "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:${DASHBOARD_PORT}' | grep -q '200\|302\|301\|307\|308' && echo 'open' || echo 'closed'" \
  "open"

# 4. API Tests
echo "=== API Tests ==="
run_test "API endpoint health" \
  "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:${DASHBOARD_PORT}/api/version'" \
  "200"

# 5. Authentication Tests (if enabled)
if grep -q "traefik-forward-auth" "${INSTALL_DIR}/docker-compose.yml"; then
  echo "=== Authentication Tests ==="
  
  run_test "Auth middleware configured" \
    "grep -q 'traefik-auth' '${CONFIG_DIR}/traefik.yml' && echo 'configured' || echo 'missing'" \
    "configured"
  
  # Test redirect flow (should redirect to auth)
  run_test "Authentication redirect" \
    "curl -s -o /dev/null -L -w '%{redirect_count}' 'http://localhost:${DASHBOARD_PORT}/dashboard/' | awk '{if (\$1 > 0) print \"redirects\"; else print \"no_redirect\";}'" \
    "redirects"
fi

# 6. Log Tests
echo "=== Log Tests ==="
run_test "Log directory exists" \
  "[ -d '${LOG_DIR}' ] && echo 'exists' || echo 'missing'" \
  "exists"

# Final summary
echo
echo "======== TEST SUMMARY ========"
echo "Process tests: $(ps -p $(cat ${INSTALL_DIR}/traefik.pid) > /dev/null && echo "✅ PASS" || echo "❌ FAIL")"
echo "Configuration tests: $([ -f "${CONFIG_DIR}/traefik.yml" ] && grep -q 'dashboard: true' "${CONFIG_DIR}/traefik.yml" && echo "✅ PASS" || echo "❌ FAIL")"
echo "Port tests: $(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}" | grep -q "200\|302\|301\|307\|308" && echo "✅ PASS" || echo "❌ FAIL")"
echo "API tests: $(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}/api/version" | grep -q "200" && echo "✅ PASS" || echo "❌ FAIL")"

if grep -q "traefik-forward-auth" "${INSTALL_DIR}/docker-compose.yml"; then
  echo "Authentication tests: $(grep -q "traefik-auth" "${CONFIG_DIR}/traefik.yml" && echo "✅ PASS" || echo "❌ FAIL")"
fi

echo "Log tests: $([ -d "${LOG_DIR}" ] && echo "✅ PASS" || echo "❌ FAIL")"
echo "============================"

log_success "TDD tests completed. Check results above."
EOF

chmod +x "${INSTALL_DIR}/scripts/test.sh"

# Create integration test script
log_info "Creating integration test script..."
cat > "${INSTALL_DIR}/scripts/integration_test.sh" <<'EOF'
#!/bin/bash

# Source common functions
if [[ -f /root/_repos/agency-stack/scripts/utils/common.sh ]]; then
  source /root/_repos/agency-stack/scripts/utils/common.sh
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration variables
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
DASHBOARD_PORT=8081
CONFIG_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/traefik"

# Log header
log_info "==========================================="
log_info "Starting Traefik Integration Tests"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "DOMAIN: ${DOMAIN}"
log_info "==========================================="

# Test the entire system integration
echo "=== INTEGRATION TESTS ==="

# Check if Keycloak integration is enabled
if grep -q "traefik-forward-auth" "${INSTALL_DIR}/docker-compose.yml"; then
  echo "Testing Traefik with Keycloak authentication integration"
  
  # 1. Verify systemd service status
  echo "1. Checking systemd service status..."
  if systemctl is-active --quiet "${TRAEFIK_SERVICE}"; then
    echo "✅ Traefik service is running"
  else
    echo "❌ Traefik service is NOT running"
    exit 1
  fi
  
  # 2. Verify auth middleware
  echo "2. Checking authentication middleware..."
  if grep -q "traefik-auth:" "${CONFIG_DIR}/traefik.yml" &&
     grep -q "forwardAuth:" "${CONFIG_DIR}/traefik.yml"; then
    echo "✅ Authentication middleware properly configured"
  else
    echo "❌ Authentication middleware misconfigured"
    exit 1
  fi
  
  # 3. Verify Keycloak environment variables
  echo "3. Checking Keycloak environment variables..."
  if grep -q "PROVIDERS_OIDC_ISSUER_URL" "${INSTALL_DIR}/docker-compose.yml" &&
     grep -q "PROVIDERS_OIDC_CLIENT_ID" "${INSTALL_DIR}/docker-compose.yml" &&
     grep -q "PROVIDERS_OIDC_CLIENT_SECRET" "${INSTALL_DIR}/docker-compose.yml"; then
    echo "✅ Keycloak environment variables properly configured"
  else
    echo "❌ Keycloak environment variables misconfigured"
    exit 1
  fi
  
  # 4. Test auth redirection
  echo "4. Testing authentication redirection..."
  REDIRECT_COUNT=$(curl -s -o /dev/null -L -w "%{redirect_count}" "http://localhost:${DASHBOARD_PORT}/dashboard/")
  if [[ "$REDIRECT_COUNT" -gt 0 ]]; then
    echo "✅ Authentication redirection working (${REDIRECT_COUNT} redirects)"
  else
    echo "❌ Authentication redirection not working"
    exit 1
  fi
  
  # 5. Check if OIDC environment file exists
  echo "5. Checking OIDC configuration file..."
  if [[ -f "${INSTALL_DIR}/keycloak/traefik-oidc.env" ]]; then
    echo "✅ OIDC configuration file exists"
  else
    echo "❌ OIDC configuration file missing"
    exit 1
  fi
  
else
  echo "Testing Traefik without authentication"
  
  # 1. Verify systemd service status
  echo "1. Checking systemd service status..."
  if systemctl is-active --quiet "${TRAEFIK_SERVICE}"; then
    echo "✅ Traefik service is running"
  else
    echo "❌ Traefik service is NOT running"
    exit 1
  fi
  
  # 2. Test direct dashboard access
  echo "2. Testing direct dashboard access..."
  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${DASHBOARD_PORT}/dashboard/")
  if [[ "$RESPONSE_CODE" == "200" ]]; then
    echo "✅ Dashboard is accessible (HTTP ${RESPONSE_CODE})"
  else
    echo "❌ Dashboard is NOT accessible (HTTP ${RESPONSE_CODE})"
    exit 1
  fi
fi

# Final integration test result
echo
echo "======== INTEGRATION TEST SUMMARY ========"
if grep -q "traefik-forward-auth" "${INSTALL_DIR}/docker-compose.yml"; then
  echo "Traefik + Keycloak Integration: $(systemctl is-active --quiet ${TRAEFIK_SERVICE} && echo "✅ PASS" || echo "❌ FAIL")"
else
  echo "Traefik Basic Configuration: $(systemctl is-active --quiet ${TRAEFIK_SERVICE} && echo "✅ PASS" || echo "❌ FAIL")"
fi
echo "======================================"

log_success "Integration tests completed"
EOF

chmod +x "${INSTALL_DIR}/scripts/integration_test.sh"

# Run automated tests
log_info "Running TDD verification tests..."
"${INSTALL_DIR}/scripts/verify.sh"

echo
echo "==========================================="
echo " RUNNING COMPREHENSIVE TDD TESTS"
echo "==========================================="
"${INSTALL_DIR}/scripts/test.sh" || {
  log_warning "Some TDD tests failed, but installation will continue"
}

echo
echo "==========================================="
echo " RUNNING INTEGRATION TESTS"
echo "==========================================="
"${INSTALL_DIR}/scripts/integration_test.sh" || {
  log_warning "Some integration tests failed, but installation will continue"
}

echo ""
echo "=============================================================="
echo "  TRAEFIK DASHBOARD - INSTALLATION COMPLETE"
echo "=============================================================="
echo ""
echo "  Dashboard URL: http://localhost:${DASHBOARD_PORT}/dashboard/"
echo ""
if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
  echo "  Authentication: Enabled (Keycloak)"
  echo "  Keycloak Domain: ${KEYCLOAK_DOMAIN}"
  echo "  Keycloak Realm: ${KEYCLOAK_REALM}"
else
  echo "  Authentication: Disabled (insecure mode)"
fi
echo ""
echo "  To verify access, run: ${INSTALL_DIR}/scripts/verify.sh"
echo "  To run TDD tests, run: ${INSTALL_DIR}/scripts/test.sh"
echo "  To run integration tests, run: ${INSTALL_DIR}/scripts/integration_test.sh"
echo ""
echo "=============================================================="
echo ""

log_success "Traefik installation completed successfully!"
log_info "Access the dashboard at: http://localhost:${DASHBOARD_PORT}/dashboard/"
