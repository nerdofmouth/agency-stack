#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: traefik_port_proxy.sh
# Path: /scripts/components/traefik_port_proxy.sh
#

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-agencystack-dev}"
TRAEFIK_PORT="${TRAEFIK_PORT:-8081}"
HOST_PORT="${HOST_PORT:-18081}"
TRAEFIK_PID_FILE="/tmp/traefik_proxy.pid"

# Header
log_info "==========================================="
log_info "Traefik Port Proxy (Host to Container)"
log_info "Container: $CONTAINER_NAME"
log_info "Mapping host:$HOST_PORT -> container:$TRAEFIK_PORT"
log_info "==========================================="

# Check if socat is installed
if ! command -v socat &> /dev/null; then
  log_error "socat is not installed. Please install it with: apt-get install socat"
  exit 1

# Get container IP
CONTAINER_IP=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_NAME 2>/dev/null)
if [[ -z "$CONTAINER_IP" || "$CONTAINER_IP" == "<no value>" ]]; then
  log_error "Could not determine container IP for $CONTAINER_NAME"
  log_info "Container status:"
  docker ps -a | grep $CONTAINER_NAME || echo "Container not found"
  exit 1

log_info "Container IP: $CONTAINER_IP"

# Check for existing proxy process
if [[ -f "$TRAEFIK_PID_FILE" ]]; then
  OLD_PID=$(cat "$TRAEFIK_PID_FILE")
  if ps -p $OLD_PID > /dev/null; then
    log_info "Stopping existing proxy (PID: $OLD_PID)..."
    kill $OLD_PID
    sleep 1
  else
    log_info "Found stale PID file, cleaning up..."
  fi
  rm -f "$TRAEFIK_PID_FILE"

# Start socat as a proxy
log_info "Starting proxy from host:$HOST_PORT to container:$TRAEFIK_PORT..."
socat TCP-LISTEN:$HOST_PORT,fork TCP:$CONTAINER_IP:$TRAEFIK_PORT &
PROXY_PID=$!

# Check if proxy started successfully
if ps -p $PROXY_PID > /dev/null; then
  log_success "Proxy started with PID: $PROXY_PID"
  echo $PROXY_PID > "$TRAEFIK_PID_FILE"
  
  # Test the proxy
  log_info "Testing proxy..."
  sleep 1
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HOST_PORT/dashboard/" || echo "Failed")
  
  if [[ "$HTTP_CODE" == "200" ]]; then
    log_success "Proxy is working correctly (HTTP $HTTP_CODE)"
    log_info "==========================================="
    log_info "✅ Access Traefik dashboard at: http://localhost:$HOST_PORT/dashboard/"
    log_info "==========================================="
    
    # Run this as a keep-alive process
    log_info "Proxy will continue running in background (PID: $PROXY_PID)"
    log_info "To stop, run: kill $(cat $TRAEFIK_PID_FILE)"
    
    # Create quick browser view instructions
    cat > "/tmp/traefik_browser_access.txt" <<EOF
Access Traefik dashboard in your browser:

http://localhost:$HOST_PORT/dashboard/

The port proxy is running with PID $PROXY_PID.
To stop it: kill $PROXY_PID
EOF

    log_success "Browser access instructions saved to: /tmp/traefik_browser_access.txt"
    cat "/tmp/traefik_browser_access.txt"
    exit 0
  else
    log_error "Proxy test failed (HTTP $HTTP_CODE)"
    log_info "Debugging information:"
    log_info "- Container IP: $CONTAINER_IP"
    log_info "- Container status:"
    docker inspect $CONTAINER_NAME --format '{{.State.Status}}'
    
    # Check if Traefik is running in container
    log_info "Traefik status in container:"
    docker exec -it $CONTAINER_NAME bash -c "ps -ef | grep traefik | grep -v grep" || echo "Failed to check"
    
    kill $PROXY_PID
    rm -f "$TRAEFIK_PID_FILE"
    exit 1
  fi
  log_error "Failed to start proxy process"
  exit 1
