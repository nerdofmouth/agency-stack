#!/bin/bash

# PeaceFestivalUSA Windows Browser Access Fix
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - WSL2/Docker Mount Safety
# - Proper Change Workflow

set -e

# Get script directory and setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CLIENT_ID="peacefestivalusa"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}"
TRAEFIK_DIR="${INSTALL_DIR}/traefik"

# Source common utilities
if [[ -f "${COMPONENTS_DIR}/utils/common.sh" ]]; then
  source "${COMPONENTS_DIR}/utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  echo "Looking in: ${COMPONENTS_DIR}/utils/common.sh"
  # Fallback simple logging
  log_info() { echo "[INFO] $1"; }
  log_warning() { echo "[WARNING] $1"; }
  log_error() { echo "[ERROR] $1"; }
fi

log_info "Starting Windows browser access fix for ${CLIENT_ID}"

# Check if running in WSL
if [[ -f /proc/version ]] && grep -q -E "Microsoft|WSL" /proc/version; then
  log_info "Detected WSL environment"
  
  # Get Windows host IP
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  log_info "Windows Host IP: ${WINDOWS_HOST_IP}"
else
  log_warning "Not running in WSL, but continuing anyway for testing"
  WINDOWS_HOST_IP="127.0.0.1" # Fallback for non-WSL
fi

# Update Traefik configuration for Windows host browser access
log_info "Updating Traefik configuration for Windows host browser access"

# 1. Update Traefik static configuration
log_info "Updating Traefik static configuration"
cat > "${TRAEFIK_DIR}/config/traefik.yml" << EOL
# Traefik static configuration for PeaceFestivalUSA - Windows Browser Access Fix
# Following AgencyStack Charter v1.0.3 Principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

# API and Dashboard with proper access for Windows browser
api:
  dashboard: true
  insecure: true  # For development environment only

# Explicitly bind to all interfaces to allow Windows host access
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "${CLIENT_ID}_traefik_network"
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

# Enable debug logging temporarily
log:
  level: "DEBUG"
  filePath: "/var/log/traefik/traefik.log"

accessLog:
  filePath: "/var/log/traefik/access.log"
EOL

# 2. Update Traefik docker-compose.yml
log_info "Updating Traefik docker-compose.yml"
cat > "${TRAEFIK_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  traefik:
    container_name: ${CLIENT_ID}_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
      - "8080:8080"  # Expose dashboard port directly for easy access
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/dynamic:ro
      - ${TRAEFIK_DIR}/logs:/var/log/traefik
    networks:
      - traefik_network
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"  # For development only
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--log.level=DEBUG"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`traefik.${CLIENT_ID}.localhost\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.services.dashboard.loadbalancer.server.port=8080"

networks:
  traefik_network:
    name: ${CLIENT_ID}_traefik_network
    external: true
EOL

# 3. Update hosts file for proper resolution
log_info "Updating hosts file entries"

# Add hosts entries if they don't exist
if ! grep -q "${CLIENT_ID}.localhost" /etc/hosts; then
  log_info "Adding ${CLIENT_ID}.localhost to /etc/hosts"
  echo "127.0.0.1 ${CLIENT_ID}.localhost traefik.${CLIENT_ID}.localhost" | sudo tee -a /etc/hosts > /dev/null
else
  log_info "Host entries already exist in /etc/hosts"
fi

# 4. Create Windows hosts file helper
log_info "Creating Windows hosts file helper"
cat > "${INSTALL_DIR}/add_windows_hosts.bat" << EOL
@echo off
:: PeaceFestivalUSA Windows Hosts File Setup
:: Following AgencyStack Charter v1.0.3 Principles

echo Adding host entries to Windows hosts file...
echo This requires Administrator privileges
echo.

:: Add host entries
echo 127.0.0.1 ${CLIENT_ID}.localhost >> %windir%\\System32\\drivers\\etc\\hosts
echo 127.0.0.1 traefik.${CLIENT_ID}.localhost >> %windir%\\System32\\drivers\\etc\\hosts

echo.
echo Done! You can now access:
echo   - WordPress: http://${CLIENT_ID}.localhost
echo   - Traefik Dashboard: http://traefik.${CLIENT_ID}.localhost
echo.
pause
EOL

# 5. Update WordPress docker-compose.yml for better Windows host compatibility
log_info "Updating WordPress docker-compose.yml"

# Restart Traefik first
log_info "Restarting Traefik with Windows host browser access configuration"
cd "${TRAEFIK_DIR}" && docker-compose down && docker-compose up -d

# Wait for Traefik to be ready
log_info "Waiting for Traefik to be ready..."
sleep 5

# Test access
log_info "Testing Windows host browser access..."
curl -v http://${WINDOWS_HOST_IP}:80

# Create a Windows browser access guide
log_info "Creating Windows browser access guide"
cat > "${INSTALL_DIR}/windows_browser_access.md" << EOL
# Windows Browser Access Guide for PeaceFestivalUSA

## Overview

This guide explains how to access the PeaceFestivalUSA WordPress site from your Windows host browser when running in WSL2.

## Quick Setup

1. **Run the Windows Hosts File Setup**
   - Open Command Prompt as Administrator
   - Run \`add_windows_hosts.bat\` which can be found at:
     \`\\\\wsl\$\\Ubuntu\\opt\\agency_stack\\clients\\${CLIENT_ID}\\add_windows_hosts.bat\`

2. **Access in Browser**
   - WordPress: [http://${CLIENT_ID}.localhost](http://${CLIENT_ID}.localhost)
   - Traefik Dashboard: [http://traefik.${CLIENT_ID}.localhost](http://traefik.${CLIENT_ID}.localhost)

## Manual Setup

If the quick setup doesn't work, follow these manual steps:

1. **Edit Windows Hosts File**
   - Open Notepad as Administrator
   - Open \`C:\\Windows\\System32\\drivers\\etc\\hosts\`
   - Add these lines:
     ```
     127.0.0.1 ${CLIENT_ID}.localhost
     127.0.0.1 traefik.${CLIENT_ID}.localhost
     ```
   - Save the file

2. **Direct IP Access**
   - If hostname resolution doesn't work, use direct IP access:
     - [http://${WINDOWS_HOST_IP}:80](http://${WINDOWS_HOST_IP}:80)
     - Add the Host header \`${CLIENT_ID}.localhost\` in browser developer tools

## Troubleshooting

1. **Check Traefik logs**:
   ```bash
   docker logs ${CLIENT_ID}_traefik
   ```

2. **Restart WSL**:
   ```powershell
   wsl --shutdown
   ```

3. **Check Docker Network**:
   ```bash
   docker network inspect ${CLIENT_ID}_traefik_network
   ```
EOL

log_info "Windows browser access fix completed"
log_info "To access from Windows browser, follow instructions in: ${INSTALL_DIR}/windows_browser_access.md"
