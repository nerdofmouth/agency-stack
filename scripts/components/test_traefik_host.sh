#!/bin/bash

# Source common utilities if available
if [ -f "$(dirname "$0")/../utils/common.sh" ]; then
  source "$(dirname "$0")/../utils/common.sh"
else
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-agencystack-dev}"
CONTAINER_IP=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_NAME)
TRAEFIK_PORT="${TRAEFIK_PORT:-8081}"
DASHBOARD_URL="http://${CONTAINER_IP}:${TRAEFIK_PORT}/dashboard/"

# Header
log_info "==========================================="
log_info "Testing Traefik from HOST to CONTAINER"
log_info "Container: $CONTAINER_NAME"
log_info "Container IP: $CONTAINER_IP"
log_info "==========================================="

# Network connectivity check
log_info "Testing network connectivity to container..."
if ping -c 1 -W 1 $CONTAINER_IP > /dev/null; then
  log_success "Network connectivity to container IP $CONTAINER_IP is working"
else
  log_error "Cannot ping container IP $CONTAINER_IP"
  log_info "This might be due to ICMP being blocked, proceeding with HTTP test..."
fi

# Dashboard HTTP check
log_info "Testing Traefik dashboard via container IP..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_URL")

if [[ "$HTTP_CODE" == "200" ]]; then
  log_success "Traefik dashboard is accessible from host (HTTP $HTTP_CODE)"
  log_info "Dashboard URL: $DASHBOARD_URL"
  
  # Fetch and display Traefik version from API
  VERSION_JSON=$(curl -s "http://${CONTAINER_IP}:${TRAEFIK_PORT}/api/version")
  if [[ -n "$VERSION_JSON" ]]; then
    log_info "Traefik version info: $VERSION_JSON"
  fi
  
  # Test solution instructions
  log_info "==========================================="
  log_info "✅ SOLUTION: To access Traefik dashboard from your host browser:"
  log_info "1. Add this entry to your host machine's /etc/hosts file:"
  log_info "   $CONTAINER_IP traefik.local"
  log_info "2. Then open: http://traefik.local:${TRAEFIK_PORT}/dashboard/"
  log_info "==========================================="
  
  # Additional port exposure option
  log_info "ALTERNATIVE: Restart container with port mapping:"
  log_info "docker rm -f $CONTAINER_NAME"
  log_info "docker run ... -p ${TRAEFIK_PORT}:${TRAEFIK_PORT} ... (with your other options)"
  log_info "==========================================="
  
  exit 0
else
  log_error "Traefik dashboard is NOT accessible from host (HTTP $HTTP_CODE)"
  log_info "Debugging information:"
  log_info "- Container IP: $CONTAINER_IP"
  log_info "- Attempted URL: $DASHBOARD_URL"
  
  # Check if Traefik is running in container
  TRAEFIK_PROCESS=$(docker exec -it $CONTAINER_NAME ps -ef | grep traefik | grep -v grep || echo "None")
  log_info "Traefik processes in container:"
  log_info "$TRAEFIK_PROCESS"
  
  # Check port binding in container
  PORT_BINDING=$(docker exec -it $CONTAINER_NAME netstat -tuln | grep ${TRAEFIK_PORT} || echo "None")
  log_info "Port binding in container:"
  log_info "$PORT_BINDING"
  
  exit 1
fi
