#!/bin/bash

# Import common utilities if available
if [[ -f $(dirname "$0")/common.sh ]]; then
  source $(dirname "$0")/common.sh
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

# Header
log_info "============================================="
log_info "Starting Traefik strict verification"
log_info "CLIENT_ID: ${CLIENT_ID}"
log_info "============================================="

# Step 1: Verify process health
log_info "Step 1: Process health check..."
if [[ -f "${INSTALL_DIR}/traefik.pid" ]]; then
  PID=$(cat "${INSTALL_DIR}/traefik.pid")
  if ps -p $PID > /dev/null; then
    # Check if it's a zombie process
    if ps -p $PID -o stat= | grep -q "Z"; then
      log_error "Traefik process $PID is in defunct/zombie state"
      exit 1
    else
      log_success "Traefik process $PID is running"
    fi
  else
    log_error "No process with PID $PID is running"
    # Check for any Traefik processes that might be running
    TRAEFIK_PROCESSES=$(ps -ef | grep traefik | grep -v grep || echo "None")
    log_info "Other Traefik processes: $TRAEFIK_PROCESSES"
    exit 1
  fi
else
  log_error "No PID file found at ${INSTALL_DIR}/traefik.pid"
  # Check for any Traefik processes that might be running
  TRAEFIK_PROCESSES=$(ps -ef | grep traefik | grep -v grep || echo "None")
  log_info "Traefik processes found: $TRAEFIK_PROCESSES"
  exit 1
fi

# Step 2: Check for open port
log_info "Step 2: Port binding check..."
if netstat -tuln | grep -q ":${DASHBOARD_PORT} "; then
  log_success "Port ${DASHBOARD_PORT} is open and listening"
else
  log_error "Port ${DASHBOARD_PORT} is not listening"
  # Show all open ports for debugging
  log_info "Open ports: $(netstat -tuln | head -5)"
  exit 1
fi

# Step 3: Dashboard HTTP check
log_info "Step 3: Dashboard HTTP check..."
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${DASHBOARD_PORT}/dashboard/)
if [[ "$DASHBOARD_STATUS" == "200" ]]; then
  log_success "Dashboard HTTP status: $DASHBOARD_STATUS"
else
  log_error "Dashboard HTTP status: $DASHBOARD_STATUS (expected 200)"
  log_info "Debug output:"
  curl -v http://localhost:${DASHBOARD_PORT}/dashboard/ 2>&1 | head -20
  exit 1
fi

# Step 4: API HTTP check
log_info "Step 4: API HTTP check..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${DASHBOARD_PORT}/api/version)
if [[ "$API_STATUS" == "200" ]]; then
  log_success "API HTTP status: $API_STATUS"
else
  log_error "API HTTP status: $API_STATUS (expected 200)"
  exit 1
fi

# Step 5: API content check (deeper verification)
log_info "Step 5: API content check..."
VERSION_INFO=$(curl -s http://localhost:${DASHBOARD_PORT}/api/version)
if [[ "$VERSION_INFO" == *"Version"* ]]; then
  log_success "API returned valid version info"
  log_info "Version info: $VERSION_INFO"
else
  log_error "API did not return expected version info"
  log_info "Debug output: $VERSION_INFO"
  exit 1
fi

log_info "============================================="
log_success "ALL CHECKS PASSED: Traefik is functioning correctly"
log_info "============================================="
